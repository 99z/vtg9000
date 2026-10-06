#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
quartus_image=${QUARTUS_IMAGE:-docker.io/theypsilon/quartus-lite-c5:17.0.2.docker0}
output_dir=${QUARTUS_OUTPUT_DIR:-"$project_dir/build/quartus"}
if [ -e "$output_dir" ]; then
	echo "Refusing to replace existing build directory: $output_dir" >&2
	exit 1
fi

stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/vtg9000-quartus.XXXXXX")

cleanup() {
	rm -rf -- "$stage_dir"
}
trap cleanup EXIT HUP INT TERM

if ! command -v podman >/dev/null 2>&1; then
	echo "podman is required (Ubuntu: sudo apt-get install -y podman)" >&2
	exit 1
fi

# Stage only compiler inputs. In particular, never expose .local/ (which may
# contain the dedicated MiSTer SSH key) or firmware/reference files to a
# third-party container image.
cp "$project_dir/VTG9000.qpf" "$stage_dir/"
cp "$project_dir/VTG9000.qsf" "$stage_dir/"
cp "$project_dir/VTG9000.sdc" "$stage_dir/"
cp "$project_dir/VTG9000.srf" "$stage_dir/"
cp "$project_dir/VTG9000.sv" "$stage_dir/"
cp "$project_dir/files.qip" "$stage_dir/"
cp "$project_dir/tools/quartus_timing_reports.tcl" "$stage_dir/"
cp -R "$project_dir/rtl" "$stage_dir/"
cp -R "$project_dir/sys" "$stage_dir/"

# Hash the source snapshot before Quartus rewrites project-version metadata.
record_inputs() {
    (cd "$stage_dir" && find rtl sys -type f -print0 | sort -z | xargs -0 sha256sum;
        cd "$stage_dir" && sha256sum VTG9000.qpf VTG9000.qsf VTG9000.sdc VTG9000.srf VTG9000.sv files.qip quartus_timing_reports.tcl)
}
record_inputs > "$stage_dir/source-inputs.sha256"

# Pull separately, then disable networking while the image can see sources.
podman pull "$quartus_image"
compile_status=0
podman run --rm --userns=keep-id \
	--network none \
	--security-opt no-new-privileges \
	--cap-drop all \
	--volume "$stage_dir:/build:Z" \
	--workdir /build \
	"$quartus_image" \
	/bin/sh -c '/opt/intelFPGA_lite/quartus/bin/quartus_sh --flow compile VTG9000.qpf && /opt/intelFPGA_lite/quartus/bin/quartus_sta -t quartus_timing_reports.tcl' || compile_status=$?

# Retain diagnostics even when compilation or timing validation fails.
if [ -d "$stage_dir/output_files" ]; then
    mkdir -p "$output_dir"
    cp -R "$stage_dir/output_files/." "$output_dir/"
    cp "$stage_dir/source-inputs.sha256" "$output_dir/"
    record_inputs > "$output_dir/compiler-inputs.sha256"
    cp "$stage_dir/VTG9000.qsf" "$output_dir/compiled-VTG9000.qsf"
fi
if [ "$compile_status" -eq 0 ]; then
    python3 "$project_dir/tools/check_quartus_timing.py" "$output_dir/VTG9000.sta.summary" || compile_status=$?
fi
exit "$compile_status"

#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
quartus_image=${QUARTUS_IMAGE:-docker.io/theypsilon/quartus-lite-c5:17.0.2.docker0}
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
cp -R "$project_dir/rtl" "$stage_dir/"
cp -R "$project_dir/sys" "$stage_dir/"

# Pull separately, then disable networking while the image can see sources.
podman pull "$quartus_image"
podman run --rm --userns=keep-id \
	--network none \
	--security-opt no-new-privileges \
	--cap-drop all \
	--volume "$stage_dir:/build:Z" \
	--workdir /build \
	"$quartus_image" \
	/opt/intelFPGA_lite/quartus/bin/quartus_sh --flow compile VTG9000.qpf

output_dir="$project_dir/build/quartus"
rm -rf -- "$output_dir"
mkdir -p "$output_dir"
cp -R "$stage_dir/output_files/." "$output_dir/"

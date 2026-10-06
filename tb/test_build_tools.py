# SPDX-License-Identifier: GPL-2.0-or-later
"""Build-workflow regression checks; no Quartus invocation or FPGA build."""
import importlib.util
from hashlib import sha256
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from shutil import copyfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("timing", ROOT / "tools/check_quartus_timing.py")
timing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(timing)


def summary(slack="0.100", omit=None):
    return "\n\n".join(
        f"Type  : {kind} 'test_clock'\nSlack : {slack}\nTNS   : 0.000"
        for kind in sorted(timing.REQUIRED) if kind != omit
    ) + "\n"


class TimingChecks(unittest.TestCase):
    def check(self, content):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary"
            path.write_text(content)
            timing.check_summary(path)

    def test_passing_and_zero_slack(self):
        self.check(summary())
        self.check(summary("0.000"))

    def test_any_clock_violation_fails(self):
        with self.assertRaisesRegex(ValueError, "Timing violations"):
            self.check(summary() + "Type : Setup 'second_clock'\nSlack : -0.001\n")

    def test_missing_or_corrupt_reports_fail(self):
        for content in ["", summary(omit="Removal"), summary().replace("Slack", "Lost")]:
            with self.subTest(content=content), self.assertRaises(ValueError):
                self.check(content)

    def test_non_finite_slack_fails(self):
        for slack in ["nan", "inf", "-inf"]:
            with self.subTest(slack=slack), self.assertRaises(ValueError):
                self.check(summary(slack))


class WrapperChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ["tools", "rtl", "sys", ".local", "fw", "bin"]:
            (self.root / directory).mkdir()
        for filename in ["VTG9000.qpf", "VTG9000.qsf", "VTG9000.sdc", "VTG9000.srf", "VTG9000.sv", "files.qip", "rtl/core.sv", "sys/framework.sv"]:
            (self.root / filename).write_text("original source\n")
        (self.root / ".local/private-marker").write_text("synthetic fixture")
        (self.root / "fw/private-marker").write_text("synthetic fixture")
        for filename in ["quartus_container_build.sh", "quartus_timing_reports.tcl", "check_quartus_timing.py"]:
            copyfile(ROOT / "tools" / filename, self.root / "tools" / filename)
        self.podman = self.root / "bin/podman"
        self.podman.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
if sys.argv[1] == "pull":
    sys.exit(0)
args=sys.argv[1:]
stage=Path(args[args.index("--volume")+1].split(":")[0])
assert not (stage/".local").exists()
assert not (stage/"fw").exists()
assert (stage/"source-inputs.sha256").exists()
(stage/"VTG9000.qsf").write_text("compiler metadata update\\n")
out=stage/"output_files"
out.mkdir()
(out/"VTG9000.sta.summary").write_text(os.environ["MOCK_TIMING"])
(out/"VTG9000.rbf").write_text("synthetic fixture, not an FPGA bitstream\\n")
sys.exit(int(os.environ.get("MOCK_COMPILE_STATUS", "0")))
''')
        self.podman.chmod(0o755)
        self.output = self.root / "results"
        self.environment = dict(os.environ, PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                                QUARTUS_OUTPUT_DIR=str(self.output), MOCK_TIMING=summary())

    def run_wrapper(self):
        return subprocess.run(["sh", str(self.root / "tools/quartus_container_build.sh")],
                              env=self.environment, capture_output=True, text=True)

    def test_preserves_source_and_compiler_manifests(self):
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotEqual((self.output / "source-inputs.sha256").read_text(),
                            (self.output / "compiler-inputs.sha256").read_text())
        for line in (self.output / "source-inputs.sha256").read_text().splitlines():
            digest, name = line.split(None, 1)
            source = self.root / ("tools/" + name if name == "quartus_timing_reports.tcl" else name)
            self.assertEqual(digest, sha256(source.read_bytes()).hexdigest(), name)
        self.assertEqual((self.output / "compiled-VTG9000.qsf").read_text(), "compiler metadata update\n")

    def test_timing_failure_retains_diagnostics(self):
        self.environment["MOCK_TIMING"] = summary("-0.001")
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Timing violations", result.stderr)
        self.assertTrue((self.output / "VTG9000.sta.summary").exists())

    def test_compile_failure_retains_status_and_diagnostics(self):
        self.environment["MOCK_COMPILE_STATUS"] = "23"
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 23)
        self.assertTrue((self.output / "source-inputs.sha256").exists())

    def test_existing_output_is_not_replaced(self):
        self.output.mkdir()
        marker = self.output / "keep"
        marker.write_text("original")
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker.read_text(), "original")
        self.assertFalse((self.output / "VTG9000.rbf").exists())

    def test_default_output_is_also_protected(self):
        self.environment.pop("QUARTUS_OUTPUT_DIR")
        default = self.root / "build/quartus"
        default.mkdir(parents=True)
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to replace", result.stderr)


if __name__ == "__main__":
    unittest.main()

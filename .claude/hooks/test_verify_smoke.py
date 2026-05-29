#!/usr/bin/env python3
"""Tests for verify-smoke.py (INTEGRATION_SMOKE evidence backstop).

Zero-dep stdlib unittest. Run:  python3 .claude/hooks/test_verify_smoke.py
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stderr
from pathlib import Path

_HOOK = Path(__file__).parent / "verify-smoke.py"
_spec = importlib.util.spec_from_file_location("verify_smoke", _HOOK)
mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mod)  # type: ignore

HEAD = "abc1234"


def run_main(cwd: Path, head_sha: str | None = HEAD):
    if head_sha is None:
        os.environ.pop("SMOKE_VERIFY_HEAD_SHA", None)
    else:
        os.environ["SMOKE_VERIFY_HEAD_SHA"] = head_sha
    payload = json.dumps({"cwd": str(cwd)})
    old = sys.stdin
    sys.stdin = io.StringIO(payload)
    err = io.StringIO()
    try:
        with redirect_stderr(err):
            rc = mod.main()
    finally:
        sys.stdin = old
    return rc, err.getvalue()


def scaffold(tmp: Path, status: str, *, with_archive=True, with_section=True,
             artifact=True, sha=HEAD, markers=True, result_ok=True,
             boot_sha=None):
    phases = tmp / ".project" / "phases"
    qa = tmp / ".project" / "qa-runs"
    phases.mkdir(parents=True, exist_ok=True)
    qa.mkdir(parents=True, exist_ok=True)
    (phases / "phase-03-auth.md").write_text(
        f"---\nphase_id: 03\nslug: auth\nstatus: {status}\n---\n# Goal\nx\n")
    if not with_archive:
        return tmp
    log_name = f"smoke-03-{sha}-1716981234.log"
    if with_section:
        inner = f"- artifact: `.project/qa-runs/{log_name}`\n- result: PASS\n" \
            if artifact else "ran smoke, all good (no path)\n"
        sect = f"## Integration Smoke\n{inner}"
    else:
        sect = ""  # no section header at all
    (phases / "phase-03-auth-archive.md").write_text(
        f"## Decisions Log\n\n{sect}\n## Smoke Test Log\n\n## Handoff Notes\n")
    if artifact:
        bs = boot_sha if boot_sha is not None else sha
        body = ""
        if markers:
            body += f"BOOT_OK flavor=dev sha={bs} ts=2026-05-29T10:00:00\n"
            body += f"FIRST_SCREEN_OK route=/home sha={bs}\n"
        body += f"SMOKE_RESULT exit={'0' if result_ok else '1'} sha={sha}\n"
        (qa / log_name).write_text(body)
    return tmp


class SkipCases(unittest.TestCase):
    def test_pre_gate_status_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "IN_PROGRESS", with_archive=False)
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 0)

    def test_done_skipped_even_without_evidence(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "DONE", with_archive=False)
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 0)

    def test_no_phases_dir(self):
        with tempfile.TemporaryDirectory() as d:
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 0)


class ValidEvidence(unittest.TestCase):
    def test_integration_smoke_valid_passes(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE")
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 0)

    def test_later_state_valid_passes(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "COMPLIANCE_CHECK")
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 0)

    def test_git_unavailable_skips_sha_but_passes_on_markers(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "QA_SMOKE_TEST")
            rc, _ = run_main(Path(d), head_sha=None)  # no git, no override
            self.assertEqual(rc, 0)


class MissingOrForged(unittest.TestCase):
    def test_no_archive_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", with_archive=False)
            rc, err = run_main(Path(d))
            self.assertEqual(rc, 2)
            self.assertIn("archive", err.lower())

    def test_no_section_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", with_section=False)
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 2)

    def test_section_without_artifact_ref_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", artifact=False)
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 2)

    def test_referenced_artifact_missing_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE")
            # delete the log the archive points to
            for f in (Path(d) / ".project" / "qa-runs").glob("*.log"):
                f.unlink()
            rc, _ = run_main(Path(d))
            self.assertEqual(rc, 2)

    def test_missing_boot_ok_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", markers=False)
            rc, err = run_main(Path(d))
            self.assertEqual(rc, 2)
            self.assertIn("BOOT_OK", err)

    def test_smoke_result_nonzero_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", result_ok=False)
            rc, err = run_main(Path(d))
            self.assertEqual(rc, 2)
            self.assertIn("SMOKE_RESULT", err)

    def test_filename_sha_mismatch_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", sha="deadbee")
            rc, err = run_main(Path(d), head_sha="abc1234")
            self.assertEqual(rc, 2)
            self.assertIn("eski koda", err)

    def test_boot_marker_sha_mismatch_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            scaffold(Path(d), "INTEGRATION_SMOKE", sha="abc1234", boot_sha="0000000")
            rc, err = run_main(Path(d), head_sha="abc1234")
            self.assertEqual(rc, 2)
            self.assertIn("forge", err.lower())

    def test_stale_vs_source_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            scaffold(tmp, "INTEGRATION_SMOKE")
            # make a lib/ source file NEWER than the smoke artifact
            lib = tmp / "lib"
            lib.mkdir()
            log = next((tmp / ".project" / "qa-runs").glob("*.log"))
            old = time.time() - 600
            os.utime(log, (old, old))
            (lib / "main.dart").write_text("void main(){}\n")  # mtime = now
            rc, err = run_main(tmp)
            self.assertEqual(rc, 2)
            self.assertIn("ESKİ", err)


if __name__ == "__main__":
    unittest.main(verbosity=2)

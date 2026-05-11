"""Unit tests for validate-phase-state.py.

Run with:
    python3 .claude/hooks/test_validate_phase_state.py

Or via pytest if installed:
    pytest .claude/hooks/test_validate_phase_state.py

Zero-dep: uses unittest from the standard library so it runs anywhere.
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location(
    "validate_phase_state", HERE / "validate-phase-state.py"
)
assert SPEC is not None and SPEC.loader is not None
mod = importlib.util.module_from_spec(SPEC)
sys.modules["validate_phase_state"] = mod
SPEC.loader.exec_module(mod)


# ----- helpers -----

def _phase(status="PLANNED", owner="task-planner", missing_section=None,
           extra_frontmatter=""):
    """Generate a syntactically valid phase file for tests."""
    sections = [
        "## Goal", "## Acceptance Criteria", "## Tasks", "## Decisions Log",
        "## Skipped Steps", "## Open Questions", "## Smoke Test Log",
        "## Handoff Notes",
    ]
    if missing_section:
        sections = [s for s in sections if s != missing_section]
    body = "\n\n".join(f"{s}\n\n(content)" for s in sections)
    fm = f"""---
phase_id: 03
title: Test Phase
slug: test-phase
status: {status}
depends_on: [01, 02]
unblocks: [04]
owner_agent: {owner}
created: 2026-05-10
last_updated: 2026-05-10
last_reconciled: 2026-05-10
skills_used: []
skills_to_extract: []
risk_score: null
user_approved: false
linked_frs: [FR-01]
estimated_tasks: 5
estimated_files: 8
walking_skeleton_invariant: "app builds"
{extra_frontmatter}---

{body}
"""
    return fm


# ----- inline-comment stripper -----

class TestStripInlineComment(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(mod._strip_inline_comment("false  # comment"), "false")

    def test_no_comment(self):
        self.assertEqual(mod._strip_inline_comment("true"), "true")

    def test_hash_in_double_quotes(self):
        self.assertEqual(mod._strip_inline_comment('"hex #ff0000"'), '"hex #ff0000"')

    def test_hash_in_single_quotes(self):
        self.assertEqual(mod._strip_inline_comment("'value # not-comment'"), "'value # not-comment'")

    def test_hash_no_leading_space(self):
        # `value#x` should NOT be treated as comment (no whitespace before #)
        self.assertEqual(mod._strip_inline_comment("value#x"), "value#x")

    def test_hash_at_start(self):
        self.assertEqual(mod._strip_inline_comment("# whole line"), "")


# ----- frontmatter parser (mini) -----

class TestMiniFrontmatter(unittest.TestCase):
    def test_flat_keys(self):
        out = mod._mini_parse_frontmatter("phase_id: 03\nstatus: PLANNED")
        self.assertEqual(out["phase_id"], "03")
        self.assertEqual(out["status"], "PLANNED")

    def test_list(self):
        out = mod._mini_parse_frontmatter("depends_on: [01, 02, 03]")
        self.assertEqual(out["depends_on"], ["01", "02", "03"])

    def test_empty_list(self):
        out = mod._mini_parse_frontmatter("depends_on: []")
        self.assertEqual(out["depends_on"], [])

    def test_bool(self):
        out = mod._mini_parse_frontmatter("user_approved: false\nauto_approve: true")
        self.assertIs(out["user_approved"], False)
        self.assertIs(out["auto_approve"], True)

    def test_null_variants(self):
        out = mod._mini_parse_frontmatter("a: null\nb: ~\nc:")
        self.assertIsNone(out["a"])
        self.assertIsNone(out["b"])
        self.assertIsNone(out["c"])

    def test_inline_comment(self):
        out = mod._mini_parse_frontmatter("auto_approve: false   # bypass off")
        self.assertIs(out["auto_approve"], False)

    def test_full_line_comment(self):
        out = mod._mini_parse_frontmatter("# comment\nphase_id: 01")
        self.assertEqual(out["phase_id"], "01")

    def test_blank_line(self):
        out = mod._mini_parse_frontmatter("a: 1\n\nb: 2")
        self.assertEqual(out["a"], "1")
        self.assertEqual(out["b"], "2")


# ----- phase file validation -----

class TestValidatePhase(unittest.TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())

    def _write_phase(self, content: str) -> Path:
        p = self.tmpdir / "phase-03-test.md"
        p.write_text(content, encoding="utf-8")
        return p

    def test_valid_phase(self):
        p = self._write_phase(_phase())
        errors = mod.validate_phase(p)
        self.assertEqual(errors, [], f"Expected no errors, got: {errors}")

    def test_missing_decisions_log(self):
        p = self._write_phase(_phase(missing_section="## Decisions Log"))
        errors = mod.validate_phase(p)
        self.assertTrue(any("Decisions Log" in e for e in errors))

    def test_invalid_status(self):
        p = self._write_phase(_phase(status="WEIRD_STATE"))
        errors = mod.validate_phase(p)
        self.assertTrue(any("WEIRD_STATE" in e for e in errors))

    def test_owner_status_mismatch(self):
        # PLANNED must be owned by task-planner / orchestrator / app-bootstrap / coder.
        # Using "performance-reviewer" should fail.
        p = self._write_phase(_phase(status="PLANNED", owner="performance-reviewer"))
        errors = mod.validate_phase(p)
        self.assertTrue(any("PLANNED" in e and "performance-reviewer" in e for e in errors))

    def test_unknown_owner_agent(self):
        p = self._write_phase(_phase(owner="not-a-real-agent"))
        errors = mod.validate_phase(p)
        self.assertTrue(any("not-a-real-agent" in e for e in errors))


# ----- doc validation -----

class TestValidateDoc(unittest.TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())

    def _write(self, name: str, body: str) -> Path:
        p = self.tmpdir / name
        p.write_text(body, encoding="utf-8")
        return p

    def test_valid_prd(self):
        body = """---
doc_type: prd
app_name: TestApp
version: 1.0
status: approved
---

# TestApp PRD
"""
        p = self._write("prd.md", body)
        self.assertEqual(mod.validate_doc(p, "prd"), [])

    def test_prd_missing_status(self):
        body = """---
doc_type: prd
app_name: TestApp
version: 1.0
---

# TestApp PRD
"""
        p = self._write("prd.md", body)
        errors = mod.validate_doc(p, "prd")
        self.assertTrue(any("status" in e for e in errors))

    def test_prd_invalid_status(self):
        body = """---
doc_type: prd
app_name: TestApp
version: 1.0
status: maybe-approved
---
"""
        p = self._write("prd.md", body)
        errors = mod.validate_doc(p, "prd")
        self.assertTrue(any("maybe-approved" in e for e in errors))

    def test_architecture_triggers_must_be_bool(self):
        body = """---
doc_type: architecture
app_name: TestApp
version: 1.0
status: approved
triggers_api_design: yes-please
---
"""
        p = self._write("architecture.md", body)
        errors = mod.validate_doc(p, "architecture")
        self.assertTrue(any("triggers_api_design" in e for e in errors))

    def test_architecture_triggers_bool_ok(self):
        for value in ("true", "false"):
            body = f"""---
doc_type: architecture
app_name: TestApp
version: 1.0
status: approved
triggers_api_design: {value}
---
"""
            p = self._write(f"architecture-{value}.md", body)
            errors = mod.validate_doc(p, "architecture")
            self.assertEqual(errors, [], f"Expected no errors for {value}, got: {errors}")

    def test_doc_no_frontmatter(self):
        p = self._write("prd.md", "# Just a header, no frontmatter\n")
        errors = mod.validate_doc(p, "prd")
        self.assertTrue(any("frontmatter eksik" in e for e in errors))

    def test_doc_missing_file(self):
        # Non-existent file → no errors (validate_doc tolerates absence)
        p = self.tmpdir / "nope.md"
        self.assertEqual(mod.validate_doc(p, "prd"), [])


# ----- decisions.md validation -----

class TestValidateDecisions(unittest.TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())

    def _write(self, body: str) -> Path:
        p = self.tmpdir / "decisions.md"
        p.write_text(body, encoding="utf-8")
        return p

    def test_valid(self):
        p = self._write("---\nauto_approve: false\n---\n\n# decisions\n")
        self.assertEqual(mod.validate_decisions(p), [])

    def test_inline_comment_works(self):
        # F2-02 + bonus inline-comment fix: this used to fail
        p = self._write("---\nauto_approve: false   # bypass off\n---\n")
        self.assertEqual(mod.validate_decisions(p), [])

    def test_missing_flag(self):
        p = self._write("---\nfoo: bar\n---\n")
        errors = mod.validate_decisions(p)
        self.assertTrue(any("auto_approve" in e for e in errors))

    def test_non_bool_value(self):
        p = self._write("---\nauto_approve: maybe\n---\n")
        errors = mod.validate_decisions(p)
        self.assertTrue(any("bool olmalı" in e for e in errors))

    def test_no_frontmatter(self):
        p = self._write("# decisions\n\nno frontmatter\n")
        errors = mod.validate_decisions(p)
        self.assertTrue(any("frontmatter eksik" in e for e in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)

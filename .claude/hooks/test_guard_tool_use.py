#!/usr/bin/env python3
"""Tests for guard-tool-use.py (PreToolUse mechanical guardrail).

Zero-dep stdlib unittest. Run:  python3 .claude/hooks/test_guard_tool_use.py
"""

from __future__ import annotations

import importlib.util
import io
import json
import unittest
from contextlib import redirect_stdout
from pathlib import Path

# Load the hook module by path (it has a hyphenated filename).
_HOOK = Path(__file__).parent / "guard-tool-use.py"
_spec = importlib.util.spec_from_file_location("guard_tool_use", _HOOK)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)  # type: ignore

CWD = "/Users/dev/app"


def run(payload: dict):
    """Run evaluate(); return (denied: bool, reason: str|None)."""
    buf = io.StringIO()
    denied = False
    reason = None
    try:
        with redirect_stdout(buf):
            guard.evaluate(payload)
    except SystemExit:
        denied = True
        out = buf.getvalue().strip()
        if out:
            reason = json.loads(out)["hookSpecificOutput"]["permissionDecisionReason"]
    return denied, reason


def write(agent, path, tool="Edit"):
    return {
        "agent_type": agent, "tool_name": tool, "cwd": CWD,
        "tool_input": {"file_path": path},
    }


class ArchitectureAuthority(unittest.TestCase):
    def test_non_architect_blocked_from_architecture_md(self):
        denied, _ = run(write("coder", f"{CWD}/.project/architecture.md"))
        self.assertTrue(denied)

    def test_non_architect_blocked_from_arch_slice(self):
        denied, _ = run(write("security-reviewer", f"{CWD}/.project/arch/04-security-and-secrets.md"))
        self.assertTrue(denied)

    def test_architect_allowed(self):
        denied, _ = run(write("architect", f"{CWD}/.project/arch/01-foundation.md"))
        self.assertFalse(denied)

    def test_relative_path_also_caught(self):
        denied, _ = run({
            "agent_type": "task-planner", "tool_name": "Write", "cwd": CWD,
            "tool_input": {"file_path": ".project/architecture.md"},
        })
        self.assertTrue(denied)


class ReadOnlyReviewers(unittest.TestCase):
    def test_reviewer_blocked_from_lib(self):
        for agent in guard.READ_ONLY_REVIEWERS:
            denied, _ = run(write(agent, f"{CWD}/lib/feature/foo.dart"))
            self.assertTrue(denied, f"{agent} should be blocked from lib/")

    def test_reviewer_blocked_from_test_and_native(self):
        for path in ("test/foo_test.dart", "ios/Runner/AppDelegate.swift",
                     "android/app/build.gradle", "integration_test/x_test.dart"):
            denied, _ = run(write("code-reviewer", f"{CWD}/{path}"))
            self.assertTrue(denied, f"reviewer should be blocked from {path}")

    def test_reviewer_allowed_to_edit_phase_file(self):
        denied, _ = run(write("security-reviewer", f"{CWD}/.project/phases/phase-03-auth.md"))
        self.assertFalse(denied)

    def test_reviewer_allowed_to_edit_checklist(self):
        denied, _ = run(write("compliance", f"{CWD}/.project/compliance-checklist.md"))
        self.assertFalse(denied)

    def test_reviewer_bash_not_blocked(self):
        # Reviewers legitimately run read-only Bash (analyze, grep, test).
        denied, _ = run({"agent_type": "security-reviewer", "tool_name": "Bash",
                         "cwd": CWD, "tool_input": {"command": "flutter analyze"}})
        self.assertFalse(denied)


class CoderAndTestWriter(unittest.TestCase):
    def test_coder_allowed_in_lib(self):
        denied, _ = run(write("coder", f"{CWD}/lib/feature/foo.dart"))
        self.assertFalse(denied)

    def test_test_writer_allowed_in_test(self):
        denied, _ = run(write("test-writer", f"{CWD}/test/foo_test.dart"))
        self.assertFalse(denied)


class Orchestrator(unittest.TestCase):
    def test_orchestrator_bash_blocked(self):
        denied, _ = run({"agent_type": "orchestrator", "tool_name": "Bash",
                         "cwd": CWD, "tool_input": {"command": "ls"}})
        self.assertTrue(denied)

    def test_orchestrator_blocked_from_lib(self):
        denied, _ = run(write("orchestrator", f"{CWD}/lib/main.dart"))
        self.assertTrue(denied)

    def test_orchestrator_allowed_phase_frontmatter(self):
        denied, _ = run(write("orchestrator", f"{CWD}/.project/phases/phase-01-foundation.md"))
        self.assertFalse(denied)


class MainSessionDeferred(unittest.TestCase):
    def test_no_agent_type_never_blocked(self):
        # Main / human session: agent_type absent → defer on everything.
        denied, _ = run({"tool_name": "Edit", "cwd": CWD,
                         "tool_input": {"file_path": f"{CWD}/.project/architecture.md"}})
        self.assertFalse(denied)

    def test_unknown_agent_type_deferred(self):
        denied, _ = run(write("Explore", f"{CWD}/lib/main.dart"))
        self.assertFalse(denied)


if __name__ == "__main__":
    unittest.main(verbosity=2)

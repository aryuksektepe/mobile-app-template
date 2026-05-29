#!/usr/bin/env python3
"""
PreToolUse guardrail hook — mechanically enforces the per-agent prohibitions
that CLAUDE.md states in prose (and that, until now, relied on the model
obeying). A written rule is advisory; a hook is deterministic. (See CLAUDE.md
§11 write-authority, §4 agent lanes, and the read-only-reviewer contracts.)

Fires on PreToolUse for Write / Edit / MultiEdit / NotebookEdit / Bash.
Uses the `agent_type` field that Claude Code injects into the PreToolUse
payload when the tool call originates inside a subagent. When `agent_type`
is absent (the main / human-driven session) the hook DEFERS — it never
constrains the operator, only the pipeline subagents.

Enforced rules:
  1. Architecture write-authority (CLAUDE.md §11): ONLY `architect` may write
     `.project/architecture.md` or anything under `.project/arch/`. Every other
     pipeline subagent is blocked from modifying them.
  2. Read-only reviewers (code-reviewer, bug-hunter, security-reviewer,
     performance-reviewer, compliance) may NOT modify production code
     (lib/ test/ integration_test/ ios/ android/). They bounce fixes to the
     coder via findings. They MAY still edit phase files / rolling checklists
     under .project/ (their verdict blocks) — those are not production code.
  3. Orchestrator (CLAUDE.md §4 / orchestrator prohibitions): no Bash at all
     (it only routes), and no writing of production code.

Output contract (PreToolUse):
  - On violation: print a JSON object with hookSpecificOutput.permissionDecision
    = "deny" and a reason, then exit 0.
  - Otherwise: exit 0 silently → normal permission flow ("defer") applies.

Zero external deps — stdlib only.
"""

from __future__ import annotations

import json
import os
import sys

# --- Rule tables -----------------------------------------------------------

WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

READ_ONLY_REVIEWERS = {
    "code-reviewer",
    "bug-hunter",
    "security-reviewer",
    "performance-reviewer",
    "compliance",
}

# Top-level dirs that constitute "production / native code" a reviewer or the
# orchestrator must never modify.
PRODUCTION_DIRS = {"lib", "test", "integration_test", "ios", "android"}

# The full pipeline roster (mirrors validate-phase-state.py VALID_AGENTS minus
# "user"). We only enforce when agent_type is a known pipeline agent — an
# unknown / absent agent_type means main session → defer.
PIPELINE_AGENTS = {
    "orchestrator", "product-analyst", "architect", "ux-designer",
    "task-planner", "app-bootstrap", "api-design", "coder", "test-writer",
    "code-reviewer", "bug-hunter", "bug-report-handler", "security-reviewer",
    "performance-reviewer", "compliance", "localization", "crash-monitor",
    "db-migration", "qa-test-guide", "feature-chronicler", "aso",
    "skill-extractor", "release-manager",
}


def _rel_to_cwd(path: str, cwd: str) -> str:
    """Best-effort path relative to project root, using forward slashes."""
    if not path:
        return ""
    p = path.replace("\\", "/")
    c = (cwd or "").replace("\\", "/").rstrip("/")
    if c and p.startswith(c + "/"):
        p = p[len(c) + 1:]
    return p.lstrip("/")


def _is_production_path(path: str, cwd: str) -> bool:
    rel = _rel_to_cwd(path, cwd)
    if not rel:
        return False
    head = rel.split("/", 1)[0]
    return head in PRODUCTION_DIRS


def _is_architecture_path(path: str, cwd: str) -> bool:
    rel = _rel_to_cwd(path, cwd)
    if not rel:
        return False
    return rel == ".project/architecture.md" or rel.startswith(".project/arch/")


def _deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def evaluate(payload: dict) -> None:
    agent = payload.get("agent_type")
    # Main / human session, or an agent outside the pipeline → never constrain.
    if not agent or agent not in PIPELINE_AGENTS:
        return

    tool = payload.get("tool_name", "")
    tin = payload.get("tool_input") or {}
    cwd = payload.get("cwd", "") or os.getcwd()
    target = tin.get("file_path", "") if isinstance(tin, dict) else ""

    # Rule 3a: orchestrator runs no Bash — it only routes.
    if agent == "orchestrator" and tool == "Bash":
        _deny(
            "orchestrator is a router and MUST NOT run Bash (CLAUDE.md §4 / "
            "orchestrator prohibitions). Dispatch the right subagent instead."
        )

    if tool in WRITE_TOOLS:
        # Rule 1: architecture single-source-of-truth — architect only.
        if agent != "architect" and _is_architecture_path(target, cwd):
            _deny(
                f"'{agent}' is READ-ONLY on .project/architecture.md and "
                ".project/arch/* — only 'architect' has write authority "
                "(CLAUDE.md §11). Post-approval changes go through an ADR."
            )

        # Rule 2: read-only reviewers never touch production code.
        if agent in READ_ONLY_REVIEWERS and _is_production_path(target, cwd):
            _deny(
                f"'{agent}' is a read-only reviewer and MUST NOT modify "
                f"production code ('{_rel_to_cwd(target, cwd)}'). File a "
                "BLOCKER finding and bounce the fix to 'coder'."
            )

        # Rule 3b: orchestrator never writes production code either.
        if agent == "orchestrator" and _is_production_path(target, cwd):
            _deny(
                "orchestrator MUST NOT write production code "
                f"('{_rel_to_cwd(target, cwd)}') — it only routes and edits "
                "phase frontmatter. Dispatch 'coder'."
            )


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        # Malformed payload — fail open (defer) rather than block everything.
        return 0
    try:
        evaluate(payload)  # may sys.exit(0) on deny
    except SystemExit:
        raise
    except Exception:
        # Never let a guard bug hard-block the pipeline; defer on internal error.
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())

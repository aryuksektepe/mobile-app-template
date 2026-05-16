#!/usr/bin/env python3
"""
Phase + project doc state validator hook.

Runs on Stop / SubagentStop events. Validates:
  1. .project/prd.md frontmatter (status, doc_type, etc.)
  2. .project/architecture.md frontmatter (status, triggers_api_design)
  3. Every active (non-DONE) .project/phases/phase-*.md file

Exit codes:
  0  → all good (silent)
  2  → state inconsistency detected; Claude is asked to fix before stopping

Validation rules (from CLAUDE.md):
  - PRD + architecture MUST have YAML frontmatter with status field
  - architecture MUST have triggers_api_design as bool
  - Phase frontmatter must be well-formed YAML with all required keys
  - status must be one of the valid pipeline states
  - owner_agent must be one of the known 23 agents
  - owner_agent must match what is allowed for the current status
  - Required body sections must exist (Goal, Acceptance Criteria, Tasks,
    Decisions Log, Skipped Steps, Open Questions, Smoke Test Log, Handoff Notes)
  - If any state was skipped, ## Skipped Steps must explain why
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

# Prefer pyyaml when available (handles multi-line scalars, anchors, nested maps).
# Fall back to the bundled mini parser when not — keeps the hook zero-dep by default
# but lets richer YAML "just work" if the user installs pyyaml.
try:
    import yaml as _yaml  # type: ignore
    _HAS_PYYAML = True
except ImportError:
    _yaml = None
    _HAS_PYYAML = False

VALID_STATUSES = {
    "DRAFT",
    "PLANNED",
    "BOOTSTRAPPING",
    "IN_PROGRESS",
    "TESTS_WRITTEN",
    "CODE_REVIEW",
    "BUG_HUNT",
    "SECURITY_REVIEW",
    "PERFORMANCE_REVIEW",
    "COMPLIANCE_CHECK",
    "BUILD_VERIFIED",
    "QA_SMOKE_TEST",
    "USER_APPROVAL",
    "CHRONICLED",
    "SKILL_EXTRACTED",
    "DONE",
}

VALID_AGENTS = {
    "orchestrator",
    "product-analyst",
    "architect",
    "ux-designer",
    "task-planner",
    "app-bootstrap",
    "api-design",
    "coder",
    "test-writer",
    "code-reviewer",
    "bug-hunter",
    "bug-report-handler",
    "security-reviewer",
    "performance-reviewer",
    "compliance",
    "localization",
    "crash-monitor",
    "db-migration",
    "qa-test-guide",
    "feature-chronicler",
    "aso",
    "skill-extractor",
    "release-manager",
    "user",
}

STATUS_TO_OWNER = {
    "DRAFT": {"task-planner", "product-analyst"},
    "PLANNED": {"orchestrator", "task-planner", "app-bootstrap", "coder"},
    "BOOTSTRAPPING": {"app-bootstrap"},
    "IN_PROGRESS": {"coder"},
    "TESTS_WRITTEN": {"test-writer", "code-reviewer"},
    "CODE_REVIEW": {"code-reviewer"},
    "BUG_HUNT": {"bug-hunter", "coder"},
    "SECURITY_REVIEW": {"security-reviewer"},
    "PERFORMANCE_REVIEW": {"performance-reviewer"},
    "COMPLIANCE_CHECK": {"compliance"},
    "BUILD_VERIFIED": {"orchestrator", "app-bootstrap", "coder", "qa-test-guide"},
    "QA_SMOKE_TEST": {"qa-test-guide"},
    "USER_APPROVAL": {"user", "qa-test-guide"},
    "CHRONICLED": {"feature-chronicler"},
    "SKILL_EXTRACTED": {"skill-extractor"},
    "DONE": {"orchestrator", "skill-extractor"},
}

REQUIRED_FRONTMATTER_KEYS = {
    "phase_id",
    "title",
    "slug",
    "status",
    "depends_on",
    "unblocks",
    "owner_agent",
    "created",
    "last_updated",
    "last_reconciled",
    "skills_used",
    "skills_to_extract",
    "risk_score",
    "user_approved",
    "linked_frs",
    "estimated_tasks",
    "estimated_files",
    "walking_skeleton_invariant",
}

REQUIRED_BODY_SECTIONS = [
    "## Goal",
    "## Acceptance Criteria",
    "## Tasks",
    "## Decisions Log",
    "## Skipped Steps",
    "## Open Questions",
    "## Build Verification",
    "## Smoke Test Log",
    "## Handoff Notes",
]

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _strip_inline_comment(value: str) -> str:
    """Strip a trailing ` # comment` from a YAML scalar value.

    Respects quoted strings: a `#` inside single/double quotes is literal.
    """
    in_single = False
    in_double = False
    for i, ch in enumerate(value):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            # Comment only valid if preceded by whitespace or at start
            if i == 0 or value[i - 1].isspace():
                return value[:i].rstrip()
    return value


def parse_frontmatter(text: str) -> dict | None:
    """Parse YAML frontmatter.

    Uses pyyaml when available (handles multi-line scalars, anchors, nested maps).
    Falls back to a tiny YAML-subset parser otherwise.
    """
    match = FRONTMATTER_RE.match(text)
    if not match:
        return None
    raw = match.group(1)

    if _HAS_PYYAML:
        try:
            loaded = _yaml.safe_load(raw)
            if isinstance(loaded, dict):
                return loaded
            # If pyyaml returns something non-dict, fall through to mini parser
        except _yaml.YAMLError:
            return None

    return _mini_parse_frontmatter(raw)


def _mini_parse_frontmatter(raw: str) -> dict:
    """Bundled fallback: handles flat key:value, lists `[a, b]`, bool, null,
    full-line and inline `#` comments, and quoted scalars. Multi-line scalars
    and nested maps are NOT supported — install pyyaml for those."""
    data: dict[str, object] = {}
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = key.strip()
        value = _strip_inline_comment(value.strip())
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            data[key] = [v.strip().strip("'\"") for v in inner.split(",") if v.strip()]
        elif value.lower() in {"null", "none", "~", ""}:
            data[key] = None
        elif value.lower() == "true":
            data[key] = True
        elif value.lower() == "false":
            data[key] = False
        else:
            data[key] = value.strip("'\"")
    return data


def validate_phase(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")

    fm = parse_frontmatter(text)
    if fm is None:
        errors.append(f"{path.name}: frontmatter eksik veya bozuk")
        return errors

    missing_keys = REQUIRED_FRONTMATTER_KEYS - set(fm.keys())
    if missing_keys:
        errors.append(
            f"{path.name}: frontmatter eksik anahtar(lar): {sorted(missing_keys)}"
        )

    status = fm.get("status")
    if status not in VALID_STATUSES:
        errors.append(
            f"{path.name}: status '{status}' geçersiz. İzinli: {sorted(VALID_STATUSES)}"
        )

    owner = fm.get("owner_agent")
    if owner not in VALID_AGENTS:
        errors.append(
            f"{path.name}: owner_agent '{owner}' bilinmiyor. İzinli ajan listesi CLAUDE.md'de."
        )

    if status in STATUS_TO_OWNER and owner not in STATUS_TO_OWNER[status]:
        errors.append(
            f"{path.name}: status='{status}' iken owner_agent='{owner}' "
            f"olamaz. Bu state için izinli ajanlar: {sorted(STATUS_TO_OWNER[status])}"
        )

    body = text[FRONTMATTER_RE.match(text).end():] if FRONTMATTER_RE.match(text) else ""
    for section in REQUIRED_BODY_SECTIONS:
        if section not in body:
            errors.append(f"{path.name}: gerekli bölüm eksik: '{section}'")

    return errors


VALID_DOC_STATUSES = {"draft", "approved"}
DOC_REQUIRED_KEYS = {
    "prd": {"doc_type", "app_name", "version", "status"},
    "architecture": {"doc_type", "app_name", "version", "status", "triggers_api_design"},
}
DECISIONS_REQUIRED_KEYS = {"auto_approve"}


def validate_doc(path: Path, expected_doc_type: str) -> list[str]:
    """Validate PRD or architecture.md frontmatter.

    These docs are not phase files but downstream agents (orchestrator,
    architect halt-check) parse their frontmatter for status + flags.
    """
    errors: list[str] = []
    if not path.exists():
        return errors
    text = path.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    if fm is None:
        errors.append(
            f"{path.name}: frontmatter eksik. "
            f"Doc başına YAML frontmatter ekle (doc_type, status vs.)"
        )
        return errors
    missing = DOC_REQUIRED_KEYS[expected_doc_type] - set(fm.keys())
    if missing:
        errors.append(
            f"{path.name}: frontmatter eksik anahtar(lar): {sorted(missing)}"
        )
    status = fm.get("status")
    if status not in VALID_DOC_STATUSES:
        errors.append(
            f"{path.name}: status='{status}' geçersiz. "
            f"İzinli: {sorted(VALID_DOC_STATUSES)}"
        )
    if expected_doc_type == "architecture":
        trig = fm.get("triggers_api_design")
        if trig not in (True, False):
            errors.append(
                f"{path.name}: triggers_api_design field bool olmalı (true|false), "
                f"şu an: {trig!r}"
            )
    return errors


def validate_decisions(path: Path) -> list[str]:
    """Validate .project/decisions.md frontmatter (auto_approve flag)."""
    errors: list[str] = []
    if not path.exists():
        return errors
    text = path.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    if fm is None:
        errors.append(
            f"{path.name}: frontmatter eksik. "
            f"Doc başına YAML frontmatter ekle (auto_approve flag'i için)"
        )
        return errors
    missing = DECISIONS_REQUIRED_KEYS - set(fm.keys())
    if missing:
        errors.append(
            f"{path.name}: frontmatter eksik anahtar(lar): {sorted(missing)}"
        )
    aa = fm.get("auto_approve")
    if aa not in (True, False):
        errors.append(
            f"{path.name}: auto_approve field bool olmalı (true|false), şu an: {aa!r}"
        )
    return errors


def main() -> int:
    try:
        payload = json.load(sys.stdin) if not sys.stdin.isatty() else {}
    except json.JSONDecodeError:
        payload = {}

    project_dir = Path(
        payload.get("cwd")
        or os.environ.get("CLAUDE_PROJECT_DIR")
        or Path.cwd()
    )
    phases_dir = project_dir / ".project" / "phases"

    all_errors: list[str] = []

    # Validate PRD + architecture + decisions frontmatter (if they exist)
    all_errors.extend(validate_doc(project_dir / ".project" / "prd.md", "prd"))
    all_errors.extend(
        validate_doc(project_dir / ".project" / "architecture.md", "architecture")
    )
    all_errors.extend(validate_decisions(project_dir / ".project" / "decisions.md"))

    if not phases_dir.exists():
        if all_errors:
            msg_lines = [
                "🚨 Doküman doğrulama HATALARI:",
                "",
            ] + [f"  - {e}" for e in all_errors]
            print("\n".join(msg_lines), file=sys.stderr)
            return 2
        return 0

    for phase_file in sorted(phases_dir.glob("phase-*.md")):
        text = phase_file.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)
        if fm is None:
            all_errors.append(f"{phase_file.name}: frontmatter eksik")
            continue
        if fm.get("status") == "DONE":
            continue
        all_errors.extend(validate_phase(phase_file))

    if not all_errors:
        return 0

    msg_lines = [
        "🚨 Faz state doğrulama HATALARI tespit edildi (CLAUDE.md kurallarına bak):",
        "",
    ]
    msg_lines.extend(f"  - {e}" for e in all_errors)
    msg_lines.append("")
    msg_lines.append(
        "Lütfen ilgili phase dosyasını düzelt ve sonra dur. Atlanmış bir adım "
        "varsa '## Skipped Steps' bölümüne gerekçesini ekle."
    )

    print("\n".join(msg_lines), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())

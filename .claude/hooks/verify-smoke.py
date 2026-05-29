#!/usr/bin/env python3
"""
INTEGRATION_SMOKE evidence verifier hook — the mechanical backstop that turns
the runtime gate from self-reported ("BOOT_OK ✓" typed by the agent) into
proof-of-work (a captured artifact from an actually-executed build+boot+e2e).

Runs on Stop / SubagentStop. For every active phase whose status is
INTEGRATION_SMOKE or later (but not DONE), the phase's ARCHIVE file
`## Integration Smoke` section MUST reference a smoke artifact log that:
  1. exists on disk under .project/qa-runs/
  2. is named smoke-<phase_id>-<sha>-<ts>.log where <sha> == current git HEAD
     (short) — ties the evidence to the exact committed code state; if HEAD
     moved, the old smoke is stale and the gate re-fails until re-run
  3. is FRESH vs the working tree — its mtime is >= the newest lib/**/*.dart
     (catches "edited code after running smoke" with uncommitted changes)
  4. contains the markers the running app emits: BOOT_OK (with matching sha),
     FIRST_SCREEN_OK, and a SMOKE_RESULT exit=0 line

Exit codes:
  0  → all good (silent)
  2  → smoke evidence missing / forged / stale; Claude is asked to actually run
       `tool/run_smoke.sh` and paste the real artifact before stopping

Anti-gaming honesty: a determined agent with Write+Bash could still hand-forge a
log with the correct SHA + markers. This hook does not make that impossible — it
makes the honest path (run the script) strictly easier than the dishonest one
(fabricate a SHA-correct, marker-complete, freshness-correct log), and converts
a silent default into an explicit, auditable forgery. (See decisions.md ADR-011.)

Testability seam: set SMOKE_VERIFY_HEAD_SHA to override the git HEAD lookup.
Zero external deps — stdlib only.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Phase statuses at/after the runtime gate that REQUIRE smoke evidence to exist.
# DONE is excluded (archived/historical) to match validate-phase-state.py's skip.
STATES_REQUIRING_SMOKE = {
    "INTEGRATION_SMOKE",
    "COMPLIANCE_CHECK",
    "QA_SMOKE_TEST",
    "USER_APPROVAL",
    "CHRONICLED",
    "SKILL_EXTRACTED",
}

ARTIFACT_RE = re.compile(r"\.project/qa-runs/(smoke-[\w.\-]+\.log)")
FILENAME_SHA_RE = re.compile(r"^smoke-([\w]+)-([0-9a-fA-F]{4,40})-(\d+)\.log$")


def _project_dir(payload: dict) -> Path:
    for key in ("cwd",):
        v = payload.get(key)
        if v and Path(v).is_dir():
            return Path(v)
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env and Path(env).is_dir():
        return Path(env)
    return Path.cwd()


def _read_status(text: str) -> str | None:
    """Pull `status:` out of a phase LIVE file's YAML frontmatter."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    fm = text[3:end]
    for line in fm.splitlines():
        s = line.strip()
        if s.startswith("status:"):
            val = s[len("status:"):].strip().strip('"').strip("'")
            # strip trailing inline comment
            val = val.split("#", 1)[0].strip()
            return val
    return None


def _git_head_sha(root: Path) -> str | None:
    override = os.environ.get("SMOKE_VERIFY_HEAD_SHA")
    if override:
        return override.strip()
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=10,
        )
        if out.returncode == 0:
            return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None  # git unavailable → SHA check skipped (infra, not forgery)


def _section(text: str, header: str) -> str | None:
    """Return the body of a `## header` section up to the next `## `."""
    lines = text.splitlines()
    out, capture = [], False
    for line in lines:
        if line.strip().lower() == header.strip().lower():
            capture = True
            continue
        if capture and line.startswith("## ") and line.strip() != header.strip():
            break
        if capture:
            out.append(line)
    return "\n".join(out) if capture else None


def _newest_lib_mtime(root: Path) -> float | None:
    libdir = root / "lib"
    if not libdir.is_dir():
        return None  # template / pre-bootstrap — no source tree yet
    newest = 0.0
    for p in libdir.rglob("*.dart"):
        if p.name.endswith((".g.dart", ".freezed.dart")):
            continue  # generated — not hand-edited source
        try:
            newest = max(newest, p.stat().st_mtime)
        except OSError:
            continue
    return newest or None


def check_phase(live_path: Path, root: Path, head_sha: str | None) -> list[str]:
    """Return a list of error strings for one phase (empty = OK)."""
    errors: list[str] = []
    text = live_path.read_text(encoding="utf-8", errors="replace")
    status = _read_status(text)
    if status not in STATES_REQUIRING_SMOKE:
        return errors

    name = live_path.name
    if name.endswith("-archive.md"):
        return errors  # archive itself is not a state file
    archive = live_path.with_name(name[:-3] + "-archive.md")
    label = f"{name} (status={status})"

    if not archive.exists():
        errors.append(
            f"{label}: INTEGRATION_SMOKE gate ihlali — archive dosyası yok "
            f"({archive.name}). `tool/run_smoke.sh` çalıştırıp gerçek smoke "
            f"kanıtını `## Integration Smoke`'a yapıştır."
        )
        return errors

    atext = archive.read_text(encoding="utf-8", errors="replace")
    sect = _section(atext, "## Integration Smoke")
    if not sect or not sect.strip():
        errors.append(
            f"{label}: `## Integration Smoke` bölümü boş/yok ({archive.name}). "
            f"Gerçek smoke artefaktı referansı gerekli (beyan yeterli değil)."
        )
        return errors

    m = ARTIFACT_RE.search(sect)
    if not m:
        errors.append(
            f"{label}: `## Integration Smoke` bir smoke artefaktına referans "
            f"vermiyor (beklenen: `.project/qa-runs/smoke-<id>-<sha>-<ts>.log`). "
            f"Beyan değil, icra edilmiş log gerekli."
        )
        return errors

    artifact_rel = f".project/qa-runs/{m.group(1)}"
    artifact = root / artifact_rel
    if not artifact.exists():
        errors.append(
            f"{label}: referans verilen smoke artefaktı diskte yok "
            f"({artifact_rel}). `tool/run_smoke.sh`'ı GERÇEKTEN çalıştır."
        )
        return errors

    # filename SHA vs HEAD
    fnmatch = FILENAME_SHA_RE.match(artifact.name)
    file_sha = fnmatch.group(2) if fnmatch else None
    if head_sha and file_sha and not head_sha.startswith(file_sha) \
            and not file_sha.startswith(head_sha):
        errors.append(
            f"{label}: smoke artefaktı eski koda ait (artefakt sha={file_sha}, "
            f"HEAD={head_sha}). Kod değişti — smoke'u yeniden çalıştır."
        )

    # freshness vs working tree (catches uncommitted edits after smoke)
    newest_src = _newest_lib_mtime(root)
    if newest_src is not None:
        try:
            if artifact.stat().st_mtime < newest_src:
                errors.append(
                    f"{label}: smoke artefaktı kaynak koddan ESKİ (lib/ içinde "
                    f"smoke'tan sonra değişiklik var). Smoke'u yeniden çalıştır."
                )
        except OSError:
            pass

    # content markers
    body = artifact.read_text(encoding="utf-8", errors="replace")
    if "BOOT_OK" not in body:
        errors.append(f"{label}: smoke log'unda `BOOT_OK` marker'ı yok — uygulama gerçekten boot etmedi.")
    if "FIRST_SCREEN_OK" not in body:
        errors.append(f"{label}: smoke log'unda `FIRST_SCREEN_OK` marker'ı yok — ilk gerçek ekran çizilmedi.")
    if not re.search(r"SMOKE_RESULT\s+exit=0\b", body):
        errors.append(f"{label}: smoke log'unda `SMOKE_RESULT exit=0` yok — smoke geçmedi (build/boot/e2e fail).")
    if head_sha and file_sha and not re.search(rf"BOOT_OK[^\n]*sha={re.escape(file_sha)}", body):
        errors.append(f"{label}: `BOOT_OK` marker'ındaki sha, artefakt adındaki sha ile uyuşmuyor — log forge edilmiş olabilir.")

    return errors


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        return 0  # malformed payload → fail open (don't hard-block)

    root = _project_dir(payload)
    phases_dir = root / ".project" / "phases"
    if not phases_dir.is_dir():
        return 0  # no phases yet (template / pre-planning)

    head_sha = _git_head_sha(root)
    all_errors: list[str] = []
    for live in sorted(phases_dir.glob("phase-*.md")):
        if live.name.endswith("-archive.md"):
            continue
        try:
            all_errors.extend(check_phase(live, root, head_sha))
        except Exception:
            continue  # never let a verifier bug hard-block the pipeline

    if all_errors:
        print("INTEGRATION_SMOKE kanıt doğrulaması BAŞARISIZ:\n", file=sys.stderr)
        for e in all_errors:
            print(f"  ✗ {e}", file=sys.stderr)
        print(
            "\nDüzelt: emülatör açıkken `bash tool/run_smoke.sh <phase_id>` "
            "çalıştır, üretilen log'u `## Integration Smoke`'a referansla. "
            "(CLAUDE.md §3 INTEGRATION_SMOKE, ADR-011)",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

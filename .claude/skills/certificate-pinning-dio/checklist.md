# Certificate Pinning — Verification Checklist

Run on every release. Owned by `security-reviewer` agent at SECURITY_REVIEW gate.

## Setup
- [ ] SPKI hash extracted from PROD endpoint (not staging)
- [ ] Backup pin extracted from CDN / failover origin OR next-rotation cert
- [ ] Both pins committed to `_kAllowedSpkiPins`
- [ ] `network_security_config.xml` declarative pins match Dart pins
- [ ] AndroidManifest.xml references `@xml/network_security_config`

## Behavior
- [ ] DEBUG build: Charles/Proxyman works (intentional bypass)
- [ ] RELEASE build with intentionally-bad pin: request fails with `HandshakeException`
- [ ] RELEASE build with correct pin: request succeeds
- [ ] No `badCertificateCallback` returns unconditional `true`
- [ ] All HTTPS-only endpoints; no cleartext exceptions

## Rotation hygiene
- [ ] Cert expiry date noted in `.project/decisions.md` (next rotation deadline)
- [ ] Calendar reminder ≥ 60 days before primary cert expiry
- [ ] Rotation runbook documented (backup → primary, ship new backup)
- [ ] Rotation drill rehearsed at least once

## Crash reporter
- [ ] Pin mismatch logs a breadcrumb (per `crash-monitor-dual`) — visible in dashboard during incidents
- [ ] PII scrubbing applied — pin-mismatch log does NOT include user identifiers

## Compatibility
- [ ] WebView calls documented (whether pinned or not)
- [ ] System WebView fallback path explicit

# local-security-agent

A Claude Code agent that audits a macOS machine for security issues, one phase
at a time. Each phase is a [skill](.claude/skills/) with a read-only collection
tool behind it; the agent analyzes the output, verifies findings against *live*
web threat intel (published IOCs, current campaigns), and reports evidence-backed
verdicts.

## Phases

| Phase | Skill | Status |
|-------|-------|--------|
| 1. Startup agents/services/apps | [`startup-audit`](.claude/skills/startup-audit/SKILL.md) | ✅ |
| 2. Network listeners & firewall | — | planned |
| 3. Browser extensions | — | planned |
| 4. Installed apps & signatures | — | planned |

## Usage

```bash
cd local-security-agent
claude   # then: "run the startup audit"
```

Or run the collection tool directly and read the raw report:

```bash
bash tools/startup-inventory.sh | less
```

## Design principles

- **Read-only.** Tools never modify the system; remediation is proposed as
  commands for the human to review, never executed by the agent unprompted.
- **Web-verified.** Model training data goes stale; the agent must check its
  verdicts against current published IOCs before calling anything clean.
  (Origin story: a "legacy Google Keystone plist" verdict that turned out to be
  the persistence label of an active 2026 infostealer campaign — the plist was
  clean, but only inspection + live IOCs could prove it.)
- **Evidence-backed verdicts.** Every "clean" states what was verified:
  binary exists, parent app installed, Developer ID team matches vendor.

## Development

```bash
make lint   # shellcheck (or bash -n) + forbidden-command scan
make test   # smoke-run the inventory script
```

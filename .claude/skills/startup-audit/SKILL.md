---
name: startup-audit
description: Audit everything that runs at boot/login on this Mac — launch agents/daemons, login items, privileged helpers — for orphans, masquerades, unsigned binaries, and live-campaign IOCs. Use when the user asks to audit startup items, autoruns, persistence, or "what runs when this machine starts".
---

# Startup agents/services/apps audit

Audit every persistence point that executes code at boot or login, produce an
evidence-backed verdict for each item, and verify the conclusions against
*current* web threat intel — not just model knowledge.

## Step 1 — Inventory (read-only)

Run `tools/startup-inventory.sh` from the repo root and read its output. It
collects:

- `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`
  (plist listing + `ProgramArguments`/`Program`, `RunAtLoad`, `KeepAlive`,
  `StartInterval` for each)
- Login items (System Events) and `sfltool dumpbtm` (background task management)
- `/Library/PrivilegedHelperTools` binaries with `codesign` team identifiers
- Currently loaded non-Apple jobs (`launchctl list`)
- User crontab, `/Library/StartupItems`, `/etc/periodic` additions
- `/etc/hosts` (non-default lines) and `/etc/sudoers.d`
- Hidden executable dotfiles in `$HOME` (depth 1)

If the script is unavailable, run the equivalent commands manually — in bash,
never zsh (zsh `nomatch` aborts a whole command list on one failed glob and
silently skips later checks).

## Step 2 — Per-item verification chain

For every third-party item, verify each link; a broken link is a finding:

1. **Target exists** — the `ProgramArguments[0]` / `Program` path is on disk.
2. **Parent app exists** — the app the helper belongs to is still installed.
   A signed root helper whose parent app is gone is an **orphan** (finding:
   needs action). Seen in practice: NordVPN helper and Teams updater daemons
   surviving app uninstall.
3. **Signature** — `codesign -dv` shows a Developer ID with a `TeamIdentifier`,
   and the team matches the claimed vendor. Note: `spctl -a -t exec` prints
   `rejected (the code is valid but does not seem to be an app)` for CLI helper
   tools — that is NORMAL for non-bundle executables, not a red flag. Unsigned
   or ad-hoc-signed items in persistence locations ARE red flags.
4. **Path sanity** — vendor binaries live in vendor paths (`/Applications`,
   `/Library/...`, `~/Library/Application Support/<Vendor>/`). Anything running
   from `/tmp`, `Downloads`, or a bare script in Application Support deserves
   deep inspection.

## Step 3 — Masquerade checks

Attackers reuse trusted labels. Check specifically:

- **`com.apple.*` plists in user/global LaunchAgents dirs** — Apple never puts
  its plists there; any hit is suspect.
- **`com.google.keystone.agent.plist`** — abused by the 2026 Reaper/SHub
  infostealer (ClickFix delivery). The legit legacy file after Google's updater
  migration contains an **empty `<dict/>`** (no persistence). The malicious one
  has `ProgramArguments` pointing at
  `~/Library/Application Support/Google/GoogleUpdate.app/Contents/MacOS/GoogleUpdate`
  with a short `StartInterval`. `cat` the plist — never judge it by name.
- **Randomized labels** (`com.<gibberish>.plist`) and generic names
  (`com.finder.helper.plist` — AMOS) in LaunchDaemons/LaunchAgents.
- Known dropped-file IOCs: `~/.mainhelper`, `~/.agent`, `/tmp/helper`,
  `/tmp/update`, `/tmp/.c.sh`, `/tmp/shub_*`. Check each path individually.

## Step 4 — Web verification (mandatory, not optional)

Model knowledge has a cutoff; malware doesn't. Before finalizing:

1. Web-search each unusual finding (e.g. a daemon running `ifconfig lo0 alias` —
   turned out to be documented 3Dconnexion NL-server behavior).
2. Web-search "malware masquerading <label>" for the highest-value labels found
   (Google/Apple/Microsoft updater names at minimum).
3. Pull IOC lists from any current campaign the searches surface and check every
   file path, label, and domain against the machine.
4. Verify unfamiliar `TeamIdentifier` values really belong to the claimed vendor.

## Step 5 — Report

Three buckets, most severe first:

1. **Needs action** — orphaned privileged helpers, unsigned persistence, IOC
   hits. Include exact `sudo launchctl bootout` + `rm` remediation commands for
   the user to review; do not run them.
2. **Legit but notable** — documented-but-odd behavior (explain it), removable
   bloat (updaters/telemetry the user may not want).
3. **Checked out clean** — say *what was verified* (signatures, paths, IOC
   sweeps all negative), so "clean" is auditable.

End with the list of web sources used for verification.

## Step 6 — Persist the audit log

Write `audits/YYYY-MM-DD-startup-audit.md` per `audits/TEMPLATE.md`: inventory
summary (counts, not raw dumps), the three finding buckets with evidence, web
sources, remediation applied vs. pending, and the delta against the previous
startup-audit entry (new/removed/changed startup items). Commit it. Before
Step 1 of any future run, read the latest entry so the delta is computable and
prior "pending" remediations get followed up.

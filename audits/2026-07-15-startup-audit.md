# Audit log — startup-audit — 2026-07-15

- **Phase:** startup-audit
- **Host:** macOS (Darwin 25.5.0), Apple Silicon
- **Agent:** Claude Code (Fable 5), background session
- **Prior audit:** first run

## Inventory summary

- `~/Library/LaunchAgents`: 8 plists (Google Updater + legacy Keystone ×2, HP
  device monitor, JetBrains Toolbox, Edge Updater, ChatGPT Atlas updater,
  Valve steamclean)
- `/Library/LaunchAgents`: 3 plists (3Dconnexion helper, Zoom updater ×2)
- `/Library/LaunchDaemons`: 14 plists (3Dconnexion, Adobe ×3, Docker ×2,
  Teams updater, NordVPN helper, Parallels Toolbox, Proxyman, OpenVPN ×2,
  Wireshark ChmodBPF, Zoom daemon)
- Login items: Activity Monitor, GeminiAppLauncher, Terminal, Unblocked,
  Drata Agent, Claude, Dropover, Tailscale, Commander One PRO
- No user crontab, no `/Library/StartupItems`, no `/etc/sudoers.d` additions,
  `/etc/hosts` default.

## Findings

### Needs action

1. **Orphaned NordVPN root helper** — `/Library/LaunchDaemons/com.nordvpn.macos.helper.plist`
   + `/Library/PrivilegedHelperTools/com.nordvpn.macos.helper`. NordVPN.app is
   no longer installed; helper is genuinely signed by Nord Security (team
   `W5W395V82Y`, verified via web) so it is leftover cruft, not malware — but an
   orphaned root helper should not persist.
2. **Orphaned Microsoft Teams updater** —
   `/Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist`;
   Teams is not installed.

Remediation (requires sudo):

```bash
sudo launchctl bootout system/com.nordvpn.macos.helper 2>/dev/null
sudo launchctl bootout system/com.microsoft.teams.TeamsUpdaterDaemon 2>/dev/null
sudo rm /Library/LaunchDaemons/com.nordvpn.macos.helper.plist \
        /Library/PrivilegedHelperTools/com.nordvpn.macos.helper \
        /Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist
```

### Legit but notable

- **3Dconnexion `ifconfig lo0 alias 127.51.68.120` root daemon** — looks
  alarming; confirmed documented behavior (Navigation Library server listens on
  that loopback alias) via 3Dconnexion forum.
- **Adobe AGSService** (`/Library/Application Support/Adobe/AdobeGCClient/`) —
  Adobe Genuine Software license verification; canonical path + Adobe team ID.
  Removable if no paid Creative Cloud.
- **Legacy Google Keystone plists** — both contained an **empty `<dict/>`**
  (neutered by Google's migration to GoogleUpdater); no persistence. See
  masquerade note under web verification.
- Auto-start bloat candidates: steamclean, JetBrains Toolbox, ChatGPT Atlas
  update helper, HP device monitor (all belong to installed apps; user's call).

### Checked out clean

- All privileged helpers in `/Library/PrivilegedHelperTools` carry valid
  Developer ID team identifiers matching claimed vendors (Adobe `JQ525L2MZD`,
  Docker `9BNSXJN65R`, Parallels `4C6364ACXT`, Proxyman `3X57WP8E8V`, Zoom
  `BJ4HAAB9B3`, Nord `W5W395V82Y`). `spctl "rejected …not an app"` outputs are
  expected for CLI helper tools.
- Every launch agent/daemon target binary and parent app exists (except the two
  orphans above).
- No `com.apple.*` masquerade plists in user/global LaunchAgents.
- IOC sweep all negative: `~/Library/Application Support/Google/GoogleUpdate.app`,
  `~/.mainhelper`, `~/.agent`, `/tmp/helper`, `/tmp/update`, `/tmp/.c.sh`,
  `/tmp/shub_*`, `/Library/LaunchDaemons/com.finder.helper.plist`.
- `GoogleSoftwareUpdate.bundle` passes codesign designated-requirement check.

## Web verification

- **Reaper/SHub infostealer (ClickFix delivery, reported May 2026)** persists
  via a fake `com.google.keystone.agent.plist` running a script from
  `~/Library/Application Support/Google/GoogleUpdate.app/` every 60 s. Machine's
  keystone plists were empty stubs; IOC paths absent. This finding is why the
  skill mandates `cat`-ing the plist rather than judging by name.
- ClickFix/AMOS helper-campaign IOCs (`com.finder.helper.plist`, `~/.mainhelper`,
  `~/.agent`, `/tmp` staging) — all absent.
- Vendor team IDs and 3Dconnexion loopback-alias behavior confirmed against
  vendor forums/docs.

Sources: [Microsoft Security Blog — ClickFix macOS campaign](https://www.microsoft.com/en-us/security/blog/2026/05/06/clickfix-campaign-uses-fake-macos-utilities-lures-deliver-infostealers/),
[CyberSecurityNews — fake Google update LaunchAgent](https://cybersecuritynews.com/macos-malware-installs-fake-google-software/),
[AppleInsider](https://appleinsider.com/articles/26/05/18/new-infostealer-malware-hides-on-mac-disguised-as-official-apple-tools),
[3Dconnexion forum — NL server](https://forum.3dconnexion.com/viewtopic.php?t=16007),
[macsecurity.net — Adobe AGS on Mac](https://macsecurity.net/view/530-adobe-genuine-software-integrity-service-mac)

## Remediation applied

- 2026-07-15: removed `~/Library/LaunchAgents/com.google.keystone.agent.plist`
  and `com.google.keystone.xpcservice.plist` (empty legacy stubs) — by agent,
  user-approved.
- NordVPN + Teams orphan removal: **pending** (requires user sudo; commands
  above).

## Delta since last audit

n/a — first run.

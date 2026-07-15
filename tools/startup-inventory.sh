#!/usr/bin/env bash
# startup-inventory.sh — read-only collection of every macOS persistence point.
# Emits a sectioned text report on stdout for the startup-audit skill to analyze.
# Deliberately makes NO changes to the system.
set -u
shopt -s nullglob

section() { printf '\n===== %s =====\n' "$1"; }

plist_key() { # plist_key <file> <key> — best-effort extraction, never fails the script
  plutil -extract "$2" json -o - "$1" 2>/dev/null ||
    plutil -extract "$2" raw -o - "$1" 2>/dev/null ||
    printf 'n/a'
}

dump_plist_dir() {
  local dir=$1
  section "PLISTS: $dir"
  [ -d "$dir" ] || { echo "(directory absent)"; return; }
  ls -la "$dir"
  local f
  for f in "$dir"/*.plist; do
    printf -- '\n--- %s\n' "$f"
    printf 'Program:      %s\n' "$(plist_key "$f" ProgramArguments)"
    printf 'ProgramAlt:   %s\n' "$(plist_key "$f" Program)"
    printf 'RunAtLoad:    %s\n' "$(plist_key "$f" RunAtLoad)"
    printf 'KeepAlive:    %s\n' "$(plist_key "$f" KeepAlive)"
    printf 'StartInterval:%s\n' "$(plist_key "$f" StartInterval)"
    # Masquerade tell: legit-neutered plists are an empty dict; flag if this
    # plist has NO program but also is not empty (or vice versa) by showing size.
    printf 'Bytes:        %s\n' "$(stat -f %z "$f" 2>/dev/null || echo '?')"
  done
}

section "HOST"
sw_vers 2>/dev/null
date

dump_plist_dir "$HOME/Library/LaunchAgents"
dump_plist_dir "/Library/LaunchAgents"
dump_plist_dir "/Library/LaunchDaemons"

section "MASQUERADE CHECK: com.apple.* plists outside /System (should be empty)"
found_apple=0
for f in "$HOME/Library/LaunchAgents"/com.apple.*.plist \
         /Library/LaunchAgents/com.apple.*.plist \
         /Library/LaunchDaemons/com.apple.*.plist; do
  echo "SUSPECT: $f"
  found_apple=1
done
[ "$found_apple" -eq 0 ] && echo "none found"

section "KNOWN IOC PATHS (each checked individually)"
ioc_paths=(
  "$HOME/Library/Application Support/Google/GoogleUpdate.app"
  "$HOME/.mainhelper"
  "$HOME/.agent"
  "/tmp/helper"
  "/tmp/update"
  "/tmp/.c.sh"
  "/Library/LaunchDaemons/com.finder.helper.plist"
)
for p in "${ioc_paths[@]}"; do
  if [ -e "$p" ]; then echo "FOUND (suspicious): $p"; else echo "absent: $p"; fi
done
shub_hits=(/tmp/shub_*)
if [ "${#shub_hits[@]}" -gt 0 ]; then
  printf 'FOUND (suspicious): %s\n' "${shub_hits[@]}"
else
  echo "absent: /tmp/shub_*"
fi

section "PRIVILEGED HELPER TOOLS (/Library/PrivilegedHelperTools)"
for b in /Library/PrivilegedHelperTools/*; do
  printf -- '\n--- %s\n' "$b"
  codesign -dv "$b" 2>&1 | grep -E 'Identifier=|TeamIdentifier=|Authority=Developer ID' || echo "(signature unreadable as this user)"
done

# The two collectors below can raise GUI permission/password prompts
# (System Events automation consent; sfltool elevation). Set
# INVENTORY_NO_PROMPT=1 (as `make test` does) to skip them.
if [ "${INVENTORY_NO_PROMPT:-0}" = "1" ]; then
  section "LOGIN ITEMS + BTM"
  echo "(skipped: INVENTORY_NO_PROMPT=1)"
else
  section "LOGIN ITEMS (System Events)"
  osascript -e 'tell application "System Events" to get the name of every login item' 2>&1

  section "BACKGROUND TASK MANAGEMENT (sfltool dumpbtm; richer with sudo)"
  sfltool dumpbtm 2>&1 | head -200
fi

section "CURRENTLY LOADED NON-APPLE JOBS (launchctl list)"
launchctl list | grep -viE 'com\.apple' || echo "none"

section "CRONTAB (current user)"
crontab -l 2>&1

section "LEGACY STARTUP LOCATIONS"
ls /Library/StartupItems 2>&1
ls /etc/periodic/daily /etc/periodic/weekly /etc/periodic/monthly 2>/dev/null

section "/etc/hosts (non-comment lines)"
grep -vE '^\s*#|^\s*$' /etc/hosts

section "/etc/sudoers.d"
ls -la /etc/sudoers.d/ 2>&1

section "HIDDEN EXECUTABLE DOTFILES IN \$HOME (depth 1)"
find "$HOME" -maxdepth 1 -name '.*' -type f -perm -u+x 2>/dev/null
echo "(end of inventory)"

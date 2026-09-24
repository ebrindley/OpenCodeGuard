#!/bin/zsh
# Runs outside any sandbox. Requires node for the plugin checks.
emulate -L zsh
setopt no_unset pipe_fail

root=${0:A:h:h}
export HOME="$root/test/.home"
/bin/rm -rf "$HOME"
/bin/mkdir -p "$HOME"/{Projects/app/secret,Projects/archive/live,Documents/private}
home=${HOME:A}
engine="$home/Library/Application Support/OpenCodeGuard"
list="$home/OpenCode Guard/Guard List.txt"
fails=0

pass() { print -r -- "ok   $*" }
fail() { print -r -- "FAIL $*"; fails=$((fails + 1)) }
expect() { local want=$1 name=$2; shift 2; "$@" >/dev/null 2>&1; local rc=$?; if [[ ( $want == ok && $rc == 0 ) || ( $want == no && $rc != 0 ) ]]; then pass "$name"; else fail "$name (rc $rc)"; fi }

/bin/zsh "$root/install.sh" --projects "$home/Projects" </dev/null >/dev/null || fail "install"
[[ -x $engine/launch ]] && pass "install" || fail "engine missing"
/usr/bin/grep -Fxq "$home/Projects" "$list" && pass "projects added to ALLOW" || fail "projects not in list"

/usr/bin/awk -v h="$home" '
  /^READ ONLY/ { print; print h "/Projects/archive"; next }
  /^DENY/ { print; print h "/Projects/app/secret"; print "~/Documents/private"; print h "/Library"; print "not a path"; next }
  { print }' "$list" > "$list.tmp" && /bin/mv "$list.tmp" "$list"
/usr/bin/awk -v h="$home" '{ print } /^ALLOW/ { print h "/Projects/archive/live" }' "$list" > "$list.tmp" && /bin/mv "$list.tmp" "$list"

profile=$("$engine/launch" profile 2>/dev/null) || fail "profile"
log="$home/OpenCode Guard/last-launch.log"
/usr/bin/grep -q "refused DENY, OpenCode needs" "$log" && pass "essential DENY refused" || fail "essential DENY accepted"
/usr/bin/grep -q "skipped, not a full path: not a path" "$log" && pass "junk line skipped" || fail "junk line"
/usr/bin/jq -e --arg h "$home" '.deny == [$h + "/Projects/app/secret", $h + "/Documents/private"]' "$engine/state/rules.json" >/dev/null && pass "rules.json" || fail "rules.json"

darwin_user=$(cd "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)/.." && pwd -P)
sb() { /usr/bin/sandbox-exec -D "HOME=$home" -D "DARWIN_USER=$darwin_user" -D GUI=0 -p "$profile" "$@" }
echo data > "$home/Projects/app/secret/key"
echo data > "$home/Documents/private/doc"

expect ok "write in ALLOW"                sb /usr/bin/touch "$home/Projects/app/new"
expect no "remove ALLOW root"             sb /bin/rmdir "$home/Projects/archive/live"
expect no "write in READ ONLY"            sb /usr/bin/touch "$home/Projects/archive/new"
expect ok "ALLOW inside READ ONLY"        sb /usr/bin/touch "$home/Projects/archive/live/new"
expect no "read DENY inside ALLOW"        sb /bin/cat "$home/Projects/app/secret/key"
expect no "list DENY"                     sb /bin/ls "$home/Documents/private"
expect no "rename DENY"                   sb /bin/mv "$home/Projects/app/secret" "$home/Projects/app/moved"
expect no "write outside lists"           sb /usr/bin/touch "$home/Documents/new"
expect no "edit Guard List"               sb /bin/sh -c "echo x >> '$list'"
expect no "move Guard List folder"        sb /bin/mv "$home/OpenCode Guard" "$home/moved"
expect no "write engine"                  sb /usr/bin/touch "$engine/x"
expect no "write opencode config"         sb /usr/bin/touch "$home/.config/opencode/x"
expect no "write shell profile"           sb /usr/bin/touch "$home/.zshrc"
expect no "exec open"                     sb /usr/bin/open -h
expect ok "write temp"                    sb /usr/bin/touch "$darwin_user/T/.opencode-guard-test"
/bin/rm -f "$darwin_user/T/.opencode-guard-test"

if command -v node >/dev/null; then
  plugin="$home/.config/opencode/plugins/opencode-guard.js"
  node "$root/test/plugin.mjs" "$plugin" unguarded || fails=$((fails + 1))
  OPENCODE_GUARD_BYPASS=1 node "$root/test/plugin.mjs" "$plugin" bypass || fails=$((fails + 1))
  sb "$(command -v node)" "$root/test/plugin.mjs" "$plugin" guarded || fails=$((fails + 1))
else
  print "skip plugin checks (node not found)"
fi

/bin/zsh "$engine/uninstall.sh" >/dev/null && [[ ! -e $engine && ! -e $home/.config/opencode/plugins/opencode-guard.js ]] && pass "uninstall" || fail "uninstall"
! /usr/bin/grep -q opencode-guard "$home/.zshrc" && pass "rc block removed" || fail "rc block left"

/bin/rm -rf "$HOME"
print -r -- "$fails failure(s)"
(( fails == 0 ))

#!/bin/zsh
# Runs outside any sandbox. Requires node for the plugin checks and the opencode CLI for the install self-test.
emulate -L zsh
setopt no_unset pipe_fail

root=${0:A:h:h}
export HOME="$root/test/.home"
/bin/rm -rf "$HOME"
/bin/mkdir -p "$HOME"/{Projects/app/secret,Projects/archive/live,Projects/dotfiles,Documents/private,.config/opencode,bin}
home=${HOME:A}
engine="$home/Library/Application Support/OpenCodeGuard"
list="$home/OpenCode Guard/Guard List.txt"
log="$home/OpenCode Guard/last-launch.log"
cfg="$home/.config/opencode/opencode.json"
fails=0

pass() { print -r -- "ok   $*" }
fail() { print -r -- "FAIL $*"; fails=$((fails + 1)) }
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi }
expect() { local want=$1 name=$2; shift 2; "$@" >/dev/null 2>&1; local rc=$?; if [[ ( $want == ok && $rc == 0 ) || ( $want == no && $rc != 0 ) ]]; then pass "$name"; else fail "$name (rc $rc)"; fi }

print 'export X=1' > "$home/Projects/dotfiles/zshrc"
/bin/ln -s "$home/Projects/dotfiles/zshrc" "$home/.zshrc"
print -n 'alias x=y' > "$home/.zprofile"
original='{"model":"m","permission":{"bash":{"git *":"allow","*":"ask","rm *":"deny"},"task":"ask"}}'
print -r -- "$original" > "$cfg"

/bin/zsh "$root/install.sh" --projects "$home/Projects" </dev/null > "$home/install.log" 2>&1 || { fail "install"; /bin/cat "$home/install.log" }
check "install self-test incl. plugin load" /usr/bin/grep -q "ok   plugins loaded in OpenCode" "$home/install.log"
check "projects added to ALLOW" /usr/bin/grep -Fxq "$home/Projects" "$list"
check "zprofile without final newline kept intact" /usr/bin/grep -Fxq 'alias x=y' "$home/.zprofile"
check "permission merge" /usr/bin/jq -e '.permission == {"bash":{"*":"allow","git *":"allow","rm *":"deny"},"task":"ask","edit":"allow","external_directory":"allow"} and (.permission.bash | keys_unsorted[0]) == "*"' "$cfg"

/usr/bin/awk -v h="$home" '
  /^ALLOW/ { print; print h "/Projects/archive/live"; print h "/Library"; print "/"; next }
  /^READ ONLY/ { print; print h "/Projects/archive"; print "~"; next }
  /^DENY/ { print; print h "/Projects/app/secret"; print "Allow me to note:"; print "~/Documents/private"; print "~/Documents/typo"; print h "/Library"; print "not a path"; next }
  { print }' "$list" > "$list.tmp" && /bin/mv "$list.tmp" "$list"

profile=$("$engine/launch" profile 2>/dev/null) || fail "profile"
check "essential DENY refused" /usr/bin/grep -q "refused DENY, OpenCode needs" "$log"
check "broad ALLOW refused" /usr/bin/grep -q "refused ALLOW, too broad: $home/Library" "$log"
check "ALLOW / refused" /usr/bin/grep -qx "refused ALLOW, too broad: /" "$log"
check "essential READ ONLY refused" /usr/bin/grep -q "refused READ ONLY, OpenCode needs" "$log"
check "missing DENY warned" /usr/bin/grep -q "DENY entry does not exist, check the spelling: $home/Documents/typo" "$log"
check "junk line skipped" /usr/bin/grep -q "skipped, not a full path: not a path" "$log"
check "built-ins listed" /usr/bin/grep -q "always writable for OpenCode itself" "$log"
check "rules.json" /usr/bin/jq -e --arg h "$home" '.deny == [$h + "/Projects/app/secret", $h + "/Documents/private", $h + "/Documents/typo"]' "$engine/state/rules.json"

temp=${$(/usr/bin/getconf DARWIN_USER_TEMP_DIR):A}
cache=${$(/usr/bin/getconf DARWIN_USER_CACHE_DIR):A}
sb() { /usr/bin/sandbox-exec -D "HOME=$home" -D "DARWIN_TEMP=$temp" -D "DARWIN_CACHE=$cache" -D GUI=0 -p "$profile" "$@" }
print data > "$home/Projects/app/secret/key"
print data > "$home/Documents/private/doc"

expect ok "write in ALLOW"                sb /usr/bin/touch "$home/Projects/app/new"
expect no "remove ALLOW root"             sb /bin/rmdir "$home/Projects/archive/live"
expect no "write in READ ONLY"            sb /usr/bin/touch "$home/Projects/archive/new"
expect ok "ALLOW inside READ ONLY"        sb /usr/bin/touch "$home/Projects/archive/live/new"
expect no "read DENY inside ALLOW"        sb /bin/cat "$home/Projects/app/secret/key"
expect no "list DENY"                     sb /bin/ls "$home/Documents/private"
expect no "rename DENY"                   sb /bin/mv "$home/Projects/app/secret" "$home/Projects/app/moved"
expect no "rename ancestor of DENY"       sb /bin/mv "$home/Projects/app" "$home/Projects/renamed"
expect no "write outside lists"           sb /usr/bin/touch "$home/Documents/new"
expect no "edit Guard List"               sb /bin/sh -c "echo x >> '$list'"
expect no "move Guard List folder"        sb /bin/mv "$home/OpenCode Guard" "$home/moved"
expect no "write engine"                  sb /usr/bin/touch "$engine/x"
expect no "write opencode config"         sb /usr/bin/touch "$home/.config/opencode/x"
expect no "write symlinked shell profile" sb /bin/sh -c "echo x >> '$home/Projects/dotfiles/zshrc'"
expect no "write project .opencode"       sb /bin/mkdir -p "$home/Projects/app/.opencode/plugins"
expect no "write project opencode.json"   sb /usr/bin/touch "$home/Projects/app/opencode.json"
expect no "exec open"                     sb /usr/bin/open -h
expect no "exec codesign"                 sb /usr/bin/codesign -h
expect no "exec diskutil"                 sb /usr/sbin/diskutil list
expect no "write project .cc-safety-net"  sb /bin/mkdir -p "$home/Projects/app/.cc-safety-net"
expect ok "write cc-safety-net logs"      sb /usr/bin/touch "$home/.cc-safety-net/logs/x"
expect ok "write temp"                    sb /usr/bin/touch "$temp/.opencode-guard-test"
expect no "write other per-user dirs"     sb /usr/bin/touch "${temp:h}/0/.opencode-guard-test"
/bin/rm -f "$temp/.opencode-guard-test"

/bin/mkdir -p "$home/fakebin"
print -r -- $'#!/bin/sh\ntouch "$HOME/Documents/escaped"\n[ "$CC_SAFETY_NET_PARANOID_RM" = 1 ] && touch "$HOME/Projects/app/launched"' > "$home/fakebin/opencode"
/bin/chmod 755 "$home/fakebin/opencode"
PATH="$home/fakebin:$PATH" OPENCODE_SANDBOXED=1 "$engine/bin/opencode" >/dev/null 2>&1
[[ -e $home/Projects/app/launched && ! -e $home/Documents/escaped ]] && pass "launch cli sandboxes despite OPENCODE_SANDBOXED, paranoid rm on" || fail "launch cli sandbox"

if command -v node >/dev/null; then
  plugin="$home/.config/opencode/plugins/opencode-guard.js"
  node "$root/test/plugin.mjs" "$plugin" unguarded || fails=$((fails + 1))
  OPENCODE_GUARD_BYPASS=1 node "$root/test/plugin.mjs" "$plugin" bypass || fails=$((fails + 1))
  sb "$(command -v node)" "$root/test/plugin.mjs" "$plugin" guarded || fails=$((fails + 1))
  /bin/mv "$engine/state" "$engine/state.real" && /bin/ln -s /System "$engine/state"
  node "$root/test/plugin.mjs" "$plugin" symlinked || fails=$((fails + 1))
  /bin/rm "$engine/state" && /bin/mv "$engine/state.real" "$engine/state"
else
  print "skip plugin checks (node not found)"
fi

/bin/zsh "$engine/uninstall.sh" >/dev/null 2>&1
[[ ! -e $engine && ! -e $home/.config/opencode/plugins/opencode-guard.js ]] && pass "uninstall" || fail "uninstall"
check "rc block removed" sh -c "! /usr/bin/grep -q opencode-guard '$home/.zshrc' '$home/.zprofile'"
check "permissions restored" /usr/bin/jq -e --argjson o "$original" '.permission == $o.permission' "$cfg"

/bin/rm -rf "$HOME"
print -r -- "$fails failure(s)"
(( fails == 0 ))

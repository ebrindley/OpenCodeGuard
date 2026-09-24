#!/bin/zsh
# usage: install.sh [--projects DIR] [--gui]
emulate -L zsh
setopt err_exit no_unset pipe_fail

src=${0:A:h}
home=${HOME:A}
engine="$home/Library/Application Support/OpenCodeGuard"
list_dir="$home/OpenCode Guard"
list="$list_dir/Guard List.txt"
conf="$home/.config/opencode"
launcher="$home/Applications/OpenCode Guarded.app"
cc="$home/.cc-safety-net/rules"
gui=0 projects=

while (( $# )); do
  case $1 in
    (--gui) gui=1 ;;
    (--projects) projects=${2:-}; shift ;;
    (*) print -u2 "unknown option: $1"; exit 2 ;;
  esac
  shift
done

die() { print -ru2 -- "OpenCode Guard: $*"; exit 1 }
say() { print -r -- "$*" }

[[ $(uname -s) == Darwin ]] || die "macOS only"
for t in /usr/bin/sandbox-exec /usr/bin/jq /usr/bin/osacompile /usr/bin/codesign; do
  [[ -x $t ]] || die "missing $t (macOS 15 or later required)"
done

/bin/mkdir -p "$engine/bin" "$engine/state"
/bin/cp "$src/engine/launch" "$src/engine/profile.sb" "$src/uninstall.sh" "$engine/"
/bin/cp "$src/engine/opencode" "$src/engine/opencode-gui" "$engine/bin/"
/bin/rm -rf "$engine/vendor"
/bin/cp -R "$src/vendor" "$engine/vendor"
/bin/chmod 755 "$engine/launch" "$engine/uninstall.sh" "$engine/bin/opencode" "$engine/bin/opencode-gui"
/usr/bin/xattr -dr com.apple.quarantine "$engine" 2>/dev/null || true
say "engine: $engine"

/bin/mkdir -p "$list_dir"
[[ -e $list ]] || /bin/cp "$src/templates/Guard List.txt" "$list"
if [[ -z $projects && $gui == 0 && -t 0 ]]; then
  print -n "Drag your projects folder here and press Return (Return alone skips): "
  read -r projects
fi
projects=${${projects##[[:space:]]##}%%[[:space:]]##}
if [[ -n $projects ]]; then
  [[ -e $projects ]] || projects=${(Q)projects}
  [[ -d $projects ]] || die "not a folder: $projects"
  projects=${projects:A}
  if ! /usr/bin/grep -Fxq -- "$projects" "$list"; then
    /usr/bin/awk -v p="$projects" '{ print } !done && toupper($0) ~ /^ALLOW/ { print p; done = 1 }' "$list" > "$list.tmp"
    /bin/mv -f "$list.tmp" "$list"
  fi
  say "allowed: $projects"
fi
say "list: $list"

/bin/mkdir -p "$conf/plugins"
/bin/cp "$src/plugin/opencode-guard.js" "$conf/plugins/opencode-guard.js"
cfg="$conf/opencode.json"
if [[ -e $cfg ]] && /usr/bin/jq -e '(.plugin // []) | map(tostring) | any(test("cc-safety-net"))' "$cfg" >/dev/null; then
  say "cc-safety-net already configured in opencode.json; bundled copy not loaded"
else
  print -r -- "import plugin from \"file://${engine// /%20}/vendor/cc-safety-net/dist/index.js\"
export default plugin" > "$conf/plugins/cc-safety-net.js"
fi

/bin/mkdir -p "$cc/opencode-guard"
/bin/cp "$src/templates/cc-safety-net/rules/opencode-guard/rulebook.json" "$cc/opencode-guard/rulebook.json"
if [[ -e $cc/rule.json ]]; then
  /usr/bin/jq '.rules = ((.rules // []) + ["opencode-guard"] | unique)' "$cc/rule.json" > "$cc/rule.json.tmp"
  /bin/mv -f "$cc/rule.json.tmp" "$cc/rule.json"
else
  /bin/cp "$src/templates/cc-safety-net/rules/rule.json" "$cc/rule.json"
fi

perm='{"edit":"allow","bash":"allow","external_directory":"allow"}'
if [[ -e $cfg ]]; then
  [[ -e $engine/state/opencode.json.orig ]] || /bin/cp "$cfg" "$engine/state/opencode.json.orig"
  /usr/bin/jq --argjson p "$perm" '.permission = ((.permission // {}) | if type == "string" then {"*": .} else . end) + $p' "$cfg" > "$cfg.tmp"
  /bin/mv -f "$cfg.tmp" "$cfg"
elif [[ -e $conf/opencode.jsonc ]]; then
  say "note: opencode.jsonc left unchanged; set permission edit, bash and external_directory to allow"
else
  /usr/bin/jq -n --argjson p "$perm" '{"$schema": "https://opencode.ai/config.json", permission: $p}' > "$cfg"
fi

for rc in "$home/.zprofile" "$home/.zshrc" "$home/.bash_profile"; do
  [[ $rc == *bash_profile && ! -e $rc ]] && continue
  [[ -e $rc ]] && /usr/bin/sed -i '' '/^# >>> opencode-guard >>>$/,/^# <<< opencode-guard <<<$/d' "$rc"
  if [[ $rc == *bash_profile ]]; then
    line='PATH="$HOME/Library/Application Support/OpenCodeGuard/bin:$PATH"'
  else
    line='path=("$HOME/Library/Application Support/OpenCodeGuard/bin" ${path:#"$HOME/Library/Application Support/OpenCodeGuard/bin"})'
  fi
  print -r -- $'# >>> opencode-guard >>>\n'"$line"$'\n# <<< opencode-guard <<<' >> "$rc"
done
say "PATH: new terminal windows run opencode inside the guard"

app=
for a in /Applications/OpenCode.app "$home/Applications/OpenCode.app"; do [[ -d $a ]] && { app=$a; break }; done
if [[ -n $app ]]; then
  /bin/rm -rf "$launcher"
  /bin/mkdir -p "${launcher:h}"
  /usr/bin/osacompile -o "$launcher" -e "do shell script quoted form of \"$engine/bin/opencode-gui\" & \" >/dev/null 2>&1 &\""
  /usr/bin/plutil -replace CFBundleIdentifier -string ai.opencodeguard.launcher "$launcher/Contents/Info.plist"
  icon=$(/usr/bin/plutil -extract CFBundleIconFile raw "$app/Contents/Info.plist" 2>/dev/null || true)
  [[ -n $icon ]] && /bin/cp "$app/Contents/Resources/${icon%.icns}.icns" "$launcher/Contents/Resources/applet.icns" 2>/dev/null || true
  /usr/bin/codesign --force --sign - "$launcher" 2>/dev/null
  say "GUI: $launcher (drag it to the Dock)"
else
  say "GUI: OpenCode.app not found; rerun the installer after installing it"
fi

say "self-test:"
"$engine/launch" check || die "self-test failed"

if [[ $gui == 1 || -t 1 ]]; then
  answer=$(/usr/bin/osascript -e 'button returned of (display dialog "OpenCode Guard is installed.\n\nOpen OpenCode with OpenCode Guarded, or type opencode in a new terminal window.\n\nEdit the allow and deny list now?" buttons {"Later", "Edit List"} default button "Edit List" with title "OpenCode Guard")' 2>/dev/null || true)
  [[ $answer == "Edit List" ]] && /usr/bin/open -e "$list"
fi
say "done"

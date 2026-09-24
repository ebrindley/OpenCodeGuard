#!/bin/zsh
emulate -L zsh
setopt err_exit no_unset pipe_fail

home=${HOME:A}
engine="$home/Library/Application Support/OpenCodeGuard"
conf="$home/.config/opencode"
cfg="$conf/opencode.json"
cc="$home/.cc-safety-net/rules"

for rc in "$home/.zprofile" "$home/.zshrc" "$home/.bash_profile"; do
  [[ -e $rc ]] && /usr/bin/sed -i '' '/^# >>> opencode-guard >>>$/,/^# <<< opencode-guard <<<$/d' "$rc"
done

/bin/rm -f "$conf/plugins/opencode-guard.js" "$conf/plugins/cc-safety-net.js"
/bin/rm -rf "$home/Applications/OpenCode Guarded.app" "$cc/opencode-guard"
if [[ -e $cc/rule.json ]]; then
  /usr/bin/jq '.rules -= ["opencode-guard"]' "$cc/rule.json" > "$cc/rule.json.tmp"
  /bin/mv -f "$cc/rule.json.tmp" "$cc/rule.json"
fi

orig="$engine/state/opencode.json.orig"
if [[ -e $orig && -e $cfg ]]; then
  /usr/bin/jq --slurpfile o "$orig" 'if $o[0] | has("permission") then .permission = $o[0].permission else del(.permission) end' "$cfg" > "$cfg.tmp"
  /bin/mv -f "$cfg.tmp" "$cfg"
fi

/bin/rm -rf "$engine"
print -r -- "OpenCode Guard removed. Your list is still at $home/OpenCode Guard."

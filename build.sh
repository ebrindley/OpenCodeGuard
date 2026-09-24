#!/bin/zsh
emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h}
out="$root/dist"
stage=$(/usr/bin/mktemp -d)
pkg="$stage/OpenCode Guard"
app="$pkg/Install OpenCode Guard.app"
payload="$app/Contents/Resources/payload"

/bin/mkdir -p "$pkg"
/usr/bin/osacompile -o "$app" "$root/installer/Install.applescript"
/usr/bin/plutil -replace CFBundleIdentifier -string ai.opencodeguard.installer "$app/Contents/Info.plist"
/bin/mkdir -p "$payload"
/bin/cp -R "$root/install.sh" "$root/uninstall.sh" "$root/engine" "$root/plugin" "$root/templates" "$root/vendor" "$root/LICENSE" "$payload/"
/usr/bin/codesign --force --sign - "$app"
/bin/cp "$root/README.md" "$pkg/README.md"

/bin/rm -rf "$out"
/bin/mkdir -p "$out"
/usr/bin/ditto -c -k --norsrc --noextattr --noqtn --keepParent "$pkg" "$out/OpenCodeGuard.zip"
/usr/bin/hdiutil create -quiet -volname "OpenCode Guard" -srcfolder "$pkg" -format UDZO "$out/OpenCodeGuard.dmg"
/bin/rm -rf "$stage"
print -r -- "$out/OpenCodeGuard.zip"
print -r -- "$out/OpenCodeGuard.dmg"

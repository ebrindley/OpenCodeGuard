#!/bin/zsh
emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h}
out="$root/dist"
stage=$(/usr/bin/mktemp -d)
pkg="$stage/OpenCode Guard"
app="$pkg/Install OpenCode Guard.app"
payload="$app/Contents/Resources/payload"

/bin/mkdir -p "$pkg" "$stage/icon.iconset"
/usr/bin/qlmanage -t -s 1024 -o "$stage" "$root/assets/icon.svg" >/dev/null
/bin/mv "$stage/icon.svg.png" "$root/assets/icon.png"
for s in 16 32 128 256 512; do
  /usr/bin/sips -z $s $s "$root/assets/icon.png" --out "$stage/icon.iconset/icon_${s}x${s}.png" >/dev/null
  /usr/bin/sips -z $((s * 2)) $((s * 2)) "$root/assets/icon.png" --out "$stage/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$stage/icon.iconset" -o "$root/assets/OpenCodeGuard.icns"
/usr/bin/osacompile -o "$app" "$root/installer/Install.applescript"
/usr/bin/plutil -replace CFBundleIdentifier -string ai.opencodeguard.installer "$app/Contents/Info.plist"
/bin/cp "$root/assets/OpenCodeGuard.icns" "$app/Contents/Resources/applet.icns"
/bin/rm -f "$app/Contents/Resources/Assets.car"
/usr/bin/plutil -remove CFBundleIconName "$app/Contents/Info.plist"
/bin/mkdir -p "$payload"
/bin/cp -R "$root/install.sh" "$root/uninstall.sh" "$root/engine" "$root/plugin" "$root/templates" "$root/vendor" "$root/assets" "$root/LICENSE" "$payload/"
/usr/bin/codesign --force --sign - "$app"
/bin/cp "$root/README.md" "$pkg/README.md"

/bin/rm -rf "$out"
/bin/mkdir -p "$out"
/usr/bin/ditto -c -k --norsrc --noextattr --noqtn --keepParent "$pkg" "$out/OpenCodeGuard.zip"
/usr/bin/hdiutil create -quiet -volname "OpenCode Guard" -srcfolder "$pkg" -format UDZO "$out/OpenCodeGuard.dmg"
/bin/rm -rf "$stage"
print -r -- "$out/OpenCodeGuard.zip"
print -r -- "$out/OpenCodeGuard.dmg"

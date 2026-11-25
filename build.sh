#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
version=1.0.4
name="ChatGPT Account Launcher"
identifier=io.github.marcosmro.multi-ai-launcher
mkdir -p dist .build
stage=$(mktemp -d "$PWD/.build/package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/root/$name.app"
pkg="$stage/Multi-AI-Launcher-$version.pkg"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$stage/Launcher.iconset"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"

if [[ -n "${APP_SIGN_IDENTITY:-}${INSTALLER_SIGN_IDENTITY:-}${NOTARY_PROFILE:-}" ]]; then
    : "${APP_SIGN_IDENTITY:?Set the Developer ID Application identity}"
    : "${INSTALLER_SIGN_IDENTITY:?Set the Developer ID Installer identity}"
fi

for arch in arm64 x86_64; do
    xcrun swiftc -O -target "${arch}-apple-macosx13.0" -module-name MultiAILauncher src/*.swift -o "$stage/launcher-$arch"
done
lipo -create "$stage/launcher-arm64" "$stage/launcher-x86_64" -output "$app/Contents/MacOS/Launcher"
xcrun swift packaging/icon.swift "$stage/Launcher.iconset"
iconutil -c icns "$stage/Launcher.iconset" -o "$app/Contents/Resources/Launcher.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIdentifier</key><string>$identifier</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundleExecutable</key><string>Launcher</string>
<key>CFBundleIconFile</key><string>Launcher</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
codesign --force --options runtime --sign "${APP_SIGN_IDENTITY:--}" "$app"
codesign --verify --strict --all-architectures "$app"
pkgbuild --analyze --root "$stage/root" "$stage/component.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$stage/component.plist"
pkgbuild --root "$stage/root" --component-plist "$stage/component.plist" --install-location /Applications \
    --identifier "$identifier" --version "$version" "$stage/Launcher-core.pkg"
sign_args=()
if [[ -n "${INSTALLER_SIGN_IDENTITY:-}" ]]; then sign_args=(--sign "$INSTALLER_SIGN_IDENTITY"); fi
productbuild --distribution packaging/Distribution.xml --resources packaging/resources --package-path "$stage" \
    ${sign_args[@]+"${sign_args[@]}"} "$pkg"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$pkg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$pkg"
    spctl --assess --type install "$pkg"
fi
if [[ -e "dist/$name.app" ]]; then mv "dist/$name.app" "$stage/previous.app"; fi
mv "$app" "dist/$name.app"
mv "$pkg" dist/
printf 'Built dist/%s.app and dist/Multi-AI-Launcher-%s.pkg\n' "$name" "$version"

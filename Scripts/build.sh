#!/bin/bash
# 不需要 Xcode 的构建方式：swiftc + 手工组装 .app。
# 仅在装了 Command Line Tools 的机器上也能编译运行 Timer。
# 用法：Scripts/build.sh        产物：.build/Timer.app
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="Timer"
BUILD=".build"
APP="$BUILD/Timer.app"
CONTENTS="$APP/Contents"
RESOURCES="$CONTENTS/Resources"
BIN="$CONTENTS/MacOS/Timer"

BUNDLE_ID="com.michaelvillar.Timer"
VERSION="2.1.0"
BUILD_VERSION="1"
DEPLOYMENT_TARGET="14.0"
ARCH="$(uname -m)"

SDK="$(xcrun --show-sdk-path)"

rm -rf "$BUILD"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES" "$BUILD/tmp"

echo "==> 生成颜色表 mvcolors.json"
python3 Scripts/gen_colors.py "$SRC/Assets.xcassets" "$BUILD/tmp/mvcolors.json"

echo "==> 编译 Swift (SDK: $SDK)"
swiftc \
  -O \
  -parse-as-library \
  -swift-version 6 \
  -target "${ARCH}-apple-macosx${DEPLOYMENT_TARGET}" \
  -sdk "$SDK" \
  "$SRC"/*.swift \
  -o "$BIN"

echo "==> 拷贝资源"
cp "$BUILD/tmp/mvcolors.json" "$RESOURCES/mvcolors.json"
cp "$SRC"/*.caf "$SRC/Credits.rtf" "$SRC/Timer.sdef" "$RESOURCES/"
for image in "$SRC"/Assets.xcassets/*.imageset/*.png; do
  cp "$image" "$RESOURCES/$(basename "$image")"
done

echo "==> 生成 AppIcon.icns"
ICONSET="$BUILD/tmp/AppIcon.iconset"
mkdir -p "$ICONSET"
icon_dir="$SRC/Assets.xcassets/AppIcon.appiconset"
copy_icon() {
  [[ -f "$icon_dir/$2" ]] && cp "$icon_dir/$2" "$ICONSET/$1" || true
}
copy_icon "icon_16x16.png" "app-icon_16.png"
copy_icon "icon_16x16@2x.png" "app-icon_32.png"
copy_icon "icon_32x32.png" "app-icon_32.png"
copy_icon "icon_32x32@2x.png" "app-icon_64.png"
copy_icon "icon_128x128.png" "app-icon_128.png"
copy_icon "icon_128x128@2x.png" "app-icon_256.png"
copy_icon "icon_256x256.png" "app-icon_256.png"
copy_icon "icon_256x256@2x.png" "app-icon_512.png"
copy_icon "icon_512x512.png" "app-icon_512.png"
copy_icon "icon_512x512@2x.png" "app-icon_1024.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

echo "==> 写入 Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Timer</string>
	<key>CFBundleExecutable</key>
	<string>Timer</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Timer</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_VERSION</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>$DEPLOYMENT_TARGET</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>$BUNDLE_ID</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>timer</string>
			</array>
		</dict>
	</array>
	<key>NSAppleScriptEnabled</key>
	<true/>
	<key>OSAScriptingDefinition</key>
	<string>Timer.sdef</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> 签名"
codesign --force --deep --sign - "$APP"

rm -rf "$BUILD/tmp"

echo "==> 完成：$APP"

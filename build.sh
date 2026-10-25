#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
DEST="${1:-build/歇一会.app}"
mkdir -p build/ModuleCache "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macosx13.0 -module-cache-path build/ModuleCache Sources/Engine.swift Sources/main.swift -o "$DEST/Contents/MacOS/RestLeaf" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework IOKit
xcrun swiftc -module-cache-path build/ModuleCache DrawIcon.swift -o build/DrawIcon -framework AppKit
build/DrawIcon build/AppIcon.iconset
python3 pack-icon.py build/AppIcon.iconset "$DEST/Contents/Resources/AppIcon.icns"
cp Info.plist "$DEST/Contents/Info.plist"
codesign --force --sign - --identifier local.naco.RestLeaf "$DEST"
"$DEST/Contents/MacOS/RestLeaf" --self-test
echo "Built: $DEST"

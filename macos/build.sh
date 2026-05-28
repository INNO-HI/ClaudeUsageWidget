#!/bin/bash
set -e

APP_NAME="Claude Usage Widget"
BUNDLE_NAME="ClaudeUsageWidget"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SPARKLE_FRAMEWORK="vendor/Sparkle.framework"

# Signing/notarization configuration (override via env vars if needed)
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: INNO-HI Inc. (4AL4PF4BK4)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ClaudeUsageWidget}"
# Toggles:
#   SKIP_SIGN=1     → no signing, no notarization (fastest local build)
#   SKIP_NOTARIZE=1 → sign only, skip Apple notarization (dev verification)
#   SKIP_DMG=1      → skip DMG creation (zip only)

echo "🔨 Building ${APP_NAME}..."

# Clean build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Create .app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

# Copy Info.plist
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"

# Copy icon if available
ICON_SOURCE="$HOME/Downloads/클로드코드 이미지.png"
if [ -f "${ICON_SOURCE}" ]; then
    ICON_DIR="${BUILD_DIR}/icon.iconset"
    mkdir -p "${ICON_DIR}"

    sips -z 16 16     "${ICON_SOURCE}" --out "${ICON_DIR}/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICON_DIR}/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICON_DIR}/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "${ICON_SOURCE}" --out "${ICON_DIR}/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "${ICON_SOURCE}" --out "${ICON_DIR}/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICON_DIR}/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICON_DIR}/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICON_DIR}/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICON_DIR}/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_512x512@2x.png" 2>/dev/null

    iconutil -c icns "${ICON_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    rm -rf "${ICON_DIR}"

    echo "✅ Icon created"
fi

# Copy Sparkle.framework into the bundle BEFORE signing
echo "📦 Copying Sparkle.framework..."
cp -R "${SPARKLE_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/"

# Compile Swift source files for arm64 + x86_64, then lipo into a Universal Binary
echo "📦 Compiling Swift sources (Universal: arm64 + x86_64)..."

SWIFT_SOURCES=(
    Sources/Localization.swift
    Sources/Models.swift
    Sources/EventMonitor.swift
    Sources/UsageService.swift
    Sources/PopoverContentView.swift
    Sources/AppDelegate.swift
    Sources/main.swift
)

SWIFT_FLAGS=(
    -sdk "$(xcrun --show-sdk-path)"
    -F vendor
    -framework SwiftUI
    -framework AppKit
    -framework Combine
    -framework ServiceManagement
    -framework Sparkle
    -O
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks
)

ARM64_BIN="${BUILD_DIR}/ClaudeUsageBar-arm64"
X86_BIN="${BUILD_DIR}/ClaudeUsageBar-x86_64"

swiftc -target arm64-apple-macosx13.0  "${SWIFT_FLAGS[@]}" -o "${ARM64_BIN}" "${SWIFT_SOURCES[@]}"
swiftc -target x86_64-apple-macosx13.0 "${SWIFT_FLAGS[@]}" -o "${X86_BIN}"   "${SWIFT_SOURCES[@]}"

lipo -create "${ARM64_BIN}" "${X86_BIN}" -output "${APP_BUNDLE}/Contents/MacOS/ClaudeUsageBar"
rm "${ARM64_BIN}" "${X86_BIN}"

echo "✅ Compilation successful — Universal Binary: $(lipo -archs "${APP_BUNDLE}/Contents/MacOS/ClaudeUsageBar")"

# Update Info.plist with icon reference
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_BUNDLE}/Contents/Info.plist"

# ---- Code Signing (Sparkle nested → main app) ----
if [ "${SKIP_SIGN}" = "1" ]; then
    echo ""
    echo "⏭️  Skipping code signing (SKIP_SIGN=1) — app will not run on other Macs"
else
    echo ""
    echo "🔏 Code signing: ${SIGN_IDENTITY}"

    ENTITLEMENTS="${BUILD_DIR}/entitlements.plist"
    cat > "${ENTITLEMENTS}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
EOF

    # Sparkle 2.x nested binaries must be signed individually with hardened runtime
    SPARKLE_VERSIONED="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"

    # Inner-most binaries first (XPC services, helper apps), then framework, then main app
    for nested in \
        "${SPARKLE_VERSIONED}/XPCServices/Downloader.xpc" \
        "${SPARKLE_VERSIONED}/XPCServices/Installer.xpc" \
        "${SPARKLE_VERSIONED}/Updater.app" \
        "${SPARKLE_VERSIONED}/Autoupdate"; do
        if [ -e "${nested}" ]; then
            codesign --force --options runtime --timestamp \
                --sign "${SIGN_IDENTITY}" \
                "${nested}"
        fi
    done

    codesign --force --options runtime --timestamp \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"

    # Main app (no --deep; nested already signed above)
    codesign --force --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}"

    echo "✅ Code signing complete"

    # ---- Notarization ----
    if [ "${SKIP_NOTARIZE}" = "1" ]; then
        echo "⏭️  Skipping notarization (SKIP_NOTARIZE=1) — Gatekeeper will block on first download"
    else
        echo ""
        echo "📝 Submitting for notarization (1~5 minutes)..."

        NOTARY_ZIP="${BUILD_DIR}/${BUNDLE_NAME}-notary.zip"
        ditto -c -k --keepParent "${APP_BUNDLE}" "${NOTARY_ZIP}"

        xcrun notarytool submit "${NOTARY_ZIP}" \
            --keychain-profile "${NOTARY_PROFILE}" \
            --wait

        rm -f "${NOTARY_ZIP}"

        echo ""
        echo "📎 Stapling ticket to .app..."
        xcrun stapler staple "${APP_BUNDLE}"

        echo ""
        echo "🔍 Verifying with Gatekeeper..."
        spctl --assess --type execute --verbose=4 "${APP_BUNDLE}"

        # Final distribution zip (stapled, ready to upload)
        DIST_ZIP="${BUILD_DIR}/${BUNDLE_NAME}.zip"
        ditto -c -k --keepParent "${APP_BUNDLE}" "${DIST_ZIP}"
        echo ""
        echo "📦 Distribution zip: ${DIST_ZIP}"

        # ---- DMG (preferred for end-user download) ----
        if [ "${SKIP_DMG}" != "1" ]; then
            echo ""
            echo "💿 Creating DMG..."
            DMG_PATH="${BUILD_DIR}/${BUNDLE_NAME}.dmg"
            rm -f "${DMG_PATH}"
            hdiutil create \
                -volname "${APP_NAME}" \
                -srcfolder "${APP_BUNDLE}" \
                -ov -format UDZO \
                "${DMG_PATH}" >/dev/null
            echo "📦 Distribution dmg: ${DMG_PATH}"
        fi

        # ---- Sparkle EdDSA signature for appcast ----
        echo ""
        echo "🔑 Generating Sparkle EdDSA signature..."
        SIGN_TARGET="${DIST_ZIP}"
        if [ -f "${BUILD_DIR}/${BUNDLE_NAME}.dmg" ]; then
            SIGN_TARGET="${BUILD_DIR}/${BUNDLE_NAME}.dmg"
        fi
        EDDSA_LINE=$(./vendor/bin/sign_update "${SIGN_TARGET}")
        echo ""
        echo "  ↳ Append to your appcast.xml <enclosure> for $(basename "${SIGN_TARGET}"):"
        echo "    ${EDDSA_LINE}"
        echo ""
    fi
fi

echo ""
echo "✅ Build complete!"
echo "📍 App location: ${APP_BUNDLE}"
echo ""
echo "To run:     open \"${APP_BUNDLE}\""
echo "To install: cp -r \"${APP_BUNDLE}\" /Applications/"

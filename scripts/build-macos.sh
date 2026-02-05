#!/bin/bash
#
# Build script for CRT Plus on macOS
# Clears QML caches, builds the project, and deploys the QMLTermWidget
# plugin into the app bundle.
#
# Usage:
#   ./scripts/build-macos.sh           # Build only
#   ./scripts/build-macos.sh --install  # Build and copy to /Applications
#   ./scripts/build-macos.sh --run      # Build, install, and launch
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="crt-plus"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
PLUGIN_SRC="$PROJECT_DIR/qmltermwidget/QMLTermWidget"
PLUGIN_DST="$APP_BUNDLE/Contents/PlugIns/QMLTermWidget"
INSTALL_PATH="/Applications/CRT Plus.app"
NCPU=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

# QML cache locations that can cause stale behavior
QML_CACHES=(
    "$HOME/Library/Caches/crt-plus/crt-plus/qmlcache"
    "$HOME/Library/Caches/cool-retro-term/cool-retro-term/qmlcache"
)

echo "==> Clearing QML caches"
for cache in "${QML_CACHES[@]}"; do
    if [ -d "$cache" ]; then
        rm -rf "$cache"
        echo "    Removed $cache"
    fi
done

echo "==> Touching resources.qrc to force resource recompilation"
touch "$PROJECT_DIR/app/qml/resources.qrc"

echo "==> Building ($NCPU parallel jobs)"
cd "$PROJECT_DIR"
make -j"$NCPU"

echo "==> Deploying QMLTermWidget plugin into app bundle"
rm -rf "$PLUGIN_DST"
cp -R "$PLUGIN_SRC" "$PLUGIN_DST"

echo "==> Build complete: $APP_BUNDLE"

if [ "$1" = "--install" ] || [ "$1" = "--run" ]; then
    echo "==> Installing to $INSTALL_PATH"
    rm -rf "$INSTALL_PATH"
    cp -R "$APP_BUNDLE" "$INSTALL_PATH"
    echo "    Installed."
fi

if [ "$1" = "--run" ]; then
    echo "==> Launching CRT Plus"
    pkill -f "$APP_NAME" 2>/dev/null || true
    sleep 1
    open "$INSTALL_PATH"
fi

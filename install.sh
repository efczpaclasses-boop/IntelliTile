#!/bin/bash
# IntelliTile installer: Intel Mac port of k97/dock-tile (unofficial).
#
# Builds IntelliTile from this source folder for x86_64 with your full Xcode 26.2 / 26.3 and
# installs it to ~/Applications/IntelliTile.app. No sudo, no Homebrew, no Rust. Safe to re-run.
#
#   ./install.sh               build and install (or rebuild and replace)
#   ./install.sh --uninstall   remove ~/IntelPorts/dock-tile and ~/Applications/IntelliTile.app
#   ./install.sh --help
#
# Optional environment variables:
#   INTELLITILE_XCODE=/path/to/Xcode.app   use this Xcode (must be 26.2.x or 26.3.x)
#   INTELLITILE_JOBS=2                     parallel compile jobs (default 2, for 8 GB RAM)
set -euo pipefail

APP_NAME="IntelliTile"
BUNDLE_ID="io.github.efczpaclasses-boop.IntelliTile"
PORT_ROOT="${HOME}/IntelPorts/dock-tile"
DERIVED="${PORT_ROOT}/DerivedData"
PACKAGES="${PORT_ROOT}/SourcePackages"
LOG_DIR="${PORT_ROOT}/logs"
APPS_DIR="${HOME}/Applications"
APP_DEST="${APPS_DIR}/${APP_NAME}.app"
SUPPORT_DIR="${HOME}/Library/Application Support/IntelliTile"
MIN_MACOS="15.6"          # Xcode 26.0-26.3 need macOS 15.6 or later
MIN_FREE_GIB=8            # DerivedData + Swift packages (Firebase) + the app
JOBS="${INTELLITILE_JOBS:-2}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    WARNING: %s\n' "$*" >&2; }
die()  { printf '\nSTOPPED: %s\n' "$1" >&2; exit "${2:-1}"; }

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

# version_ge A B  -> true if dotted version A >= B
version_ge() {
    local IFS=.
    local a b i
    read -r -a a <<< "$1"
    read -r -a b <<< "$2"
    for i in 0 1 2; do
        local x="${a[$i]:-0}" y="${b[$i]:-0}"
        x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
        if (( ${x:-0} > ${y:-0} )); then return 0; fi
        if (( ${x:-0} < ${y:-0} )); then return 1; fi
    done
    return 0
}

check_mac() {
    say "Checking this Mac"
    [ "$(uname -s)" = "Darwin" ] || die "This installer runs on macOS only."
    local arch translated
    arch="$(uname -m)"
    translated="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
    if [ "$arch" != "x86_64" ] || [ "$translated" = "1" ]; then
        die "This port is for Intel (x86_64) Macs. This Mac reports '$arch' (Rosetta: $translated). Apple silicon Macs should use the official app."
    fi
    info "CPU: Intel x86_64"
    local ver
    ver="$(sw_vers -productVersion)"
    version_ge "$ver" "$MIN_MACOS" || die "macOS $ver found; Xcode 26 needs macOS $MIN_MACOS or later. Update macOS in System Settings > General > Software Update, then re-run."
    info "macOS: $ver (needs $MIN_MACOS or later)"
    local free_kib free_gib
    free_kib="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
    free_gib=$(( free_kib / 1024 / 1024 ))
    [ "$free_gib" -ge "$MIN_FREE_GIB" ] || die "Only ${free_gib} GiB free in your home folder; the build needs about ${MIN_FREE_GIB} GiB. Free some space and re-run."
    info "Free disk: ${free_gib} GiB (needs ${MIN_FREE_GIB} GiB)"
    if pmset -g batt 2>/dev/null | grep "Battery Power" >/dev/null; then
        warn "Running on battery. Please plug in the charger: the build is long and CPU-heavy."
    fi
}

xcode_version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$1/Contents/version.plist" 2>/dev/null || true
}

find_xcode() {
    say "Looking for full Xcode 26.2 or 26.3"
    local candidates=() x v best="" best_v=""
    if [ -n "${INTELLITILE_XCODE:-}" ]; then
        candidates=("$INTELLITILE_XCODE")
    else
        for x in /Applications/Xcode*.app "$HOME"/Applications/Xcode*.app; do
            [ -d "$x" ] && candidates+=("$x")
        done
    fi
    [ "${#candidates[@]}" -gt 0 ] || die "No Xcode found in /Applications or ~/Applications. Install Xcode 26.3 (or 26.2) Universal from developer.apple.com (see the test plan), then re-run."
    for x in "${candidates[@]}"; do
        v="$(xcode_version "$x")"
        case "$v" in
            26.2|26.2.*|26.3|26.3.*)
                if ! lipo -archs "$x/Contents/MacOS/Xcode" 2>/dev/null | grep -w x86_64 >/dev/null; then
                    info "$x is Xcode $v but Apple silicon only: skipped (you need the Universal download)"
                    continue
                fi
                info "Found $x (Xcode $v)"
                if [ -z "$best" ] || version_ge "$v" "$best_v"; then best="$x"; best_v="$v"; fi
                ;;
            "") info "$x: not a readable Xcode, skipped" ;;
            *)  info "$x is Xcode $v: skipped (this Mac needs 26.2 or 26.3; 26.4+ needs Tahoe, 27 is Apple silicon only)" ;;
        esac
    done
    [ -n "$best" ] || die "No usable Xcode 26.2/26.3 (Universal) found. Install it from developer.apple.com, then re-run."
    export DEVELOPER_DIR="$best/Contents/Developer"
    info "Using $best (Xcode $best_v) via DEVELOPER_DIR (no xcode-select change)"
}

check_xcode_ready() {
    say "Checking Xcode is ready to build"
    if ! xcodebuild -license check >/dev/null 2>&1; then
        die "The Xcode licence has not been accepted yet. This needs your approval and admin password: open the Xcode app once and click Agree (or run: sudo \"$DEVELOPER_DIR/usr/bin/xcodebuild\" -license accept). Then re-run ./install.sh." 3
    fi
    info "Xcode licence: accepted"
    if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        die "Xcode's first-launch setup has not run yet. This needs your approval: open the Xcode app once and let it install its components (admin password may be asked). Then re-run ./install.sh." 3
    fi
    info "Xcode first-launch setup: done"
    local sdk
    sdk="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
    version_ge "${sdk:-0}" "26.0" || die "Xcode's macOS SDK is '${sdk:-missing}'; the project needs the macOS 26 SDK (Xcode 26.x)."
    info "macOS SDK: $sdk"
}

build_app() {
    say "Building $APP_NAME for x86_64 (Release). First build downloads Swift packages and can take 15-40 minutes"
    mkdir -p "$DERIVED" "$PACKAGES" "$LOG_DIR"
    local log
    log="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"
    info "Full log: $log"
    info "Parallel jobs: $JOBS (set INTELLITILE_JOBS to change)"
    local start=$SECONDS
    (
        cd "$SRC_DIR"
        xcodebuild \
            -project DockTile.xcodeproj \
            -scheme DockTile \
            -configuration Release \
            -destination 'platform=macOS,arch=x86_64' \
            -derivedDataPath "$DERIVED" \
            -clonedSourcePackagesDirPath "$PACKAGES" \
            -jobs "$JOBS" \
            ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES \
            CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
            COMPILER_INDEX_STORE_ENABLE=NO \
            build
    ) > "$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        sleep 30
        kill -0 "$pid" 2>/dev/null && info "still building... $(( (SECONDS - start) / 60 )) min"
    done
    if ! wait "$pid"; then
        printf '\n---- last errors from the build log ----\n' >&2
        grep -E "error:|BUILD FAILED|\*\* .* FAILED \*\*" "$log" | tail -n 25 >&2 || true
        printf -- '---- last 30 lines ----\n' >&2
        tail -n 30 "$log" >&2
        die "Build failed. Send the full log to Port Lead: $log" 4
    fi
    info "Build succeeded in $(( (SECONDS - start) / 60 )) min"
    BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
    [ -d "$BUILT_APP" ] || die "Build said OK but $BUILT_APP is missing. Log: $log" 4
    LAST_LOG="$log"
}

verify_app() {
    say "Checking the built app"
    local exe id archs
    exe="$BUILT_APP/Contents/MacOS/$APP_NAME"
    archs="$(lipo -archs "$exe" 2>/dev/null || true)"
    case " $archs " in *" x86_64 "*) info "Architecture: $archs" ;; *) die "Built binary is '$archs', not x86_64. Log: $LAST_LOG" 4 ;; esac
    id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$BUILT_APP/Contents/Info.plist")"
    [ "$id" = "$BUNDLE_ID" ] || die "Unexpected bundle ID '$id' (expected $BUNDLE_ID)." 4
    info "Bundle ID: $id"
    if [ -d "$BUILT_APP/Contents/Frameworks/Sparkle.framework" ]; then
        die "Sparkle.framework is in the bundle; it must not be. Log: $LAST_LOG" 4
    fi
    info "Sparkle: not bundled (good)"
    if codesign --verify --deep --strict "$BUILT_APP" >/dev/null 2>&1; then
        info "Signature: valid (ad-hoc)"
    else
        warn "codesign --verify reported a problem; the app may still run. Details: codesign --verify --deep --strict -vv \"$BUILT_APP\""
    fi
}

install_app() {
    say "Installing to $APP_DEST"
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        die "$APP_NAME is running. Quit it (menu bar icon > Quit $APP_NAME, or Cmd+Q in its window), then re-run ./install.sh. Your tiles keep working." 5
    fi
    mkdir -p "$APPS_DIR"
    local staging="$APPS_DIR/.${APP_NAME}.app.installing"
    rm -rf "$staging"
    ditto "$BUILT_APP" "$staging"
    if [ -e "$APP_DEST" ]; then
        rm -rf "$APP_DEST"
        info "Replaced the previous copy"
    fi
    mv "$staging" "$APP_DEST"
    info "Installed: $APP_DEST"
}

print_data_locations() {
    cat <<EOF
    Tiles and settings live outside the app (this installer never touches them):
      - Tile helper apps and diagnostics log: $SUPPORT_DIR/
      - Tile list:        ~/Library/Preferences/${BUNDLE_ID}.configs.json
      - Smart Add log:    ~/Library/Preferences/${BUNDLE_ID}.smartadd.json
      - App settings:     ~/Library/Preferences/${BUNDLE_ID}.plist
                          ~/Library/Preferences/${BUNDLE_ID}.shared.plist
                          ~/Library/Preferences/${BUNDLE_ID}.tile.*.plist (one per tile)
      - Start at Login:   System Settings > General > Login Items ($APP_NAME)
      - Dock Lock:        System Settings > Privacy & Security > Accessibility ($APP_NAME)
EOF
}

uninstall() {
    say "Uninstalling $APP_NAME (only its own files)"
    info "This removes exactly:"
    info "  $PORT_ROOT   (source, build files, logs)"
    info "  $APP_DEST"
    printf '\n    IMPORTANT: delete your tiles in %s first (select each tile > Delete), so their\n' "$APP_NAME"
    printf '    Dock icons and helper apps are removed properly. The app cannot do that once it is gone.\n'
    local n=0
    if [ -d "$SUPPORT_DIR" ]; then
        n="$(find "$SUPPORT_DIR" -maxdepth 1 -name '*.app' -type d 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if [ "$n" -gt 0 ]; then warn "$n tile helper app(s) still exist in $SUPPORT_DIR"; fi
    if [ "${ASSUME_YES:-0}" != "1" ]; then
        printf '\n    Type yes to remove the two items above: '
        local answer=""
        read -r answer || true
        [ "$answer" = "yes" ] || die "Nothing was removed."
    fi
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        die "$APP_NAME is running. Quit it first, then re-run ./install.sh --uninstall." 5
    fi
    if [ -z "$HOME" ] || [ "$HOME" = "/" ]; then die "HOME is not set safely; nothing removed."; fi
    local p
    for p in "$APP_DEST" "$PORT_ROOT"; do
        if [ -L "$p" ]; then rm -f "$p"; info "Removed link $p"
        elif [ -e "$p" ]; then rm -rf "$p"; info "Removed $p"
        else info "Not present: $p"; fi
    done
    say "Done. Left in place on purpose:"
    print_data_locations
    info "Delete those yourself only if you no longer want your tiles or settings."
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        --uninstall)
            if [ "${2:-}" = "--yes" ]; then ASSUME_YES=1; fi
            uninstall; exit 0 ;;
        "") ;;
        *) usage; die "Unknown option: $1" 2 ;;
    esac
    say "$APP_NAME installer (unofficial Intel Mac port of k97/dock-tile)"
    info "Source: $SRC_DIR"
    [ -f "$SRC_DIR/DockTile.xcodeproj/project.pbxproj" ] || die "Run this from the IntelliTile source folder (DockTile.xcodeproj not found next to install.sh)."
    check_mac
    find_xcode
    check_xcode_ready
    build_app
    verify_app
    install_app
    say "Installed. Open it with:  open \"$APP_DEST\""
    info "Build files are kept in $PORT_ROOT (re-runs are faster). Update later with ./update.sh"
    print_data_locations
}

# Whole script is parsed before anything runs, so --uninstall can safely remove this folder.
main "$@"; exit $?

#!/bin/bash
# IntelliTile CI helper (Intel Mac port). Usage:
#   Scripts/intel-port/ci-inspect.sh binaries <App.app> <report.txt>
#   Scripts/intel-port/ci-inspect.sh smoke    <App.app> <report.txt>
# 'binaries' records file / lipo -info / minimum macOS for every Mach-O in the bundle and fails if
# any lacks x86_64 or needs a newer macOS than MAX_MINOS (default 15.8, the target Mac's line).
# 'smoke' checks identifiers, that Sparkle and the Firebase project config are absent, and that no
# original-brand strings ship (TRADEMARKS.md). Read-only; never launches the app.
set -euo pipefail

mode="${1:?mode}"; APP="${2:?app path}"; REPORT="${3:?report path}"
MAX_MINOS="${MAX_MINOS:-15.8}"
BUNDLE_ID="io.github.efczpaclasses-boop.IntelliTile"
: > "$REPORT"
fail=0
log()  { printf '%s\n' "$*" | tee -a "$REPORT"; }
bad()  { log "FAIL: $*"; fail=1; }
good() { log "ok:   $*"; }
eq()   { if [ "$1" = "$2" ]; then good "$3"; else bad "$3 (got '$1', want '$2')"; fi; }
cond() { local d="$1"; shift; if "$@"; then good "$d"; else bad "$d"; fi; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null || true; }

[ -d "$APP" ] || { log "FAIL: app bundle not found: $APP"; exit 1; }

minos_of() {
    # vtool ships with Xcode; fall back to otool for LC_VERSION_MIN_MACOSX binaries.
    local m
    m="$(xcrun vtool -arch x86_64 -show-build "$1" 2>/dev/null | awk '/minos/ {print $2; exit}')"
    if [ -z "$m" ]; then
        m="$(otool -arch x86_64 -l "$1" 2>/dev/null | awk '/LC_VERSION_MIN_MACOSX/ {f=1} f && /version/ {print $2; exit}')"
    fi
    printf '%s' "${m:-unknown}"
}

version_gt() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ] && [ "$1" != "$2" ]; }

case "$mode" in
binaries)
    log "# Mach-O report for $(basename "$APP") (max allowed minos $MAX_MINOS)"
    log "# Tile helpers are copies of the main executable made at runtime (HelperBundleManager),"
    log "# so the main executable's result applies to every helper."
    while IFS= read -r -d '' f; do
        if file "$f" | grep "Mach-O" >/dev/null; then
            rel="${f#"$APP"/}"
            info="$(lipo -info "$f" 2>&1 | sed "s#$APP/##")"
            m="$(minos_of "$f")"
            log "## $rel"
            log "file: $(file -b "$f")"
            log "lipo: $info"
            log "minos(x86_64): $m"
            lipo -archs "$f" 2>/dev/null | grep -w x86_64 >/dev/null || bad "$rel has no x86_64 slice"
            if [ "$m" != "unknown" ] && version_gt "$m" "$MAX_MINOS"; then bad "$rel needs macOS $m (> $MAX_MINOS)"; fi
        fi
    done < <(find "$APP" -type f -print0)
    ;;
smoke)
    log "# Headless smoke test for $(basename "$APP")"
    eq "$(plist CFBundleIdentifier)" "$BUNDLE_ID" "CFBundleIdentifier $BUNDLE_ID"
    eq "$(plist CFBundleName)" "IntelliTile" "CFBundleName IntelliTile"
    eq "$(plist DTHelperPrefix)" "$BUNDLE_ID.tile" "DTHelperPrefix $BUNDLE_ID.tile"
    eq "$(plist DTSupportFolder)" "IntelliTile" "DTSupportFolder IntelliTile"
    eq "$(plist DTPrefsFilename)" "$BUNDLE_ID.configs.json" "DTPrefsFilename"
    eq "$(plist CFBundleURLTypes:0:CFBundleURLSchemes:0)" "intellitile" "URL scheme intellitile"
    eq "$(plist LSMinimumSystemVersion)" "15.0" "LSMinimumSystemVersion 15.0"
    eq "$(plist FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED)" "true" "Firebase Analytics deactivated"
    eq "$(plist FirebaseCrashlyticsCollectionEnabled)" "false" "Crashlytics collection disabled"
    if /usr/libexec/PlistBuddy -c "Print" "$APP/Contents/Info.plist" | grep -E '^ *SU[A-Za-z]+ =' >/dev/null; then bad "Sparkle SU* keys in Info.plist"; else good "no SU* keys"; fi
    agent="$APP/Contents/Library/LaunchAgents/$BUNDLE_ID.tilelauncher.plist"
    if [ -f "$agent" ]; then
        good "login launcher plist present"
        prog="$(/usr/libexec/PlistBuddy -c "Print :BundleProgram" "$agent")"
        cond "launcher BundleProgram $prog exists" [ -x "$APP/$prog" ]
        eq "$(/usr/libexec/PlistBuddy -c "Print :Label" "$agent")" "$BUNDLE_ID.tilelauncher" "launcher Label"
    else
        bad "login launcher plist missing: $agent"
    fi
    n_agents="$(find "$APP/Contents/Library/LaunchAgents" -name '*.plist' 2>/dev/null | wc -l | tr -d ' ')"
    eq "$n_agents" "1" "exactly one launcher plist"
    sparkle="$(find "$APP" -iname '*sparkle*' -print)"
    cond "no Sparkle files in bundle" [ -z "$sparkle" ]
    if [ -n "$sparkle" ]; then log "$sparkle"; fi
    if otool -L "$APP/Contents/MacOS/IntelliTile" | grep -i sparkle >/dev/null; then bad "main executable links Sparkle"; else good "main executable does not link Sparkle"; fi
    gsi="$(find "$APP" -name 'GoogleService-Info.plist' -print)"
    cond "no GoogleService-Info.plist" [ -z "$gsi" ]
    if [ -n "$gsi" ]; then log "$gsi"; fi
    cond "Assets.car present (icon compiled)" [ -f "$APP/Contents/Resources/Assets.car" ]
    if [ -e "$APP/Contents/Resources/docktile-actool" ]; then log "info: docktile-actool bundled"; else log "info: docktile-actool not bundled (idea #1: expected without Rust)"; fi
    # Brand strings: raw bytes everywhere, plus every plist/strings file decoded (UTF-16 safe).
    pattern='Dock Tile|Happy Machines|happymachines|Spades|spadesaudio|docktile\.app|hello@'
    hits="$(grep -rlaE "$pattern" "$APP" 2>/dev/null || true)"
    while IFS= read -r -d '' f; do
        if plutil -p "$f" 2>/dev/null | grep -E "$pattern" >/dev/null; then hits="$hits"$'\n'"$f (decoded)"; fi
    done < <(find "$APP" \( -name '*.strings' -o -name '*.stringsdict' -o -name '*.plist' \) -print0)
    hits="$(printf '%s' "$hits" | sed '/^$/d')"
    if [ -z "$hits" ]; then good "no original-brand strings in bundle"; else bad "original-brand strings found in:"; log "$hits"; fi
    if codesign --verify --deep --strict "$APP" 2>>"$REPORT"; then good "codesign --verify --deep --strict"; else bad "codesign verify failed"; fi
    log "signature: $(codesign -dv "$APP" 2>&1 | grep -E '^Signature=|^TeamIdentifier=' | tr '\n' ' ')"
    ;;
*) echo "unknown mode $mode" >&2; exit 2 ;;
esac
if [ "$fail" = 0 ]; then log "RESULT: PASS"; else log "RESULT: FAIL"; fi
exit "$fail"

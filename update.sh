#!/bin/bash
# IntelliTile updater (unofficial Intel Mac port of k97/dock-tile). No sudo. Safe to re-run.
#
# Default: install the newest IntelliTile release from the fork's GitHub Releases. It asks GitHub
# which release is newest, downloads the x86_64 zip and its .sha256 file, checks the SHA-256, the
# code signature, the architecture and the bundle ID, then replaces ONLY
# ~/Applications/IntelliTile.app (quit IntelliTile first). Nothing else is touched.
#
#   ./update.sh                 install the newest release (does nothing if already installed)
#   ./update.sh --force         reinstall the newest release even if it is already installed
#   ./update.sh --from-source   old route: pull this git clone and rebuild with ./install.sh (needs Xcode)
#   ./update.sh --help
set -euo pipefail

APP_NAME="IntelliTile"
BUNDLE_ID="io.github.efczpaclasses-boop.IntelliTile"
FORK_SLUG="efczpaclasses-boop/IntelliTile"
API_LATEST="https://api.github.com/repos/${FORK_SLUG}/releases/latest"
DOWNLOAD_PREFIX="https://github.com/${FORK_SLUG}/releases/download/"
PORT_ROOT="${HOME}/IntelPorts/dock-tile"
STATE_FILE="${PORT_ROOT}/installed-release.txt"
APPS_DIR="${HOME}/Applications"
APP_DEST="${APPS_DIR}/${APP_NAME}.app"
BRANCH="intel-x86_64"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\nSTOPPED: %s\n' "$1" >&2; exit "${2:-1}"; }

FORCE=0
MODE=release
case "${1:-}" in
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --force) FORCE=1 ;;
    --from-source) MODE=source ;;
    "") ;;
    *) die "Unknown option: $1 (see ./update.sh --help)" 2 ;;
esac
[ "$#" -le 1 ] || die "Use one option at a time (see ./update.sh --help)" 2

# ---------------------------------------------------------------- build-from-source route (Xcode)
update_from_source() {
    cd "$SRC_DIR"
    say "Updating IntelliTile source in $SRC_DIR"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "This folder is not a git clone. Use ./update.sh without options to install the newest release instead."
    local origin current before after resolved
    origin="$(git remote get-url origin 2>/dev/null || true)"
    case "$origin" in
        *"$FORK_SLUG"*) info "origin: $origin" ;;
        *) die "origin is '$origin', not the IntelliTile fork ($FORK_SLUG). Nothing changed." ;;
    esac
    current="$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
    [ "$current" = "$BRANCH" ] || die "This clone is on '$current', not '$BRANCH'. Run: git switch $BRANCH   then re-run ./update.sh --from-source"
    # Xcode may rewrite Package.resolved (its originHash) during a build; that is not a user edit.
    resolved="DockTile.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    if [ "$(git diff --name-only)" = "$resolved" ] && git diff --cached --quiet; then
        info "Resetting $resolved (rewritten by Xcode during the last build)"
        git checkout -- "$resolved"
    fi
    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "There are local edits in this folder; update.sh will not overwrite them. Send 'git status' output to Port Lead."
    fi
    before="$(git rev-parse --short HEAD)"
    info "Fetching origin/$BRANCH"
    git fetch --quiet origin "$BRANCH"
    git merge --ff-only --quiet "origin/$BRANCH" || die "Could not fast-forward to origin/$BRANCH (history diverged). Nothing changed."
    after="$(git rev-parse --short HEAD)"
    if [ "$before" = "$after" ]; then
        info "Already up to date ($after). Rebuilding anyway so the installed app matches the source."
    else
        info "Updated $before -> $after"
    fi
    say "Rebuilding and reinstalling"
    exec "$SRC_DIR/install.sh"
}

# ---------------------------------------------------------------- release route (default)
check_mac() {
    say "Checking this Mac"
    [ "$(uname -s)" = "Darwin" ] || die "update.sh runs on macOS only."
    local arch translated ver major
    arch="$(uname -m)"
    translated="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
    if [ "$arch" != "x86_64" ] || [ "$translated" = "1" ]; then
        die "IntelliTile releases are for Intel (x86_64) Macs; this Mac reports '$arch' (Rosetta: $translated)."
    fi
    ver="$(sw_vers -productVersion)"
    major="${ver%%.*}"
    [ "${major:-0}" -ge 15 ] || die "IntelliTile needs macOS 15 or later; this Mac has $ver."
    info "Intel Mac, macOS $ver"
}

# release_lines FILE -> "tag<TAB>vX" then "asset<TAB>name<TAB>url" lines, parsed with macOS's built-in
# JavaScript for Automation (plutil cannot read GitHub's JSON: it contains null values).
release_lines() {
    local js='function run(argv) {
    var text = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null).js;
    var r = JSON.parse(text);
    var out = ["tag\t" + (r.tag_name || "")];
    (r.assets || []).forEach(function (a) { out.push("asset\t" + a.name + "\t" + a.browser_download_url); });
    return out.join("\n");
}'
    osascript -l JavaScript -e "$js" "$1"
}

update_from_release() {
    check_mac
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        die "IntelliTile is running. Quit it (menu bar icon > Quit, or Cmd+Q in its window), then run ./update.sh again."
    fi
    mkdir -p "$PORT_ROOT"
    local work
    work="$(mktemp -d "${PORT_ROOT}/update.XXXXXX")"
    # shellcheck disable=SC2064
    trap "rm -rf '$work'" EXIT

    say "Asking GitHub for the newest IntelliTile release"
    curl -fsSL --proto '=https' --max-time 30 \
        -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
        -o "$work/latest.json" "$API_LATEST" \
        || die "Could not reach GitHub (or no release is published yet). Nothing changed."
    local tag kind name url zip_name="" zip_url="" sha_url=""
    release_lines "$work/latest.json" > "$work/release.txt" 2>/dev/null || die "Could not read GitHub's answer. Nothing changed."
    tag="$(awk -F'\t' '$1 == "tag" {print $2; exit}' "$work/release.txt")"
    case "$tag" in
        v[0-9]*) ;;
        *) die "Unexpected release tag '$tag'. Nothing changed." ;;
    esac
    while IFS="$(printf '\t')" read -r kind name url; do
        [ "$kind" = "asset" ] || continue
        case "$name" in
            "$APP_NAME"-*-x86_64.zip) zip_name="$name"; zip_url="$url" ;;
            "$APP_NAME"-*-x86_64.zip.sha256) sha_url="$url" ;;
        esac
    done < "$work/release.txt"
    if [ -z "$zip_url" ] || [ -z "$sha_url" ]; then
        die "Release $tag has no x86_64 zip and .sha256 pair. Nothing changed."
    fi
    case "$zip_url" in "$DOWNLOAD_PREFIX"*) ;; *) die "Unexpected download address for $zip_name. Nothing changed." ;; esac
    case "$sha_url" in "$DOWNLOAD_PREFIX"*) ;; *) die "Unexpected download address for the checksum. Nothing changed." ;; esac
    info "Newest release: $tag ($zip_name)"

    if [ "$FORCE" -eq 0 ] && [ -d "$APP_DEST" ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$tag" ]; then
        info "Already installed: $tag at $APP_DEST. Nothing to do (use --force to reinstall)."
        exit 0
    fi

    say "Downloading and checking $zip_name"
    curl -fSL --proto '=https' --max-time 900 -o "$work/$zip_name" "$zip_url" || die "Download failed. Nothing changed."
    curl -fsSL --proto '=https' --max-time 60 -o "$work/$zip_name.sha256" "$sha_url" || die "Checksum download failed. Nothing changed."
    local expected actual
    expected="$(awk '{print $1; exit}' "$work/$zip_name.sha256")"
    actual="$(shasum -a 256 "$work/$zip_name" | awk '{print $1}')"
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        die "SHA-256 mismatch (expected $expected, got $actual). Nothing changed."
    fi
    info "SHA-256 OK: $actual"

    mkdir -p "$work/unpacked"
    ditto -x -k "$work/$zip_name" "$work/unpacked"
    local new="$work/unpacked/$APP_NAME.app"
    [ -d "$new" ] || die "The zip did not contain $APP_NAME.app. Nothing changed."
    codesign --verify --deep --strict "$new" 2>/dev/null || die "The app's code signature does not verify. Nothing changed."
    [ "$(lipo -archs "$new/Contents/MacOS/$APP_NAME" 2>/dev/null)" = "x86_64" ] || die "The app is not an x86_64 build. Nothing changed."
    [ "$(defaults read "$new/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" = "$BUNDLE_ID" ] || die "Unexpected bundle ID. Nothing changed."
    info "Signature, architecture (x86_64) and bundle ID OK"

    say "Installing to $APP_DEST"
    mkdir -p "$APPS_DIR"
    local staged="$APPS_DIR/.${APP_NAME}.app.new" old="$APPS_DIR/.${APP_NAME}.app.old"
    rm -rf "$staged" "$old"
    ditto "$new" "$staged"
    if [ -d "$APP_DEST" ]; then
        mv "$APP_DEST" "$old"
        info "Replacing the previous copy"
    fi
    mv "$staged" "$APP_DEST"
    rm -rf "$old"
    printf '%s\n' "$tag" > "$STATE_FILE"
    say "Installed IntelliTile $tag. Open it with:  open \"$APP_DEST\""
}

if [ "$MODE" = "source" ]; then
    update_from_source
else
    update_from_release
fi

#!/bin/bash
# IntelliTile updater (unofficial Intel Mac port of k97/dock-tile). No sudo. Safe to re-run.
#
# Default: install the newest IntelliTile release from the fork's GitHub Releases. It asks GitHub
# which release is newest, downloads the x86_64 zip and its .sha256 file, checks the SHA-256, the
# code signature, the architecture and the bundle ID, then replaces ONLY IntelliTile.app where it
# already is: /Applications or ~/Applications (a new install goes to ~/Applications). Quit IntelliTile
# first. It stops, changing nothing, if both folders hold a copy or the copy can't be replaced
# without an administrator password. Nothing else is touched.
#
#   ./update.sh                 install the newest release (does nothing if already installed)
#   ./update.sh --force         reinstall the newest release even if it is already installed
#   ./update.sh --from-source   old route: pull this git clone and rebuild with ./install.sh (needs Xcode)
#   ./update.sh --help
#   (curl does not add macOS's "downloaded from the internet" mark, so the installed app is not
#   run from a protected App Translocation copy.)
set -euo pipefail

APP_NAME="IntelliTile"
BUNDLE_ID="io.github.efczpaclasses-boop.IntelliTile"
FORK_SLUG="efczpaclasses-boop/IntelliTile"
API_LATEST="https://api.github.com/repos/${FORK_SLUG}/releases/latest"
DOWNLOAD_PREFIX="https://github.com/${FORK_SLUG}/releases/download/"
PORT_ROOT="${HOME}/IntelPorts/dock-tile"
STATE_FILE="${PORT_ROOT}/installed-release.txt"
SYSTEM_APP="/Applications/${APP_NAME}.app"
USER_APPS_DIR="${HOME}/Applications"
USER_APP="${USER_APPS_DIR}/${APP_NAME}.app"
APPS_DIR=""   # set by choose_target
APP_DEST=""   # set by choose_target
BRANCH="intel-x86_64"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\nSTOPPED: %s\n' "$1" >&2; exit "${2:-1}"; }

FORCE=0
MODE=release
case "${1:-}" in
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# can_replace APP -> true when this account can swap APP out of its folder and delete the old copy
# without sudo: the folder is writable (for /Applications: an admin account, see README) and every
# item in the bundle belongs to this user with writable folders.
can_replace() {
    local app="$1" me
    me="$(id -un)"
    [ -w "$(dirname "$app")" ] || return 1
    [ -z "$(find "$app" ! -user "$me" -print 2>/dev/null | head -n 1)" ] || return 1
    [ -z "$(find "$app" -type d ! -perm -u+w -print 2>/dev/null | head -n 1)" ] || return 1
}

# choose_target -> sets APP_DEST/APPS_DIR to the existing copy, or ~/Applications for a new install.
choose_target() {
    local sys=0 usr=0
    if [ -L "$SYSTEM_APP" ] || [ -L "$USER_APP" ]; then
        die "IntelliTile.app in /Applications or ~/Applications is a link, which update.sh does not handle. Nothing changed."
    fi
    [ -e "$SYSTEM_APP" ] && sys=1
    [ -e "$USER_APP" ] && usr=1
    if [ "$sys" -eq 1 ] && [ "$usr" -eq 1 ]; then
        die "Two copies of IntelliTile are installed: $SYSTEM_APP and $USER_APP. Keep only one: in Finder, drag the copy you don't use to the Bin, then run ./update.sh again. Nothing changed."
    fi
    if [ "$sys" -eq 1 ]; then
        APP_DEST="$SYSTEM_APP"
    elif [ "$usr" -eq 1 ]; then
        APP_DEST="$USER_APP"
    else
        APP_DEST="$USER_APP"
        info "No installed copy found; installing to $USER_APP"
    fi
    APPS_DIR="$(dirname "$APP_DEST")"
    if [ -e "$APP_DEST" ] && ! can_replace "$APP_DEST"; then
        die "IntelliTile is installed at $APP_DEST, and this account can't replace it without an administrator password (update.sh never uses sudo). To update without admin rights: in Finder, drag $APP_DEST to the Bin (Finder may ask for an administrator's name and password), then run ./update.sh again; it then installs to $USER_APP. Nothing changed."
    fi
    info "Installed copy to update: $APP_DEST"
}

update_from_release() {
    check_mac
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        die "IntelliTile is running. Quit it (menu bar icon > Quit, or Cmd+Q in its window), then run ./update.sh again."
    fi
    choose_target
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
    ditto "$new" "$staged" || { rm -rf "$staged"; die "Could not write to $APPS_DIR. Nothing changed."; }
    if [ -d "$APP_DEST" ]; then
        mv "$APP_DEST" "$old" || { rm -rf "$staged"; die "Could not move the old copy aside. Nothing changed."; }
        info "Replacing the previous copy"
    fi
    if ! mv "$staged" "$APP_DEST"; then
        [ -d "$old" ] && mv "$old" "$APP_DEST"
        rm -rf "$staged"
        die "Could not put the new copy in place; the previous copy was restored."
    fi
    rm -rf "$old" || info "Note: could not delete the old copy at $old; drag it to the Bin."
    printf '%s\n' "$tag" > "$STATE_FILE"
    say "Installed IntelliTile $tag. Open it with:  open \"$APP_DEST\""
}

if [ "$MODE" = "source" ]; then
    update_from_source
else
    update_from_release
fi

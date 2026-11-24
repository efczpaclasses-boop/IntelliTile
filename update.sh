#!/bin/bash
# IntelliTile updater: fast-forward this source folder to the latest intel-x86_64 branch of the
# fork, then rebuild and reinstall with ./install.sh. No sudo. Safe to re-run.
#
#   ./update.sh            pull (fast-forward only) and reinstall
#   ./update.sh --help
set -euo pipefail

BRANCH="intel-x86_64"
FORK_SLUG="efczpaclasses-boop/IntelliTile"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\nSTOPPED: %s\n' "$1" >&2; exit "${2:-1}"; }

case "${1:-}" in
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1 (update.sh takes no options)" 2 ;;
esac

cd "$SRC_DIR"
say "Updating IntelliTile source in $SRC_DIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "This folder is not a git clone. Re-clone it as shown in the README."
origin="$(git remote get-url origin 2>/dev/null || true)"
case "$origin" in
    *"$FORK_SLUG"*|*"${FORK_SLUG}.git"*) info "origin: $origin" ;;
    *) die "origin is '$origin', not the IntelliTile fork ($FORK_SLUG). Nothing changed." ;;
esac
current="$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
[ "$current" = "$BRANCH" ] || die "This clone is on '$current', not '$BRANCH'. Run: git switch $BRANCH   then re-run ./update.sh"
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "There are local edits in this folder; update.sh will not overwrite them. Send 'git status' output to Port Lead."
fi
before="$(git rev-parse --short HEAD)"
info "Fetching origin/$BRANCH"
git fetch --quiet origin "$BRANCH"
if ! git merge --ff-only --quiet "origin/$BRANCH"; then
    die "Could not fast-forward to origin/$BRANCH (history diverged). Nothing changed. Send this output to Port Lead."
fi
after="$(git rev-parse --short HEAD)"
if [ "$before" = "$after" ]; then
    info "Already up to date ($after). Rebuilding anyway so the installed app matches the source."
else
    info "Updated $before -> $after:"
    git --no-pager log --oneline "$before..$after" | sed 's/^/      /'
fi
say "Rebuilding and reinstalling"
exec "$SRC_DIR/install.sh"

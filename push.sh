#!/usr/bin/env bash
set -Eeuo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOT"

GITHUB_USER="$(gh api user --jq .login)"
REMOTE_URL="https://github.com/$GITHUB_USER/dotfiles.git"

echo "Sync current configs into repo..."

sync_dir() {
    local src="$1"
    local dst="$2"

    if [ -d "$src" ]; then
        echo "Sync: $src -> $dst"
        mkdir -p "$dst"
        rsync -a --delete \
            --exclude '.git' \
            --exclude '.cache' \
            --exclude 'cache' \
            --exclude 'Cache' \
            --exclude 'logs' \
            --exclude 'log' \
            --exclude '*.log' \
            --exclude '*.bak' \
            --exclude '*.backup*' \
            --exclude '*backup*' \
            --exclude 'node_modules' \
            --exclude '.venv' \
            --exclude 'venv' \
            --exclude 'build' \
            --exclude 'dist' \
            --exclude '__pycache__' \
            "$src/" "$dst/"
    fi
}

mkdir -p "$DOT/.config" "$DOT/.local/share" "$DOT/.local/bin"

if [ -f "$HOME/.local/bin/xlll-start-caelestia-shell" ]; then
    cp -a "$HOME/.local/bin/xlll-start-caelestia-shell" "$DOT/.local/bin/xlll-start-caelestia-shell"
fi

sync_dir "$HOME/.config/hypr" "$DOT/.config/hypr"
sync_dir "$HOME/.config/caelestia" "$DOT/.config/caelestia"
sync_dir "$HOME/.config/foot" "$DOT/.config/foot"
sync_dir "$HOME/.config/fish" "$DOT/.config/fish"
sync_dir "$HOME/.config/fastfetch" "$DOT/.config/fastfetch"
sync_dir "$HOME/.config/btop" "$DOT/.config/btop"
sync_dir "$HOME/.config/uwsm" "$DOT/.config/uwsm"

# Optional: keep Caelestia source bundled too if it exists
if [ -d "$HOME/.local/share/caelestia" ]; then
    sync_dir "$HOME/.local/share/caelestia" "$DOT/.local/share/caelestia"
fi

if [ -x "$DOT/check-secrets.sh" ]; then
    "$DOT/check-secrets.sh"
fi

BIG_FILES="$(find "$DOT" -type f -size +95M -not -path '*/.git/*' || true)"
if [ -n "$BIG_FILES" ]; then
    echo "❌ Files over 95MB. GitHub will reject them:"
    echo "$BIG_FILES"
    exit 1
fi

gh auth setup-git >/dev/null 2>&1 || true
gh config set -h github.com git_protocol https >/dev/null 2>&1 || true

git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"

git branch -M main
git add .
git commit -m "update dotfiles $(date +%Y-%m-%d_%H-%M-%S)" || true
git push -u origin main

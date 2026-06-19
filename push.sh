#!/usr/bin/env bash
set -Eeuo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

copy_config() {
    local name="$1"
    local src="$HOME/.config/$name"
    local dst="$DOT/.config/$name"

    if [ -d "$src" ]; then
        echo "Sync: ~/.config/$name"
        mkdir -p "$dst"
        rsync -a --delete \
            --exclude '.git' \
            --exclude 'cache' \
            --exclude 'Cache' \
            --exclude 'logs' \
            --exclude 'log' \
            --exclude '*.log' \
            --exclude '*.bak' \
            --exclude '*.backup*' \
            --exclude '*backup*' \
            --exclude 'xlll-backups' \
            --exclude 'xlll-working-caelestia-backup' \
            "$src/" "$dst/"
    fi
}

copy_config hypr
copy_config caelestia
copy_config foot
copy_config fish
copy_config fastfetch
copy_config btop
copy_config uwsm

cd "$DOT"

./check-secrets.sh

git add .
git commit -m "update dotfiles $(date +%Y-%m-%d_%H-%M-%S)" || true
git push

#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL RESTORE DOTFILES"
echo "======================================"

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$HOME/.config/xlll-restore-backups"

for dir in hypr caelestia foot fish fastfetch btop uwsm; do
    if [ -d "$DOT/.config/$dir" ]; then
        if [ -e "$HOME/.config/$dir" ]; then
            echo "Backup: ~/.config/$dir"
            cp -a "$HOME/.config/$dir" "$HOME/.config/xlll-restore-backups/$dir.backup-$TS"
        fi

        echo "Restore: ~/.config/$dir"
        mkdir -p "$HOME/.config/$dir"
        rsync -a --delete "$DOT/.config/$dir/" "$HOME/.config/$dir/"
    fi
done

echo
echo "Reload Hyprland..."
hyprctl reload 2>/dev/null || true

echo
echo "Restart Caelestia shell..."
qs -c caelestia kill 2>/dev/null || true
sleep 1
nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &

echo
echo "DONE"

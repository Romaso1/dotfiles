#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL POLKIT SETUP FOR HYPRLAND"
echo "======================================"

HYPR_EXECS="$HOME/.config/hypr/hyprland/execs.conf"
TS="$(date +%Y%m%d-%H%M%S)"

sudo pacman -S --needed --noconfirm polkit hyprpolkitagent
sudo systemctl start polkit.service 2>/dev/null || true

pkill -u "$USER" -f "polkit-gnome-authentication-agent-1" 2>/dev/null || true
pkill -u "$USER" -f "polkit-kde-authentication-agent-1" 2>/dev/null || true
pkill -u "$USER" -f "lxpolkit" 2>/dev/null || true
pkill -u "$USER" -f "mate-polkit" 2>/dev/null || true
pkill -u "$USER" -f "xfce-polkit" 2>/dev/null || true

systemctl --user daemon-reload || true
systemctl --user enable --now hyprpolkitagent.service

mkdir -p "$(dirname "$HYPR_EXECS")"
touch "$HYPR_EXECS"
cp -a "$HYPR_EXECS" "$HYPR_EXECS.backup-polkit-$TS"

python - "$HYPR_EXECS" <<'PY'
from pathlib import Path
import sys
import re

p = Path(sys.argv[1])
text = p.read_text(errors="ignore")

remove_patterns = [
    r"hyprpolkitagent",
    r"polkit-gnome-authentication-agent-1",
    r"polkit-kde-authentication-agent-1",
    r"lxpolkit",
    r"mate-polkit",
    r"xfce-polkit",
]

lines = []
for line in text.splitlines():
    if any(re.search(pat, line, re.I) for pat in remove_patterns):
        continue
    lines.append(line)

block = """
# XLLL proper polkit agent for Hyprland
exec-once = systemctl --user start hyprpolkitagent.service
"""

p.write_text("\n".join(lines).rstrip() + "\n" + block + "\n")
PY

hyprctl reload 2>/dev/null || true

echo "DONE"

#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL FULL HYPRLAND + CAELESTIA INSTALL"
echo "======================================"

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/xlll-install-backups/$TS"
CAEL_REPO="$HOME/.local/share/caelestia"

mkdir -p "$BACKUP"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.local/bin"

echo
echo "=== 1. System check ==="

if ! command -v pacman >/dev/null 2>&1; then
    echo "❌ This installer is for Arch/CachyOS/EndeavourOS with pacman."
    exit 1
fi

sudo -v

echo
echo "=== 2. Install base packages ==="

sudo pacman -Syu --needed --noconfirm \
    git \
    base-devel \
    fish \
    rsync \
    jq \
    python \
    curl \
    wget \
    unzip \
    foot \
    fastfetch \
    btop \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    polkit \
    hyprpolkitagent

echo
echo "=== 3. Install AUR helper if needed ==="

if command -v yay >/dev/null 2>&1; then
    AUR="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR="paru"
else
    echo "yay/paru not found, installing yay..."
    TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$TMP/yay"
    cd "$TMP/yay"
    makepkg -si --noconfirm
    cd "$DOT"
    AUR="yay"
fi

echo "AUR helper: $AUR"

echo
echo "=== 4. Backup current configs ==="

backup_item() {
    local path="$1"
    local name="$2"

    if [ -e "$path" ]; then
        echo "Backup: $path"
        mkdir -p "$BACKUP"
        cp -a "$path" "$BACKUP/$name"
    fi
}

backup_item "$HOME/.config/hypr" "hypr"
backup_item "$HOME/.config/caelestia" "caelestia-config"
backup_item "$HOME/.local/share/caelestia" "caelestia-local-share"
backup_item "$HOME/.config/foot" "foot"
backup_item "$HOME/.config/fish" "fish"
backup_item "$HOME/.config/fastfetch" "fastfetch"
backup_item "$HOME/.config/btop" "btop"
backup_item "$HOME/.config/uwsm" "uwsm"

echo "Backup folder: $BACKUP"

echo
echo "=== 5. Install / update Caelestia ==="

if [ -d "$DOT/.local/share/caelestia/.git" ]; then
    echo "Using Caelestia bundled in dotfiles repo..."
    rm -rf "$CAEL_REPO"
    mkdir -p "$(dirname "$CAEL_REPO")"
    rsync -a --delete "$DOT/.local/share/caelestia/" "$CAEL_REPO/"
elif [ -d "$CAEL_REPO/.git" ]; then
    echo "Updating existing Caelestia..."
    git -C "$CAEL_REPO" pull --ff-only || true
else
    echo "Cloning official Caelestia..."
    rm -rf "$CAEL_REPO"
    git clone https://github.com/caelestia-dots/caelestia.git "$CAEL_REPO"
fi

cd "$CAEL_REPO"

echo
echo "Running Caelestia installer..."
if [ -f "$CAEL_REPO/install.fish" ]; then
    fish "$CAEL_REPO/install.fish" --noconfirm --aur-helper="$AUR" || \
    fish "$CAEL_REPO/install.fish" || true
else
    echo "❌ install.fish not found in $CAEL_REPO"
    exit 1
fi

cd "$DOT"

echo
echo "=== 6. Restore XLLL configs from repo ==="

restore_dir() {
    local src="$1"
    local dst="$2"

    if [ -d "$src" ]; then
        echo "Restore: $src -> $dst"
        mkdir -p "$dst"
        rsync -a --delete "$src/" "$dst/"
    else
        echo "Skip: $src not found"
    fi
}

restore_dir "$DOT/.config/hypr" "$HOME/.config/hypr"
restore_dir "$DOT/.config/caelestia" "$HOME/.config/caelestia"
restore_dir "$DOT/.config/foot" "$HOME/.config/foot"
restore_dir "$DOT/.config/fish" "$HOME/.config/fish"
restore_dir "$DOT/.config/fastfetch" "$HOME/.config/fastfetch"
restore_dir "$DOT/.config/btop" "$HOME/.config/btop"
restore_dir "$DOT/.config/uwsm" "$HOME/.config/uwsm"

echo
echo "=== 7. Ensure XLLL personal Caelestia config exists ==="

mkdir -p "$HOME/.config/caelestia"

if [ ! -f "$HOME/.config/caelestia/hypr-user.conf" ]; then
cat > "$HOME/.config/caelestia/hypr-user.conf" <<'XLLL'
# XLLL PERSONAL CONFIG FOR CAELESTIA
# Loaded last by Caelestia.

monitor = DP-2, 3440x1440@180.00, 0x0, 1.25
monitor = DP-1, 3440x1440@180.00, 0x0, 1.25
monitor = HDMI-A-1, 3440x1440@180.00, 0x0, 1.25
monitor = , preferred, auto, 1

input {
    kb_layout = us,ru,ua
    kb_variant = ,,
    kb_options = grp:alt_shift_toggle
    numlock_by_default = true
    repeat_delay = 250
    repeat_rate = 35

    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat

    touchpad {
        natural_scroll = true
        disable_while_typing = true
    }
}

general {
    allow_tearing = false
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}
XLLL
fi

echo
echo "=== 8. Hard fix Caelestia launcher on SUPER ==="

KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"
mkdir -p "$(dirname "$KEYBINDS")"

if [ -f "$KEYBINDS" ]; then
    cp -a "$KEYBINDS" "$BACKUP/keybinds.conf.before-super-fix"
else
    touch "$KEYBINDS"
fi

python - "$KEYBINDS" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(errors="ignore")

launcher_block = """# Launcher
# XLLL FIX:
# Bare SUPER opens Caelestia launcher.
# The catchall launcherInterrupt is disabled because it can break bare SUPER.
bindi = Super, Super_L, global, caelestia:launcher
# bindin = Super, catchall, global, caelestia:launcherInterrupt
bindin = Super, mouse:272, global, caelestia:launcherInterrupt
bindin = Super, mouse:273, global, caelestia:launcherInterrupt
bindin = Super, mouse:274, global, caelestia:launcherInterrupt
bindin = Super, mouse:275, global, caelestia:launcherInterrupt
bindin = Super, mouse:276, global, caelestia:launcherInterrupt
bindin = Super, mouse:277, global, caelestia:launcherInterrupt
bindin = Super, mouse_up, global, caelestia:launcherInterrupt
bindin = Super, mouse_down, global, caelestia:launcherInterrupt
"""

# Remove old XLLL direct launcher attempts if they exist
lines = []
for line in text.splitlines():
    low = line.lower()
    if "xlll-caelestia" in low:
        continue
    if re.match(r"\s*bindr\s*=\s*Super\s*,\s*Super_L\s*,\s*exec\s*,", line):
        continue
    if re.match(r"\s*unbind\s*=\s*Super\s*,\s*Super_L\s*$", line):
        continue
    lines.append(line)

text = "\n".join(lines) + "\n"

# Replace Launcher block if standard Caelestia sections exist
if "# Launcher" in text and "# Misc" in text:
    text = re.sub(
        r"# Launcher\b.*?(?=\n# Misc\b)",
        launcher_block.rstrip(),
        text,
        flags=re.S,
    )
elif "caelestia:launcher" not in text:
    text += "\n" + launcher_block + "\n"
else:
    # Disable active catchall launcherInterrupt if present
    text = re.sub(
        r"(?m)^(\s*)bindin\s*=\s*Super\s*,\s*catchall\s*,\s*global\s*,\s*caelestia:launcherInterrupt\s*$",
        r"\1# bindin = Super, catchall, global, caelestia:launcherInterrupt",
        text,
    )

p.write_text(text)
PY

echo
echo "=== 9. Ensure Caelestia shell autostart ==="

EXECS="$HOME/.config/hypr/hyprland/execs.conf"
mkdir -p "$(dirname "$EXECS")"
touch "$EXECS"

grep -q "caelestia shell -d" "$EXECS" || {
    echo "" >> "$EXECS"
    echo "# XLLL Caelestia shell autostart" >> "$EXECS"
    echo "exec-once = caelestia shell -d" >> "$EXECS"
}

grep -q "hyprpolkitagent" "$EXECS" || {
    echo "" >> "$EXECS"
    echo "# XLLL polkit agent" >> "$EXECS"
    echo "exec-once = systemctl --user start hyprpolkitagent.service" >> "$EXECS"
}

systemctl --user daemon-reload || true
systemctl --user enable --now hyprpolkitagent.service || true

echo
echo "=== 10. Restart portals ==="

systemctl --user restart xdg-desktop-portal xdg-desktop-portal-hyprland 2>/dev/null || true

echo
echo "=== 11. Reload Hyprland + start Caelestia shell ==="

if command -v qs >/dev/null 2>&1; then
    qs -c caelestia kill >/dev/null 2>&1 || true
fi

pkill -u "$USER" -f "qs.*caelestia|quickshell.*caelestia" >/dev/null 2>&1 || true
sleep 1

if command -v caelestia >/dev/null 2>&1; then
    "$HOME/.local/bin/xlll-start-caelestia-shell" || true
else
    echo "WARNING: caelestia command not found after install"
fi

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload || true
fi

sleep 2

echo
echo "=== 12. Check ==="

echo "--- Caelestia shell ---"
pgrep -a -u "$USER" -f "qs.*caelestia|quickshell.*caelestia|caelestia shell" || {
    echo "Shell process not found. Log:"
    cat /tmp/xlll-caelestia-shell.log 2>/dev/null || true
}

echo
echo "--- Launcher binds ---"
hyprctl binds 2>/dev/null | grep -Ei "Super_L|caelestia:launcher|launcherInterrupt" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Now press SUPER once."
echo
echo "If something breaks, backup is here:"
echo "$BACKUP"

# XLLL_RUN_POLKIT_SETUP
echo
echo "=== XLLL Polkit setup ==="
if [ -x "$DOT/polkit-setup.sh" ]; then
    "$DOT/polkit-setup.sh" || true
fi


# XLLL_INSTALL_SINGLE_CAEL_STARTER
echo
echo "=== XLLL single-instance Caelestia starter ==="
mkdir -p "$HOME/.local/bin"

if [ -f "$DOT/.local/bin/xlll-start-caelestia-shell" ]; then
    cp -a "$DOT/.local/bin/xlll-start-caelestia-shell" "$HOME/.local/bin/xlll-start-caelestia-shell"
else
    cat > "$HOME/.local/bin/xlll-start-caelestia-shell" <<'SH'
#!/usr/bin/env bash
set -u
LOG="/tmp/xlll-caelestia-shell.log"

if pgrep -u "$USER" -f "qs.*caelestia|quickshell.*caelestia|caelestia shell" >/dev/null 2>&1; then
    exit 0
fi

if ! command -v caelestia >/dev/null 2>&1; then
    echo "caelestia command not found" > "$LOG"
    exit 1
fi

nohup caelestia shell -d > "$LOG" 2>&1 &
disown 2>/dev/null || true
SH
fi

chmod +x "$HOME/.local/bin/xlll-start-caelestia-shell"

EXECS="$HOME/.config/hypr/hyprland/execs.conf"
mkdir -p "$(dirname "$EXECS")"
touch "$EXECS"

python - "$EXECS" "$HOME" <<'PY2'
from pathlib import Path
import sys
import re

p = Path(sys.argv[1])
home = sys.argv[2]
text = p.read_text(errors="ignore")

lines = []
for line in text.splitlines():
    low = line.lower()
    if "caelestia shell" in low:
        continue
    if "xlll-start-caelestia-shell" in low:
        continue
    if re.search(r"qs\s+-c\s+caelestia", low):
        continue
    if re.search(r"quickshell.*caelestia", low):
        continue
    lines.append(line)

block = f"""
# XLLL single-instance Caelestia shell autostart
exec-once = {home}/.local/bin/xlll-start-caelestia-shell
"""

p.write_text("\n".join(lines).rstrip() + "\n" + block + "\n")
PY2

"$HOME/.local/bin/xlll-start-caelestia-shell" || true


# XLLL_HYPR055_MOUSE_BUG_WORKAROUND
echo
echo "=== XLLL Hyprland 0.55 mouse bind workaround ==="

for f in "$HOME/.config/hypr/variables.conf" "$HOME/.config/caelestia/hypr-vars.conf"; do
    mkdir -p "$(dirname "$f")"
    touch "$f"

    python - "$f" <<'PY2'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(errors="ignore")

text = re.sub(r'(?m)^\s*\$kbMoveWindow\s*=.*$', '', text)
text = re.sub(r'(?m)^\s*\$kbResizeWindow\s*=.*$', '', text)

text = text.rstrip() + """

# XLLL Hyprland 0.55 legacy mouse-binds workaround
$kbMoveWindow = Super, Z
$kbResizeWindow = Super, X
"""

p.write_text(text + "\n")
PY2
done

KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"
mkdir -p "$(dirname "$KEYBINDS")"
touch "$KEYBINDS"

grep -q 'bindm = $kbMoveWindow, movewindow' "$KEYBINDS" || \
    echo 'bindm = $kbMoveWindow, movewindow' >> "$KEYBINDS"

grep -q 'bindm = $kbResizeWindow, resizewindow' "$KEYBINDS" || \
    echo 'bindm = $kbResizeWindow, resizewindow' >> "$KEYBINDS"

grep -q 'caelestia shell drawers toggle launcher' "$KEYBINDS" || \
    echo 'bind = SUPER, SPACE, exec, caelestia shell drawers toggle launcher' >> "$KEYBINDS"

rm -f "$HOME/.local/bin/xlll-caelestia-super-used"
rm -f "$HOME/.local/bin/xlll-caelestia-super-press"
rm -f "$HOME/.local/bin/xlll-caelestia-super-launcher"
rm -f "$HOME/.local/bin/xlll-caelestia-launcher"
rm -f "$HOME/.local/bin/xlll-caelestia-interrupt"

hyprctl reload 2>/dev/null || true


# XLLL_LUA_SUPER_MOUSE_BINDS
echo
echo "=== XLLL Lua/eval SUPER mouse binds ==="

mkdir -p "$HOME/.local/bin"

for s in xlll-caelestia-super-used xlll-caelestia-super-launcher xlll-apply-lua-super-binds; do
    if [ -f "$DOT/.local/bin/$s" ]; then
        cp -a "$DOT/.local/bin/$s" "$HOME/.local/bin/$s"
        chmod +x "$HOME/.local/bin/$s"
    fi
done

EXECS="$HOME/.config/hypr/hyprland/execs.conf"
mkdir -p "$(dirname "$EXECS")"
touch "$EXECS"

grep -q "xlll-apply-lua-super-binds" "$EXECS" || \
    echo "exec-once = $HOME/.local/bin/xlll-apply-lua-super-binds" >> "$EXECS"

hyprctl reload 2>/dev/null || true
"$HOME/.local/bin/xlll-apply-lua-super-binds" 2>/dev/null || true

#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL SUPER LAUNCHER FIX V4"
echo "======================================"

TS="$(date +%Y%m%d-%H%M%S)"
HOME_BIN="$HOME/.local/bin"
STATE="/tmp/xlll-caelestia-super-used-${UID}"
KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"

mkdir -p "$HOME_BIN"
mkdir -p "$(dirname "$KEYBINDS")"

echo
echo "=== 1. Helper scripts ==="

cat > "$HOME_BIN/xlll-caelestia-super-used" <<'EOS'
#!/usr/bin/env bash
set -u

STATE="/tmp/xlll-caelestia-super-used-${UID}"
NOW="$(date +%s%3N 2>/dev/null || python - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

echo "$NOW" > "$STATE"

(
    sleep 1.0
    if [ -f "$STATE" ]; then
        OLD="$(cat "$STATE" 2>/dev/null || true)"
        if [ "$OLD" = "$NOW" ]; then
            rm -f "$STATE"
        fi
    fi
) >/dev/null 2>&1 &
EOS

cat > "$HOME_BIN/xlll-caelestia-super-launcher" <<'EOS'
#!/usr/bin/env bash
set -u

STATE="/tmp/xlll-caelestia-super-used-${UID}"
LOG="/tmp/xlll-caelestia-launcher.log"

now_ms() {
    date +%s%3N 2>/dev/null || python - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

# Если перед отпусканием SUPER был bind/drag — launcher не открываем.
if [ -f "$STATE" ]; then
    NOW="$(now_ms)"
    OLD="$(cat "$STATE" 2>/dev/null || echo 0)"
    AGE="$((NOW - OLD))"

    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 1000 ]; then
        rm -f "$STATE"
        exit 0
    fi

    rm -f "$STATE"
fi

if ! command -v caelestia >/dev/null 2>&1; then
    notify-send "Caelestia" "Команда caelestia не найдена" 2>/dev/null || true
    exit 1
fi

if ! pgrep -u "$USER" -f "qs.*caelestia|quickshell.*caelestia|caelestia shell" >/dev/null 2>&1; then
    if command -v xlll-start-caelestia-shell >/dev/null 2>&1; then
        xlll-start-caelestia-shell || true
    else
        nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &
    fi
    sleep 0.8
fi

caelestia shell drawers toggle launcher >"$LOG" 2>&1 || {
    if command -v xlll-start-caelestia-shell >/dev/null 2>&1; then
        xlll-start-caelestia-shell || true
    else
        nohup caelestia shell -d >>/tmp/xlll-caelestia-shell.log 2>&1 &
    fi
    sleep 1
    caelestia shell drawers toggle launcher >>"$LOG" 2>&1
}
EOS

chmod +x "$HOME_BIN/xlll-caelestia-super-used"
chmod +x "$HOME_BIN/xlll-caelestia-super-launcher"

echo
echo "=== 2. Backup keybinds ==="

if [ -f "$KEYBINDS" ]; then
    cp -a "$KEYBINDS" "$KEYBINDS.backup-super-mouse-v4-$TS"
else
    touch "$KEYBINDS"
fi

echo
echo "=== 3. Patch keybinds ==="

python - "$KEYBINDS" "$HOME" <<'PY'
from pathlib import Path
import re
import sys

keybinds = Path(sys.argv[1])
home = Path(sys.argv[2])

text = keybinds.read_text(errors="ignore")

clean = []
for line in text.splitlines():
    low = line.lower()

    # Удалить старые XLLL launcher/mouse/interruption строки
    if "xlll-caelestia-super" in low:
        continue
    if "xlll-caelestia-launcher" in low:
        continue
    if "xlll-caelestia-interrupt" in low:
        continue
    if "caelestia:launcherinterrupt" in low:
        continue

    # Удалить старый global launcher на bare Super
    if re.match(r"\s*bindi?\s*=\s*super\s*,\s*super_l\s*,\s*global\s*,\s*caelestia:launcher\s*$", line, re.I):
        continue
    if re.match(r"\s*bindr\s*=\s*super\s*,\s*super_l\s*,", line, re.I):
        continue

    # Удалить любые конфликтующие SUPER+mouse:272/273, потом добавим правильные
    if re.search(r"^\s*bind[a-z]*\s*=\s*(\$mainmod|\$mod|super|super)\s*,\s*mouse:(272|273)\s*,", line, re.I):
        continue

    clean.append(line)

text = "\n".join(clean).rstrip() + "\n"

# Interrupt на клавиатурные комбо — только на отпускание клавиши.
keys = []
keys += list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
keys += [str(i) for i in range(10)]
keys += [
    "SPACE", "TAB", "RETURN", "ESCAPE", "BACKSPACE", "DELETE",
    "LEFT", "RIGHT", "UP", "DOWN",
    "F1", "F2", "F3", "F4", "F5", "F6",
    "F7", "F8", "F9", "F10", "F11", "F12",
]

keyboard_interrupts = "\n".join(
    f"bindr = SUPER, {k}, exec, {home}/.local/bin/xlll-caelestia-super-used"
    for k in keys
)

launcher_block = f"""# Launcher
# XLLL FIX V4:
# Bare SUPER opens launcher.
# SUPER + keyboard bind marks interrupt on key release.
# SUPER + LMB/RMB uses bindm for real Hyprland move/resize.
# Mouse interrupt is on mouse-button release only, not on press, so drag works.
bindr = SUPER, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-launcher

# XLLL keyboard combo interrupt
{keyboard_interrupts}

# XLLL mouse combo interrupt on release only
bindr = SUPER, mouse:272, exec, {home}/.local/bin/xlll-caelestia-super-used
bindr = SUPER, mouse:273, exec, {home}/.local/bin/xlll-caelestia-super-used

# XLLL real Hyprland mouse move/resize
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
"""

if "# Launcher" in text and "# Misc" in text:
    text = re.sub(
        r"# Launcher\b.*?(?=\n# Misc\b)",
        launcher_block.rstrip(),
        text,
        flags=re.S,
    )
elif "# Launcher" in text:
    text = re.sub(
        r"# Launcher\b.*?\Z",
        launcher_block.rstrip() + "\n",
        text,
        flags=re.S,
    )
else:
    text += "\n" + launcher_block + "\n"

keybinds.write_text(text)
PY

echo
echo "=== 4. Clear stale state ==="
rm -f "$STATE" 2>/dev/null || true

echo
echo "=== 5. Reload Hyprland ==="
hyprctl reload 2>/dev/null || true

echo
echo "=== 6. Check binds ==="
hyprctl binds 2>/dev/null | grep -Ei "Super_L|mouse:272|mouse:273|movewindow|resizewindow|xlll-caelestia-super" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Test:"
echo "SUPER + ЛКМ drag = move"
echo "SUPER + ПКМ drag = resize"
echo "SUPER once = launcher"

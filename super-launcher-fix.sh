#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL SUPER LAUNCHER FIX FINAL"
echo "======================================"

TS="$(date +%Y%m%d-%H%M%S)"
HOME_BIN="$HOME/.local/bin"
STATE="/tmp/xlll-caelestia-super-used-${UID}"
PRESS="/tmp/xlll-caelestia-super-press-${UID}"
KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"
USERCONF="$HOME/.config/caelestia/hypr-user.conf"

mkdir -p "$HOME_BIN"
mkdir -p "$(dirname "$KEYBINDS")"
mkdir -p "$(dirname "$USERCONF")"

echo
echo "=== 1. Helper scripts ==="

cat > "$HOME_BIN/xlll-caelestia-super-press" <<'EOS'
#!/usr/bin/env bash
set -u

PRESS="/tmp/xlll-caelestia-super-press-${UID}"

NOW="$(date +%s%3N 2>/dev/null || python - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

POS="$(hyprctl cursorpos 2>/dev/null | tr -d ',' || echo '0 0')"
X="$(echo "$POS" | awk '{print $1}')"
Y="$(echo "$POS" | awk '{print $2}')"

case "$X" in ''|*[!0-9-]*) X=0 ;; esac
case "$Y" in ''|*[!0-9-]*) Y=0 ;; esac

echo "$NOW $X $Y" > "$PRESS"
EOS

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
PRESS="/tmp/xlll-caelestia-super-press-${UID}"
LOG="/tmp/xlll-caelestia-launcher.log"

now_ms() {
    date +%s%3N 2>/dev/null || python - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

NOW="$(now_ms)"

# 1. Если был SUPER+keyboard bind — launcher не открываем.
if [ -f "$STATE" ]; then
    OLD="$(cat "$STATE" 2>/dev/null || echo 0)"
    AGE="$((NOW - OLD))"

    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 1000 ]; then
        rm -f "$STATE"
        rm -f "$PRESS"
        exit 0
    fi

    rm -f "$STATE"
fi

# 2. Если при зажатом SUPER мышь заметно двигалась — это move/resize, launcher не открываем.
if [ -f "$PRESS" ]; then
    read -r T0 X0 Y0 < "$PRESS" || true
    rm -f "$PRESS"

    POS="$(hyprctl cursorpos 2>/dev/null | tr -d ',' || echo '0 0')"
    X1="$(echo "$POS" | awk '{print $1}')"
    Y1="$(echo "$POS" | awk '{print $2}')"

    case "${T0:-0}" in ''|*[!0-9-]*) T0=0 ;; esac
    case "${X0:-0}" in ''|*[!0-9-]*) X0=0 ;; esac
    case "${Y0:-0}" in ''|*[!0-9-]*) Y0=0 ;; esac
    case "${X1:-0}" in ''|*[!0-9-]*) X1=0 ;; esac
    case "${Y1:-0}" in ''|*[!0-9-]*) Y1=0 ;; esac

    AGE="$((NOW - T0))"
    DX="$((X1 - X0))"
    DY="$((Y1 - Y0))"
    [ "$DX" -lt 0 ] && DX="$((-DX))"
    [ "$DY" -lt 0 ] && DY="$((-DY))"

    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 6000 ] && { [ "$DX" -gt 8 ] || [ "$DY" -gt 8 ]; }; then
        exit 0
    fi
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

chmod +x "$HOME_BIN/xlll-caelestia-super-press"
chmod +x "$HOME_BIN/xlll-caelestia-super-used"
chmod +x "$HOME_BIN/xlll-caelestia-super-launcher"

echo
echo "=== 2. Backup configs ==="

cp -a "$KEYBINDS" "$KEYBINDS.backup-final-super-fix-$TS" 2>/dev/null || true
cp -a "$USERCONF" "$USERCONF.backup-final-super-fix-$TS" 2>/dev/null || true
touch "$KEYBINDS"
touch "$USERCONF"

echo
echo "=== 3. Clean old broken mouse interrupts from keybinds ==="

python - "$KEYBINDS" "$HOME" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
home = Path(sys.argv[2])
text = p.read_text(errors="ignore")

clean = []
for line in text.splitlines():
    low = line.lower()

    # Удаляем все старые XLLL строки
    if "xlll-caelestia-super" in low:
        continue
    if "xlll-caelestia-launcher" in low:
        continue
    if "xlll-caelestia-interrupt" in low:
        continue
    if "caelestia:launcherinterrupt" in low:
        continue

    # Удаляем старый global bare-super launcher
    if re.match(r"\s*bindi?\s*=\s*super\s*,\s*super_l\s*,\s*global\s*,\s*caelestia:launcher\s*$", line, re.I):
        continue
    if re.match(r"\s*bindr\s*=\s*super\s*,\s*super_l\s*,", line, re.I):
        continue

    # Удаляем любые SUPER mouse exec/interruption, они ломают bindm
    if re.search(r"^\s*bind[a-z]*\s*=\s*(\$mainmod|\$mod|super|super)\s*,\s*mouse:(272|273)\s*,\s*exec", line, re.I):
        continue

    clean.append(line)

text = "\n".join(clean).rstrip() + "\n"

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
# XLLL FINAL FIX:
# Bare SUPER opens launcher.
# SUPER press saves mouse position.
# SUPER + keyboard bind blocks launcher.
# SUPER + mouse drag blocks launcher by mouse movement detection.
# NO mouse:272/273 exec binds here, because they break movewindow/resizewindow.
bindi = SUPER, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-press
bindr = SUPER, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-launcher

# XLLL keyboard combo interrupt
{keyboard_interrupts}
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

p.write_text(text)
PY

echo
echo "=== 4. Force mouse move/resize in hypr-user.conf loaded last ==="

python - "$USERCONF" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(errors="ignore")

# Убираем старые XLLL mouse force blocks
text = re.sub(
    r"\n?# XLLL FORCE MOUSE MOVE RESIZE\b.*?(?=\n# |\Z)",
    "\n",
    text,
    flags=re.S,
)

# Убираем конфликтующие mouse:272/273 строки
lines = []
for line in text.splitlines():
    if re.search(r"mouse:(272|273)", line, re.I):
        continue
    lines.append(line)

text = "\n".join(lines).rstrip()

block = """

# XLLL FORCE MOUSE MOVE RESIZE
# Loaded last, removes broken mouse binds and restores Hyprland bindm.
unbind = SUPER, mouse:272
unbind = SUPER, mouse:273
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
"""

p.write_text(text + block + "\n")
PY

echo
echo "=== 5. Clear old state and reload ==="

rm -f "$STATE" "$PRESS" 2>/dev/null || true
hyprctl reload 2>/dev/null || true

echo
echo "=== 6. Check final binds ==="

echo "--- mouse binds ---"
hyprctl binds 2>/dev/null | grep -Ei "mouse:272|mouse:273|movewindow|resizewindow" || true

echo
echo "--- xlll launcher binds ---"
hyprctl binds 2>/dev/null | grep -Ei "Super_L|xlll-caelestia-super|xlll-caelestia-launcher" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Test:"
echo "SUPER + ЛКМ drag = move"
echo "SUPER + ПКМ drag = resize"
echo "SUPER once = launcher"

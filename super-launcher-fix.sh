#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL SUPER LAUNCHER FIX V3 MOUSE OK"
echo "======================================"

TS="$(date +%Y%m%d-%H%M%S)"
HOME_BIN="$HOME/.local/bin"
STATE="/tmp/xlll-caelestia-super-used-${UID}"
KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"

mkdir -p "$HOME_BIN"
mkdir -p "$(dirname "$KEYBINDS")"

echo
echo "=== 1. Create helper scripts ==="

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
    cp -a "$KEYBINDS" "$KEYBINDS.backup-super-mouse-fix-$TS"
else
    touch "$KEYBINDS"
fi

echo
echo "=== 3. Patch keybinds: mouse move/resize restored ==="

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

    # Удаляем старые конфликтующие xlll mouse/key launcher строки
    if "xlll-caelestia-super" in low:
        continue
    if "xlll-caelestia-launcher" in low:
        continue
    if "xlll-caelestia-interrupt" in low:
        continue
    if "caelestia:launcherinterrupt" in low:
        continue

    # Удаляем старый global bare-super launcher
    if re.match(r"\s*bindi?\s*=\s*Super\s*,\s*Super_L\s*,\s*global\s*,\s*caelestia:launcher\s*$", line, re.I):
        continue
    if re.match(r"\s*bindr\s*=\s*Super\s*,\s*Super_L\s*,", line, re.I):
        continue

    # Удаляем любые старые mouse:272/273 конфликты только в Launcher-блоке/XLLL-контексте
    if re.search(r"bindin\s*=\s*Super\s*,\s*mouse:(272|273)", line, re.I):
        continue

    # Удаляем старые bindm mouse чтобы вставить нормальные один раз
    if re.match(r"\s*bindm\s*=\s*(\$mainMod|\$mainmod|\$mod|Super|SUPER)\s*,\s*mouse:272\s*,\s*movewindow", line, re.I):
        continue
    if re.match(r"\s*bindm\s*=\s*(\$mainMod|\$mainmod|\$mod|Super|SUPER)\s*,\s*mouse:273\s*,\s*resizewindow", line, re.I):
        continue

    clean.append(line)

text = "\n".join(clean).rstrip() + "\n"

# Клавиши, которые НЕ должны открывать launcher после SUPER+bind
keys = []
keys += list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
keys += [str(i) for i in range(10)]
keys += [
    "SPACE", "TAB", "RETURN", "ESCAPE", "BACKSPACE", "DELETE",
    "LEFT", "RIGHT", "UP", "DOWN",
]

key_interrupts = "\n".join(
    f"bindin = Super, {k}, exec, {home}/.local/bin/xlll-caelestia-super-used"
    for k in keys
)

launcher_block = f"""# Launcher
# XLLL FIX V3:
# Bare SUPER opens launcher.
# SUPER + keyboard bind sets short interrupt flag.
# SUPER + LMB/RMB uses real Hyprland bindm for move/resize.
bindr = Super, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-launcher

# XLLL SUPER keyboard combo interrupts
{key_interrupts}

# XLLL mouse move/resize, do NOT replace with bindin
bindm = Super, mouse:272, movewindow
bindm = Super, mouse:273, resizewindow
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
echo "=== 6. Check mouse binds ==="
hyprctl binds 2>/dev/null | grep -Ei "mouse:272|mouse:273|movewindow|resizewindow|Super_L|xlll-caelestia-super" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Test now:"
echo "SUPER + ЛКМ drag = move window"
echo "SUPER + ПКМ drag = resize window"
echo "SUPER once = launcher"

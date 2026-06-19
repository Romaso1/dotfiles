#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL SUPER LAUNCHER FIX V2"
echo "======================================"

TS="$(date +%Y%m%d-%H%M%S)"
HOME_BIN="$HOME/.local/bin"
STATE="/tmp/xlll-caelestia-super-used-${UID}"
KEYBINDS="$HOME/.config/hypr/hyprland/keybinds.conf"

mkdir -p "$HOME_BIN"
mkdir -p "$(dirname "$KEYBINDS")"

echo
echo "=== 1. Create helper scripts with TTL ==="

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

# Авто-очистка флага, чтобы после SUPER+bind следующий SUPER открывал launcher сразу,
# а не только со второго раза.
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

# Если только что был SUPER+bind — не открываем launcher.
# Если флаг старый — считаем его залипшим и открываем launcher нормально.
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
    nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &
    sleep 0.8
fi

caelestia shell drawers toggle launcher >"$LOG" 2>&1 || {
    nohup caelestia shell -d >>/tmp/xlll-caelestia-shell.log 2>&1 &
    sleep 1
    caelestia shell drawers toggle launcher >>"$LOG" 2>&1
}
EOS

chmod +x "$HOME_BIN/xlll-caelestia-super-used"
chmod +x "$HOME_BIN/xlll-caelestia-super-launcher"

echo
echo "=== 2. Backup keybinds ==="

if [ -f "$KEYBINDS" ]; then
    cp -a "$KEYBINDS" "$KEYBINDS.backup-super-ttl-fix-$TS"
else
    touch "$KEYBINDS"
fi

echo
echo "=== 3. Ensure launcher block exists ==="

python - "$KEYBINDS" "$HOME" <<'PY'
from pathlib import Path
import re
import sys

keybinds = Path(sys.argv[1])
home = Path(sys.argv[2])

text = keybinds.read_text(errors="ignore")

# Удаляем старые xlll строки
clean = []
skip = False
for line in text.splitlines():
    low = line.lower()

    if "xlll-caelestia-super" in low:
        continue
    if "xlll-caelestia-launcher" in low:
        continue
    if "xlll-caelestia-interrupt" in low:
        continue
    if "caelestia:launcherinterrupt" in low:
        continue
    if re.match(r"\s*bindi?\s*=\s*Super\s*,\s*Super_L\s*,\s*global\s*,\s*caelestia:launcher\s*$", line, re.I):
        continue
    if re.match(r"\s*bindr\s*=\s*Super\s*,\s*Super_L\s*,", line, re.I):
        continue

    clean.append(line)

text = "\n".join(clean).rstrip() + "\n"

# Самые частые Super-комбо, чтобы launcher не открывался после них
keys = []
keys += list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
keys += [str(i) for i in range(10)]
keys += [
    "SPACE", "TAB", "RETURN", "ESCAPE", "BACKSPACE", "DELETE",
    "LEFT", "RIGHT", "UP", "DOWN",
    "mouse:272", "mouse:273", "mouse:274", "mouse:275",
    "mouse:276", "mouse:277", "mouse_up", "mouse_down",
]

interrupt = "\n".join(
    f"bindin = Super, {k}, exec, {home}/.local/bin/xlll-caelestia-super-used"
    for k in keys
)

launcher_block = f"""# Launcher
# XLLL FIX V2:
# Bare SUPER opens launcher.
# SUPER + bind sets short TTL interrupt flag, so launcher does not open after combos.
# Stuck flag auto-expires, so next bare SUPER works from first press.
bindr = Super, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-launcher

# XLLL SUPER combo interrupts
{interrupt}
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
echo "=== 5. Reload Hyprland + restart shell ==="

hyprctl reload 2>/dev/null || true

qs -c caelestia kill >/dev/null 2>&1 || true
pkill -u "$USER" -f "qs.*caelestia|quickshell.*caelestia" 2>/dev/null || true
sleep 1

nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &
sleep 2

echo
echo "=== 6. Check binds ==="
hyprctl binds 2>/dev/null | grep -Ei "Super_L|xlll-caelestia-super" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Test:"
echo "1. SUPER+T / SUPER+Q / SUPER+1"
echo "2. Потом подожди 1 секунду"
echo "3. Нажми SUPER один раз — launcher должен открыться сразу"

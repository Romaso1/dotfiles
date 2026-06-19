#!/usr/bin/env bash
set -Eeuo pipefail

echo "======================================"
echo " XLLL SUPER LAUNCHER FIX"
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
: > "/tmp/xlll-caelestia-super-used-${UID}"
EOS

cat > "$HOME_BIN/xlll-caelestia-super-launcher" <<'EOS'
#!/usr/bin/env bash
set -u

STATE="/tmp/xlll-caelestia-super-used-${UID}"
LOG="/tmp/xlll-caelestia-launcher.log"

# Если перед отпусканием SUPER была нажата другая клавиша/мышь —
# это был SUPER+bind, значит launcher открывать нельзя.
if [ -e "$STATE" ]; then
    rm -f "$STATE"
    exit 0
fi

rm -f "$STATE" 2>/dev/null || true

if ! command -v caelestia >/dev/null 2>&1; then
    notify-send "Caelestia" "Команда caelestia не найдена" 2>/dev/null || true
    exit 1
fi

# Поднять shell если он не запущен
if ! pgrep -u "$USER" -f "qs.*caelestia|quickshell.*caelestia|caelestia shell" >/dev/null 2>&1; then
    nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &
    sleep 0.8
fi

# Открыть launcher
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
    cp -a "$KEYBINDS" "$KEYBINDS.backup-super-combo-fix-$TS"
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

# Собираем все Super bind-клавиши из конфигов, чтобы они ставили interrupt-флаг.
scan_files = []
for root in [
    home / ".config/hypr",
    home / ".config/caelestia",
]:
    if root.exists():
        scan_files += list(root.rglob("*.conf"))

texts = {}
for p in scan_files:
    try:
        texts[p] = p.read_text(errors="ignore")
    except Exception:
        pass

# Переменные типа: $kbTerminal = Super, T
var_binds = {}
var_re = re.compile(r"^\s*\$([A-Za-z0-9_]+)\s*=\s*([^,\n#]+)\s*,\s*([^,\n#]+)", re.M)

for text in texts.values():
    for name, mods, key in var_re.findall(text):
        mods = mods.strip()
        key = key.strip()
        if "super" in mods.lower() or "$mainmod" in mods.lower() or "$mod" in mods.lower():
            mods = re.sub(r"\$mainmod|\$mod", "Super", mods, flags=re.I)
            var_binds[name] = (mods, key)

binds = set()

bind_re = re.compile(r"^\s*bind[a-z]*\s*=\s*([^,\n]+)\s*,\s*([^,\n]+)\s*,", re.M)

for text in texts.values():
    for mods, key in bind_re.findall(text):
        mods = mods.strip()
        key = key.strip()

        # bind = $kbTerminal, exec, foot
        if mods.startswith("$"):
            name = mods[1:].strip()
            if name in var_binds:
                mods, key = var_binds[name]
            else:
                continue

        mods_low = mods.lower()
        key_low = key.lower()

        if "$mainmod" in mods_low or "$mod" in mods_low:
            mods = re.sub(r"\$mainmod|\$mod", "Super", mods, flags=re.I)
            mods_low = mods.lower()

        if "super" not in mods_low:
            continue

        if key_low in {"super_l", "super_r", "catchall"}:
            continue

        if "caelestia:launcher" in key_low:
            continue

        binds.add((mods, key))

# Обязательно ловим мышь, чтобы Super+drag/click не открывал launcher
for key in [
    "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276", "mouse:277",
    "mouse_up", "mouse_down",
]:
    binds.add(("Super", key))

# На всякий случай ловим самые частые клавиши, которые могут быть через переменные.
# Это не мешает обычным биндам, только ставит флаг "SUPER использовался как модификатор".
for key in list("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
    binds.add(("Super", key))
for key in [str(i) for i in range(10)]:
    binds.add(("Super", key))
for key in [
    "SPACE", "TAB", "RETURN", "ESCAPE", "BACKSPACE", "DELETE",
    "LEFT", "RIGHT", "UP", "DOWN",
]:
    binds.add(("Super", key))

interrupt_lines = []
for mods, key in sorted(binds, key=lambda x: (x[0].lower(), x[1].lower())):
    interrupt_lines.append(
        f"bindin = {mods}, {key}, exec, {home}/.local/bin/xlll-caelestia-super-used"
    )

launcher_block = f"""# Launcher
# XLLL FIX:
# Bare SUPER opens launcher.
# SUPER + any configured key sets interrupt flag, so launcher does NOT open after combos.
bindr = Super, Super_L, exec, {home}/.local/bin/xlll-caelestia-super-launcher

# XLLL SUPER combo interrupts
""" + "\n".join(interrupt_lines) + "\n"

text = keybinds.read_text(errors="ignore")

# Удаляем старые попытки фикса
clean_lines = []
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
    clean_lines.append(line)

text = "\n".join(clean_lines).rstrip() + "\n"

# Полностью заменяем Launcher-блок в Caelestia keybinds
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
echo "=== 4. Reload Hyprland and restart shell ==="

rm -f "$STATE" 2>/dev/null || true

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload || true
fi

if command -v qs >/dev/null 2>&1; then
    qs -c caelestia kill >/dev/null 2>&1 || true
fi

pkill -u "$USER" -f "qs.*caelestia|quickshell.*caelestia" 2>/dev/null || true
sleep 1

if command -v caelestia >/dev/null 2>&1; then
    nohup caelestia shell -d >/tmp/xlll-caelestia-shell.log 2>&1 &
fi

sleep 2

echo
echo "=== 5. Check ==="

echo "--- Caelestia shell ---"
pgrep -a -u "$USER" -f "qs.*caelestia|quickshell.*caelestia|caelestia shell" || true

echo
echo "--- Launcher binds ---"
hyprctl binds 2>/dev/null | grep -Ei "Super_L|xlll-caelestia-super|launcher" || true

echo
echo "======================================"
echo " DONE"
echo "======================================"
echo "Test:"
echo "1. Press SUPER once -> launcher opens"
echo "2. Press SUPER+T / SUPER+Q / SUPER+1 -> launcher must NOT open"

# XLLL Hyprland + Caelestia Dotfiles

Full installer for clean Arch/CachyOS/EndeavourOS Hyprland.

## Install on clean Hyprland

```bash
sudo pacman -S --needed git
git clone https://github.com/Romaso1/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## What it does

- Installs base packages
- Installs yay if needed
- Installs Caelestia
- Restores my Hyprland config
- Restores my Caelestia config
- Restores foot/fish/fastfetch/btop configs
- Fixes Caelestia launcher on bare SUPER
- Disables broken catchall launcherInterrupt
- Starts Caelestia shell

## Update repo from current system

```bash
cd ~/dotfiles
./push.sh
```

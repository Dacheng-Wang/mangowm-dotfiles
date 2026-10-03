# MangoWM & Noctalia Dotfiles

Complete, modular configuration files for **MangoWM** (Wayland tiling compositor featuring the scroller layout) paired with the **Noctalia** desktop shell, **Ghostty** terminal emulator, and unified GTK/Qt theming.

Designed to effortlessly bring your exact desktop workflow to any new machine or fresh installation.

---

## 🖥️ Overview & Features

- **Compositor**: [MangoWM](https://mangowm.github.io/) configured with:
  - **Dynamic Scroller Layout**: Horizontal scroller on primary display, vertical scroller on secondary display.
  - **Auto-recovering Workspaces**: Custom Python daemon (`watch-workspaces.py`) monitoring Mango IPC for monitor hotplug events and automatically restoring workspace assignments.
  - **Named Scratchpads**: Quick-toggle scratchpads for Zed, Spotify, Spotube, and SpeedCrunch.
- **Desktop Shell**: [Noctalia](https://github.com/noctalia-dev) providing:
  - Sleek top status bar with workspace switcher, media player, system monitors (CPU/GPU temp & RAM), notifications, tray, and quick settings.
  - Built-in application launcher, clipboard manager, and lock screen.
  - Hardware display brightness integration via `ddcutil`.
- **Terminal**: [Ghostty](https://ghostty.org/) with Catppuccin Mocha theme, background blur, and intuitive split keybindings (`Super+h/j/k/l`, `Super+d`).
- **Cohesive Theming**:
  - Unified color scheme across GTK3 (`adw-gtk3`), GTK4, and Qt6 (`qt6ct`).
  - Cursor: `capitaine-cursors`.
- **System Stability & Hardware Reliability**:
  - **OLED Standby Watchdog** (`samsung-standby-fix` + systemd user service): Automatically turns off displays if awake while locked for over 30s.
  - **Systemd Cgroup OOM Isolation**: Wrappers for Firefox and Chrome (`app.slice`) to protect the Mango session (`session.slice`) from OOM kills.
  - **Lockscreen Hotplug Patch**: Fixes keyboard focus loss during DPMS/hub reconnect on lockscreen (`patches/session-lock-focus.patch`).

---

## 📁 Repository Structure

```text
.
├── .config/
│   ├── environment.d/
│   │   └── 10-qt.conf               # QT_QPA_PLATFORMTHEME=qt6ct
│   ├── ghostty/
│   │   └── config                   # Ghostty terminal config & keybindings
│   ├── gtk-3.0/
│   │   ├── gtk.css                  # Imports Noctalia theme
│   │   ├── noctalia.css             # GTK3 color variables
│   │   └── settings.ini             # Theme, icon, and cursor preferences
│   ├── gtk-4.0/
│   │   ├── gtk.css
│   │   └── noctalia.css             # GTK4 theme colors
│   ├── mango/
│   │   ├── config.conf              # Master config sourcing modular cfg files
│   │   ├── cfg/
│   │   │   ├── appearance.conf      # Gaps, borders, colors, blur, animations
│   │   │   ├── autostart.conf       # Apps executed on login
│   │   │   ├── env.conf             # Environment variables (Wayland, fcitx, Qt)
│   │   │   ├── input.conf           # Keyboard layout & acceleration
│   │   │   ├── keybinds.conf        # App, window, and desktop shortcuts
│   │   │   ├── layout.conf          # Scroller & master-stack settings
│   │   │   ├── misc.conf            # Tearing, syncobj, scratchpads
│   │   │   ├── monitors.conf        # Display geometry, refresh, and scale
│   │   │   └── rules.conf           # Window, layer, and scratchpad rules
│   │   └── scripts/
│   │       ├── init-workspaces.sh   # Entry script for workspace watcher
│   │       └── watch-workspaces.py  # Event-driven monitor hotplug watcher
│   ├── noctalia/
│   │   └── config.toml              # Bar, widgets, idle, lockscreen, brightness
│   ├── qt6ct/
│   │   ├── colors/
│   │   │   └── noctalia.conf        # Noctalia Qt color palette
│   │   └── qt6ct.conf               # Qt6 styling preferences
│   ├── systemd/
│   │   └── user/
│   │       ├── app.slice.d/         # OOM kill policy for user applications
│   │       ├── session.slice.d/     # OOM protection for compositor session
│   │       └── samsung-standby-fix.service
│   ├── xdg-desktop-portal/
│   │   └── mango-portals.conf       # Portal routing rules
│   └── xdg-desktop-portal-wlr/
│       └── config                   # Screen sharing backend settings
├── .local/
│   └── bin/
│       ├── firefox                  # Runs Firefox inside app.slice
│       ├── google-chrome-stable     # Runs Chrome inside app.slice
│       └── samsung-standby-fix      # OLED wake event-driven watchdog
├── patches/
│   ├── mangowm-issue-1017-comment.md # Root-cause analysis for lockscreen focus
│   └── session-lock-focus.patch     # C patch for wlroots keyboard focus
├── wayland-sessions/
│   └── mango.desktop                # Display manager session entry
├── install.sh                       # Automated installation & backup script
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start on a New Machine

### 1. Prerequisites (Arch Linux / CachyOS)

Install MangoWM, Noctalia, and supporting packages:

```bash
# Core Window Manager & Desktop Shell
paru -S mangowm noctalia-git ghostty

# Portals, Screen Capture & Display Control
paru -S xdg-desktop-portal-wlr xdg-desktop-portal-gtk slurp grim wlopm ddcutil

# Theming, Fonts & Input
paru -S qt6ct adw-gtk3 breeze capitaine-cursors fcitx5 fcitx5-configtool solaar speedcrunch

# Utilities required by scripts
paru -S jq python
```

### 2. Clone and Install

Clone your repository and run the automated installer:

```bash
git clone <your-repo-url> ~/mangowm-dotfiles
cd ~/mangowm-dotfiles

# Preview changes before applying:
./install.sh --dry-run

# Run installer (creates symlinks and backs up existing configs):
./install.sh
```

#### Installer Options:
- `-s, --symlink`: Symlink files into place (default, enables version tracking).
- `-c, --copy`: Copy files instead of symlinking.
- `-d, --dry-run`: Preview actions without modifying disks.
- `--no-backup`: Skip backing up existing configurations.
- `--no-systemd`: Skip systemd daemon reload.

### 3. Display Manager Session Entry

To ensure your display manager (SDDM, GDM, Greetd) lists Mango:

```bash
sudo cp ~/mangowm-dotfiles/wayland-sessions/mango.desktop /usr/share/wayland-sessions/
```

---

## ⚙️ Adapting to New Hardware

When deploying to a different machine, adjust the following hardware-specific settings:

### 1. Monitor Outputs
Run `wlr-randr` to list your display connectors:

1. **Geometry & Refresh Rates**: Edit `~/.config/mango/cfg/monitors.conf`:
   ```ini
   # Example: Single 1440p 144Hz monitor
   monitorrule = name:DP-1, width:2560, height:1440, refresh:144.0, x:0, y:0, scale:1.0, rr:0
   ```
2. **Layout Tag Rules**: Edit `~/.config/mango/cfg/layout.conf` to assign layouts to your monitor output names.
3. **Workspace Default Mapping**: In `~/.config/mango/scripts/watch-workspaces.py`, update the `DEFAULTS` dictionary:
   ```python
   DEFAULTS = {"DP-1": 1, "HDMI-A-1": 2}
   ```
4. **Brightness Control**: In `~/.config/noctalia/config.toml`, configure the monitor name under `[brightness.monitor.<OUTPUT_NAME>]` (`backend = "ddcutil"` or `"sysfs"`).

---

## ⌨️ Keybindings Cheat Sheet

### Application Launchers
| Shortcut | Action |
| :--- | :--- |
| <kbd>Alt</kbd> + <kbd>t</kbd> | Launch Ghostty Terminal |
| <kbd>Alt</kbd> + <kbd>e</kbd> | Open Dolphin File Manager |
| <kbd>Alt</kbd> + <kbd>f</kbd> | Open Firefox |
| <kbd>Alt</kbd> + <kbd>b</kbd> | Open Google Chrome |
| <kbd>Alt</kbd> + <kbd>z</kbd> | Toggle Zed Editor (Scratchpad) |
| <kbd>Alt</kbd> + <kbd>s</kbd> | Toggle Spotify (Scratchpad) |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>s</kbd> | Toggle Spotube (Scratchpad) |
| <kbd>Alt</kbd> + <kbd>c</kbd> | Toggle SpeedCrunch Calculator |

### Window Management
| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>q</kbd> | Close active window |
| <kbd>Alt</kbd> + <kbd>h/j/k/l</kbd> | Move focus (Left / Down / Up / Right) |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>h/j/k/l</kbd> | Swap window position |
| <kbd>Alt</kbd> + <kbd>Space</kbd> | Toggle floating mode |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Toggle fullscreen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Toggle window overview |
| <kbd>Super</kbd> + <kbd>x</kbd> | Cycle Scroller proportion preset |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>e</kbd> | Reset Scroller proportion to 1.0 |
| <kbd>Super</kbd> + Left Click Drag | Move window |
| <kbd>Super</kbd> + Right Click Drag | Resize window |

### Noctalia Desktop Controls
| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle App Launcher |
| <kbd>Super</kbd> + <kbd>x</kbd> | Toggle Control Center |
| <kbd>Super</kbd> + <kbd>z</kbd> | Toggle Settings |
| <kbd>Super</kbd> + <kbd>c</kbd> | Toggle Clipboard History |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>w</kbd> | Open Wallhaven Wallpaper Browser |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>q</kbd> | Session Menu (Power / Reboot / Logout) |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>q</kbd> | Lock Screen |

### Screenshots
| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>p</kbd> | Interactive Region Screenshot |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>p</kbd> | Fullscreen Screenshot (Current Output) |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>p</kbd> | Fullscreen Screenshot (All Displays) |

---

## 📜 License

Configurations and personal scripts are released under the [MIT License](LICENSE).
Feel free to fork, adapt, and customize for your own workflow!

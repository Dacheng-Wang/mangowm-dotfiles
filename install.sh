#!/usr/bin/env bash
# ==============================================================================
# MangoWM Dotfiles Installer
# ==============================================================================
# Automates setting up MangoWM, Noctalia, Ghostty, and related configurations
# on any new machine.
# ==============================================================================

set -euo pipefail

# ANSI color codes
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.dotfiles_backup_${BACKUP_TIMESTAMP}"

MODE="symlink"   # Default mode: symlink
DRY_RUN=false
BACKUP_ENABLED=true
SYSTEMD_ENABLE=true

show_help() {
    cat <<EOF
${BOLD}Usage:${NC} ./install.sh [OPTIONS]

${BOLD}Options:${NC}
    -s, --symlink       Symlink configuration files (default)
    -c, --copy          Copy files instead of symlinking
    -d, --dry-run       Preview actions without making changes
    --no-backup         Do not create backups of existing files
    --no-systemd        Skip systemd user daemon reload/enable
    -h, --help          Show this help message

${BOLD}Description:${NC}
    Installs MangoWM and Noctalia desktop configurations into \$HOME.
    Existing files will be safely backed up to ~/.dotfiles_backup_<timestamp>/
    unless --no-backup is specified.
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--symlink)
            MODE="symlink"
            shift
            ;;
        -c|--copy)
            MODE="copy"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-backup)
            BACKUP_ENABLED=false
            shift
            ;;
        --no-systemd)
            SYSTEMD_ENABLE=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD}       MangoWM & Noctalia Environment Installer       ${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "Source: ${BLUE}${REPO_DIR}${NC}"
echo -e "Target: ${BLUE}${TARGET_DIR}${NC}"
echo -e "Mode:   ${GREEN}${MODE}${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}${BOLD}[DRY-RUN MODE] No changes will be written to disk.${NC}"
fi
echo ""

# List of all files to install relative to repo root
FILES=(
    ".config/mango/config.conf"
    ".config/mango/cfg/appearance.conf"
    ".config/mango/cfg/autostart.conf"
    ".config/mango/cfg/env.conf"
    ".config/mango/cfg/input.conf"
    ".config/mango/cfg/keybinds.conf"
    ".config/mango/cfg/layout.conf"
    ".config/mango/cfg/misc.conf"
    ".config/mango/cfg/monitors.conf"
    ".config/mango/cfg/rules.conf"
    ".config/mango/scripts/init-workspaces.sh"
    ".config/mango/scripts/watch-workspaces.py"
    ".config/noctalia/config.toml"
    ".config/ghostty/config"
    ".config/environment.d/10-qt.conf"
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-3.0/gtk.css"
    ".config/gtk-3.0/noctalia.css"
    ".config/gtk-4.0/gtk.css"
    ".config/gtk-4.0/noctalia.css"
    ".config/qt6ct/qt6ct.conf"
    ".config/qt6ct/colors/noctalia.conf"
    ".config/systemd/user/samsung-standby-fix.service"
    ".config/systemd/user/app.slice.d/override.conf"
    ".config/systemd/user/session.slice.d/override.conf"
    ".config/xdg-desktop-portal/mango-portals.conf"
    ".config/xdg-desktop-portal-wlr/config"
    ".local/bin/samsung-standby-fix"
    ".local/bin/firefox"
    ".local/bin/google-chrome-stable"
)

EXECUTABLES=(
    ".config/mango/scripts/init-workspaces.sh"
    ".config/mango/scripts/watch-workspaces.py"
    ".local/bin/samsung-standby-fix"
    ".local/bin/firefox"
    ".local/bin/google-chrome-stable"
)

install_file() {
    local rel_path="$1"
    local src="${REPO_DIR}/${rel_path}"
    local dest="${TARGET_DIR}/${rel_path}"
    local dest_dir="$(dirname "${dest}")"

    if [ ! -f "${src}" ]; then
        echo -e "${YELLOW}Warning: Source file ${src} not found, skipping.${NC}"
        return
    fi

    # Check if target already points to source
    if [ -L "${dest}" ] && [ "$(readlink -f "${dest}")" = "$(readlink -f "${src}")" ]; then
        echo -e "${BLUE}[OK] Already linked:${NC} ${rel_path}"
        return
    fi

    # Back up existing file/link if present and different
    if [ -e "${dest}" ] || [ -L "${dest}" ]; then
        if [ "$BACKUP_ENABLED" = true ]; then
            local backup_target="${BACKUP_DIR}/${rel_path}"
            if [ "$DRY_RUN" = false ]; then
                mkdir -p "$(dirname "${backup_target}")"
                cp -a "${dest}" "${backup_target}"
            fi
            echo -e "${YELLOW}[BACKUP]${NC} ${dest} -> ${backup_target}"
        fi
        if [ "$DRY_RUN" = false ]; then
            rm -rf "${dest}"
        fi
    fi

    # Ensure parent directory exists
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "${dest_dir}"
    fi

    if [ "$MODE" = "symlink" ]; then
        if [ "$DRY_RUN" = false ]; then
            ln -sf "${src}" "${dest}"
        fi
        echo -e "${GREEN}[LINK]${NC} ${rel_path} -> ${dest}"
    else
        if [ "$DRY_RUN" = false ]; then
            cp -p "${src}" "${dest}"
        fi
        echo -e "${GREEN}[COPY]${NC} ${rel_path} -> ${dest}"
    fi
}

echo -e "${BOLD}Step 1: Installing configuration files...${NC}"
for file in "${FILES[@]}"; do
    install_file "${file}"
done

echo ""
echo -e "${BOLD}Step 2: Setting executable permissions...${NC}"
for exe in "${EXECUTABLES[@]}"; do
    target="${TARGET_DIR}/${exe}"
    if [ -f "${target}" ] || [ -L "${target}" ]; then
        if [ "$DRY_RUN" = false ]; then
            chmod +x "${target}"
            # Also ensure source executable bit is set
            chmod +x "${REPO_DIR}/${exe}" 2>/dev/null || true
        fi
        echo -e "${GREEN}[EXEC]${NC} Marked executable: ${exe}"
    fi
done

echo ""
echo -e "${BOLD}Step 3: Post-install adjustments...${NC}"
# Adjust qt6ct.conf color_scheme_path to current user's HOME if copied
QT6CT_FILE="${TARGET_DIR}/.config/qt6ct/qt6ct.conf"
if [ -f "${QT6CT_FILE}" ] && [ "$DRY_RUN" = false ]; then
    if grep -q "color_scheme_path=" "${QT6CT_FILE}"; then
        sed -i "s|color_scheme_path=.*|color_scheme_path=${HOME}/.config/qt6ct/colors/noctalia.conf|g" "${QT6CT_FILE}"
        echo -e "${GREEN}[OK]${NC} Updated qt6ct color scheme path for user ${USER}"
    fi
fi

# Reload systemd user daemon if available
if [ "$SYSTEMD_ENABLE" = true ] && command -v systemctl >/dev/null 2>&1; then
    echo ""
    echo -e "${BOLD}Step 4: Reloading systemd user daemon...${NC}"
    if [ "$DRY_RUN" = false ]; then
        systemctl --user daemon-reload 2>/dev/null || true
        echo -e "${GREEN}[OK]${NC} systemctl --user daemon-reload executed."
    else
        echo -e "${CYAN}[DRY-RUN] Would run: systemctl --user daemon-reload${NC}"
    fi
fi

echo ""
echo -e "${BOLD}Step 5: Wayland Session Desktop Entry...${NC}"
DESKTOP_ENTRY="/usr/share/wayland-sessions/mango.desktop"
if [ ! -f "${DESKTOP_ENTRY}" ]; then
    echo -e "${YELLOW}[NOTE] ${DESKTOP_ENTRY} is not installed.${NC}"
    echo -e "       To enable Mango in your display manager (SDDM/GDM/Greetd), run:"
    echo -e "       ${BOLD}sudo cp ${REPO_DIR}/wayland-sessions/mango.desktop /usr/share/wayland-sessions/${NC}"
else
    echo -e "${GREEN}[OK]${NC} ${DESKTOP_ENTRY} is present."
fi

echo ""
echo -e "${GREEN}${BOLD}Installation Complete!${NC}"
echo ""
echo -e "${BOLD}Helpful reminders for a new machine setup:${NC}"
echo -e "  1. ${CYAN}Display Setup:${NC} Edit ${BOLD}~/.config/mango/cfg/monitors.conf${NC} and ${BOLD}~/.config/mango/cfg/layout.conf${NC}"
echo -e "     to match the display output names (e.g. DP-1, HDMI-A-1) of your new hardware."
echo -e "  2. ${CYAN}Dependencies (Arch / CachyOS):${NC}"
echo -e "     paru -S mangowm noctalia ghostty xdg-desktop-portal-wlr xdg-desktop-portal-gtk \\"
echo -e "             slurp grim wlopm ddcutil qt6ct adw-gtk3 breeze capitaine-cursors \\"
echo -e "             fcitx5 fcitx5-configtool solaar speedcrunch jq python"
echo -e "  3. ${CYAN}Optional Services:${NC}"
echo -e "     systemctl --user enable --now samsung-standby-fix.service  (for OLED monitor standby fix)"
echo ""

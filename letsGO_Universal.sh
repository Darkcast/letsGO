#!/usr/bin/env bash

# This script checks for the presence of jq and curl utilities, prints an ASCII art banner if provided,
# checks if the latest version of Go (Golang) is installed, and if not, downloads and installs it.
# Version 0.14 codename: universal-shell-compatible
# NOTE: Requires bash. Run as: bash letsGO_Universal.sh

# ANSI Colors
red='\033[1;31m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'
blue='\033[38;5;87m'
cyan='\033[0;36m'
purple='\033[0;35m'

# Global variables - declared early to avoid scope issues
MODE="install"  # Default mode
VERBOSE=false
LOG_FILE=""
SPECIFIC_VERSION=""  # For --version flag
DOWNLOAD_FILE=""
OS=""
REAL_USER=""
HOME_DIR=""
INSTALL_DIR=""
BIN_DIR=""
PROFILE_FILE=""
GO_VERSION=""
ARCH=""
CLEANUP_PERFORMED=false
TEMP_DIR=""
GO_CHECKSUM=""
GO_API_RESPONSE=""

# Enhanced cleanup function - centralized and robust
cleanup() {
    if [ "$CLEANUP_PERFORMED" = true ]; then
        return 0
    fi

    if [ -n "$DOWNLOAD_FILE" ] && [ -f "$DOWNLOAD_FILE" ]; then
        log_message "Cleaning up downloaded file: $DOWNLOAD_FILE"
        rm -f "$DOWNLOAD_FILE" 2>/dev/null || true
    fi

    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_message "Cleaning up temp directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi

    CLEANUP_PERFORMED=true
}

# Safe exit function that always cleans up
safe_exit() {
    local exit_code="${1:-0}"
    cleanup
    exit "$exit_code"
}

# Set trap to cleanup on exit (success, failure, or interruption)
trap cleanup EXIT INT TERM

# Command line argument parsing
parse_arguments() {
    while [ $# -gt 0 ]; do
        case $1 in
            --uninstall)
                MODE="uninstall"
                shift
                ;;
            --diagnostic)
                MODE="diagnostic"
                shift
                ;;
            --setup)
                MODE="setup"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --log)
                case "${2:-}" in
                    ''|--*)
                        echo -e "${red}[✗] option    :: --log requires a file path (e.g., --log /tmp/install.log)${reset}"
                        safe_exit 1
                        ;;
                esac
                LOG_FILE="$2"
                shift 2
                ;;
            --version)
                case "${2:-}" in
                    ''|--*)
                        echo -e "${red}[✗] option    :: --version requires a version number (e.g., --version 1.21.0)${reset}"
                        safe_exit 1
                        ;;
                esac
                SPECIFIC_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                safe_exit 0
                ;;
            *)
                echo -e "${red}[✗] option    :: unknown: $1${reset}"
                echo -e "${cyan}[*] hint      :: use --help for usage information${reset}"
                safe_exit 1
                ;;
        esac
    done
}

# Help function
show_help() {
    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${cyan}    letsGO Universal Go Installer${reset}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo ""
    echo -e "${cyan}// ── USAGE ───────────────────────────────────────────────────${reset}"
    echo ""
    echo -e "  $0 [OPTIONS]"
    echo ""
    echo -e "${cyan}// ── OPTIONS ─────────────────────────────────────────────────${reset}"
    echo ""
    echo "  --setup           Check and install required dependencies, then exit"
    echo "  --uninstall       Completely remove Go installation and clean environment"
    echo "  --diagnostic      Check current Go setup health and show system info"
    echo "  --version VERSION Install a specific version of Go (e.g., --version 1.21.0)"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --log FILE        Log installation details to specified file"
    echo "  --help, -h        Show this help message"
    echo ""
    echo -e "${cyan}// ── EXAMPLES ────────────────────────────────────────────────${reset}"
    echo ""
    echo "  $0                        Install or update to latest Go version"
    echo "  $0 --version 1.20.5       Install Go version 1.20.5"
    echo "  $0 --uninstall            Remove Go completely"
    echo "  $0 --diagnostic           Check Go installation health"
    echo "  $0 --verbose              Install with detailed output"
    echo ""
    echo -e "${yellow}[!] note      :: --version flag works only on Linux/MacOS, not Android/Termux${reset}"
    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo ""
}

# Enhanced logging functions
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[LOG] $message${reset}"
    fi

    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_error() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${red}[✗] error     :: $message${reset}" >&2

    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] ERROR: $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Detect operating system
detect_os() {
    case "$OSTYPE" in
        linux-android*)
            echo "android"
            ;;
        linux-*)
            # Matches linux-gnu (glibc), linux-musl (Alpine), and other Linux variants
            echo "linux"
            ;;
        darwin*)
            echo "MacOS"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Enhanced user shell detection - fixed to not contaminate return value
detect_user_shell() {
    local target_user="$1"
    local detected_shell=""

    # Log to stderr or file only, not stdout to avoid contaminating return value
    if [ "$VERBOSE" = true ]; then
        echo "[LOG] Detecting shell for user: $target_user" >&2
    fi
    if [ -n "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Detecting shell for user: $target_user" >> "$LOG_FILE" 2>/dev/null || true
    fi

    # Method 1: Check user's login shell from passwd
    if command -v getent >/dev/null 2>&1; then
        detected_shell=$(getent passwd "$target_user" 2>/dev/null | cut -d: -f7)
        if [ "$VERBOSE" = true ]; then
            echo "[LOG] getent detected shell: $detected_shell" >&2
        fi
    fi

    # Method 2: Fallback to environment
    if [ -z "$detected_shell" ]; then
        detected_shell="$SHELL"
        if [ "$VERBOSE" = true ]; then
            echo "[LOG] Using environment SHELL: $detected_shell" >&2
        fi
    fi

    # Method 3: Check for common shells by testing files
    if [ -z "$detected_shell" ]; then
        if [ -f "$HOME_DIR/.zshrc" ]; then
            detected_shell="/bin/zsh"
        elif [ -f "$HOME_DIR/.bashrc" ]; then
            detected_shell="/bin/bash"
        elif [ -f "$HOME_DIR/.config/fish/config.fish" ]; then
            detected_shell="/usr/bin/fish"
        else
            detected_shell="/bin/bash"  # Default fallback
        fi
        if [ "$VERBOSE" = true ]; then
            echo "[LOG] File-based detection: $detected_shell" >&2
        fi
    fi

    # Determine profile file based on shell - OUTPUT ONLY THE PROFILE FILE PATH
    case "$(basename "$detected_shell")" in
        zsh)
            echo "$HOME_DIR/.zshrc"
            ;;
        bash)
            if [ "$OS" = "MacOS" ]; then
                echo "$HOME_DIR/.bash_profile"
            else
                echo "$HOME_DIR/.bashrc"
            fi
            ;;
        fish)
            echo "$HOME_DIR/.config/fish/config.fish"
            ;;
        pwsh|powershell)
            # PowerShell profile (for WSL scenarios)
            echo "$HOME_DIR/.profile"
            ;;
        *)
            echo "$HOME_DIR/.profile"
            ;;
    esac
}

# Initialize core variables early
initialize_variables() {
    OS=$(detect_os)
    log_message "Detected operating system: $OS ($OSTYPE)"

    if [ "$OS" = "unsupported" ]; then
        log_error "Unsupported operating system: $OSTYPE"
        echo -e "${red}[✗] platform  :: unsupported: $OSTYPE${reset}"
        safe_exit 1
    fi

    # Set user and directories based on OS
    if [ "$OS" = "android" ]; then
        REAL_USER="${USER:-$(id -un 2>/dev/null)}"
        HOME_DIR="$HOME"
        INSTALL_DIR="$PREFIX"  # Termux uses $PREFIX instead of /usr/local
        BIN_DIR="$PREFIX/bin"
    elif [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        # Get home directory safely without eval
        HOME_DIR=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        if [ -z "$HOME_DIR" ] || [ ! -d "$HOME_DIR" ]; then
            # Try macOS-specific directory lookup
            if [ "$OS" = "MacOS" ]; then
                HOME_DIR=$(dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
            fi
        fi
        if [ -z "$HOME_DIR" ] || [ ! -d "$HOME_DIR" ]; then
            # Final fallback by OS
            if [ "$OS" = "MacOS" ]; then
                HOME_DIR="/Users/$SUDO_USER"
            else
                HOME_DIR="/home/$SUDO_USER"
            fi
        fi
        INSTALL_DIR="/usr/local"
        BIN_DIR="/usr/local/bin"
    else
        REAL_USER="${USER:-$(id -un 2>/dev/null)}"
        HOME_DIR="$HOME"
        INSTALL_DIR="/usr/local"
        BIN_DIR="/usr/local/bin"
    fi

    # Detect profile file
    PROFILE_FILE=$(detect_user_shell "$REAL_USER")

    log_message "User: $REAL_USER, Home: $HOME_DIR, Install: $INSTALL_DIR"
    log_message "Profile file: $PROFILE_FILE"
}

# Enhanced portable sed function
portable_sed() {
    local pattern="$1"
    local file="$2"
    local backup_ext=".bak"

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Create backup and perform sed operation
    if sed -i"$backup_ext" "$pattern" "$file" 2>/dev/null; then
        # Remove backup file if successful
        rm -f "${file}${backup_ext}" 2>/dev/null || true
        return 0
    else
        # Restore from backup if sed failed
        if [ -f "${file}${backup_ext}" ]; then
            mv "${file}${backup_ext}" "$file" 2>/dev/null || true
        fi
        return 1
    fi
}

# PATH deduplication function using string operations
deduplicate_path() {
    local new_path="$1"
    local profile_file="$2"

    if [ ! -f "$profile_file" ]; then
        return 1
    fi

    # Check if PATH addition already exists
    if grep -Fq "$new_path" "$profile_file" 2>/dev/null; then
        log_message "PATH entry already exists in $profile_file"
        return 0  # Already exists
    fi

    return 1  # Doesn't exist
}

# Print banner function
print_banner() {
    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${blue}    ██╗     ███████╗████████╗███████╗ ██████╗  ██████╗${reset}"
    echo -e "${blue}    ██║     ██╔════╝╚══██╔══╝██╔════╝██╔════╝ ██╔═══██╗${reset}"
    echo -e "${blue}    ██║     █████╗     ██║   ███████╗██║  ███╗██║   ██║${reset}"
    echo -e "${blue}    ██║     ██╔══╝     ██║   ╚════██║██║   ██║██║   ██║${reset}"
    echo -e "${blue}    ███████╗███████╗   ██║   ███████║╚██████╔╝╚██████╔╝${reset}"
    echo -e "${blue}    ╚══════╝╚══════╝   ╚═╝   ╚══════╝ ╚═════╝  ╚═════╝${reset}"
    echo -e "${cyan}                                              v0.14 // Darkcast${reset}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo ""
}

# Enhanced validation for Go version using portable pattern matching
validate_go_version() {
    local version="$1"

    # Add 'go' prefix if not present
    case "$version" in
        go*) ;;
        *) version="go${version}" ;;
    esac

    log_message "Validating Go version: $version"

    # Basic format validation using case statement (POSIX compatible)
    case "$version" in
        go1.[0-9]|go1.[0-9][0-9])
            # Valid: go1.x or go1.xx
            ;;
        go1.[0-9].[0-9]|go1.[0-9].[0-9][0-9]|go1.[0-9][0-9].[0-9]|go1.[0-9][0-9].[0-9][0-9])
            # Valid: go1.x.x or go1.xx.x or go1.x.xx or go1.xx.xx
            ;;
        *)
            echo -e "${red}[✗] version   :: invalid format: $version${reset}"
            echo -e "${cyan}[*] hint      :: expected format: 1.21.0 or go1.21.0${reset}"
            safe_exit 1
            ;;
    esac

    echo "$version"
}

# Enhanced version availability check - accepts redirects as valid
check_version_availability() {
    local version="$1"
    local arch="$2"
    local download_url="https://go.dev/dl/${version}.${arch}.tar.gz"

    log_message "Checking availability of $version for $arch"
    echo -e "${cyan}[*] checking  :: $version for $arch${reset}"

    # Use HEAD request to check if file exists
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --head "$download_url" 2>/dev/null)

    # Accept successful responses AND redirects as valid
    # go.dev uses CDN redirects for valid download URLs; treating 301/302 as available is intentional
    case "$response_code" in
        200|301|302)
            log_message "Version $version is available for $arch (HTTP $response_code)"
            echo -e "${green}[+] version   :: $version  available for $arch${reset}"
            return 0
            ;;
        *)
            log_error "Version $version is not available for $arch (HTTP $response_code)"
            echo -e "${red}[✗] version   :: $version  not available for $arch${reset}"
            echo -e "${cyan}[*] hint      :: check available versions at: https://go.dev/dl/${reset}"
            return 1
            ;;
    esac
}

# Check for sudo privileges (not needed for Android/Termux)
check_sudo() {
    if [ "$OS" = "linux" ] || [ "$OS" = "MacOS" ]; then
        if ! sudo -v >/dev/null 2>&1; then
            echo -e "${red}[✗] sudo      :: not available${reset}" >&2
            echo -e "${yellow}[!] action    :: run as: sudo ./$(basename "$0")${reset}" >&2
            safe_exit 1
        fi
    elif [ "$OS" = "android" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "${cyan}[*] platform  :: Android/Termux -- no sudo required${reset}"
        fi
    fi
}

# Enhanced package installation function
install_package() {
    local package="$1"

    echo -e "${cyan}[*] install   :: $package via apt-get${reset}"
    log_message "Installing package: $package"

    if [ "$OS" = "android" ]; then
        if command -v pkg >/dev/null 2>&1; then
            if pkg install -y "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via pkg"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            else
                log_error "Failed to install $package via pkg"
                echo -e "${red}[✗] install   :: $package failed${reset}"
                safe_exit 1
            fi
        else
            echo -e "${red}[✗] pkgmgr    :: none found -- install $package manually${reset}"
            safe_exit 1
        fi
    elif [ "$OS" = "linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            log_message "Using apt-get to install $package"
            if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via apt-get"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            fi
        elif command -v yum >/dev/null 2>&1; then
            log_message "Using yum to install $package"
            if sudo yum install -y "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via yum"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            fi
        elif command -v dnf >/dev/null 2>&1; then
            log_message "Using dnf to install $package"
            if sudo dnf install -y "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via dnf"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            fi
        elif command -v apk >/dev/null 2>&1; then
            log_message "Using apk to install $package"
            if sudo apk add "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via apk"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            fi
        else
            echo -e "${red}[✗] pkgmgr    :: none found -- install $package manually${reset}"
            safe_exit 1
        fi
        log_error "Failed to install $package via package manager"
        echo -e "${red}[✗] install   :: $package failed${reset}"
        safe_exit 1
    elif [ "$OS" = "MacOS" ]; then
        if command -v brew >/dev/null 2>&1; then
            log_message "Using brew to install $package"
            brew update >/dev/null 2>&1 || true
            if brew install "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via brew"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            else
                log_error "Failed to install $package via brew"
            fi
        elif command -v port >/dev/null 2>&1; then
            if sudo port install "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via port"
                echo -e "${green}[+] install   :: $package done${reset}"
                return 0
            else
                log_error "Failed to install $package via port"
            fi
        fi

        echo -e "${red}[✗] pkgmgr    :: not found${reset}"
        echo -e "${yellow}[!] homebrew  :: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${reset}"
        echo -e "${yellow}[!] then run  :: brew install $package${reset}"
        safe_exit 1
    fi
}

# Enhanced system information collection
collect_system_info() {
    log_message "Collecting system information"

    echo -e "${cyan}// ── SYSTEM ──────────────────────────────────────────────────${reset}"
    echo -e "${cyan}[*] ostype    :: $OSTYPE${reset}"
    echo -e "${cyan}[*] platform  :: $OS${reset}"
    echo -e "${cyan}[*] arch      :: $(uname -m)${reset}"
    echo -e "${cyan}[*] kernel    :: $(uname -r)${reset}"

    if [ "$OS" = "android" ]; then
        echo -e "${cyan}[*] termux    :: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')${reset}"
        echo -e "${cyan}[*] prefix    :: $PREFIX${reset}"

        # Android architecture detection
        local android_arch
        android_arch=$(uname -m)
        echo -e "${cyan}[*] arch      :: $android_arch${reset}"

        # Validate architecture support
        case "$android_arch" in
            aarch64|arm64)
                echo -e "${green}[+] arch      :: ARM64  supported${reset}"
                ;;
            armv7l|armv8l)
                echo -e "${green}[+] arch      :: ARM32  supported${reset}"
                ;;
            x86_64)
                echo -e "${green}[+] arch      :: x86_64  supported${reset}"
                ;;
            i686|i386)
                echo -e "${yellow}[!] arch      :: x86_32  limited support${reset}"
                ;;
            *)
                echo -e "${yellow}[!] arch      :: $android_arch  unknown${reset}"
                ;;
        esac
    fi

    echo -e "${cyan}[*] user      :: $REAL_USER${reset}"
    echo -e "${cyan}[*] home      :: $HOME_DIR${reset}"
    echo -e "${cyan}[*] shell     :: $(basename "$SHELL")${reset}"
    echo -e "${cyan}[*] profile   :: $PROFILE_FILE${reset}"

    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[*] PATH      :: $PATH${reset}"
    fi
    echo ""

    # Go-specific information
    echo -e "${cyan}// ── GO ENVIRONMENT ──────────────────────────────────────────${reset}"
    if command -v go >/dev/null 2>&1; then
        echo -e "${cyan}[*] go        :: $(go version 2>/dev/null)${reset}"
        echo -e "${cyan}[*] binary    :: $(which go 2>/dev/null)${reset}"
        echo -e "${cyan}[*] GOROOT    :: $(go env GOROOT 2>/dev/null)${reset}"
        echo -e "${cyan}[*] GOPATH    :: $(go env GOPATH 2>/dev/null)${reset}"
        echo -e "${cyan}[*] GOOS      :: $(go env GOOS 2>/dev/null)${reset}"
        echo -e "${cyan}[*] GOARCH    :: $(go env GOARCH 2>/dev/null)${reset}"
    else
        echo -e "${yellow}[!] go        :: not installed${reset}"
    fi
    echo ""
}

# Enhanced diagnostic mode function using string operations
run_diagnostics() {
    echo -e "${cyan}// ── DIAGNOSTIC ──────────────────────────────────────────────${reset}"
    echo ""

    collect_system_info

    # Check for conflicts using string operations
    echo -e "${cyan}// ── HEALTH ──────────────────────────────────────────────────${reset}"
    local issues_found=false

    # Fixed: Only check for actual Go INSTALLATIONS, not GOPATH directories
    local go_locations=""
    local location_count=0
    # Removed $HOME_DIR/go from list since it's GOPATH, not an installation
    local potential_locations="/usr/local/go /usr/bin/go $PREFIX/go $PREFIX/lib/go"

    for location in $potential_locations; do
        # Only count directories that contain Go binaries (actual installations)
        if [ -d "$location" ] && [ -f "$location/bin/go" ]; then
            go_locations="$go_locations $location"
            location_count=$((location_count + 1))
        fi
    done

    if [ $location_count -gt 1 ]; then
        echo -e "${yellow}[!] conflicts :: multiple Go installations found:${reset}"
        for loc in $go_locations; do
            [ -n "$loc" ] && echo -e "               $loc"
        done
        issues_found=true
    fi

    # Check for broken symlinks
    local bin_paths="$PREFIX/bin/go $BIN_DIR/go /usr/local/bin/go"
    for bin_path in $bin_paths; do
        if [ -L "$bin_path" ] && [ ! -e "$bin_path" ]; then
            echo -e "${yellow}[!] symlink   :: broken: $bin_path${reset}"
            issues_found=true
        fi
    done

    # Fixed: Improved GOROOT/binary relationship check
    if command -v go >/dev/null 2>&1; then
        local go_which
        go_which=$(which go 2>/dev/null)
        local go_root
        go_root=$(go env GOROOT 2>/dev/null)

        if [ -n "$go_root" ] && [ ! -d "$go_root" ]; then
            echo -e "${yellow}[!] GOROOT    :: points to non-existent directory: $go_root${reset}"
            issues_found=true
        fi

        if [ -n "$go_which" ] && [ -n "$go_root" ]; then
            # Enhanced check: resolve symlinks and check if binary is actually under GOROOT
            local resolved_go_binary=""
            if [ -L "$go_which" ]; then
                # If it's a symlink, resolve it
                resolved_go_binary=$(readlink -f "$go_which" 2>/dev/null || readlink "$go_which" 2>/dev/null)
            else
                resolved_go_binary="$go_which"
            fi

            # Check if the resolved binary path starts with GOROOT
            case "$resolved_go_binary" in
                "$go_root"*)
                    # Good - go binary is under GOROOT (directly or via symlink)
                    ;;
                *)
                    # Only flag as mismatch if it's genuinely wrong
                    echo -e "${yellow}[!] mismatch  :: go binary and GOROOT differ${reset}"
                    echo -e "               binary   $go_which"
                    if [ "$resolved_go_binary" != "$go_which" ]; then
                        echo -e "               resolved $resolved_go_binary"
                    fi
                    echo -e "               GOROOT   $go_root"
                    issues_found=true
                    ;;
            esac
        fi
    fi

    # Check profile file issues
    if [ -f "$PROFILE_FILE" ]; then
        local go_path_count
        go_path_count=$(grep -c "GOROOT\|GOPATH" "$PROFILE_FILE" 2>/dev/null || echo "0")
        if [ "$go_path_count" -gt 4 ]; then
            echo -e "${yellow}[!] profile   :: multiple Go env declarations in $PROFILE_FILE${reset}"
            issues_found=true
        fi
    fi

    # Additional helpful checks
    if command -v go >/dev/null 2>&1; then
        local gopath_dir
        gopath_dir=$(go env GOPATH 2>/dev/null)
        if [ -n "$gopath_dir" ] && [ ! -d "$gopath_dir" ]; then
            echo -e "${yellow}[!] GOPATH    :: directory does not exist: $gopath_dir${reset}"
            echo -e "${cyan}[*] hint      :: run: mkdir -p $gopath_dir${reset}"
            issues_found=true
        fi
    fi

    if [ "$issues_found" = false ]; then
        echo -e "${green}[✓] health    :: no issues detected${reset}"
    fi

    # Version currency check — only runs if online
    echo ""
    echo -e "${cyan}// ── VERSION STATUS ──────────────────────────────────────────${reset}"
    if command -v go >/dev/null 2>&1; then
        local installed_version
        installed_version=$(go version 2>/dev/null | awk '{print $3}')

        # Detect connectivity with a lightweight HEAD request (5s timeout)
        local online=false
        if curl -s --max-time 5 --head "https://go.dev" >/dev/null 2>&1; then
            online=true
        fi

        if [ "$online" = true ]; then
            # Try jq first, fall back to plain curl
            local latest_version=""
            if command -v jq >/dev/null 2>&1; then
                latest_version=$(curl -s --max-time 10 "https://go.dev/dl/?mode=json" 2>/dev/null \
                    | jq -r '.[0].version' 2>/dev/null)
            fi
            if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
                latest_version=$(curl -s --max-time 10 https://go.dev/VERSION 2>/dev/null \
                    | head -1 | tr -d '\r')
            fi

            if [ -n "$latest_version" ]; then
                if [ "$installed_version" = "$latest_version" ]; then
                    echo -e "${green}[+] version   :: $installed_version  up to date${reset}"
                else
                    echo -e "${cyan}[*] installed :: $installed_version${reset}"
                    echo -e "${yellow}[!] latest    :: $latest_version  update available${reset}"
                    echo -e "${cyan}[*] hint      :: run: $(basename "$0") to upgrade${reset}"
                fi
            else
                echo -e "${cyan}[*] installed :: $installed_version${reset}"
                echo -e "${yellow}[!] latest    :: could not fetch from go.dev${reset}"
            fi
        else
            # Offline — just show installed version, skip the comparison
            echo -e "${cyan}[*] installed :: $installed_version${reset}"
            echo -e "${blue}[*] offline   :: skipping latest version check${reset}"
        fi
    else
        echo -e "${yellow}[!] go        :: not installed -- cannot check version status${reset}"
    fi

    echo ""
    echo -e "${cyan}// ── RECOMMENDATIONS ─────────────────────────────────────────${reset}"
    if command -v go >/dev/null 2>&1; then
        echo -e "${green}[✓] health    :: installation healthy${reset}"
        echo -e "${cyan}[*] try       :: go version${reset}"
        echo -e "${cyan}[*] try       :: go env${reset}"
        echo -e "${cyan}[*] try       :: go env GOPATH && ls \$(go env GOPATH)${reset}"
    else
        echo -e "${yellow}[!] status    :: Go not installed${reset}"
        echo -e "${cyan}[*] hint      :: run: sudo ./$(basename "$0")${reset}"
    fi

    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    safe_exit 0
}

# Enhanced backup function
create_backup() {
    local backup_dir="$HOME_DIR/.letsgo_backups/$(date +%Y%m%d_%H%M%S)"
    log_message "Creating backup in: $backup_dir"

    mkdir -p "$backup_dir" 2>/dev/null || {
        log_error "Failed to create backup directory: $backup_dir"
        echo -e "${yellow}[!] backup    :: could not create backup directory${reset}"
        return 1
    }

    # Estimate backup size and check available space
    local backup_size_kb=0
    if [ -d "$INSTALL_DIR/go" ]; then
        backup_size_kb=$(du -sk "$INSTALL_DIR/go" 2>/dev/null | awk '{print $1}')
    fi
    if [ "$OS" = "android" ] && [ -d "$PREFIX/lib/go" ]; then
        backup_size_kb=$(du -sk "$PREFIX/lib/go" 2>/dev/null | awk '{print $1}')
    fi
    if [ "${backup_size_kb:-0}" -gt 0 ]; then
        local avail_kb
        avail_kb=$(df -k "$HOME_DIR" 2>/dev/null | awk 'NR==2{print $4}')
        if [ -n "$avail_kb" ] && [ "$avail_kb" -lt "$backup_size_kb" ]; then
            echo -e "${yellow}[!] disk      :: insufficient space for backup -- skipping${reset}"
            log_message "Backup skipped: insufficient disk space"
            return 1
        fi
        local avail_mb=$(( avail_kb / 1024 ))
        echo -e "${cyan}[*] backup    :: creating (~${avail_mb}MB)${reset}"
    fi

    # Backup existing Go installation
    if [ -d "$INSTALL_DIR/go" ]; then
        log_message "Backing up $INSTALL_DIR/go"
        sudo cp -r "$INSTALL_DIR/go" "$backup_dir/go_installation" 2>/dev/null || true
    fi

    if [ "$OS" = "android" ] && [ -d "$PREFIX/lib/go" ]; then
        log_message "Backing up $PREFIX/lib/go"
        cp -r "$PREFIX/lib/go" "$backup_dir/termux_go" 2>/dev/null || true
    fi

    # Backup profile files using string list
    local profiles="$HOME_DIR/.bashrc $HOME_DIR/.bash_profile $HOME_DIR/.zshrc $HOME_DIR/.profile $HOME_DIR/.config/fish/config.fish"
    for profile in $profiles; do
        if [ -f "$profile" ]; then
            log_message "Backing up $profile"
            cp "$profile" "$backup_dir/$(basename "$profile").backup" 2>/dev/null || true
        fi
    done

    # Save backup location
    echo "$backup_dir" > "$HOME_DIR/.letsgo_last_backup" 2>/dev/null || true
    echo -e "${green}[+] backup    :: $backup_dir  done${reset}"
    return 0
}

# Enhanced uninstall function
uninstall_go() {
    echo -e "${cyan}// ── UNINSTALL ───────────────────────────────────────────────${reset}"
    echo ""

    # Collect info before uninstalling
    if command -v go >/dev/null 2>&1; then
        echo -e "${cyan}[*] target    :: $(go env GOROOT 2>/dev/null)${reset}"
        echo -e "${cyan}[*] version   :: $(go version 2>/dev/null)${reset}"
        echo -e "${cyan}[*] binary    :: $(which go 2>/dev/null)${reset}"
        echo -e "${cyan}[*] user      :: $REAL_USER${reset}"
        echo ""
    fi

    # ── Privilege ──────────────────────────────────────────────────────────────
    echo -e "${cyan}// ── PRIVILEGE ───────────────────────────────────────────────${reset}"
    if [ "$OS" != "android" ]; then
        check_sudo
        echo -e "${green}[+] sudo      :: granted${reset}"
    else
        echo -e "${green}[+] sudo      :: no sudo required${reset}"
    fi
    echo ""

    # ── Backup ─────────────────────────────────────────────────────────────────
    echo -e "${cyan}// ── BACKUP ──────────────────────────────────────────────────${reset}"
    create_backup
    echo ""

    log_message "Starting Go uninstallation"

    # ── Remove ─────────────────────────────────────────────────────────────────
    echo -e "${cyan}// ── REMOVE ──────────────────────────────────────────────────${reset}"
    if [ "$OS" = "android" ]; then
        # Termux uninstallation
        log_message "Removing Go via pkg"
        if command -v go >/dev/null 2>&1; then
            if pkg uninstall golang -y >/dev/null 2>&1; then
                echo -e "${yellow}[-] remove    :: Go via pkg  done${reset}"
                log_message "Successfully removed Go via pkg"
            else
                echo -e "${yellow}[!] remove    :: failed via pkg, continuing with manual cleanup${reset}"
                log_message "Failed to remove Go via pkg, performing manual cleanup"
            fi
        fi
        rm -rf "$PREFIX/go" 2>/dev/null
        rm -f "$PREFIX/bin/go" "$PREFIX/bin/gofmt" 2>/dev/null
        log_message "Cleaned up Termux Go files"
    else
        # Linux/MacOS uninstallation
        local go_install_path="$INSTALL_DIR/go"
        if [ -d "$go_install_path" ]; then
            if sudo rm -rf "$go_install_path" 2>/dev/null; then
                log_message "Removed $go_install_path"
                echo -e "${yellow}[-] remove    :: $go_install_path  done${reset}"
            else
                log_error "Failed to remove $go_install_path"
                echo -e "${red}[✗] remove    :: $go_install_path  failed${reset}"
            fi
        fi

        # Remove symlinks — only report what actually existed
        local symlinks_removed=false
        if [ -L "$BIN_DIR/go" ] || [ -L "$BIN_DIR/gofmt" ]; then
            symlinks_removed=true
        fi
        sudo rm -f "$BIN_DIR/go" "$BIN_DIR/gofmt" 2>/dev/null
        if [ "$symlinks_removed" = true ]; then
            echo -e "${yellow}[-] symlinks  :: $BIN_DIR/go  $BIN_DIR/gofmt  removed${reset}"
        else
            echo -e "${cyan}[*] symlinks  :: none found in $BIN_DIR${reset}"
        fi
        log_message "Removed Go symlinks from $BIN_DIR"
    fi
    echo ""

    # ── Environment cleanup ────────────────────────────────────────────────────
    echo -e "${cyan}// ── ENVIRONMENT ─────────────────────────────────────────────${reset}"
    log_message "Cleaning environment variables"
    local profiles="$HOME_DIR/.bashrc $HOME_DIR/.bash_profile $HOME_DIR/.zshrc $HOME_DIR/.profile $HOME_DIR/.config/fish/config.fish"

    for profile in $profiles; do
        if [ -f "$profile" ]; then
            log_message "Cleaning Go config from $profile"
            portable_sed '/# golang setup/d' "$profile"
            portable_sed '/export GOROOT/d' "$profile"
            portable_sed '/export GOPATH/d' "$profile"
            portable_sed '/export GOBIN/d' "$profile"
            portable_sed '/export PATH.*GOROOT/d' "$profile"
            portable_sed '/export PATH.*GOPATH/d' "$profile"
            portable_sed '/export PATH.*\/go\/bin/d' "$profile"
            portable_sed '/export PATH.*\/usr\/local\/go/d' "$profile"
            portable_sed '/set -x GOROOT/d' "$profile"
            portable_sed '/set -x GOPATH/d' "$profile"
            portable_sed '/set -x PATH.*GOROOT/d' "$profile"
            portable_sed '/set -x PATH.*GOPATH/d' "$profile"
            portable_sed '/set -x PATH.*\/go\/bin/d' "$profile"
            portable_sed '/fish_add_path.*go/d' "$profile"
        fi
    done

    for profile in $profiles; do
        if [ -f "$profile" ]; then
            portable_sed '/.*\/usr\/local\/go\/bin/d' "$profile"
            portable_sed '/.*\$HOME\/go\/bin/d' "$profile"
            portable_sed '/.*\${HOME}\/go\/bin/d' "$profile"
        fi
    done

    echo -e "${yellow}[-] env       :: $PROFILE_FILE  cleaned${reset}"
    echo ""

    # ── GOPATH workspace ───────────────────────────────────────────────────────
    if [ -d "$HOME_DIR/go" ]; then
        echo -e "${cyan}// ── GOPATH ──────────────────────────────────────────────────${reset}"
        echo -e "${yellow}[?] GOPATH    :: remove $HOME_DIR/go and all Go packages?${reset}"
        echo -e "${cyan}[*] warning   :: this will delete all Go projects and installed packages${reset}"
        printf "Remove GOPATH? (y/N): "
        read -r reply
        case "$reply" in
            [Yy]|[Yy][Ee][Ss])
                if rm -rf "$HOME_DIR/go" 2>/dev/null; then
                    log_message "Removed GOPATH directory"
                    echo -e "${yellow}[-] GOPATH    :: $HOME_DIR/go  removed${reset}"
                else
                    log_error "Failed to remove GOPATH directory"
                    echo -e "${red}[✗] GOPATH    :: failed to remove $HOME_DIR/go${reset}"
                fi
                ;;
            *)
                echo -e "${cyan}[*] GOPATH    :: keeping $HOME_DIR/go${reset}"
                ;;
        esac
        echo ""
    fi

    # ── Summary ────────────────────────────────────────────────────────────────
    echo -e "${cyan}// ── SUMMARY ─────────────────────────────────────────────────${reset}"
    echo -e "${green}[✓] uninstall :: complete${reset}"
    if [ -f "$HOME_DIR/.letsgo_last_backup" ]; then
        echo -e "${cyan}[*] backup    :: $(cat "$HOME_DIR/.letsgo_last_backup" 2>/dev/null)${reset}"
    fi
    echo -e "${yellow}[!] action    :: source $(basename "$PROFILE_FILE")${reset}"
    echo ""

    log_message "Go uninstallation completed successfully"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    safe_exit 0
}


# Enhanced Go installation verification
verify_go_installation() {
    local max_attempts=1
    local attempt=1

    echo -e "${cyan}[*] verify    :: checking Go installation${reset}"
    log_message "Starting Go installation verification"

    # Update PATH once before the retry loop — not on every attempt
    local _go_bin="$INSTALL_DIR/go/bin"
    local _gopath_bin="$HOME_DIR/go/bin"
    if [ "$OS" = "android" ]; then
        _go_bin="$PREFIX/lib/go/bin"
    fi
    case ":$PATH:" in
        *":$_go_bin:"*) ;;
        *) export PATH="$_go_bin:$PATH" ;;
    esac
    case ":$PATH:" in
        *":$_gopath_bin:"*) ;;
        *) export PATH="$_gopath_bin:$PATH" ;;
    esac

    while [ $attempt -le $max_attempts ]; do
        log_message "Verification attempt $attempt of $max_attempts"

        # Check if go command is available
        if command -v go >/dev/null 2>&1; then
            local go_version_output
            local go_version_exit_code
            go_version_output=$(go version 2>&1)
            go_version_exit_code=$?

            if [ $go_version_exit_code -eq 0 ]; then
                echo -e "${green}[+] verify    :: $go_version_output${reset}"
                log_message "Go verification successful: $go_version_output"

                # Additional verification - check GOROOT
                local goroot_output
                goroot_output=$(go env GOROOT 2>&1)
                if [ $? -eq 0 ]; then
                    echo -e "${cyan}[*] GOROOT    :: $goroot_output${reset}"
                    log_message "GOROOT verification: $goroot_output"
                else
                    echo -e "${yellow}[!] GOROOT    :: could not verify${reset}"
                fi

                return 0
            else
                log_message "Go version command failed: $go_version_output"
                echo -e "${yellow}[!] verify    :: go command not found in PATH${reset}"
            fi
        else
            log_message "Go command not found in PATH (attempt $attempt)"
            echo -e "${yellow}[!] verify    :: go command not found in PATH${reset}"
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo -e "${cyan}[*] verify    :: retrying...${reset}"
        fi

        attempt=$((attempt + 1))
    done

    # If we get here, verification failed
    log_error "Go installation verification failed after $max_attempts attempts"
    echo -e "${red}[✗] verify    :: installation check failed${reset}"
    echo -e "${yellow}[!] hint      :: source $(basename "$PROFILE_FILE") && go version${reset}"
    return 1
}

# Enhanced success exit function with cleanup
success_exit() {
    local message="${1:-Installation complete! Run 'go version' to verify.}"
    local skip_verification="${2:-false}"

    # Verify installation unless explicitly skipped
    if [ "$skip_verification" != "true" ]; then
        if verify_go_installation; then
            message="Installation completed and verified successfully!"
        else
            message="Installation completed but verification failed - please check manually"
        fi
    fi

    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "${green}[✓] done      :: $message${reset}"
    if [ -n "$PROFILE_FILE" ]; then
        echo -e "${yellow}[!] action    :: source $(basename "$PROFILE_FILE")${reset}"
    fi
    echo -e "${cyan}[*] share     :: Enjoyed this? Help others discover it by sharing!${reset}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo    ""
    safe_exit 0
}

# Enhanced Android Go installation
install_go_android() {
    echo -e "${cyan}// ── INSTALL (TERMUX) ─────────────────────────────────────────${reset}"
    echo -e "${cyan}[*] platform  :: android/termux${reset}"
    echo -e "${cyan}[*] user      :: $REAL_USER${reset}"
    log_message "Starting Android Go installation"

    # Enhanced detection of problematic installations
    local cleanup_needed=false

    # Check for broken manual Go installation in $PREFIX/go
    if [ -d "$PREFIX/go" ]; then
        echo -e "${yellow}[!] install   :: found previous manual Go installation in $PREFIX/go${reset}"
        cleanup_needed=true
    fi

    # Check for broken symlinks
    if [ -L "$PREFIX/bin/go" ] && [ ! -e "$PREFIX/bin/go" ]; then
        echo -e "${yellow}[!] symlink   :: broken Go symlink in $PREFIX/bin/go${reset}"
        cleanup_needed=true
    fi

    # Check for problematic GOROOT in profile
    if [ -f "$PROFILE_FILE" ] && grep -q "export GOROOT\|set -x GOROOT" "$PROFILE_FILE" 2>/dev/null; then
        if ! deduplicate_path "GOROOT=\$PREFIX/lib/go" "$PROFILE_FILE" && \
           ! deduplicate_path "GOROOT \$PREFIX/lib/go" "$PROFILE_FILE"; then
            echo -e "${yellow}[!] profile   :: incorrect GOROOT in $PROFILE_FILE${reset}"
            cleanup_needed=true
        fi
    fi

    # Clean up if issues were detected
    if [ "$cleanup_needed" = true ]; then
        echo -e "${yellow}[!] cleanup   :: removing previous broken installations${reset}"
        rm -rf "$PREFIX/go" 2>/dev/null
        rm -f "$PREFIX/bin/go" "$PREFIX/bin/gofmt" 2>/dev/null

        # Clean environment variables
        if [ -f "$PROFILE_FILE" ]; then
            portable_sed '/# golang setup/d' "$PROFILE_FILE"
            portable_sed '/export GOROOT/d' "$PROFILE_FILE"
            portable_sed '/export GOPATH/d' "$PROFILE_FILE"
            portable_sed '/export GOBIN/d' "$PROFILE_FILE"
            portable_sed '/set -x GOROOT/d' "$PROFILE_FILE"
            portable_sed '/set -x GOPATH/d' "$PROFILE_FILE"
        fi
        echo -e "${green}[-] cleanup   :: done${reset}"
    fi

    # Install Go via pkg
    echo -e "${cyan}[*] install   :: golang via pkg${reset}"
    log_message "Installing Go via Termux pkg"
    if pkg install golang -y >/dev/null 2>&1; then
        echo -e "${green}[+] install   :: done${reset}"
        log_message "Successfully installed Go via pkg"

        # Set up correct environment variables for Termux
        log_message "Setting up Termux Go environment variables"

        # Ensure profile file and its directory exist
        mkdir -p "$(dirname "$PROFILE_FILE")" 2>/dev/null || true
        touch "$PROFILE_FILE"

        # Check if environment is already configured properly
        if ! deduplicate_path "GOROOT=\$PREFIX/lib/go" "$PROFILE_FILE"; then
            # Handle different shell configurations
            case "$PROFILE_FILE" in
                *config.fish*)
                    # Fish shell configuration
                    {
                        echo ""
                        echo "# golang setup for Termux (fish shell)"
                        echo "set -x GOROOT \$PREFIX/lib/go"
                        echo "set -x GOPATH \$HOME/go"
                        echo "fish_add_path \$GOROOT/bin \$GOPATH/bin"
                    } >> "$PROFILE_FILE"
                    ;;
                *)
                    # Bash/Zsh configuration
                    {
                        echo ""
                        echo "# golang setup for Termux"
                        echo "export GOROOT=\$PREFIX/lib/go"
                        echo "export GOPATH=\$HOME/go"
                        echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin"
                    } >> "$PROFILE_FILE"
                    ;;
            esac

            echo -e "${green}[+] env       :: $PROFILE_FILE  patched${reset}"
            log_message "Environment variables added to $PROFILE_FILE"
        else
            echo -e "${green}[+] env       :: already configured${reset}"
            log_message "Environment variables already present in $PROFILE_FILE"
        fi

        # Create GOPATH directory
        mkdir -p "$HOME/go/bin" 2>/dev/null || true
        log_message "Created GOPATH directory: $HOME/go/bin"

        echo -e "${yellow}[!] action    :: source $(basename "$PROFILE_FILE")${reset}"

        # Success exit with cleanup and social message
        log_message "Android Go installation completed successfully"
        success_exit "Android Go installation completed successfully!"
    else
        log_error "Failed to install Go via pkg"
        echo -e "${red}[✗] install   :: failed via pkg${reset}"
        echo -e "${red}[✗] hint      :: try manually: pkg install golang${reset}"
        safe_exit 1
    fi
}

# Enhanced Linux/MacOS manual Go installation
install_go_manual() {
    # Check if the requested version is available
    if ! check_version_availability "$GO_VERSION" "$ARCH"; then
        echo -e "${red}[✗] abort     :: cannot proceed with unavailable version${reset}"
        safe_exit 1
    fi

    echo -e "${cyan}// ── TARGET ──────────────────────────────────────────────────${reset}"
    echo -e "${cyan}[*] version   :: $GO_VERSION${reset}"
    echo -e "${cyan}[*] platform  :: $OS $ARCH${reset}"
    echo -e "${cyan}[*] target    :: $INSTALL_DIR/go${reset}"
    echo ""
    log_message "Starting manual installation for $OS with architecture $ARCH"

    # Create backup before installation
    echo -e "${cyan}// ── BACKUP ──────────────────────────────────────────────────${reset}"
    if command -v go >/dev/null 2>&1; then
        create_backup
    else
        echo -e "${cyan}[*] backup    :: no existing installation -- skipping${reset}"
    fi
    echo ""

    # Create temp directory for download
    TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'letsgo')
    if [ -z "$TEMP_DIR" ] || [ ! -d "$TEMP_DIR" ]; then
        log_error "Failed to create temporary directory"
        echo -e "${red}[✗] tmpdir    :: failed to create temporary directory${reset}"
        safe_exit 1
    fi
    log_message "Using temp directory: $TEMP_DIR"

    # Set download file path (absolute, in temp dir)
    DOWNLOAD_FILE="$TEMP_DIR/${GO_VERSION}.${ARCH}.tar.gz"
    log_message "Download file: $DOWNLOAD_FILE"

    # Extract SHA256 checksum for this specific build from cached API response
    if [ -n "$GO_API_RESPONSE" ] && command -v jq >/dev/null 2>&1; then
        GO_CHECKSUM=$(echo "$GO_API_RESPONSE" | jq -r \
            --arg fn "${GO_VERSION}.${ARCH}.tar.gz" \
            '.[0].files[] | select(.filename == $fn) | .sha256' 2>/dev/null)
        log_message "Expected checksum: $GO_CHECKSUM"
    fi

    # Download Go
    echo -e "${cyan}// ── DOWNLOAD ────────────────────────────────────────────────${reset}"
    echo -e "${cyan}[*] fetch     :: $GO_VERSION.$ARCH.tar.gz${reset}"
    if ! wget -q "https://go.dev/dl/${GO_VERSION}.${ARCH}.tar.gz" -O "$DOWNLOAD_FILE"; then
        log_error "Failed to download Go version $GO_VERSION"
        echo -e "${red}[✗] fetch     :: failed${reset}"
        safe_exit 1
    fi
    echo -e "${green}[+] fetch     :: done${reset}"
    log_message "Successfully downloaded Go binary"

    # Verify download
    if [ ! -f "$DOWNLOAD_FILE" ] || [ ! -s "$DOWNLOAD_FILE" ]; then
        log_error "Downloaded file is missing or empty"
        echo -e "${red}[✗] fetch     :: downloaded file is corrupt or missing${reset}"
        safe_exit 1
    fi

    # Verify SHA256 checksum of downloaded file
    echo -e "${cyan}[*] sha256    :: verifying${reset}"
    if [ -n "$GO_CHECKSUM" ]; then
        local actual_checksum=""
        if command -v sha256sum >/dev/null 2>&1; then
            actual_checksum=$(sha256sum "$DOWNLOAD_FILE" 2>/dev/null | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            actual_checksum=$(shasum -a 256 "$DOWNLOAD_FILE" 2>/dev/null | awk '{print $1}')
        else
            echo -e "${yellow}[!] sha256    :: no SHA256 tool found -- skipping verification${reset}"
        fi
        if [ -n "$actual_checksum" ]; then
            if [ "$actual_checksum" = "$GO_CHECKSUM" ]; then
                echo -e "${green}[+] sha256    :: verified${reset}"
                log_message "Checksum verified: $actual_checksum"
            else
                log_error "Checksum mismatch! Expected: $GO_CHECKSUM, Got: $actual_checksum"
                echo -e "${red}[✗] sha256    :: mismatch${reset}"
                echo -e "${red}               expected  $GO_CHECKSUM${reset}"
                echo -e "${red}               got       $actual_checksum${reset}"
                echo -e "${red}[✗] abort     :: verify your connection and retry${reset}"
                safe_exit 1
            fi
        fi
    else
        echo -e "${yellow}[!] sha256    :: no checksum available -- skipping verification${reset}"
        log_message "No checksum available - skipping verification"
    fi
    echo ""

    # Remove existing Go installation if it exists
    echo -e "${cyan}// ── INSTALL ─────────────────────────────────────────────────${reset}"
    local go_install_path="$INSTALL_DIR/go"
    if [ -d "$go_install_path" ]; then
        echo -e "${yellow}[!] remove    :: existing installation${reset}"
        if sudo rm -rf "$go_install_path" 2>/dev/null; then
            log_message "Removed existing Go installation"
        else
            log_error "Failed to remove existing Go installation"
            echo -e "${red}[✗] remove    :: failed${reset}"
            safe_exit 1
        fi
    fi

    # Extract Go
    echo -e "${cyan}[*] extract   :: $INSTALL_DIR${reset}"
    if ! sudo tar -C "$INSTALL_DIR" -xzf "$DOWNLOAD_FILE" >/dev/null 2>&1; then
        log_error "Failed to extract Go version $GO_VERSION"
        echo -e "${red}[✗] extract   :: failed${reset}"
        safe_exit 1
    fi
    echo -e "${green}[+] extract   :: done${reset}"
    log_message "Successfully extracted Go binary"

    # Ensure bin directory exists
    sudo mkdir -p "$BIN_DIR" 2>/dev/null || true

    # Create symbolic links
    local symlink_path="$BIN_DIR/go"
    local symlink_ok=true
    if sudo ln -sf "$go_install_path/bin/go" "$symlink_path" 2>/dev/null; then
        log_message "Created Go symlink"
    else
        echo -e "${yellow}[!] symlink   :: failed for $symlink_path -- Go still usable from $go_install_path/bin/${reset}"
        log_message "Failed to create Go symlink, but installation continues"
        symlink_ok=false
    fi

    # Also create symlink for gofmt
    if sudo ln -sf "$go_install_path/bin/gofmt" "$BIN_DIR/gofmt" 2>/dev/null; then
        log_message "Created gofmt symlink"
    else
        echo -e "${yellow}[!] symlink   :: failed to create gofmt symlink${reset}"
        log_message "Failed to create gofmt symlink"
        symlink_ok=false
    fi

    if [ "$symlink_ok" = true ]; then
        echo -e "${green}[+] symlink   :: $BIN_DIR/go  $BIN_DIR/gofmt${reset}"
    fi
    echo ""

    # Add Go to the PATH environment variable for the REAL user
    echo -e "${cyan}// ── ENVIRONMENT ─────────────────────────────────────────────${reset}"
    if ! deduplicate_path "# golang setup" "$PROFILE_FILE"; then
        # Ensure the profile file exists and is owned by the real user
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$REAL_USER" touch "$PROFILE_FILE" 2>/dev/null || touch "$PROFILE_FILE"
        else
            touch "$PROFILE_FILE"
        fi

        {
            echo ""
            echo "# golang setup"
            echo "export GOROOT=$go_install_path"
            echo "export GOPATH=\$HOME/go"
            echo "export GOBIN=\$HOME/go/bin"
            echo "export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH"
        } >> "$PROFILE_FILE"

        # Ensure the profile file is owned by the real user
        if [ -n "$SUDO_USER" ]; then
            local real_group
            real_group=$(id -gn "$REAL_USER" 2>/dev/null) || real_group="$REAL_USER"
            sudo chown "$REAL_USER:$real_group" "$PROFILE_FILE" 2>/dev/null || true
        fi

        echo -e "${green}[+] env       :: $PROFILE_FILE  patched${reset}"
        log_message "Added Go environment variables to $PROFILE_FILE"
    else
        echo -e "${green}[+] env       :: $PROFILE_FILE  already configured${reset}"
        log_message "Go environment variables already present in $PROFILE_FILE"
    fi

    # Create GOPATH directory for the real user
    local gopath_dir="$HOME_DIR/go/bin"
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$REAL_USER" mkdir -p "$gopath_dir" 2>/dev/null || mkdir -p "$gopath_dir"
    else
        mkdir -p "$gopath_dir" 2>/dev/null || true
    fi
    log_message "Created GOPATH directory: $gopath_dir"
    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

# Pre-flight setup: verify and install all required dependencies
run_setup() {
    print_banner
    echo -e "${cyan}// ── SETUP ───────────────────────────────────────────────────${reset}"
    echo -e "${cyan}[*] platform  :: $OS${reset}"
    echo -e "${cyan}[*] user      :: $REAL_USER${reset}"
    echo -e "${cyan}[*] target    :: $INSTALL_DIR/go${reset}"
    echo ""

    local issues=0
    local installed=0

    # ── 1. Sudo check ──────────────────────────────────────────────────────────
    echo -e "${cyan}// ── PRIVILEGE ───────────────────────────────────────────────${reset}"
    if [ "$OS" = "android" ]; then
        echo -e "${green}[+] sudo      :: no sudo required${reset}"
    else
        if sudo -v >/dev/null 2>&1; then
            echo -e "${green}[+] sudo      :: granted${reset}"
        else
            echo -e "${red}[✗] sudo      :: not available${reset}"
            echo -e "${yellow}[!] action    :: run as: sudo ./$(basename "$0")${reset}"
            issues=$((issues + 1))
        fi
    fi
    echo ""

    # ── 2. Internet connectivity ───────────────────────────────────────────────
    echo -e "${cyan}// ── CONNECTIVITY ────────────────────────────────────────────${reset}"
    if curl -s --max-time 5 --head "https://go.dev" >/dev/null 2>&1; then
        echo -e "${green}[+] net       :: go.dev reachable${reset}"
    else
        echo -e "${yellow}[!] net       :: go.dev unreachable${reset}"
        issues=$((issues + 1))
    fi
    echo ""

    # ── 3. Architecture ────────────────────────────────────────────────────────
    echo -e "${cyan}// ── ARCHITECTURE ────────────────────────────────────────────${reset}"
    local machine_arch
    machine_arch=$(uname -m)
    case "$machine_arch" in
        x86_64|amd64)
            echo -e "${green}[+] arch      :: $machine_arch  supported${reset}"
            ;;
        aarch64|arm64)
            echo -e "${green}[+] arch      :: $machine_arch  supported${reset}"
            ;;
        armv6l|armv7l)
            echo -e "${green}[+] arch      :: $machine_arch  supported${reset}"
            ;;
        *)
            echo -e "${red}[✗] arch      :: $machine_arch  may not be supported${reset}"
            echo -e "${cyan}[*] hint      :: check https://go.dev/dl/ for supported platforms${reset}"
            issues=$((issues + 1))
            ;;
    esac
    echo ""

    # ── 4. Disk space ─────────────────────────────────────────────────────────
    echo -e "${cyan}// ── DISK SPACE ──────────────────────────────────────────────${reset}"
    local avail_kb
    avail_kb=$(df -k "$HOME_DIR" 2>/dev/null | awk 'NR==2{print $4}')
    local required_kb=600000  # ~600 MB minimum for download + extraction
    if [ -n "$avail_kb" ] && [ "$avail_kb" -gt 0 ] 2>/dev/null; then
        local avail_mb=0
        avail_mb=$(( avail_kb / 1024 ))
        if [ "$avail_kb" -ge "$required_kb" ]; then
            echo -e "${green}[+] disk      :: ${avail_mb}MB free${reset}"
        else
            echo -e "${red}[✗] disk      :: ${avail_mb}MB free -- at least 600MB required${reset}"
            issues=$((issues + 1))
        fi
    else
        echo -e "${yellow}[!] disk      :: could not determine available space${reset}"
    fi
    echo ""

    # ── 5. Dependencies ────────────────────────────────────────────────────────
    echo -e "${cyan}// ── DEPENDENCIES ────────────────────────────────────────────${reset}"
    local required_tools=""
    if [ "$OS" != "android" ]; then
        required_tools="curl wget jq"
    else
        required_tools="curl wget"
        echo -e "${cyan}[*] note      :: jq not available on Termux -- version fetching will use curl fallback${reset}"
    fi

    for tool in $required_tools; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${green}[+] $tool$(printf '%*s' $((9 - ${#tool})) ''):: found${reset}"
            log_message "$tool is available"
        elif [ "$OS" = "MacOS" ] && ! command -v brew >/dev/null 2>&1 && ! command -v port >/dev/null 2>&1; then
            echo -e "${red}[✗] $tool$(printf '%*s' $((9 - ${#tool})) ''):: not found -- install manually${reset}"
            echo -e "${cyan}[*] hint      :: install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${reset}"
            echo -e "${cyan}[*] hint      :: then run: brew install $tool${reset}"
            issues=$((issues + 1))
        elif [ "$OS" != "android" ] && ! sudo -v >/dev/null 2>&1; then
            echo -e "${yellow}[!] $tool$(printf '%*s' $((9 - ${#tool})) ''):: not found -- skipping (no sudo)${reset}"
            issues=$((issues + 1))
        else
            echo -e "${yellow}[!] $tool$(printf '%*s' $((9 - ${#tool})) ''):: not found -- installing${reset}"
            log_message "Installing missing dependency: $tool"
            if install_package "$tool"; then
                if command -v "$tool" >/dev/null 2>&1; then
                    echo -e "${green}[+] $tool$(printf '%*s' $((9 - ${#tool})) ''):: installed${reset}"
                    log_message "Successfully installed $tool"
                    installed=$((installed + 1))
                else
                    echo -e "${red}[✗] $tool$(printf '%*s' $((9 - ${#tool})) ''):: installation failed${reset}"
                    log_error "Failed to install $tool"
                    issues=$((issues + 1))
                fi
            else
                echo -e "${red}[✗] $tool$(printf '%*s' $((9 - ${#tool})) ''):: installation failed${reset}"
                log_error "Failed to install $tool"
                issues=$((issues + 1))
            fi
        fi
    done
    echo ""

    # ── 6. Verdict ─────────────────────────────────────────────────────────────
    echo -e "${cyan}// ── SUMMARY ─────────────────────────────────────────────────${reset}"
    if [ "$installed" -gt 0 ]; then
        echo -e "${green}[+] installed :: $installed dependenc$([ "$installed" -eq 1 ] && echo 'y' || echo 'ies')${reset}"
    fi

    if [ "$issues" -eq 0 ]; then
        echo -e "${green}[✓] ready     :: system is ready to install Go${reset}"
        echo -e "${cyan}[*] action    :: sudo ./$(basename "$0")${reset}"
    else
        echo -e "${red}[✗] ready     :: $issues issue$([ "$issues" -eq 1 ] && echo '' || echo 's') found -- resolve above first${reset}"
    fi
    echo ""
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"

    if [ "$issues" -eq 0 ]; then
        safe_exit 0
    else
        safe_exit 1
    fi
}

# Main execution starts here
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    # Initialize core variables early
    initialize_variables

    # Set default log file if none specified but verbose mode is on
    if [ "$VERBOSE" = true ] && [ -z "$LOG_FILE" ]; then
        local log_dir
        if [ "$OS" = "android" ]; then
            log_dir="$HOME"
        elif [ -w "/tmp" ]; then
            log_dir="/tmp"
        else
            log_dir="$HOME_DIR"
        fi
        LOG_FILE="$log_dir/letsgo_install_$(date +%Y%m%d_%H%M%S).log"
        echo -e "${cyan}[*] log       :: $LOG_FILE${reset}"
    fi

    # Handle different modes
    case "$MODE" in
        setup)
            run_setup
            ;;
        uninstall)
            uninstall_go
            ;;
        diagnostic)
            run_diagnostics
            ;;
        install)
            # Continue with installation
            ;;
        *)
            echo -e "${red}[✗] mode      :: unknown: $MODE${reset}"
            safe_exit 1
            ;;
    esac

    # Check for sudo privileges (not needed for Android/Termux)
    check_sudo

    # Print banner
    print_banner

    echo -e "${cyan}// ── INSTALL ─────────────────────────────────────────────────${reset}"

    # Show detected OS after banner with proper spacing
    echo -e "${cyan}[*] platform  :: $OS${reset}"

    # Install the required tools with enhanced validation
    local required_tools=""
    if [ "$OS" != "android" ]; then
        required_tools="curl jq wget"
    else
        required_tools="curl wget"  # jq might not be needed for Android
    fi

    for tool in $required_tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${yellow}[!] $tool$(printf '%*s' $((9 - ${#tool})) ''):: not found -- installing${reset}"
            log_message "Installing missing tool: $tool"
            install_package "$tool"
            if ! command -v "$tool" >/dev/null 2>&1; then
                log_error "Failed to install $tool"
                echo -e "${red}[✗] $tool$(printf '%*s' $((9 - ${#tool})) ''):: installation failed${reset}"
                safe_exit 1
            else
                log_message "Successfully installed $tool"
                echo -e "${green}[+] $tool$(printf '%*s' $((9 - ${#tool})) ''):: installed${reset}"
            fi
        else
            log_message "Tool $tool is already installed"
            if [ "$VERBOSE" = true ]; then
                echo -e "${green}[+] $tool$(printf '%*s' $((9 - ${#tool})) ''):: found${reset}"
            fi
        fi
    done

    echo -e "${cyan}[*] user      :: $REAL_USER${reset}"
    echo -e "${cyan}[*] target    :: $INSTALL_DIR/go${reset}"
    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[*] profile   :: $PROFILE_FILE${reset}"
    fi

    # Check to see what's the latest version of GO (skip for Android since we use pkg)
    if [ "$OS" != "android" ]; then
        if [ -n "$SPECIFIC_VERSION" ]; then
            # Validate and use specific version
            GO_VERSION=$(validate_go_version "$SPECIFIC_VERSION")
            echo -e "${cyan}[*] version   :: specific: $GO_VERSION${reset}"
            log_message "User requested specific version: $GO_VERSION"
        else
            # Get latest version with better error handling
            log_message "Fetching latest Go version from golang.org"
            if command -v jq >/dev/null 2>&1; then
                GO_API_RESPONSE=$(curl -s --max-time 30 "https://go.dev/dl/?mode=json" 2>/dev/null)
                GO_VERSION=$(echo "$GO_API_RESPONSE" | jq -r '.[0].version' 2>/dev/null)
                if [ -z "$GO_VERSION" ] || [ "$GO_VERSION" = "null" ]; then
                    log_error "Failed to fetch latest Go version"
                    echo -e "${red}[✗] version   :: failed to fetch latest -- check your internet connection${reset}"
                    safe_exit 1
                fi
            else
                # Fallback method without jq
                log_message "jq not available, using fallback method"
                GO_VERSION=$(curl -s --max-time 30 https://go.dev/VERSION 2>/dev/null | head -1 | tr -d '\r')
                if [ -z "$GO_VERSION" ]; then
                    log_error "Failed to fetch latest Go version using fallback method"
                    echo -e "${red}[✗] version   :: failed to fetch latest -- install jq or check internet${reset}"
                    safe_exit 1
                fi
            fi
            echo -e "${green}[+] version   :: $GO_VERSION (stable)${reset}"
            log_message "Latest Go version: $GO_VERSION"
        fi
    else
        if [ -n "$SPECIFIC_VERSION" ]; then
            echo -e "${yellow}[!] version   :: --version not supported on Android/Termux${reset}"
            echo -e "${cyan}[*] hint      :: Termux uses package manager -- try: pkg install golang${reset}"
            log_message "Specific version requested on Android - not supported"
        fi
        echo -e "${cyan}[*] install   :: using Termux package manager${reset}"
        log_message "Skipping version check for Android - using pkg"
    fi

    # Check if Go is already installed and up-to-date
    local current_version=""
    local go_installed=false

    echo -e "${cyan}[*] version   :: checking installed Go${reset}"
    if command -v go >/dev/null 2>&1; then
        go_installed=true
        current_version=$(go version 2>/dev/null | awk '{print $3}')
        log_message "Current Go version detected: $current_version"
    fi

    # Handle Android/Termux separately from other systems
    if [ "$OS" = "android" ]; then
        if [ "$go_installed" = true ]; then
            echo -e "${green}[+] go        :: installed via Termux package manager${reset}"
            echo -e "${cyan}[*] version   :: $(go version 2>/dev/null)${reset}"
            echo -e "${yellow}[!] update    :: use: pkg upgrade golang${reset}"

            # Verify and fix environment if needed
            local env_needs_fix=false

            # Check for correct GOROOT pattern
            if [ -f "$PROFILE_FILE" ]; then
                if ! deduplicate_path "GOROOT=\$PREFIX/lib/go" "$PROFILE_FILE" && \
                   ! deduplicate_path "GOROOT \$PREFIX/lib/go" "$PROFILE_FILE"; then
                    env_needs_fix=true
                fi

                # Check for GOPATH
                if ! grep -q "GOPATH.*\$HOME/go" "$PROFILE_FILE" 2>/dev/null; then
                    env_needs_fix=true
                fi
            else
                env_needs_fix=true
            fi

            if [ "$env_needs_fix" = true ]; then
                echo -e "${yellow}[!] env       :: needs configuration -- setting up${reset}"
                log_message "Fixing Android Go environment configuration"

                # Ensure profile file exists
                mkdir -p "$(dirname "$PROFILE_FILE")" 2>/dev/null || true
                touch "$PROFILE_FILE"

                # Clean problematic entries
                if [ -f "$PROFILE_FILE" ]; then
                    portable_sed '/export GOROOT/d' "$PROFILE_FILE"
                    portable_sed '/export GOPATH/d' "$PROFILE_FILE"
                    portable_sed '/export GOBIN/d' "$PROFILE_FILE"
                    portable_sed '/set -x GOROOT/d' "$PROFILE_FILE"
                    portable_sed '/set -x GOPATH/d' "$PROFILE_FILE"
                    portable_sed '/# golang setup/d' "$PROFILE_FILE"
                fi

                # Add correct environment variables
                case "$PROFILE_FILE" in
                    *config.fish*)
                        {
                            echo ""
                            echo "# golang setup for Termux (fish shell)"
                            echo "set -x GOROOT \$PREFIX/lib/go"
                            echo "set -x GOPATH \$HOME/go"
                            echo "fish_add_path \$GOROOT/bin \$GOPATH/bin"
                        } >> "$PROFILE_FILE"
                        ;;
                    *)
                        {
                            echo ""
                            echo "# golang setup for Termux"
                            echo "export GOROOT=\$PREFIX/lib/go"
                            echo "export GOPATH=\$HOME/go"
                            echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin"
                        } >> "$PROFILE_FILE"
                        ;;
                esac

                mkdir -p "$HOME/go/bin" 2>/dev/null || true
                echo -e "${green}[+] env       :: $PROFILE_FILE  patched${reset}"
                echo -e "${yellow}[!] action    :: source $(basename "$PROFILE_FILE")${reset}"
                log_message "Fixed Android Go environment configuration"
            else
                echo -e "${green}[+] env       :: properly configured${reset}"
            fi

            # Skip verification since Go is already installed and working
            success_exit "Go is already installed and properly configured!" "true"
        else
            echo -e "${yellow}[!] go        :: not installed -- installing via Termux package manager${reset}"
            install_go_android
        fi
    else
        # Handle Linux/MacOS version checking
        if [ "$go_installed" = true ]; then
            if [ "$current_version" = "$GO_VERSION" ]; then
                # Skip verification since Go is already working
                echo -e "${green}[+] version   :: $current_version already installed${reset}"
                echo -e "${cyan}[*] hint      :: run: sudo ./$(basename "$0") --version X.X.X to change${reset}"
                success_exit "Go version: $GO_VERSION is already installed" "true"
            else
                if [ -n "$SPECIFIC_VERSION" ]; then
                    echo -e "${yellow}[!] update    :: $current_version -> $GO_VERSION${reset}"
                else
                    echo -e "${yellow}[!] update    :: $current_version -> $GO_VERSION${reset}"
                fi
            fi
        else
            if [ -n "$SPECIFIC_VERSION" ]; then
                echo -e "${yellow}[!] go        :: not installed -- installing requested: $GO_VERSION${reset}"
            else
                echo -e "${yellow}[!] go        :: not installed -- installing latest: $GO_VERSION${reset}"
            fi
        fi

        # Set architecture and download URL for Linux/MacOS
        if [ "$OS" = "linux" ]; then
            # Detect Linux architecture (x86_64, aarch64, etc.)
            local machine_arch
            machine_arch=$(uname -m)
            case $machine_arch in
                x86_64)
                    ARCH="linux-amd64"
                    ;;
                aarch64|arm64)
                    ARCH="linux-arm64"
                    ;;
                armv7l)
                    ARCH="linux-armv6l"
                    ;;
                i386|i686)
                    ARCH="linux-386"
                    ;;
                *)
                    echo -e "${red}[✗] arch      :: unsupported: $machine_arch${reset}"
                    safe_exit 1
                    ;;
            esac

        elif [ "$OS" = "MacOS" ]; then
            # Detect Mac architecture (Intel vs Apple Silicon)
            case "$(uname -m)" in
                arm64)
                    ARCH="darwin-arm64"
                    ;;
                *)

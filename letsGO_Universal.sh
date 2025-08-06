#!/bin/env bash

# This script checks for the presence of jq and curl utilities, prints an ASCII art banner if provided,
# checks if the latest version of Go (Golang) is installed, and if not, downloads and installs it.
# Version 0.13 codename: universal-shell-compatible

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

# Shell capability detection
SHELL_HAS_ARRAYS=false
SHELL_HAS_REGEX=false

# Detect shell capabilities
detect_shell_capabilities() {
    # Test arrays (suppress all output and errors)
    if (
        test_arr=""
        test_arr="$test_arr item1"
        test_arr="$test_arr item2"
        test $test_arr != ""
    ) >/dev/null 2>&1; then
        SHELL_HAS_ARRAYS=false  # We'll use string-based approach for maximum compatibility
    fi
    
    # Test regex
    if [ "$1" = "test" ] 2>/dev/null; then
        case "$1" in
            test) SHELL_HAS_REGEX=true ;;
            *) SHELL_HAS_REGEX=false ;;
        esac
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[LOG] Shell compatibility: Arrays=$SHELL_HAS_ARRAYS, Regex=$SHELL_HAS_REGEX${reset}"
    fi
}

# Enhanced cleanup function - centralized and robust
cleanup() {
    if [ "$CLEANUP_PERFORMED" = true ]; then
        return 0
    fi
    
    if [ -n "$DOWNLOAD_FILE" ] && [ -f "$DOWNLOAD_FILE" ]; then
        log_message "Cleaning up downloaded file: $DOWNLOAD_FILE"
        rm -f "$DOWNLOAD_FILE" 2>/dev/null || true
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
            --diagnose)
                MODE="diagnose"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --log)
                LOG_FILE="$2"
                if [ -z "$LOG_FILE" ]; then
                    echo -e "${red}[✗] --log requires a file path${reset}"
                    safe_exit 1
                fi
                shift 2
                ;;
            --version)
                SPECIFIC_VERSION="$2"
                if [ -z "$SPECIFIC_VERSION" ]; then
                    echo -e "${red}[✗] --version requires a version number (e.g., --version 1.21.0)${reset}"
                    safe_exit 1
                fi
                shift 2
                ;;
            --help|-h)
                show_help
                safe_exit 0
                ;;
            *)
                echo -e "${red}[✗] Unknown option: $1${reset}"
                echo "Use --help for usage information"
                safe_exit 1
                ;;
        esac
    done
}

# Help function
show_help() {
    echo ""
    echo -e "                    ${blue}letsGO Universal Go Installer${reset}"
    echo ""
    echo -e "${blue}---------------------------------  Usage  ---------------------------------${reset}"
    echo ""
    echo -e "${blue}Usage: $0 [OPTIONS]${reset}"
    echo ""
    echo -e "${yellow}Options:${reset}"
    echo "  --uninstall       Completely remove Go installation and clean environment"
    echo "  --diagnose        Check current Go setup health and show system info"
    echo "  --version VERSION Install a specific version of Go (e.g., --version 1.21.0)"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --log FILE        Log installation details to specified file"
    echo "  --help, -h        Show this help message"
    echo ""
    echo -e "${yellow}Examples:${reset}"
    echo "  $0                Install or update to latest Go version"
    echo "  $0 --version 1.20.5    Install Go version 1.20.5"
    echo "  $0 --uninstall    Remove Go completely"
    echo "  $0 --diagnose     Check Go installation health"
    echo "  $0 --verbose      Install with detailed output"
    echo ""
    echo -e "${red}Note: --version flag works only on Linux/MacOS, NOT Android/Termux.${reset} "
    echo ""
    echo -e "${blue}---------------------------------  Usage  ---------------------------------${reset}"
    echo ""
}

# Enhanced logging functions
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[LOG] $message${reset}"
    fi
    
    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${red}[ERROR] $message${reset}"
    
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
        linux-gnu*)
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
        echo -e "${red}[✗] Unsupported operating system: $OSTYPE${reset}"
        safe_exit 1
    fi

    # Set user and directories based on OS
    if [ "$OS" = "android" ]; then
        REAL_USER="$USER"
        HOME_DIR="$HOME"
        INSTALL_DIR="$PREFIX"  # Termux uses $PREFIX instead of /usr/local
        BIN_DIR="$PREFIX/bin"
    elif [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        # Get home directory safely without eval
        HOME_DIR=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        if [ -z "$HOME_DIR" ] || [ ! -d "$HOME_DIR" ]; then
            # Fallback if getent doesn't work
            HOME_DIR="/home/$SUDO_USER"
        fi
        INSTALL_DIR="/usr/local"
        BIN_DIR="/usr/local/bin"
    else
        REAL_USER="$USER"
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
    echo -e "${blue}-----------------------------------------------------------------${reset}"
    echo ""
    echo -e "${blue}[i] Let'sGO Now with 10% more GO than the leading brand.${reset}"
    echo -e "${blue}[i] Version 0.13 codename: universal-shell-compatible${reset}"
    echo -e "${blue}[i] By Darkcast (Android support added, universal compatibility)${reset}"
    echo -e "${blue}[i] Git https://github.com/Darkcast/letsGO${reset}"
    echo ""
    echo -e "${blue}-----------------------------------------------------------------${reset}"
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
            echo -e "${red}[✗] Invalid Go version format: $version${reset}"
            echo -e "${cyan}[i] Expected format: 1.21.0 or go1.21.0${reset}"
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
    echo -e "${blue}[i] Checking if Go version $version is available for $arch...${reset}"
    
    # Use HEAD request to check if file exists
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --head "$download_url" 2>/dev/null)
    
    # Accept successful responses AND redirects as valid (CDNs commonly use redirects)
    case "$response_code" in
        200|301|302)
            log_message "Version $version is available for $arch (HTTP $response_code)"
            echo -e "${green}[✓] Go version $version is available for $arch${reset}"
            return 0
            ;;
        *)
            log_error "Version $version is not available for $arch (HTTP $response_code)"
            echo -e "${red}[✗] Go version $version is not available for $arch${reset}"
            echo -e "${cyan}[i] Check available versions at: https://go.dev/dl/${reset}"
            return 1
            ;;
    esac
}

# Check for sudo privileges (not needed for Android/Termux)
check_sudo() {
    if [ "$OS" = "linux" ] || ([ "$OS" = "MacOS" ] && ! command -v brew >/dev/null 2>&1); then
        if ! sudo -v >/dev/null 2>&1; then
            echo -e "${red}[✗] This script requires sudo privileges. Please run as 'sudo ./letsGO.sh'${reset}"
            safe_exit 1
        fi
    elif [ "$OS" = "android" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "${blue}[i] Running on Android/Termux - no sudo required${reset}"
        fi
    fi
}

# Enhanced package installation function
install_package() {
    local package="$1"
    
    echo -e "${yellow}[!] Installing $package...${reset}"
    log_message "Installing package: $package"
    
    if [ "$OS" = "android" ]; then
        if command -v pkg >/dev/null 2>&1; then
            if pkg install -y "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via pkg"
                return 0
            else
                log_error "Failed to install $package via pkg"
                echo -e "${red}[✗] Failed to install $package. Please try manually: pkg install $package${reset}"
                safe_exit 1
            fi
        else
            echo -e "${red}[✗] pkg (Termux package manager) not found. Please install $package manually using 'pkg install $package'.${reset}"
            safe_exit 1
        fi
    elif [ "$OS" = "linux" ]; then
        local package_manager=""
        local install_cmd=""
        
        if command -v apt-get >/dev/null 2>&1; then
            package_manager="apt-get"
            install_cmd="sudo apt-get update && sudo apt-get install -y $package"
        elif command -v yum >/dev/null 2>&1; then
            package_manager="yum"
            install_cmd="sudo yum install -y $package"
        elif command -v dnf >/dev/null 2>&1; then
            package_manager="dnf"
            install_cmd="sudo dnf install -y $package"
        elif command -v apk >/dev/null 2>&1; then
            package_manager="apk"
            install_cmd="sudo apk add $package"
        else
            echo -e "${red}[✗] No supported package manager found. Please install $package manually.${reset}"
            safe_exit 1
        fi
        
        log_message "Using $package_manager to install $package"
        if eval "$install_cmd" >/dev/null 2>&1; then
            log_message "Successfully installed $package via $package_manager"
            return 0
        else
            log_error "Failed to install $package via $package_manager"
            echo -e "${red}[✗] Failed to install $package. Please install it manually.${reset}"
            safe_exit 1
        fi
    elif [ "$OS" = "MacOS" ]; then
        if command -v brew >/dev/null 2>&1; then
            if brew install "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via brew"
                return 0
            else
                log_error "Failed to install $package via brew"
            fi
        elif command -v port >/dev/null 2>&1; then
            if sudo port install "$package" >/dev/null 2>&1; then
                log_message "Successfully installed $package via port"
                return 0
            else
                log_error "Failed to install $package via port"
            fi
        fi
        
        echo -e "${red}[✗] Package manager not found. Please install Homebrew or MacPorts, or install $package manually.${reset}"
        safe_exit 1
    fi
}

# Enhanced system information collection
collect_system_info() {
    log_message "Collecting system information"
    
    echo -e "${blue}=== System Information ===${reset}"
    echo -e "${cyan}OS Type:${reset} $OSTYPE"
    echo -e "${cyan}Detected OS:${reset} $OS"
    echo -e "${cyan}Architecture:${reset} $(uname -m)"
    echo -e "${cyan}Kernel:${reset} $(uname -r)"
    
    if [ "$OS" = "android" ]; then
        echo -e "${cyan}Termux Version:${reset} $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
        echo -e "${cyan}PREFIX:${reset} $PREFIX"
        
        # Android architecture detection
        local android_arch
        android_arch=$(uname -m)
        echo -e "${cyan}Android Architecture:${reset} $android_arch"
        
        # Validate architecture support
        case "$android_arch" in
            aarch64|arm64)
                echo -e "${green}[✓] Architecture supported: ARM64${reset}"
                ;;
            armv7l|armv8l)
                echo -e "${green}[✓] Architecture supported: ARM32${reset}"
                ;;
            x86_64)
                echo -e "${green}[✓] Architecture supported: x86_64${reset}"
                ;;
            i686|i386)
                echo -e "${yellow}[!] Architecture may have limited support: x86_32${reset}"
                ;;
            *)
                echo -e "${yellow}[!] Unknown architecture: $android_arch${reset}"
                ;;
        esac
    fi
    
    echo -e "${cyan}User:${reset} $REAL_USER"
    echo -e "${cyan}Home Directory:${reset} $HOME_DIR"
    echo -e "${cyan}Current Shell:${reset} $(basename "$SHELL")"
    echo -e "${cyan}Profile File:${reset} $PROFILE_FILE"
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}PATH:${reset} $PATH"
    fi
    echo ""
    
    # Go-specific information
    echo -e "${blue}=== Go Environment ===${reset}"
    if command -v go >/dev/null 2>&1; then
        echo -e "${cyan}Go Version:${reset} $(go version 2>/dev/null)"
        echo -e "${cyan}Go Location:${reset} $(which go 2>/dev/null)"
        echo -e "${cyan}GOROOT:${reset} $(go env GOROOT 2>/dev/null)"
        echo -e "${cyan}GOPATH:${reset} $(go env GOPATH 2>/dev/null)"
        echo -e "${cyan}GOOS:${reset} $(go env GOOS 2>/dev/null)"
        echo -e "${cyan}GOARCH:${reset} $(go env GOARCH 2>/dev/null)"
    else
        echo -e "${yellow}Go is not installed or not in PATH${reset}"
    fi
    echo ""
}

# Enhanced diagnostic mode function using string operations
run_diagnostics() {
    echo -e "${purple}=== Go Installation Diagnostics ===${reset}"
    echo ""
    
    collect_system_info
    
    # Check for conflicts using string operations
    echo -e "${blue}=== Potential Issues ===${reset}"
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
        echo -e "${yellow}[!] Multiple Go installations found:${reset}"
        for loc in $go_locations; do
            [ -n "$loc" ] && echo -e "    $loc"
        done
        issues_found=true
    fi
    
    # Check for broken symlinks
    local bin_paths="$PREFIX/bin/go $BIN_DIR/go /usr/local/bin/go"
    for bin_path in $bin_paths; do
        if [ -L "$bin_path" ] && [ ! -e "$bin_path" ]; then
            echo -e "${yellow}[!] Broken symlink: $bin_path${reset}"
            issues_found=true
        fi
    done
    
    # Fixed: Improved GOROOT/binary relationship check
    if command -v go >/dev/null 2>&1; then
        local go_which=$(which go 2>/dev/null)
        local go_root=$(go env GOROOT 2>/dev/null)
        
        if [ -n "$go_root" ] && [ ! -d "$go_root" ]; then
            echo -e "${yellow}[!] GOROOT points to non-existent directory: $go_root${reset}"
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
                    echo -e "${yellow}[!] Go binary and GOROOT mismatch:${reset}"
                    echo -e "    Binary: $go_which"
                    if [ "$resolved_go_binary" != "$go_which" ]; then
                        echo -e "    Resolved: $resolved_go_binary"
                    fi
                    echo -e "    GOROOT: $go_root"
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
            echo -e "${yellow}[!] Multiple Go environment variable declarations in $PROFILE_FILE${reset}"
            issues_found=true
        fi
    fi
    
    # Additional helpful checks
    if command -v go >/dev/null 2>&1; then
        local gopath_dir=$(go env GOPATH 2>/dev/null)
        if [ -n "$gopath_dir" ] && [ ! -d "$gopath_dir" ]; then
            echo -e "${yellow}[!] GOPATH directory does not exist: $gopath_dir${reset}"
            echo -e "${cyan}[i] Run: mkdir -p $gopath_dir${reset}"
            issues_found=true
        fi
    fi
    
    if [ "$issues_found" = false ]; then
        echo -e "${green}[✓] No issues detected - Go installation is healthy!${reset}"
    fi
    
    echo ""
    echo -e "${blue}=== Recommendations ===${reset}"
    if command -v go >/dev/null 2>&1; then
        echo -e "${green}[✓] Go is installed and accessible${reset}"
        echo -e "${cyan}Try: go version${reset}"
        echo -e "${cyan}Try: go env${reset}"
        echo -e "${cyan}Try: go env GOPATH && ls \$(go env GOPATH)${reset}"
    else
        echo -e "${yellow}[!] Go is not installed or not in PATH${reset}"
        echo -e "${cyan}Run: $0 --verbose${reset} to install"
    fi
    
    safe_exit 0
}

# Enhanced backup function
create_backup() {
    local backup_dir="$HOME_DIR/.letsgo_backups/$(date +%Y%m%d_%H%M%S)"
    log_message "Creating backup in: $backup_dir"
    
    mkdir -p "$backup_dir" 2>/dev/null || {
        log_error "Failed to create backup directory: $backup_dir"
        echo -e "${yellow}[!] Warning: Could not create backup directory${reset}"
        return 1
    }
    
    # Backup existing Go installation
    if [ -d "/usr/local/go" ]; then
        log_message "Backing up /usr/local/go"
        cp -r "/usr/local/go" "$backup_dir/go_installation" 2>/dev/null || true
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
    echo -e "${green}[✓] Backup created at: $backup_dir${reset}"
    return 0
}

# Enhanced uninstall function
uninstall_go() {
    echo -e "${yellow}=== Go Uninstallation ===${reset}"
    echo ""
    
    # Collect info before uninstalling
    if command -v go >/dev/null 2>&1; then
        echo -e "${blue}Current Go installation:${reset}"
        echo -e "Version: $(go version 2>/dev/null)"
        echo -e "Location: $(which go 2>/dev/null)"
        echo -e "GOROOT: $(go env GOROOT 2>/dev/null)"
        echo ""
    fi
    
    # Create backup before uninstalling
    create_backup
    
    echo -e "${yellow}[!] Starting Go removal...${reset}"
    log_message "Starting Go uninstallation"
    
    # Remove Go installations
    if [ "$OS" = "android" ]; then
        # Termux uninstallation
        log_message "Removing Go via pkg"
        if command -v go >/dev/null 2>&1; then
            if pkg uninstall golang -y >/dev/null 2>&1; then
                echo -e "${green}[✓] Removed Go via pkg${reset}"
                log_message "Successfully removed Go via pkg"
            else
                echo -e "${yellow}[!] Failed to remove via pkg, continuing with manual cleanup${reset}"
                log_message "Failed to remove Go via pkg, performing manual cleanup"
            fi
        fi
        
        # Manual cleanup for Termux
        rm -rf "$PREFIX/go" 2>/dev/null
        rm -f "$PREFIX/bin/go" "$PREFIX/bin/gofmt" 2>/dev/null
        log_message "Cleaned up Termux Go files"
        
    else
        # Linux/MacOS uninstallation
        if [ -d "/usr/local/go" ]; then
            echo -e "${yellow}[!] Removing /usr/local/go${reset}"
            if sudo rm -rf "/usr/local/go" 2>/dev/null; then
                log_message "Removed /usr/local/go"
                echo -e "${green}[✓] Removed /usr/local/go${reset}"
            else
                log_error "Failed to remove /usr/local/go"
                echo -e "${red}[✗] Failed to remove /usr/local/go${reset}"
            fi
        fi
        
        # Remove symlinks
        sudo rm -f "/usr/local/bin/go" "/usr/local/bin/gofmt" 2>/dev/null
        log_message "Removed Go symlinks"
    fi
    
    # Enhanced environment cleanup using string list - FIXED to remove PATH lines
    echo -e "${yellow}[!] Cleaning up environment variables${reset}"
    local profiles="$HOME_DIR/.bashrc $HOME_DIR/.bash_profile $HOME_DIR/.zshrc $HOME_DIR/.profile"
    
    for profile in $profiles; do
        if [ -f "$profile" ]; then
            log_message "Cleaning Go config from $profile"
            
            # Remove Go-related lines using portable sed
            portable_sed '/# golang setup/d' "$profile"
            portable_sed '/export GOROOT/d' "$profile"
            portable_sed '/export GOPATH/d' "$profile"
            portable_sed '/export GOBIN/d' "$profile"
            
            # FIX: Remove PATH lines that reference Go variables
            portable_sed '/export PATH.*GOROOT/d' "$profile"
            portable_sed '/export PATH.*GOPATH/d' "$profile"
            portable_sed '/export PATH.*\/go\/bin/d' "$profile"
            portable_sed '/export PATH.*\/usr\/local\/go/d' "$profile"
            
            # Fish shell cleanup
            portable_sed '/set -x GOROOT/d' "$profile"
            portable_sed '/set -x GOPATH/d' "$profile"
            portable_sed '/set -x PATH.*GOROOT/d' "$profile"
            portable_sed '/set -x PATH.*GOPATH/d' "$profile"
            portable_sed '/set -x PATH.*\/go\/bin/d' "$profile"
        fi
    done
    
    # Special handling for fish shell
    if [ -f "$HOME_DIR/.config/fish/config.fish" ]; then
        log_message "Cleaning Go config from fish shell"
        portable_sed '/set -x GOROOT/d' "$HOME_DIR/.config/fish/config.fish"
        portable_sed '/set -x GOPATH/d' "$HOME_DIR/.config/fish/config.fish"
        portable_sed '/set -x PATH.*GOROOT/d' "$HOME_DIR/.config/fish/config.fish"
        portable_sed '/set -x PATH.*GOPATH/d' "$HOME_DIR/.config/fish/config.fish"
        portable_sed '/set -x PATH.*\/go\/bin/d' "$HOME_DIR/.config/fish/config.fish"
        portable_sed '/# golang setup/d' "$HOME_DIR/.config/fish/config.fish"
    fi
    
    # Remove any remaining orphaned Go-related lines (comprehensive cleanup)
    for profile in $profiles; do
        if [ -f "$profile" ]; then
            # Remove any lines containing common Go paths
            portable_sed '/.*\/usr\/local\/go\/bin/d' "$profile"
            portable_sed '/.*\$HOME\/go\/bin/d' "$profile"
            portable_sed '/.*\${HOME}\/go\/bin/d' "$profile"
            
            # Remove empty lines that might be left behind (optional)
            # portable_sed '/^[[:space:]]*$/d' "$profile"
        fi
    done
    
    # Remove GOPATH directory (ask user first)
    if [ -d "$HOME_DIR/go" ]; then
        echo ""
        echo -e "${yellow}[?] Remove GOPATH directory ($HOME_DIR/go) and all Go packages?${reset}"
        echo -e "${cyan}    This will delete all your Go projects and installed packages${reset}"
        printf "Remove GOPATH? (y/N): "
        read -r reply
        case "$reply" in
            [Yy]|[Yy][Ee][Ss])
                if rm -rf "$HOME_DIR/go" 2>/dev/null; then
                    log_message "Removed GOPATH directory"
                    echo -e "${green}[✓] Removed GOPATH directory${reset}"
                else
                    log_error "Failed to remove GOPATH directory"
                    echo -e "${red}[✗] Failed to remove GOPATH directory${reset}"
                fi
                ;;
            *)
                echo -e "${blue}[i] Keeping GOPATH directory${reset}"
                ;;
        esac
    fi
    
    echo ""
    echo -e "${green}[✓] Go uninstallation completed!${reset}"
    if [ -f "$HOME_DIR/.letsgo_last_backup" ]; then
        echo -e "${cyan}[i] Backup saved at: $(cat "$HOME_DIR/.letsgo_last_backup" 2>/dev/null)${reset}"
    fi
    echo -e "${yellow}[!] Please restart your terminal or source your profile to update your environment${reset}"
    
    log_message "Go uninstallation completed successfully"
    safe_exit 0
}


# Enhanced Go installation verification
verify_go_installation() {
    local max_attempts=3
    local attempt=1
    
    echo -e "${blue}[i] Verifying Go installation...${reset}"
    log_message "Starting Go installation verification"
    
    while [ $attempt -le $max_attempts ]; do
        log_message "Verification attempt $attempt of $max_attempts"
        
        # For fish shell, we can't source in bash, so skip sourcing
        case "$PROFILE_FILE" in
            *config.fish*)
                # Skip sourcing for fish shell
                ;;
            *)
                if [ -f "$PROFILE_FILE" ]; then
                    # Source the profile to get updated PATH
                    # Disable exit on error temporarily
                    set +e
                    . "$PROFILE_FILE" >/dev/null 2>&1 || true
                    set -e
                fi
                ;;
        esac
        
        # Check if go command is available
        if command -v go >/dev/null 2>&1; then
            local go_version_output
            go_version_output=$(go version 2>&1)
            local go_version_exit_code=$?
            
            if [ $go_version_exit_code -eq 0 ]; then
                echo -e "${green}[✓] Go verification successful!${reset}"
                echo -e "${cyan}[i] $go_version_output${reset}"
                log_message "Go verification successful: $go_version_output"
                
                # Additional verification - check GOROOT
                local goroot_output
                goroot_output=$(go env GOROOT 2>&1)
                if [ $? -eq 0 ]; then
                    echo -e "${cyan}[i] GOROOT: $goroot_output${reset}"
                    log_message "GOROOT verification: $goroot_output"
                else
                    echo -e "${yellow}[!] Warning: Could not verify GOROOT${reset}"
                fi
                
                return 0
            else
                log_message "Go version command failed: $go_version_output"
                echo -e "${yellow}[!] Go version command failed (attempt $attempt): $go_version_output${reset}"
            fi
        else
            log_message "Go command not found in PATH (attempt $attempt)"
            echo -e "${yellow}[!] Go command not found in PATH (attempt $attempt)${reset}"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${blue}[i] Waiting 2 seconds before retry...${reset}"
            sleep 2
        fi
        
        attempt=$((attempt + 1))
    done
    
    # If we get here, verification failed
    log_error "Go installation verification failed after $max_attempts attempts"
    echo -e "${red}[✗] Go installation verification failed after $max_attempts attempts${reset}"
    echo -e "${yellow}[!] Go may be installed but not accessible in current session${reset}"
    echo -e "${yellow}[!] Try: source $(basename "$PROFILE_FILE") && go version${reset}"
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
    
    echo -e "${green}[✓] $message${reset}"
    echo    ""
    echo -e "${green}------------------------------------------------------------------------${reset}"
    echo -e "${green}[i] Enjoyed this? Help others discover it by sharing on social media! 💖${reset}"
    echo -e "${green}------------------------------------------------------------------------${reset}"
    echo    ""
    safe_exit 0
}

# Enhanced Android Go installation
install_go_android() {
    echo -e "${yellow}[!] Installing Go using Termux package manager (pkg)...${reset}"
    log_message "Starting Android Go installation"
    
    # Enhanced detection of problematic installations
    local cleanup_needed=false
    
    # Check for broken manual Go installation in $PREFIX/go
    if [ -d "$PREFIX/go" ]; then
        echo -e "${yellow}[!] Found previous manual Go installation in $PREFIX/go${reset}"
        cleanup_needed=true
    fi
    
    # Check for broken symlinks
    if [ -L "$PREFIX/bin/go" ] && [ ! -e "$PREFIX/bin/go" ]; then
        echo -e "${yellow}[!] Found broken Go symlink in $PREFIX/bin/go${reset}"
        cleanup_needed=true
    fi
    
    # Check for problematic GOROOT in profile
    if [ -f "$PROFILE_FILE" ] && grep -q "export GOROOT" "$PROFILE_FILE" 2>/dev/null; then
        if ! grep -q "GOROOT.*\$PREFIX/lib/go" "$PROFILE_FILE" 2>/dev/null; then
            echo -e "${yellow}[!] Found incorrect GOROOT configuration in $PROFILE_FILE${reset}"
            cleanup_needed=true
        fi
    fi
    
    # Clean up if issues were detected
    if [ "$cleanup_needed" = true ]; then
        echo -e "${yellow}[!] Cleaning up previous broken installations...${reset}"
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
        echo -e "${green}[✓] Cleanup completed${reset}"
    fi
    
    # Install Go via pkg
    echo -e "${blue}[i] Installing Go via pkg...${reset}"
    log_message "Installing Go via Termux pkg"
    if pkg install golang -y >/dev/null 2>&1; then
        echo -e "${green}[✓] Go successfully installed via pkg!${reset}"
        log_message "Successfully installed Go via pkg"
        
        # Set up correct environment variables for Termux
        echo -e "${blue}[i] Setting up Go environment variables for Termux...${reset}"
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
                        echo "set -x PATH \$PATH \$GOROOT/bin \$GOPATH/bin"
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
            
            echo -e "${green}[✓] Go environment variables configured for Termux${reset}"
            log_message "Environment variables added to $PROFILE_FILE"
        else
            echo -e "${green}[✓] Go environment variables already configured${reset}"
            log_message "Environment variables already present in $PROFILE_FILE"
        fi
        
        # Create GOPATH directory
        mkdir -p "$HOME/go/bin" 2>/dev/null || true
        log_message "Created GOPATH directory: $HOME/go/bin"
        
        echo -e "${green}[✓] Installation complete!${reset}"
        echo -e "${yellow}[!] Please run 'source $(basename "$PROFILE_FILE")' or restart Termux to update your PATH.${reset}"
        echo -e "${green}[✓] Then run 'go version' to verify installation.${reset}"
        
        # Success exit with cleanup and social message
        log_message "Android Go installation completed successfully"
        success_exit "Android Go installation completed successfully!"
    else
        log_error "Failed to install Go via pkg"
        echo -e "${red}[✗] Failed to install Go via pkg.${reset}"
        echo -e "${red}[✗] Please try manually: pkg install golang${reset}"
        safe_exit 1
    fi
}

# Enhanced Linux/MacOS manual Go installation
install_go_manual() {
    # Check if the requested version is available
    if ! check_version_availability "$GO_VERSION" "$ARCH"; then
        echo -e "${red}[✗] Cannot proceed with unavailable version${reset}"
        safe_exit 1
    fi
    
    echo -e "${green}[✓] Downloading and installing Go-lang version: $GO_VERSION for $ARCH${reset}"
    log_message "Starting manual installation for $OS with architecture $ARCH"
    
    # Create backup before installation
    if command -v go >/dev/null 2>&1; then
        create_backup
    fi
    
    # Set download file for cleanup
    DOWNLOAD_FILE="${GO_VERSION}.${ARCH}.tar.gz"
    log_message "Download file: $DOWNLOAD_FILE"
    
    # Download Go
    echo -e "${blue}[i] Downloading Go binary...${reset}"
    if ! wget -q "https://go.dev/dl/$DOWNLOAD_FILE"; then
        log_error "Failed to download Go version $GO_VERSION"
        echo -e "${red}[✗] Failed to download Go-lang version: $GO_VERSION${reset}"
        safe_exit 1
    fi
    log_message "Successfully downloaded Go binary"
    
    # Verify download
    if [ ! -f "$DOWNLOAD_FILE" ] || [ ! -s "$DOWNLOAD_FILE" ]; then
        log_error "Downloaded file is missing or empty"
        echo -e "${red}[✗] Downloaded file is corrupt or missing${reset}"
        safe_exit 1
    fi
    
    # Remove existing Go installation if it exists
    local go_install_path="$INSTALL_DIR/go"
    if [ -d "$go_install_path" ]; then
        echo -e "${yellow}[!] Removing existing Go installation${reset}"
        if sudo rm -rf "$go_install_path" 2>/dev/null; then
            log_message "Removed existing Go installation"
        else
            log_error "Failed to remove existing Go installation"
            echo -e "${red}[✗] Failed to remove existing Go installation${reset}"
            safe_exit 1
        fi
    fi
    
    # Extract Go
    echo -e "${blue}[i] Extracting Go binary...${reset}"
    if ! sudo tar -C "$INSTALL_DIR" -xzf "$DOWNLOAD_FILE" >/dev/null 2>&1; then
        log_error "Failed to extract Go version $GO_VERSION"
        echo -e "${red}[✗] Failed to extract Go-lang version: $GO_VERSION${reset}"
        safe_exit 1
    fi
    log_message "Successfully extracted Go binary"
    
    # Ensure bin directory exists
    sudo mkdir -p "$BIN_DIR" 2>/dev/null || true
    
    # Create symbolic links
    local symlink_path="$BIN_DIR/go"
    if sudo ln -sf "$go_install_path/bin/go" "$symlink_path" 2>/dev/null; then
        echo -e "${green}[✓] Created symbolic link for Go in $symlink_path${reset}"
        log_message "Created Go symlink"
    else
        echo -e "${yellow}[!] Failed to create symbolic link for Go in $symlink_path. Go is still installed in $go_install_path/bin/${reset}"
        log_message "Failed to create Go symlink, but installation continues"
    fi
    
    # Also create symlink for gofmt
    if sudo ln -sf "$go_install_path/bin/gofmt" "$BIN_DIR/gofmt" 2>/dev/null; then
        log_message "Created gofmt symlink"
    else
        echo -e "${yellow}[!] Failed to create symbolic link for gofmt${reset}"
        log_message "Failed to create gofmt symlink"
    fi
    
    echo -e "${green}[✓] Go-lang successfully installed.${reset}"

    # Add Go to the PATH environment variable for the REAL user
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
        
        echo -e "${green}[✓] Added Go to PATH in $(basename "$PROFILE_FILE") for user $REAL_USER${reset}"
        log_message "Added Go environment variables to $PROFILE_FILE"
    else
        echo -e "${green}[✓] Go is already in the PATH in $(basename "$PROFILE_FILE")${reset}"
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
}

# Main execution starts here
main() {
    # Detect shell capabilities early
    detect_shell_capabilities
    
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
        echo -e "${cyan}[i] Logging to: $LOG_FILE${reset}"
    fi
    
    # Handle different modes
    case "$MODE" in
        uninstall)
            uninstall_go
            ;;
        diagnose)
            run_diagnostics
            ;;
        install)
            # Continue with installation
            ;;
        *)
            echo -e "${red}[✗] Unknown mode: $MODE${reset}"
            safe_exit 1
            ;;
    esac
    
    # Check for sudo privileges (not needed for Android/Termux)
    check_sudo
    
    #print ascii art 
    # put ascii art here

    # Print banner
    print_banner
    
    # Show detected OS after banner with proper spacing
    echo -e "${blue}[i] Detected OS: $OS${reset}"
    
    # Install the required tools with enhanced validation
    local required_tools=""
    if [ "$OS" != "android" ]; then
        required_tools="curl jq wget"
    else
        required_tools="curl wget"  # jq might not be needed for Android
    fi
    
    for tool in $required_tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${yellow}[!] $tool is not installed. Attempting to install...${reset}"
            log_message "Installing missing tool: $tool"
            install_package "$tool"
            if ! command -v "$tool" >/dev/null 2>&1; then
                log_error "Failed to install $tool"
                echo -e "${red}[✗] Failed to install $tool. Please install it manually.${reset}"
                safe_exit 1
            else
                log_message "Successfully installed $tool"
                echo -e "${green}[✓] Successfully installed $tool${reset}"
            fi
        else
            log_message "Tool $tool is already installed"
            if [ "$VERBOSE" = true ]; then
                echo -e "${green}[✓] $tool is available${reset}"
            fi
        fi
    done
    
    echo -e "${blue}[i] Installing for user: $REAL_USER${reset}"
    echo -e "${blue}[i] User home directory: $HOME_DIR${reset}"
    echo -e "${blue}[i] Install directory: $INSTALL_DIR${reset}"
    if [ "$VERBOSE" = true ]; then
        echo -e "${cyan}[i] Profile file: $PROFILE_FILE${reset}"
    fi
    
    # Check to see what's the latest version of GO (skip for Android since we use pkg)
    if [ "$OS" != "android" ]; then
        if [ -n "$SPECIFIC_VERSION" ]; then
            # Validate and use specific version
            GO_VERSION=$(validate_go_version "$SPECIFIC_VERSION")
            echo -e "${blue}[i] Installing specific Go version: $GO_VERSION${reset}"
            log_message "User requested specific version: $GO_VERSION"
        else
            # Get latest version with better error handling
            log_message "Fetching latest Go version from golang.org"
            if command -v jq >/dev/null 2>&1; then
                GO_VERSION=$(curl -s --max-time 30 https://go.dev/dl/?mode=json 2>/dev/null | jq -r '.[0].version' 2>/dev/null)
                if [ -z "$GO_VERSION" ] || [ "$GO_VERSION" = "null" ]; then
                    log_error "Failed to fetch latest Go version"
                    echo -e "${red}[✗] Failed to fetch latest Go version. Please check your internet connection.${reset}"
                    safe_exit 1
                fi
            else
                # Fallback method without jq
                log_message "jq not available, using fallback method"
                GO_VERSION=$(curl -s --max-time 30 https://go.dev/VERSION 2>/dev/null | head -1)
                if [ -z "$GO_VERSION" ]; then
                    log_error "Failed to fetch latest Go version using fallback method"
                    echo -e "${red}[✗] Failed to fetch latest Go version. Please install jq or check your internet connection.${reset}"
                    safe_exit 1
                fi
            fi
            echo -e "${blue}[i] Latest Go version available: $GO_VERSION${reset}"
            log_message "Latest Go version: $GO_VERSION"
        fi
    else
        if [ -n "$SPECIFIC_VERSION" ]; then
            echo -e "${yellow}[!] Warning: --version flag is not supported on Android/Termux${reset}"
            echo -e "${cyan}[i] Termux uses package manager versions. Use 'pkg install golang' for available version${reset}"
            log_message "Specific version requested on Android - not supported"
        fi
        echo -e "${blue}[i] Using Termux package manager for Go installation${reset}"
        log_message "Skipping version check for Android - using pkg"
    fi
    
    # Check if Go is already installed and up-to-date
    local current_version=""
    local go_installed=false
    
    if command -v go >/dev/null 2>&1; then
        go_installed=true
        current_version=$(go version 2>/dev/null | awk '{print $3}')
        log_message "Current Go version detected: $current_version"
    fi
    
    # Handle Android/Termux separately from other systems
    if [ "$OS" = "android" ]; then
        if [ "$go_installed" = true ]; then
            echo -e "${green}[✓] Go is installed via Termux package manager 🎉${reset}"
            echo -e "${blue}[i] Termux version: $(go version 2>/dev/null)${reset}"
            echo -e "${yellow}[!] To update Go on Termux, use: pkg upgrade golang${reset}"
            
            # Verify and fix environment if needed
            local env_needs_fix=false
            
            # Check for correct GOROOT pattern
            if [ -f "$PROFILE_FILE" ]; then
                if ! grep -q "GOROOT.*\$PREFIX/lib/go" "$PROFILE_FILE" 2>/dev/null; then
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
                echo -e "${yellow}[!] Go environment variables need configuration. Setting up...${reset}"
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
                            echo "set -x PATH \$PATH \$GOROOT/bin \$GOPATH/bin"
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
                echo -e "${green}[✓] Go environment variables configured for Termux${reset}"
                echo -e "${yellow}[!] Please run 'source $(basename "$PROFILE_FILE")' to update your environment${reset}"
                log_message "Fixed Android Go environment configuration"
            else
                echo -e "${green}[✓] Go environment is properly configured${reset}"
            fi
            
            # Skip verification since Go is already installed and working
            success_exit "Go is already installed and properly configured!" "true"
        else
            echo -e "${yellow}[yikes bro] Go is not installed. Installing via Termux package manager${reset}"
            install_go_android
        fi
    else
        # Handle Linux/MacOS version checking
        if [ "$go_installed" = true ]; then
            if [ "$current_version" = "$GO_VERSION" ]; then
                # Skip verification since Go is already working
                success_exit "Go version: $GO_VERSION is already installed 🎉" "true"
            else
                if [ -n "$SPECIFIC_VERSION" ]; then
                    echo -e "${yellow}[yikes bro] Current version: $current_version, installing requested version: $GO_VERSION${reset}"
                else
                    echo -e "${yellow}[yikes bro] Updating Go from version: $current_version to version: $GO_VERSION${reset}"
                fi
            fi
        else
            if [ -n "$SPECIFIC_VERSION" ]; then
                echo -e "${yellow}[yikes bro] Go is not installed. Installing requested version: $GO_VERSION${reset}"
            else
                echo -e "${yellow}[yikes bro] Go is not installed. Installing latest version: $GO_VERSION${reset}"
            fi
        fi
        
        # Set architecture and download URL for Linux/MacOS
        if [ "$OS" = "linux" ]; then
            # Detect Linux architecture (x86_64, aarch64, etc.)
            local machine_arch=$(uname -m)
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
                    echo -e "${red}[✗] Unsupported architecture: $machine_arch${reset}"
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
                    ARCH="darwin-amd64"
                    ;;
            esac
        fi
        
        log_message "Detected architecture: $ARCH"
        
        # Proceed with manual installation
        install_go_manual
    fi
    
    # Final instructions based on OS
    echo ""
    case "$OS" in
        android)
            echo -e "${yellow}[!] Please run 'source $(basename "$PROFILE_FILE")' or restart Termux to update your PATH.${reset}"
            ;;
        linux)
            echo -e "${yellow}[!] Please run 'source $(basename "$PROFILE_FILE")' or log out and back in to update your PATH.${reset}"
            ;;
        MacOS)
            echo -e "${yellow}[!] Please run 'source $(basename "$PROFILE_FILE")' or restart your terminal to update your PATH.${reset}"
            ;;
    esac
    
    success_exit
}

# Call main function with all arguments
main "$@"

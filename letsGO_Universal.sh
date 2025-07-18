#!/bin/bash

# This script checks for the presence of jq and curl utilities, prints an ASCII art banner if provided,
# checks if the latest version of Go (Golang) is installed, and if not, downloads and installs it.
# Version 0.09 codename: cross-platform-universal

# ANSI Colors
red='\033[1;31m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'
blue='\033[38;5;87m'

# Encoded ASCII art 
encoded_art="ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAuLiAgLi46Oi09PSsrKysrKz09PS0tOjouLi4uLi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAuLi4uOi09KysrKysrKz09LS0tOjo6Ojo6Oi0tLS09PSsrKysrKystOi4uLi4uICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAuLSsrKz09LS06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi09KysqPTouICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgIC4uLj0qKz0tOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotPSsrLS4uIC4uLjo6OjouLi4gICAgICAgICAKICAgICAgICAuLi46LS0tOi4gIC4uPSorLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6LT0rKioqKioqPS06Ojo6Oi09Kj09Kis9PT0tPT09Kis6Li4gICAgIAogICAgIC4uKyo9PS0tLS09PSsqKistOjo6Oi09KiMrPS0tPSsqKj0tOjo6Ojo6Ojo6Ojo6Ojo6Ojo9Iz06Oi4uLi4uLi4uOj0jPTo6Ojo6LSoqLTo6Ojo6Ojo6LSsrOi4uICAgCiAgIC4uKystOjo6Ojo6OjotKistOjo6LSorLTouLi4uLi4uLi4uOi0qKy06Ojo6Ojo6Ojo6Oi0jPTouLi4uOiolJSMtLi4uLi46Kis6Ojo6Oi0qKy0tOjo6Ojo6Oi0qLS4gICAKICAuOio9Ojo6Ojo6Ojo6KyotOjo6LSo9Li4uLiAuLiolQEAlPS4uIC4uKys6Ojo6Ojo6OjorKy4uLi4uLjpAQEBAQEArLiAgIC4uLSotOjo6Ojo9QEBAJT06Ojo6Oi0rOi4gIAogLi4rPTo6Oi0qQEBAJSU9Ojo6Oj0rOi4uLi4gIC4lQEBAQEBAPS4gICAuOiM6Ojo6Ojo6Kj0uLi4gICAuPUBAQEBAQCU6ICAgICAuLSo6Ojo6OjotJUBAJTo6Ojo6OiotLiAgCiAuOiM6Ojo6KkBAQEAlLTo6Ojo9KzouLi4gICAgLkBAQEBAQEA9Li4gICAgLSs6Ojo6Oj09Li4uLiAgIC46JUArOiNAPS4gICAgIC46Kz06Ojo6Ojo6I0A9Ojo6Ojo6Ki0uICAKIC46Izo6Ojo9JUBAJS06Ojo6LSsrLi4gICAgICAuLUAlLT1AIzogICAgICAuJTo6Ojo6Kj0uLi4uICAgIC4uLSsqPS4uLi4gICAgLi4tKzo6Ojo6Ojo6Iy06Ojo6Oi0rOi4uIAogIC4rPTo6Ojo6LSMtOjo6OjotPT0uLiAgICAgICAuLi4uLi4uLiAgICAgIC4jOjo6OjoqPS4uLi4gICAgICAgICAgICAgICAgICAuLi0rOjo6Ojo6OjotIzo6Ojo9Ki0uICAgCiAgLi4rKzo6OjoqPTo6Ojo6Oi0rPS4uICAgICAgICAgICAgICAgICAgICAgLiU6Ojo6OistLi4uLiAgICAgICAgICAgICAgICAgICA6PT06Ojo6Ojo6Oi0rKzo9Iz0uICAgICAKICAgIC46KiMtPSstOjo6Ojo6Oj0rLi4gICAgICAgICAgICAgICAgICAgICA6Izo6Ojo6OiMtLi4uICAgICAgICAgICAgICAgICAgLi0qOjo6Ojo6Ojo6Oi0jLS4uLiAgICAgIAogICAgICAuLi4qPTo6Ojo6Ojo6LSs9Li4uICAgICAgICAgICAgICAgIC4uLiU6Ojo6Ojo6OiMtLi4uICAgICAgICAgICAgICAuLi4rKzo6Ojo6Ojo6Ojo6LSs9Li4uICAgICAgCiAgICAgICAuLSstOjo6Ojo6Ojo6OisrLi4uLiAgICAgICAgICAgICAuLiorOjotLSolJSMrLS0lOi4uLi4uICAgICAuLi4uLi4rIy06Ojo6Ojo6Ojo6Ojo6PSouLi4gICAgICAKICAgICAgIC4rPTo6Ojo6Ojo6Ojo6Oi0qPTouLi4gICAgICAuLi4uOiorLTotJUBAQEBAQEBAQD0tKyU9Oi4uLi4uLi46OiolLTo6Ojo6Ojo6Ojo6Ojo6OjotKy0uLi4gICAgIAogICAgICAgLis9Ojo6Ojo6Ojo6Ojo6Ojo6LSMjPTo6Ojo6Oi0qIystOjotLSNAQEBAQEBAQEBAIy06Ojo6LS09PT09LS06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi09Ky4uICAgICAgCiAgICAgICA6Kz06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotKiM9PSVAQEBAQEBAJSstPSUrLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oj0rLi4uICAgICAKICAgICAgLi0rLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6LSU9LS0tLS0tLS0tLS0tLS0tLS0jKzo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSs6LiAgICAgIAogICAgICAuLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9Ky0tLS0tLS0tLS0tLS0tLS0tLT0jLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotKy0uLiAgICAgCiAgICAgICAtKy06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0jKy0tLS09PSsqIyorPT0tLS0tKyMtOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0rLS4gICAgICAKICAgICAgLi0rLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9IyUqPTouLisrLi4uKyMqKiM9Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oj09LiAgICAgIAogICAgICAuLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6QC4gICA6Kz0gICA6Ki06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSsuICAgICAgCiAgICAgIC4tKy06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjoqOiAgLjorPSAgLi4jLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9Ky4gICAgICAKICAgICAgLjorLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0lOi4uPSMrLi4uLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OisrLiAgICAgIAogICAgIC4uOis9Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0rKys9Oj0rKyo9LTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSsuICAgICAgCgo="

# Global variable for cleanup
DOWNLOAD_FILE=""

# Cleanup function - called on script exit
cleanup() {
    if [ -n "$DOWNLOAD_FILE" ] && [ -f "$DOWNLOAD_FILE" ]; then
        echo -e "${yellow}[!] Cleaning up downloaded file: $DOWNLOAD_FILE${reset}"
        rm -f "$DOWNLOAD_FILE"
        echo ""
    fi
}

# Manual cleanup function
manual_cleanup() {
    if [ -n "$DOWNLOAD_FILE" ] && [ -f "$DOWNLOAD_FILE" ]; then
        echo -e "${yellow}[!] Cleaning up downloaded file: $DOWNLOAD_FILE${reset}"
        rm -f "$DOWNLOAD_FILE"
        echo ""
    fi
}

# Set trap to cleanup on exit (success, failure, or interruption)
trap cleanup EXIT

# Print ASCII art function
print_ascii_art() {
    # Decode the base64 input and print it with the specified color
    if [ -n "$1" ]; then
        echo -e "$1" | base64 -d | while IFS= read -r line; do
            echo -e "${blue}${line}${reset}"
        done
    fi
}

# Print banner function
print_banner() {
    echo -e "${blue}-----------------------------------------------------------------${reset}"
    echo ""
    echo -e "${blue}[i] Let'sGO Now with 10% more GO than the leading brand.${reset}"
    echo -e "${blue}[i] Version 0.09 codename: cross-platform-universal${reset}"
    echo -e "${blue}[i] By Darkcast${reset}"
    echo -e "${blue}[i] Git https://github.com/Darkcast/letsGO${reset}"
    echo ""
    echo -e "${blue}-----------------------------------------------------------------${reset}"
    echo ""
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unsupported"
    fi
}

# Get the current OS
OS=$(detect_os)

if [ "$OS" = "unsupported" ]; then
    echo -e "${red}[✗] Unsupported operating system: $OSTYPE${reset}"
    exit 1
fi

echo -e "${blue}[i] Detected OS: $OS${reset}"

# Check for sudo privileges (only for Linux or if not using Homebrew on macOS)
check_sudo() {
    if [ "$OS" = "linux" ] || ([ "$OS" = "macos" ] && ! command -v brew &> /dev/null); then
        if ! sudo -v &> /dev/null; then
            echo -e "${red}[✗] This script requires sudo privileges. Please run as 'sudo ./letsGO.sh'${reset}"
            exit 1
        fi
    fi
}

# Function to check for package managers
install_package() {
    local package="$1"
    
    if [ "$OS" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y "$package" > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            sudo yum install -y "$package" > /dev/null 2>&1
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$package" > /dev/null 2>&1
        else
            echo -e "${red}[✗] Package manager not found. Please install $package manually.${reset}"
            exit 1
        fi
    elif [ "$OS" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew install "$package" > /dev/null 2>&1
        elif command -v port &> /dev/null; then
            sudo port install "$package" > /dev/null 2>&1
        else
            echo -e "${red}[✗] Package manager not found. Please install Homebrew or MacPorts, or install $package manually.${reset}"
            exit 1
        fi
    fi
}

# Check sudo privileges
check_sudo

# Print ASCII art first (if provided)
print_ascii_art "$encoded_art"

# Then print banner
print_banner

# Install the required tools
for tool in jq curl wget; do
  if ! command -v "$tool" &> /dev/null; then
    echo -e "${yellow}[!] $tool is not installed. Attempting to install...${reset}"
    install_package "$tool"
    if ! command -v "$tool" &> /dev/null; then
      echo -e "${red}[✗] Failed to install $tool. Please install it manually.${reset}"
      exit 1
    fi
  fi
done

# FIXED: Get the real user (not root when using sudo) and home directory
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    # Get home directory safely without eval
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -z "$HOME_DIR" ]; then
        # Fallback if getent doesn't work
        HOME_DIR="/home/$SUDO_USER"
    fi
else
    REAL_USER="$USER"
    HOME_DIR="$HOME"
fi

echo -e "${blue}[i] Installing for user: $REAL_USER${reset}"
echo -e "${blue}[i] User home directory: $HOME_DIR${reset}"

# Check to see whats the latest version of GO
GO_VERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')

# Check if Go is already installed and up-to-date
current_version=""
if command -v go >/dev/null 2>&1; then
    current_version=$(go version | awk '{print $3}')
    if [ "$current_version" = "$GO_VERSION" ]; then
        echo -e "${green}[✓] Go latest version: $GO_VERSION is already installed 🎉${reset}"
    else
        echo -e "${yellow}[yikes bro] Updating Go from version: $current_version to version: $GO_VERSION${reset}"
    fi
else
    echo -e "${yellow}[yikes bro] Go is not installed. Installing latest version: $GO_VERSION${reset}"
fi

# If Go is not installed or needs updating, proceed with installation
if [ "$current_version" != "$GO_VERSION" ]; then
    
    # Set architecture and download URL based on OS
    if [ "$OS" = "linux" ]; then
        # Detect Linux architecture (x86_64, aarch64, etc.)
        MACHINE_ARCH=$(uname -m)
        case $MACHINE_ARCH in
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
                echo -e "${red}[✗] Unsupported architecture: $MACHINE_ARCH${reset}"
                exit 1
                ;;
        esac
        SYMLINK_PATH="/usr/local/bin/go"  # FIXED: Changed from /usr/bin/go to /usr/local/bin/go
        PROFILE_FILE="$HOME_DIR/.profile"
    elif [ "$OS" = "macos" ]; then
        # Detect Mac architecture (Intel vs Apple Silicon)
        if [[ $(uname -m) == "arm64" ]]; then
            ARCH="darwin-arm64"
        else
            ARCH="darwin-amd64"
        fi
        SYMLINK_PATH="/usr/local/bin/go"
        
        # FIXED: Detect shell for the actual user, not the current environment
        USER_SHELL=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f7)
        if [ -z "$USER_SHELL" ]; then
            # Fallback if getent doesn't work
            USER_SHELL="$SHELL"
        fi
        
        case "$USER_SHELL" in
            */zsh)
                PROFILE_FILE="$HOME_DIR/.zshrc"
                ;;
            */bash)
                PROFILE_FILE="$HOME_DIR/.bash_profile"
                ;;
            *)
                PROFILE_FILE="$HOME_DIR/.profile"
                ;;
        esac
    fi
    
    echo -e "${green}[✓] Downloading and installing Go-lang version: $GO_VERSION for $ARCH${reset}"
    
    # FIXED: Set download file for cleanup
    DOWNLOAD_FILE="${GO_VERSION}.${ARCH}.tar.gz"
    
    # Download Go
    if ! wget -q "https://go.dev/dl/$DOWNLOAD_FILE"; then
        echo -e "${red}[✗] Failed to download Go-lang version: $GO_VERSION${reset}"
        exit 1
    fi
    
    # Remove existing Go installation if it exists
    if [ -d "/usr/local/go" ]; then
        echo -e "${yellow}[!] Removing existing Go installation${reset}"
        sudo rm -rf /usr/local/go
    fi
    
    # Extract Go
    if ! sudo tar -C /usr/local -xzf "$DOWNLOAD_FILE" > /dev/null 2>&1; then
        echo -e "${red}[✗] Failed to extract Go-lang version: $GO_VERSION${reset}"
        exit 1
    fi
    
    # Ensure /usr/local/bin exists
    sudo mkdir -p /usr/local/bin
    
    # Create symbolic link - FIXED: Point to the correct binary location
    if ! sudo ln -sf /usr/local/go/bin/go "$SYMLINK_PATH"; then
        echo -e "${yellow}[!] Failed to create symbolic link for Go in $SYMLINK_PATH. Go is still installed in /usr/local/go/bin/${reset}"
    else
        echo -e "${green}[✓] Created symbolic link for Go in $SYMLINK_PATH${reset}"
    fi
    
    # Also create symlink for gofmt if it doesn't exist
    if ! sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt; then
        echo -e "${yellow}[!] Failed to create symbolic link for gofmt${reset}"
    fi
    
    echo -e "${green}[✓] Go-lang successfully installed.${reset}"

    # FIXED: Add Go to the PATH environment variable for the REAL user
    if ! grep -q "# golang setup" "$PROFILE_FILE" 2>/dev/null; then
        # Ensure the profile file is owned by the real user
        sudo -u "$REAL_USER" touch "$PROFILE_FILE"
        
        echo "# golang setup" >> "$PROFILE_FILE"
        echo "export GOROOT=/usr/local/go" >> "$PROFILE_FILE"
        echo "export GOPATH=\$HOME/go" >> "$PROFILE_FILE"
        echo "export GOBIN=\$HOME/go/bin" >> "$PROFILE_FILE"
        echo "export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH" >> "$PROFILE_FILE"
        
        # Ensure the profile file is owned by the real user
        sudo chown "$REAL_USER:$(id -gn "$REAL_USER")" "$PROFILE_FILE"
        
        echo -e "${green}[✓] Added Go to PATH in $(basename "$PROFILE_FILE") for user $REAL_USER${reset}"
    else
        echo -e "${green}[✓] Go is already in the PATH in $(basename "$PROFILE_FILE")${reset}"
    fi
else
    echo -e "${green}[✓] Go is already installed and up-to-date.${reset}"
fi

# Final instructions based on OS
if [ "$OS" = "linux" ]; then
    echo -e "${yellow}[!] Please run 'source ~/.profile' or log out and back in to update your PATH.${reset}"
elif [ "$OS" = "macos" ]; then
    USER_SHELL=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f7)
    case "$USER_SHELL" in
        */zsh)
            echo -e "${yellow}[!] Please run 'source ~/.zshrc' or restart your terminal to update your PATH.${reset}"
            ;;
        */bash)
            echo -e "${yellow}[!] Please run 'source ~/.bash_profile' or restart your terminal to update your PATH.${reset}"
            ;;
        *)
            echo -e "${yellow}[!] Please run 'source ~/.profile' or restart your terminal to update your PATH.${reset}"
            ;;
    esac
fi
echo -e "${green}[✓] Installation complete! Run 'go version' to verify.${reset}"

# Manual cleanup before final messages
manual_cleanup

echo -e "${green}------------------------------------------------------------------------${reset}"
echo -e "${green}[i] Enjoyed this? Help others discover it by sharing on social media! 💖${reset}"
echo -e "${green}------------------------------------------------------------------------${reset}"

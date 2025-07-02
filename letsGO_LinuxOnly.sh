#!/bin/bash

# This script checks for the presence of jq and curl utilities, prints an ASCII art banner if provided,
# checks if the latest version of Go (Golang) is installed, and if not, downloads and installs it.
# Version 0.05 codename: fiver

# ANSI Colors
red='\033[1;31m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'
blue='\033[38;5;87m'

# Encoded ASCII art 
encoded_art="ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAuLiAgLi46Oi09PSsrKysrKz09PS0tOjouLi4uLi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAuLi4uOi09KysrKysrKz09LS0tOjo6Ojo6Oi0tLS09PSsrKysrKystOi4uLi4uICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAuLSsrKz09LS06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi09KysqPTouICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgIC4uLj0qKz0tOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotPSsrLS4uIC4uLjo6OjouLi4gICAgICAgICAKICAgICAgICAuLi46LS0tOi4gIC4uPSorLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6LT0rKioqKioqPS06Ojo6Oi09Kj09Kis9PT0tPT09Kis6Li4gICAgIAogICAgIC4uKyo9PS0tLS09PSsqKistOjo6Oi09KiMrPS0tPSsqKj0tOjo6Ojo6Ojo6Ojo6Ojo6Ojo9Iz06Oi4uLi4uLi4uOj0jPTo6Ojo6LSoqLTo6Ojo6Ojo6LSsrOi4uICAgCiAgIC4uKystOjo6Ojo6OjotKistOjo6LSorLTouLi4uLi4uLi4uOi0qKy06Ojo6Ojo6Ojo6Oi0jPTouLi4uOiolJSMtLi4uLi46Kis6Ojo6Oi0qKy0tOjo6Ojo6Oi0qLS4gICAKICAuOio9Ojo6Ojo6Ojo6KyotOjo6LSo9Li4uLiAuLiolQEAlPS4uIC4uKys6Ojo6Ojo6OjorKy4uLi4uLjpAQEBAQEArLiAgIC4uLSotOjo6Ojo9QEBAJT06Ojo6Oi0rOi4gIAogLi4rPTo6Oi0qQEBAJSU9Ojo6Oj0rOi4uLi4gIC4lQEBAQEBAPS4gICAuOiM6Ojo6Ojo6Kj0uLi4gICAuPUBAQEBAQCU6ICAgICAuLSo6Ojo6OjotJUBAJTo6Ojo6OiotLiAgCiAuOiM6Ojo6KkBAQEAlLTo6Ojo9KzouLi4gICAgLkBAQEBAQEA9Li4gICAgLSs6Ojo6Oj09Li4uLiAgIC46JUArOiNAPS4gICAgIC46Kz06Ojo6Ojo6I0A9Ojo6Ojo6Ki0uICAKIC46Izo6Ojo9JUBAJS06Ojo6LSsrLi4gICAgICAuLUAlLT1AIzogICAgICAuJTo6Ojo6Kj0uLi4uICAgIC4uLSsqPS4uLi4gICAgLi4tKzo6Ojo6Ojo6Iy06Ojo6Oi0rOi4uIAogIC4rPTo6Ojo6LSMtOjo6OjotPT0uLiAgICAgICAuLi4uLi4uLiAgICAgIC4jOjo6OjoqPS4uLi4gICAgICAgICAgICAgICAgICAuLi0rOjo6Ojo6OjotIzo6Ojo9Ki0uICAgCiAgLi4rKzo6OjoqPTo6Ojo6Oi0rPS4uICAgICAgICAgICAgICAgICAgICAgLiU6Ojo6OistLi4uLiAgICAgICAgICAgICAgICAgICA6PT06Ojo6Ojo6Oi0rKzo9Iz0uICAgICAKICAgIC46KiMtPSstOjo6Ojo6Oj0rLi4gICAgICAgICAgICAgICAgICAgICA6Izo6Ojo6OiMtLi4uICAgICAgICAgICAgICAgICAgLi0qOjo6Ojo6Ojo6Oi0jLS4uLiAgICAgIAogICAgICAuLi4qPTo6Ojo6Ojo6LSs9Li4uICAgICAgICAgICAgICAgIC4uLiU6Ojo6Ojo6OiMtLi4uICAgICAgICAgICAgICAuLi4rKzo6Ojo6Ojo6Ojo6LSs9Li4uICAgICAgCiAgICAgICAuLSstOjo6Ojo6Ojo6OisrLi4uLiAgICAgICAgICAgICAuLiorOjotLSolJSMrLS0lOi4uLi4uICAgICAuLi4uLi4rIy06Ojo6Ojo6Ojo6Ojo6PSouLi4gICAgICAKICAgICAgIC4rPTo6Ojo6Ojo6Ojo6Oi0qPTouLi4gICAgICAuLi4uOiorLTotJUBAQEBAQEBAQD0tKyU9Oi4uLi4uLi46OiolLTo6Ojo6Ojo6Ojo6Ojo6OjotKy0uLi4gICAgIAogICAgICAgLis9Ojo6Ojo6Ojo6Ojo6Ojo6LSMjPTo6Ojo6Oi0qIystOjotLSNAQEBAQEBAQEBAIy06Ojo6LS09PT09LS06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi09Ky4uICAgICAgCiAgICAgICA6Kz06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotKiM9PSVAQEBAQEBAJSstPSUrLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oj0rLi4uICAgICAKICAgICAgLi0rLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6LSU9LS0tLS0tLS0tLS0tLS0tLS0jKzo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSs6LiAgICAgIAogICAgICAuLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9Ky0tLS0tLS0tLS0tLS0tLS0tLT0jLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjotKy0uLiAgICAgCiAgICAgICAtKy06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0jKy0tLS09PSsqIyorPT0tLS0tKyMtOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0rLS4gICAgICAKICAgICAgLi0rLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9IyUqPTouLisrLi4uKyMqKiM9Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oj09LiAgICAgIAogICAgICAuLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6QC4gICA6Kz0gICA6Ki06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSsuICAgICAgCiAgICAgIC4tKy06Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OjoqOiAgLjorPSAgLi4jLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo9Ky4gICAgICAKICAgICAgLjorLTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0lOi4uPSMrLi4uLSstOjo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6OisrLiAgICAgIAogICAgIC4uOis9Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Oi0rKys9Oj0rKyo9LTo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6PSsuICAgICAgCgogICAgICAgKy0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKwogICAgICAgfCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgfAogICAgICAgfCAgICAgICAgIExldCdzR08gdmVyc2lvbiAwLjUuIE5vdyB3aXRoIDEwJSBtb3JlIEdPIHRoYW4gdGhlIGxlYWRpbmcgYnJhbmQuICAgICAgICAgfAogICAgICAgfCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgfAogICAgICAgKy0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKwo="

print_ascii_art() {
    # Decode the base64 input and print it with the specified color
    if [ -n "$1" ]; then
        echo -e "$1" | base64 -d | while IFS= read -r line; do
            echo -e "${blue}${line}${reset}"
        done
    fi
}


# Check for sudo privileges
if ! sudo -v &> /dev/null; then
    echo -e "${red}[✗] This script requires sudo privileges. Please run as 'sudo ./letsGO.sh' ${reset}"
    exit 1
fi

# Function to check for package managers
install_package() {
    package=$1
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
}

# Print ASCII banner
print_ascii_art "$encoded_art"

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

# Get current user and home directory
CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)

# Check to see whats the latest version of GO
GO_VERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')

# Check if Go is already installed and up-to-date
current_version=""
if command -v go >/dev/null 2>&1; then
    current_version=$(go version | awk '{print $3}')
    if [ "$current_version" = "$GO_VERSION" ]; then
        echo -e "${green}[✓] Go latest version: $GO_VERSION is already installed 🎉 ${reset}"
    else
        echo -e "${yellow}[yikes bro] Updating Go from version: $current_version to version: $GO_VERSION ${reset}"
    fi
else
    echo -e "${yellow}[yikes bro] Go is not installed. Installing latest version: $GO_VERSION ${reset}"
fi

# If Go is not installed or needs updating, proceed with installation
if [ "$current_version" != "$GO_VERSION" ]; then
    echo -e "${green}[✓] Downloading and installing Go-lang version: $GO_VERSION ${reset}"
    if ! wget -q https://go.dev/dl/"${GO_VERSION}".linux-amd64.tar.gz; then
        echo -e "${red}[✗] Failed to download Go-lang version: $GO_VERSION ${reset}"
        exit 1
    fi
    if ! sudo tar -C /usr/local -xzf "${GO_VERSION}".linux-amd64.tar.gz > /dev/null 2>&1; then
        echo -e "${red}[✗] Failed to extract Go-lang version: $GO_VERSION ${reset}"
        rm "${GO_VERSION}".linux-amd64.tar.gz
        exit 1
    fi
    if ! sudo ln -sf /usr/local/go/bin/go /usr/bin/go; then
        echo -e "${red}[✗] Failed to create symbolic link for Go ${reset}"
        exit 1
    fi
    rm "${GO_VERSION}".linux-amd64.tar.gz
    echo -e "${green}[✓] Go-lang successfully installed. ${reset}"
else
    echo -e "${green}[✓] Go is already installed and up-to-date. ${reset}"
fi

# Add Go to the PATH environment variable for the current user
if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' "$HOME_DIR/.profile"; then
    echo "# golang setup" >> "$HOME_DIR/.profile"
    echo "export GOROOT=/usr/local/go" >> "$HOME_DIR/.profile"
    echo "export GOPATH=\$HOME/go" >> "$HOME_DIR/.profile"
    echo "export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH" >> "$HOME_DIR/.profile"
    echo -e "${green}[✓] Added Go to PATH in .profile${reset}"
else
    echo -e "${green}[✓] Go is already in the PATH in .profile ${reset}"
fi

echo -e "${yellow}[!] Please run 'source ~/.profile' or log out and back in to update your PATH.${reset}"
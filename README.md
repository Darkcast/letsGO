# letsGo.sh

![Logo](img/logo.png)


## Description

`letsGo.sh` is a Bash script designed to automate the installation and updating of Go (Golang) on Linux systems.

## Features

- Checks and installs required dependencies (jq, curl, wget)
- Detects the latest version of Go
- Installs Go if not present
- Updates Go to the latest version if an older version is installed
- Adds Go to the system PATH

## Prerequisites

- A Linux-based operating system
- Sudo privileges

## Usage

1. Download the script:
```git clone https://github.com/Darkcast/letsGO.git```

2. Make the script executable:
```chmod +x letsGo.sh```

3. Run the script with sudo privileges:
```sudo ./letsGo.sh```

## What the Script Does

1. Checks for for required packages (jq, curl, wget) if not present it will install them
2. Fetches the latest Go version information
3. Checks if Go is installed and compares the version
4. Downloads and installs the latest Go version if necessary
5. Creates a symbolic link for the Go executable
6. Adds Go to the PATH in the user's .profile file

## Note

After running the script, you may need to reload your profile or log out and back in for the PATH changes to take effect.

## Troubleshooting

If you encounter any issues:
- Ensure you have an active internet connection
- Verify that you have sudo privileges
- Check system logs for any error messages

## Contributing

Feel free to fork this repository and submit pull requests for any improvements or bug fixes.


## Disclaimer
This script has only been tested on Ubuntu 24.04 LTS, it should work on other linux distros.

This script is provided as-is, without any warranties. Use at your own risk.

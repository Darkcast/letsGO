# letsGo.sh

![Logo](img/logo.png)


## Description

The most simplest/easiest way to install Golang on linux and now on MacOs distros.

`letsGo.sh` is a Bash script designed to automate the installation and updating of Go (Golang) on Linux systems.

## Features

- Detects the latest version of Go lang.
- Installs Go if not present.
- Updates Go to the latest version if an older version is installed
- Adds Go to the system PATH.
- It createst the Go directory in the users home folder

## Prerequisites

- A Linux-based operating system
- Sudo privileges

## Usage

1. Download the script:
```git clone https://github.com/Darkcast/letsGO.git```

2. change into the directory
```cd letsGO```

3. Make the script executable:
```chmod +x letsGo.sh```

4. Run the script with sudo privileges:
```sudo ./letsGo.sh```

## What the Script Does

1. Checks for for required packages (jq, curl, wget) if not present it will install them.
2. Fetches the latest Go version information.
3. Checks if Go is installed and compares the version.
4. Downloads and installs the latest Go version if necessary.
5. Creates a symbolic link for the Go executable.
6. Adds Go to the PATH in the user's .profile file.

## Note
- This code requires root to move the binary into the appropiate directory, make sure you look at the code before executing.
- After running the script, you may need to reload your profile or log out and back in for the PATH changes to take effect.

## Troubleshooting

If you encounter any issues:
- Ensure you have an active internet connection.
- Verify that you have sudo privileges.
- Check system logs for any error messages.
- Check if your distro can install the required packages (wget, curl, jq) via the package manager.

- If go version doesn't work after installation:
  

If`go version` doesn't work, check that these lines are in your shell profile `(~/.zshrc` for macOS zsh, `~/.bash_profile` for macOS bash, or `~/.profile` for Linux):

```
# golang setup
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

```
Then source the file Or simply restart your terminal.

On macOS:
If using zsh (default): `source ~/.zshrc`
If using bash: source `~/.bash_profile`

On Linux:
`source ~/.profile`



## Disclaimer
This script has only been tested on Ubuntu 24.04 LTS, it should work on other linux distros and MacOS.

This script is provided as-is, without any warranties. Use at your own risk.

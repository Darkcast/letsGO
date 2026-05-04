# letsGO Universal

![Logo](img/logo.png)

![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20android-yellow)
![Go Installer](https://img.shields.io/badge/installer-golang-success)
![Shell Support](https://img.shields.io/badge/shells-bash%20%7C%20zsh%20%7C%20fish-informational)
![Maintained](https://img.shields.io/badge/maintained-yes-green)

A portable, single-file Bash script that installs, upgrades, uninstalls, and runs diagnostics on Go (Golang) across Linux, macOS, and Android (Termux). Designed to work on a fresh machine with no prior Go knowledge required.

---

## Quick Start

```bash
git clone https://github.com/Darkcast/letsGO
cd letsGO
chmod +x letsGO_Universal.sh

# First time on a new machine — check prerequisites
sudo ./letsGO_Universal.sh --setup

# Install Go
sudo ./letsGO_Universal.sh
```

On Termux (Android), omit `sudo`:

```bash
./letsGO_Universal.sh --setup
./letsGO_Universal.sh
```

---

## Options

| Option | Description |
|--------|-------------|
| `--setup` | Check system prerequisites and install any missing dependencies, then exit |
| `--diagnostic` | Check Go installation health, PATH, and latest version status |
| `--version <ver>` | Install a specific Go version (e.g., `--version 1.21.0`) |
| `--uninstall` | Completely remove Go and clean up all environment variables |
| `--verbose`, `-v` | Enable detailed output |
| `--log <file>` | Write a timestamped log to the specified file |
| `--help`, `-h` | Display usage information |

---

## How It Works

### `--setup` — Pre-flight check

Run this first on any new machine. It verifies the system is ready before touching anything:

| Check | What it does |
|-------|-------------|
| Sudo access | Confirms elevated privileges are available (skipped on Termux) |
| Internet connectivity | Verifies go.dev is reachable |
| Architecture | Confirms the CPU is supported by Go |
| Disk space | Ensures at least 600MB is free |
| Dependencies | Checks for `curl`, `wget`, `jq` — installs any that are missing |

Exits `0` if everything is ready with the exact command to run next. Exits `1` and lists what needs fixing if anything fails.

---

### `--diagnostic` — Health check

Non-destructive. Safe to run at any time. Reports:

- OS, architecture, kernel, shell, and profile file
- Go version, binary location, GOROOT, GOPATH
- Broken symlinks, conflicting installations, GOROOT mismatches
- PATH reachability
- Version currency — fetches the latest release from go.dev and compares it to what is installed. Skips automatically when offline.

---

### Install / Upgrade

Running the script without flags installs the latest stable Go release, or upgrades if an older version is detected:

```bash
sudo ./letsGO_Universal.sh
```

What happens under the hood:

1. Detects platform and architecture
2. Resolves the latest stable version from go.dev
3. Downloads the release tarball to an isolated temp directory
4. Verifies the SHA256 checksum against the official go.dev value
5. Backs up any existing Go installation (with a disk space check first)
6. Extracts to `/usr/local/go` and creates symlinks in `/usr/local/bin`
7. Updates the correct shell profile (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`, etc.)
8. Verifies the installation before exiting

---

### `--uninstall` — Clean removal

Removes the Go installation, symlinks, and all Go-related exports from every detected shell profile:

```bash
sudo ./letsGO_Universal.sh --uninstall
```

---

## Requirements

| Dependency | Notes |
|------------|-------|
| `bash` | Required to run the script |
| `curl` | Version metadata and connectivity checks |
| `wget` | Fetching Go release tarballs |
| `sudo` | Required on Linux and macOS — not needed on Termux |
| `jq` | Optional — enables faster version and checksum parsing |
| `sha256sum` or `shasum` | Standard on all supported platforms |

Missing tools are installed automatically via the detected package manager (`apt-get`, `yum`, `dnf`, `apk`, or `brew`). On macOS without Homebrew or MacPorts, the script will tell you exactly what to install and how.

---

## Shell Support

The script detects your active shell and updates the correct profile:

| Shell | Profile updated |
|-------|----------------|
| bash | `~/.bashrc`, `~/.bash_profile` |
| zsh | `~/.zshrc` |
| fish | `~/.config/fish/config.fish` via `fish_add_path` |
| sh | `~/.profile` |

---

## Platform Support

| Platform | Architecture |
|----------|-------------|
| Ubuntu 24.04 | x86_64, aarch64 |
| Debian 12 | x86_64 |
| Alpine Linux (musl) | x86_64 |
| macOS 13+ | Intel, Apple Silicon |
| Android (Termux) | aarch64 |

---

## Troubleshooting

**Go command not found after install**

Source your shell profile or open a new terminal:

```bash
source ~/.zshrc      # zsh
source ~/.bashrc     # bash
```

Fish shell users: open a new terminal or the install output will show the exact command.

**Permission denied on Linux or macOS**

The script installs to `/usr/local/go` which requires root access. Run with `sudo`:

```bash
sudo ./letsGO_Universal.sh
```

**Multiple Go installations detected**

Run `--diagnostic` to identify all installations, then `--uninstall` to clean up before reinstalling.

**Capturing output for debugging**

```bash
sudo ./letsGO_Universal.sh --verbose --log /tmp/letsgo.log
```

---

## What's New in v0.14

- Redesigned output — structured, labeled, consistent across all modes
- `--setup` mode — pre-flight checks with dependency installation
- SHA256 checksum verification of every downloaded tarball
- Downloads isolated to a temp directory instead of the current working directory
- `--diagnostic` now compares installed version against latest; skips when offline
- Removed `eval` from package installation — direct quoted calls per package manager
- Removed unsafe shell profile sourcing in elevated context
- Alpine Linux / musl detection fixed
- macOS `HOME_DIR` resolution fixed when running as `sudo`
- fish shell updated to `fish_add_path` for fish 3+ compatibility
- Uninstall path uses `$INSTALL_DIR` instead of hardcoded `/usr/local/go`
- Disk space check before backup
- `log_error` redirected to stderr
- `--log` and `--version` flags now reject missing or flag-like values

---

## Usage Disclaimer

This script is intended for personal use, educational purposes, or small-scale environments only.

It **must not** be used within larger organizations, enterprise environments, or integrated into broader projects without the **explicit consent of the original author**.

### Use at your own risk. 

This script modifies system-level directories and shell profiles. You should carefully review the source code before running it with elevated privileges.

Unauthorized use in such contexts may lead to unintended consequences, including security, legal, or operational risks. 

If you are considering extending or embedding this script into a larger system, please contact the author directly to obtain proper permission.

By using this script, you acknowledge and agree to these limitations.

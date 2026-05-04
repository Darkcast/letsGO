# Manual Revert Instructions — letsGO Universal v0.14

If the script fails or causes issues, follow these steps to manually undo all changes it made to your system.

---

## The Easy Way — Use the Script Itself

If the script ran successfully but you want to remove Go, the cleanest option is:

```bash
sudo ./letsGO_Universal.sh --uninstall
```

This removes the installation, symlinks, and all profile entries automatically. It will also prompt you to remove your GOPATH workspace directory (`~/go`). Only follow the manual steps below if the script itself is unavailable or the uninstall fails.

---

## What the Script Changes

Before reverting, here is exactly what the script modifies so you know what to look for:

| What | Location |
|------|----------|
| Go toolchain | `/usr/local/go` (Linux/macOS) or `$PREFIX/lib/go` (Termux) |
| Symlinks | `/usr/local/bin/go` and `/usr/local/bin/gofmt` (Linux/macOS) or `$PREFIX/bin/go` and `$PREFIX/bin/gofmt` (Termux) |
| Shell profile | `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile`, or `~/.config/fish/config.fish` depending on your shell |
| GOPATH workspace | `~/go/` and `~/go/bin/` — created if they don't exist |
| Backups | `~/.letsgo_backups/<timestamp>/` — one per install/upgrade |
| Last backup pointer | `~/.letsgo_last_backup` — a file containing the path of the most recent backup |

---

## Manual Steps

### 1. Remove the Go Installation

**Linux and macOS:**
```bash
sudo rm -rf /usr/local/go
```

**Android (Termux) — removes both possible locations:**
```bash
rm -rf $PREFIX/lib/go
rm -rf $PREFIX/go
```

---

### 2. Remove Symlinks

**Linux and macOS:**
```bash
sudo rm -f /usr/local/bin/go
sudo rm -f /usr/local/bin/gofmt
```

**Android (Termux):**
```bash
rm -f $PREFIX/bin/go
rm -f $PREFIX/bin/gofmt
```

---

### 3. Clean Up Shell Profile

The script appends a `# golang setup` block to your shell profile. Open the appropriate file and remove all lines in that block.

| Shell | Profile file |
|-------|-------------|
| zsh | `~/.zshrc` |
| bash (Linux) | `~/.bashrc` or `~/.bash_profile` |
| bash (macOS) | `~/.bash_profile` |
| fish | `~/.config/fish/config.fish` |
| sh | `~/.profile` |

**Linux and macOS — bash/zsh/sh profile block to remove:**
```bash
# golang setup
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```

**Linux and macOS — fish profile block to remove:**
```fish
# golang setup
set -x GOROOT /usr/local/go
set -x GOPATH $HOME/go
set -x GOBIN $HOME/go/bin
fish_add_path $GOROOT/bin $GOPATH/bin
```

**Android (Termux) — bash/zsh profile block to remove:**
```bash
# golang setup for Termux
export GOROOT=$PREFIX/lib/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
```

**Android (Termux) — fish profile block to remove:**
```fish
# golang setup for Termux (fish shell)
set -x GOROOT $PREFIX/lib/go
set -x GOPATH $HOME/go
fish_add_path $GOROOT/bin $GOPATH/bin
```

To find which profiles were actually modified:
```bash
grep -rl "golang setup" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.profile ~/.config/fish/config.fish 2>/dev/null
```

To remove the block with a one-liner instead of editing manually:

```bash
# Linux (GNU sed)
sed -i '/# golang setup/,/^$/d' ~/.zshrc

# macOS (BSD sed — requires a backup extension)
sed -i '' '/# golang setup/,/^$/d' ~/.zshrc
```

---

### 4. Remove the GOPATH Workspace (Optional)

The script creates `~/go/bin/` as your Go workspace. This directory contains any Go tools or packages you installed — not the Go toolchain itself. Only remove it if you want a completely clean slate.

```bash
rm -rf ~/go
```

---

### 5. Remove Backups Created by the Script (Optional)

The script creates a timestamped backup before each install or upgrade, and records the path of the most recent one:

```bash
# See what backups exist
ls ~/.letsgo_backups/

# Remove all backups
rm -rf ~/.letsgo_backups/

# Remove the last-backup pointer file
rm -f ~/.letsgo_last_backup
```

---

### 6. Remove Temp Files (If a Crash Left Any Behind)

The script downloads to a temp directory and cleans it up automatically on exit. On macOS the temp dir is under `$TMPDIR`, on Linux it is under `/tmp`. If a crash left files behind:

```bash
# macOS
ls "$TMPDIR" | grep letsgo
rm -rf "$TMPDIR"/letsgo*

# Linux / Termux
ls /tmp | grep letsgo
rm -rf /tmp/letsgo*
```

---

### 7. Reload Your Shell

After removing the profile entries, reload your shell:

```bash
source ~/.zshrc        # zsh
source ~/.bashrc       # bash (Linux)
source ~/.bash_profile # bash (macOS)
source ~/.profile      # sh
```

Or simply open a new terminal window.

---

### 8. Verify Everything Is Gone

```bash
# Should return "command not found" or empty
which go
go version

# Should return empty
echo $GOROOT
echo $GOPATH
echo $GOBIN

# Should show no Go-related paths
echo $PATH | tr ':' '\n' | grep go

# Should not exist
ls /usr/local/go 2>/dev/null && echo "still exists" || echo "gone"
ls /usr/local/bin/go 2>/dev/null && echo "still exists" || echo "gone"
```

---

### 9. Restore a Previous Go Version (If the Script Upgraded You)

If the script upgraded an existing Go installation and you want to go back, check if a backup exists:

```bash
# See available backups
ls ~/.letsgo_backups/

# Check what was saved
ls ~/.letsgo_backups/<timestamp>/
# go_installation/   — Linux/macOS Go toolchain
# termux_go/         — Termux Go toolchain (Android only)
# .zshrc.backup      — shell profile snapshots
# .bashrc.backup
# etc.
```

**Restore the Go toolchain from backup:**

```bash
# Linux/macOS
sudo rm -rf /usr/local/go
sudo cp -r ~/.letsgo_backups/<timestamp>/go_installation /usr/local/go

# Termux
rm -rf $PREFIX/lib/go
cp -r ~/.letsgo_backups/<timestamp>/termux_go $PREFIX/lib/go
```

**Or download a specific version manually from go.dev:**
1. Go to https://go.dev/dl/
2. Download your target version
3. Extract: `sudo tar -C /usr/local -xzf go<version>.<os>-<arch>.tar.gz`
4. Re-add the profile block to your shell config

---

### 10. Remove Dependencies Installed by the Script (Optional)

If `--setup` or the main install added tools you do not want to keep:

**Ubuntu / Debian:**
```bash
sudo apt-get remove jq wget
sudo apt-get autoremove
```

**CentOS / RHEL:**
```bash
sudo yum remove jq wget
```

**Fedora:**
```bash
sudo dnf remove jq wget
```

**macOS (Homebrew):**
```bash
brew uninstall jq wget
```

**Alpine:**
```bash
sudo apk del jq wget
```

Note: `curl` is a core system dependency on most platforms — do not remove it.

---

### 11. Fix File Ownership (If Needed)

If the script was run with `sudo`, your profile files should still be owned by your user. If they are not:

```bash
sudo chown $USER:$(id -gn) ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null
```

---

## Verification Checklist

| Check | Command | Expected result |
|-------|---------|----------------|
| Go binary gone | `which go` | no output |
| Go version gone | `go version` | command not found |
| GOROOT cleared | `echo $GOROOT` | empty |
| GOPATH cleared | `echo $GOPATH` | empty |
| PATH clean | `echo $PATH \| tr ':' '\n' \| grep go` | no output |
| Install dir gone | `ls /usr/local/go` | no such file |
| Symlinks gone | `ls /usr/local/bin/go` | no such file |
| Profile clean | `grep "golang setup" ~/.zshrc` | no output |

---

## Troubleshooting

**Environment variables persist after reloading profile**

Check for multiple profile files — the block may be in both `.bashrc` and `.bash_profile`:
```bash
grep -rl "golang setup" ~ 2>/dev/null
```
Log out and log back in, or reboot to be sure.

**PATH still contains Go paths after profile cleanup**

Check all profiles including hidden ones:
```bash
grep -r "GOROOT\|GOPATH\|/usr/local/go" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.profile ~/.config/fish/config.fish 2>/dev/null
```

**Permission denied when removing files**

Use `sudo` for anything under `/usr/local`. Do not use `sudo` for files under your home directory.

**`~/go` directory recreated on shell start**

This means the `export GOPATH` line is still in one of your profiles. Run the grep above to find it.

---

*These instructions reflect the exact behaviour of letsGO Universal v0.14. If you modified the script or used non-default paths, adjust the commands accordingly.*

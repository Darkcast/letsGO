# Manual Revert Instructions — letsGO Universal v0.14

If the script fails or causes issues, follow these steps to manually undo all changes it made to your system.

---

## The Easy Way — Use the Script Itself

If the script ran successfully but you want to remove Go, the cleanest option is:

```bash
sudo ./letsGO_Universal.sh --uninstall
```

This removes the installation, symlinks, and all profile entries automatically. Only follow the manual steps below if the script itself is unavailable or the uninstall fails.

---

## Manual Steps

### 1. Remove the Go Installation

**Linux and macOS:**
```bash
sudo rm -rf /usr/local/go
```

**Android (Termux):**
```bash
rm -rf $PREFIX/lib/go
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

The script adds a `# golang setup` block to your shell profile. Open the appropriate file and remove all lines between and including that block.

| Shell | File |
|-------|------|
| zsh | `~/.zshrc` |
| bash (Linux) | `~/.bashrc` or `~/.bash_profile` |
| bash (macOS) | `~/.bash_profile` |
| fish | `~/.config/fish/config.fish` |
| sh | `~/.profile` |

Remove these lines:

**bash / zsh / sh:**
```bash
# golang setup
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```

**fish:**
```fish
# golang setup
set -x GOROOT /usr/local/go
set -x GOPATH $HOME/go
set -x GOBIN $HOME/go/bin
fish_add_path $GOROOT/bin $GOPATH/bin
```

**Android (Termux) — bash/zsh:**
```bash
# golang setup for Termux
export GOROOT=$PREFIX/lib/go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
```

You can remove them with a one-liner instead of editing manually:

```bash
# bash/zsh/sh
sed -i '/# golang setup/,/^$/d' ~/.zshrc

# macOS (BSD sed requires a backup extension)
sed -i '' '/# golang setup/,/^$/d' ~/.zshrc
```

---

### 4. Remove the Go Workspace (Optional)

This only contains your personal Go projects and downloaded modules — not the Go toolchain itself. Only remove it if you want a completely clean slate.

```bash
rm -rf ~/go
```

---

### 5. Remove Backups Created by the Script (Optional)

The script creates timestamped backups before modifying an existing installation:

```bash
ls ~/.letsgo_backups/
rm -rf ~/.letsgo_backups/
```

---

### 6. Remove Downloaded Temp Files

As of v0.14 the script downloads to a temp directory that is cleaned up automatically on exit. If a crash left files behind, check:

```bash
ls /tmp/letsgo*
rm -rf /tmp/letsgo*
```

---

### 7. Reload Your Shell

After removing the profile entries, reload your shell:

```bash
source ~/.zshrc        # zsh
source ~/.bashrc       # bash
source ~/.bash_profile # bash (macOS)
```

Or simply open a new terminal window.

---

### 8. Verify Everything Is Gone

```bash
# Should return "command not found"
which go
go version

# Should return empty
echo $GOROOT
echo $GOPATH
echo $GOBIN

# Should show no Go paths
echo $PATH | tr ':' '\n' | grep go
```

---

### 9. Restore a Previous Go Version (If Applicable)

If the script upgraded an existing Go installation and you want to go back:

**Check if a backup exists:**
```bash
ls ~/.letsgo_backups/
```

**Restore from backup:**
```bash
sudo rm -rf /usr/local/go
sudo cp -r ~/.letsgo_backups/<timestamp>/go_installation /usr/local/go
```

**Or download a specific version manually:**
1. Go to https://go.dev/dl/
2. Download the version you want
3. Extract: `sudo tar -C /usr/local -xzf go<version>.<os>-<arch>.tar.gz`
4. Re-add the PATH block to your shell profile

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

Note: `curl` is a system dependency on most platforms — do not remove it unless you are certain nothing else depends on it.

---

### 11. Fix File Ownership (If Needed)

If the script was run with `sudo`, your profile files should still be owned by your user. If not:

```bash
sudo chown $USER:$USER ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile
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

---

## Troubleshooting

**Environment variables persist after reloading profile**
- Check for multiple profile files — changes may be in `.bashrc` and also `.bash_profile`
- Log out and log back in, or reboot

**PATH still contains Go paths**
- Check all profile files: `grep -r "golang setup" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.profile ~/.config/fish/config.fish 2>/dev/null`
- Remove any remaining blocks found

**Permission denied when removing files**
- Use `sudo` for anything under `/usr/local`
- Do not use `sudo` for files under your home directory

---

*These instructions cover the default installation paths used by letsGO Universal v0.14. If you modified the script or used non-default paths, adjust the commands accordingly.*

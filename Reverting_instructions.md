# Manual Revert Instructions for letsGO Script

If the letsGO script fails or causes issues on your machine, follow these steps to manually revert the changes:

## 1. Remove Go Installation

### Remove the Go directory:
```bash
sudo rm -rf /usr/local/go
```

### Remove symbolic links:
```bash
sudo rm -f /usr/local/bin/go
sudo rm -f /usr/local/bin/gofmt
```

## 2. Clean Up Environment Variables

The script modifies your shell profile file to add Go to your PATH. You need to remove these lines:

### For Linux users:
Edit your `~/.profile` file:
```bash
nano ~/.profile
```

### For macOS users:
Edit the appropriate file based on your shell:
- **Zsh users**: `nano ~/.zshrc`
- **Bash users**: `nano ~/.bash_profile`
- **Other shells**: `nano ~/.profile`

### Remove these lines from your profile file:
```bash
# golang setup
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```

## 3. Clean Up Go Workspace (Optional)

If you want to completely remove all Go-related files:

### Remove Go workspace directory:
```bash
rm -rf ~/go
```

## 4. Clean Up Downloaded Files

### Remove any leftover downloaded files:
```bash
# Look for and remove any Go tar.gz files in your current directory
ls -la go*.tar.gz
rm -f go*.tar.gz
```

## 5. Refresh Your Shell Environment

After making the changes, refresh your shell environment:

### For Linux:
```bash
source ~/.profile
```

### For macOS:
- **Zsh**: `source ~/.zshrc`
- **Bash**: `source ~/.bash_profile`
- **Other**: `source ~/.profile`

Or simply **restart your terminal**.

## 6. Verify Cleanup

Check that Go has been completely removed:

```bash
# These commands should return "command not found"
go version
which go
```

Check that the environment variables are gone:
```bash
echo $GOROOT
echo $GOPATH
echo $GOBIN
```

These should return empty values.

## 7. Restore Previous Go Installation (If Applicable)

If you had a previous Go installation that was overwritten:

### Check if you have a backup:
```bash
# Look for backup directories
ls -la /usr/local/go*
ls -la ~/go*
```

### Reinstall Go manually:
1. Download the appropriate Go version from https://golang.org/dl/
2. Extract it to `/usr/local/go`
3. Add the PATH variables back to your profile file

## 8. Package Manager Cleanup (If Applicable)

If the script installed additional tools (jq, curl, wget) that you don't want:

### For Ubuntu/Debian:
```bash
sudo apt-get remove jq curl wget
sudo apt-get autoremove
```

### For CentOS/RHEL/Fedora:
```bash
sudo yum remove jq curl wget
# or for newer versions:
sudo dnf remove jq curl wget
```

### For macOS with Homebrew:
```bash
brew uninstall jq curl wget
```

## 9. Check for Remaining Issues

### Check your PATH:
```bash
echo $PATH
```

Make sure there are no lingering Go-related paths.

### Check running processes:
```bash
ps aux | grep go
```

Kill any Go-related processes if necessary.

## 10. File Permissions Cleanup

If you ran the script with sudo, some files might have incorrect ownership:

### Fix ownership of your profile file:
```bash
sudo chown $USER:$USER ~/.profile
sudo chown $USER:$USER ~/.zshrc
sudo chown $USER:$USER ~/.bash_profile
```

## Troubleshooting

### If you can't edit files:
- Make sure you have the correct permissions
- Use `sudo` if necessary for system files
- Check if files are locked or in use

### If PATH issues persist:
- Logout and login again
- Reboot your system
- Check for other shell configuration files (.bashrc, .zshenv, etc.)

### If you're still having issues:
1. Check what the script actually changed by looking at the script output
2. Search for any remaining Go-related files: `find /usr -name "*go*" 2>/dev/null`
3. Check your shell's history for what commands were run: `history | grep go`

## Prevention for Future Use

Before running installation scripts:
1. **Backup your profile files**: `cp ~/.profile ~/.profile.backup`
2. **Note your current Go version**: `go version` (if installed)
3. **Document your current PATH**: `echo $PATH > ~/path_backup.txt`
4. **Test in a virtual machine or container first**

---

**Note**: These instructions assume the script was run with default settings. If you modified the script or installation paths, adjust the commands accordingly.
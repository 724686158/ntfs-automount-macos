#!/bin/bash
# Install (or remove) the ntfs-automount LaunchDaemon.
# Usage: sudo ./install.sh [--uninstall]

set -e
DAEMON=/usr/local/sbin/ntfs-automount.sh
PLIST=/Library/LaunchDaemons/local.ntfs.automount.plist
LABEL=local.ntfs.automount
LOG=/var/log/ntfs-automount.log
SRC="$(cd "$(dirname "$0")" && pwd)/scripts/ntfs-automount.sh"

[ "$(id -u)" = "0" ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }

if [ "$1" = "--uninstall" ]; then
  launchctl bootout "system/$LABEL" 2>/dev/null || true
  rm -f "$PLIST" "$DAEMON"
  echo "Removed $LABEL"
  exit 0
fi

# --- preflight -------------------------------------------------------------
echo "== Checking dependencies =="
NTFS3G="$(command -v ntfs-3g || true)"
[ -x "$NTFS3G" ] || { echo "Missing ntfs-3g. Install: brew install gromgit/fuse/ntfs-3g-mac"; exit 1; }
echo "  ntfs-3g: $NTFS3G"

if pkgutil --pkgs 2>/dev/null | grep -q 'org.fuse-t'; then
  echo "  fuse-t : installed"
else
  echo "  fuse-t : NOT FOUND — install it first: brew install --cask fuse-t"
  echo "           (mounting NTFS read-write needs a FUSE implementation on macOS 26)"
  exit 1
fi

if [ -f /Library/Filesystems/macfuse.fs/Contents/Info.plist ]; then
  echo "  note   : macFUSE is also present; FUSE-T takes precedence for /usr/local/lib/libfuse*"
fi

# --- install ---------------------------------------------------------------
echo "== Installing daemon =="
install -d -m 755 /usr/local/sbin
install -m 755 "$SRC" "$DAEMON"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DAEMON</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_EOF
chmod 644 "$PLIST"
touch "$LOG"; chmod 644 "$LOG"

launchctl bootout "system/$LABEL" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
sleep 2

echo
echo "Installed. Status:"
launchctl print "system/$LABEL" 2>/dev/null | grep -E 'state|pid' | sed 's/^/  /' || true
echo
echo "Log:      tail -f $LOG"
echo "Trigger:  sudo launchctl kickstart -k system/$LABEL"
echo "Uninstall: sudo ./install.sh --uninstall"

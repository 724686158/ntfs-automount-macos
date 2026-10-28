#!/bin/bash
# ntfs-automount — watch for read-only NTFS volumes and remount them read-write.
# Runs as a LaunchDaemon (root). Logs to /var/log/ntfs-automount.log.

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin
LOG="${NTFS_AUTOMOUNT_LOG:-/var/log/ntfs-automount.log}"
INTERVAL="${NTFS_AUTOMOUNT_INTERVAL:-10}"
COOLDOWN="${NTFS_AUTOMOUNT_COOLDOWN:-60}"
MAXLOG=$((1024*1024))

NTFS3G="$(command -v ntfs-3g || true)"
NTFSFIX="$(command -v ntfsfix || true)"

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

rotate_log() {
  [ -f "$LOG" ] || return 0
  size=$(stat -f %z "$LOG" 2>/dev/null || echo 0)
  if [ "$size" -gt "$MAXLOG" ]; then
    tail -c $((MAXLOG/2)) "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  fi
}

[ -x "$NTFS3G" ] || { log "fatal: ntfs-3g not found (brew install gromgit/fuse/ntfs-3g-mac)"; exit 1; }
log "started (ntfs-3g=$NTFS3G interval=${INTERVAL}s cooldown=${COOLDOWN}s)"

while true; do
  rotate_log
  mount | grep -E '\(ntfs' | grep 'read-only' | while IFS= read -r line; do
    dev=${line%% on *}
    rest=${line#* on }
    mp=${rest%% (*}

    stamp="/var/run/ntfs-auto-$(echo "$dev" | tr '/' '_')"
    if [ -f "$stamp" ]; then
      age=$(( $(date +%s) - $(stat -f %m "$stamp" 2>/dev/null || echo 0) ))
      [ "$age" -lt "$COOLDOWN" ] && continue
    fi
    touch "$stamp"

    log "read-only NTFS detected: $dev -> $mp"
    diskutil unmount force "$dev" >>"$LOG" 2>&1 || true
    [ -x "$NTFSFIX" ] && "$NTFSFIX" "$dev" >>"$LOG" 2>&1 || true
    mkdir -p "$mp"
    if "$NTFS3G" "$dev" "$mp" -o local,allow_other,auto_xattr >>"$LOG" 2>&1; then
      log "mounted read-write: $dev -> $mp"
    else
      log "ERROR: failed to mount $dev (volume may be dirty; run chkdsk on Windows)"
    fi
  done
  sleep "$INTERVAL"
done

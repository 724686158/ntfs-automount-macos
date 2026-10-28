# ntfs-automount-macos

**Write to NTFS external drives on macOS 26 (Tahoe) — automatically, with no menu bar app and no kernel extension.**

---

## The problem

If you plug an NTFS-formatted USB drive into a modern Mac, it mounts **read-only**. You can copy files *out*, but you cannot copy files *in*:

```
$ mount | grep ntfs
/dev/disk5s1 on /Volumes/TOSHIBA EXT (ntfs, local, read-only, fskit)
```

Why this happens:

1. **Apple removed NTFS write support.** Up to macOS 12, a hidden flag enabled the old kernel driver in read-write mode (this is what Boot Camp used). Starting with **macOS Ventura**, that mechanism is gone.
2. **macOS 26 goes further.** NTFS is now mounted through **FSKit**, Apple's new user-space filesystem framework, and it is read-only by design.
3. **Old tools stopped working.** [Mounty](https://mounty.app/) — the classic free workaround — last shipped version 2.4 in December 2023. Its menu bar item no longer shows up on macOS 26, and its approach (macFUSE + ntfs-3g remount) needs a kernel extension, which Apple is retiring.
4. **Kernel extensions are a dead end on Apple Silicon.** Loading one requires lowering boot security in Recovery Mode.

The result: a 1 TB drive full of backups that you can only read.

## What this project does

A tiny `launchd` daemon that makes NTFS drives writable **as soon as you plug them in**:

```
plug drive → macOS mounts it read-only (fskit)
           → daemon notices within ~10 s
           → unmount → ntfsfix → ntfs-3g remount (read-write)
           → you just drag files onto the drive
```

It uses **[FUSE-T](https://www.fuse-t.org/)** (a kext-less FUSE implementation that works with FSKit) plus **ntfs-3g** — so no kernel extension, no boot security changes, no menu bar clicking, no password prompt on every insert.

### Features

- Polls every 10 s; only touches volumes mounted **read-only NTFS**
- Runs `ntfsfix` first, so "unsafe state" volumes (unsafely ejected from Windows) can still mount
- Per-device 60 s cooldown, so a failing volume does not loop forever
- Log rotation at 1 MB, everything in `/var/log/ntfs-automount.log`
- `--uninstall` restores the machine to its previous state

## Requirements

| Item | Notes |
|---|---|
| macOS 14+ | Tested on **macOS 26.6.2 (Tahoe)**, Apple Silicon |
| [Homebrew](https://brew.sh) | |
| [FUSE-T](https://www.fuse-t.org/) | `brew install --cask fuse-t` (no kext) |
| [ntfs-3g-mac](https://github.com/gromgit/homebrew-fuse) | `brew install gromgit/fuse/ntfs-3g-mac` |

## Install

```bash
brew install --cask fuse-t
brew install gromgit/fuse/ntfs-3g-mac

git clone https://github.com/<your-account>/ntfs-automount-macos.git
cd ntfs-automount-macos
sudo ./install.sh
```

Plug the drive in, wait ~10 seconds, and check:

```bash
mount | grep ntfs
# /dev/disk5s1 on /Volumes/MyDrive (macfuse, local, synchronous)   ← read-write

tail -f /var/log/ntfs-automount.log
```

Uninstall:

```bash
sudo ./install.sh --uninstall
```

## Caveats — read before using

- **ntfs-3g is user-space software.** It does not replay the NTFS journal the way Windows does. **Always eject the drive** before unplugging; an unsafely removed drive can end up damaged.
- **A dirty volume may refuse to mount read-write.** `ntfsfix` only clears the dirty flag — it is not `chkdsk`. If mounting keeps failing, boot Windows and run `chkdsk /f X:`.
- **Do not make this your only backup.** If the data matters, keep a second copy.
- The script skips `/dev/disk1*` and `/dev/disk2*` to stay away from the boot volume; adjust if your layout differs.
- Multiple simultaneous NTFS volumes are supported by the loop but have only been tested with one.

## Why not just use Mounty?

You can — if it still works for you. On macOS 26 it does not: the menu bar icon is gone, and the remount path depends on a kernel extension that Apple is phasing out. This project removes the GUI entirely: a daemon does the same job silently and never asks for a password again.

Commercial alternatives (Paragon NTFS for Mac, Tuxera, iBoysoft) now ship FSKit-based drivers and work without any of this — they cost money, this is free.

## 中文说明

Mac 插上 NTFS 移动硬盘只能读、不能写，是因为苹果从 Ventura 起移除了 NTFS 写入能力，macOS 26 又改用 FSKit 框架挂载 NTFS，且默认只读。老牌工具 Mounty 最后一版停在 2023 年 12 月的 2.4，在 macOS 26 上菜单栏图标已经不显示，而它的方案依赖苹果正在淘汰的内核扩展。

这个项目用一个后台服务解决：插上盘 → 检测到只读 NTFS → 自动 `ntfsfix` + 用 `ntfs-3g`（跑在 FUSE-T 上，无需内核扩展）重挂成读写。**插上即用，不弹窗、不输密码。**

安装：

```bash
brew install --cask fuse-t
brew install gromgit/fuse/ntfs-3g-mac
sudo ./install.sh
```

注意：ntfs-3g 不重放 NTFS 日志，**务必安全弹出**再拔线；重要数据别只留这一份。

## License

MIT

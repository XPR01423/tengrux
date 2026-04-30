<div align="center">

# 🐺 Tengrux OS

**A Hybrid x86_64 Desktop & Laptop Operating System**

[![Status](https://img.shields.io/badge/Status-Architecture%20%26%20Planning-red?style=for-the-badge)](https://github.com/XPR01423/tengrux)
[![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue?style=for-the-badge)](https://github.com/XPR01423/tengrux)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%20GKI-orange?style=for-the-badge)](https://github.com/XPR01423/tengrux)
[![License](https://img.shields.io/badge/License-Proprietary%20%2B%20OSS-darkred?style=for-the-badge)](https://github.com/XPR01423/tengrux)
[![Theme](https://img.shields.io/badge/Theme-%23440000-440000?style=for-the-badge)](https://github.com/XPR01423/tengrux)

<br>

*Built for the Future. Powered by Tengrux.*

</div>

---

## What is Tengrux?

Tengrux is an experimental hybrid operating system built on the Linux kernel, designed exclusively for modern **x86_64 desktop and laptop hardware**.

It is not a Linux distribution. It is a ground-up rethinking of the Linux user-space — combining the structural discipline and security model of Android's system architecture with the performance characteristics of minimalist Linux systems, without carrying Android's mobile assumptions or Google's dependencies.

> **Name origin:** Tengri (Göktanrı — ancient Turkic sky deity) + Unix = **Tengrux**

---

## Table of Contents

- [Design Philosophy](#design-philosophy)
- [Filesystem Hierarchy](#filesystem-hierarchy)
- [Disk Architecture](#disk-architecture)
- [Boot Chain](#boot-chain)
- [Security Architecture](#security-architecture)
- [Nebuline Gatekeeper](#nebuline-gatekeeper)
- [ATNLFS](#atnlfs)
- [IPC Architecture](#ipc-architecture)
- [Tengrux Libc](#tengrux-libc)
- [Display & Audio Stack](#display--audio-stack)
- [SystemUI & Launcher](#systemui--launcher)
- [Application Layer](#application-layer)
- [System Tooling](#system-tooling)
- [Image Set](#image-set)
- [pKVM, TVD & DebTerm](#pkvm-tvd--debterm)
- [Cell Broadcast](#cell-broadcast)
- [SetupWizard](#setupwizard)
- [License Strategy](#license-strategy)
- [System Package List](#system-package-list)
- [Visual Identity](#visual-identity)
- [Development Roadmap](#development-roadmap)

---

## Design Philosophy

> *"Do not carry someone else's assumptions."*

Every component in Tengrux is either purpose-built from scratch or carefully forked and stripped of upstream dependencies that do not belong on a desktop system. This applies to the C library, the dynamic linker, the package runtime, the init system, and the security framework.

| Principle | Description |
|-----------|-------------|
| **x86_64 Only** | No legacy 32-bit support. `/lib` → `/lib64` symlink for POSIX compatibility |
| **Immutable Core** | EROFS read-only system, vendor, and product partitions |
| **Android-Hybrid Security** | Android's proven isolation model adapted for desktop |
| **Redistributable** | No activation, no license server, no phone-home |
| **App-Scoped Everything** | Libraries, linkers, and locale — all per-application |
| **No eFUSE Required** | ATNLFS provides software-equivalent warranty protection |
| **GKI Kernel** | Generic Kernel Image — single kernel binary, vendor modules separate |

---

## Filesystem Hierarchy

Tengrux uses Android-style **system-as-root**. `/` is directly mounted from `dm-1` (system, EROFS). `/system` is a symlink back to `/`.

```
/ (= /system → dm-1, EROFS, read-only)
│
├── atnlfs/       → dm-7   ATNLFS Triggered WORM partition
├── tpex/         → dm-11  Tengrux Pony EXpress (APEX equivalent)
├── bin           →        symlink → /system/bin
├── cache/        →        tmpfs
├── d             →        symlink → /sys/kernel/debug
├── data/         → dm-5   Encrypted user data (ext4/F2FS, RW)
├── debug_ramdisk/→        Active only in userdebug/eng builds
├── dev/          →        devtmpfs
├── etc           →        symlink → /system/etc
├── mnt/          →        Mount points
├── oem/          →        STUB — OEM customization placeholder
├── persist/      → dm-8   Persistent calibration & DRM data (ext4, RW)
├── proc/         →        procfs
├── product/      → dm-3   Product overlay (EROFS, RO)
├── recovery/     → dm-10  Recovery environment (EROFS, RO)
├── root/         →        STUB — root home placeholder
├── sbin/         →        Critical system binaries (root access only)
├── xbin/         →        Extended binaries (tcpdump, sqlite3, advanced tools)
├── sdcard        →        symlink → /storage/emulated/0
├── storage/      → dm-6   External & emulated storage (RW)
├── super         →        symlink → dm-0 container
├── sys/          →        sysfs
├── system        →        symlink → /
├── tmp/          →        tmpfs
└── vendor/       → dm-2   Hardware drivers & HAL (EROFS, RO)
```

### Key Directory Notes

| Directory | Notes |
|-----------|-------|
| `/atnlfs` | Kernel-managed WORM partition. Contains either `0x0` (clean) or `0x1` (violated) kernel file |
| `/tpex` | **T**engrux **P**ony **EX**press — loop-mounted modular system components, managed by `tpexd` |
| `/xbin` | Extended binaries for power users — keeps `/sbin` clean and minimal |
| `/oem` | Read-only OEM layer — wallpapers, boot animations, hardware config (vendor-populated) |
| `/persist` | Survives `userdata` wipe — stores sensor calibration, Wi-Fi/BT MAC, DRM licenses |
| `/debug_ramdisk` | Only mounted in `userdebug`/`eng` build variants; absent in production |

---

## Disk Architecture

### Physical Partitions (GPT — 2 partitions only)

```
┌─────────────────────────────────────────────────────┐
│  sda1  │  ESP — EFI System Partition                │
│        │  Limine bootloader (minimal footprint)      │
├─────────────────────────────────────────────────────┤
│  sda2  │  XBOOTLDR — Extended Boot Loader Partition │
│        │  boot.img (GKI) + init_boot.img             │
└─────────────────────────────────────────────────────┘
```

### Device Mapper Layout (dm-0 ~ dm-57)

All system volumes live under the Linux Device Mapper, initialized by `dm_linear_setup` inside the GKI initramfs:

```
Physical Disk (LBA)
    │
    ├─ dm-0  (super)          ─── Container: system / vendor / product
    │    ├─ dm-1  (system)         EROFS      /              RO  ← / mountpoint
    │    ├─ dm-2  (vendor)         EROFS      /vendor        RO
    │    └─ dm-3  (product)        EROFS      /product       RO
    │
    ├─ dm-4  (userdata)       ─── Container: data / storage
    │    ├─ dm-5  (data)           ext4/F2FS  /data          RW
    │    └─ dm-6  (storage)        ext4/F2FS  /storage       RW
    │
    ├─ dm-7   atnlfs               ATNLFS     /atnlfs        RW→RO  Triggered WORM
    ├─ dm-8   persist              ext4       /persist       RW     Persistent data
    ├─ dm-9   metadata             —          /metadata      RW     System metadata
    ├─ dm-10  recovery             EROFS      /recovery      RO     Recovery env
    ├─ dm-11  tpex                 —          /tpex          RO     TPEx modules
    ├─ dm-12  pvmfw                —          /pvmfw         RO     Protected VM fw
    │
    └─ dm-13 ~ dm-57          ─── OEM Optional Partitions
                                   Hardware vendors may populate
                                   these slots with proprietary
                                   partitions (max 44 slots)
```

---

## Boot Chain

### GKI Boot Sequence

```
UEFI Firmware
    └── ESP (sda1)
            └── Limine [hidden, timeout=0]
                    └── XBOOTLDR (sda2)
                            ├── boot.img      ← GKI kernel + GKI initramfs
                            └── init_boot.img ← Tengrux init ramdisk
                                    │
                                    └── Linux GKI Kernel
                                            │
                                            └── GKI initramfs
                                                    └── dm_linear_setup
                                                            └── dm-0~12 created
                                                                    └── Tengrux Init (PID 1)
                                                                            ├── BinderFS mount
                                                                            ├── SETengrux load
                                                                            ├── Property Service
                                                                            ├── tpexd
                                                                            └── Zygote64
```

### GKI vs Classic initramfs

| | Classic initramfs | Tengrux GKI |
|--|-------------------|-------------|
| **Kernel** | Vendor-specific | Generic Kernel Image (GKI) |
| **initramfs** | Bundled with kernel | Embedded in GKI `boot.img` |
| **Vendor modules** | In kernel or initramfs | `vendor_boot.img` (OEM fills) |
| **Stock vendor image** | N/A | `vendor_empty_boot.img` (placeholder) |
| **Portability** | Low | High — one kernel, many devices |

> **`vendor_empty_boot.img`** ships as a placeholder in stock Tengrux. Hardware vendors replace it with their own `vendor_boot.img` containing device-specific kernel modules, HAL binaries, and firmware. dm-13~57 slots are reserved for vendor-specific partitions.

### Boot Log Format (Android-style microsecond timestamps)

```
[    0.000001] Booting Linux on physical CPU 0x0
[    0.123456] BinderFS: binder0 initialized
[    0.123457] BinderFS: hwbinder0 initialized
[    0.123458] BinderFS: vndbinder0 initialized
[    0.234567] ATNLFS: partition mounted
[    0.234568] ATNLFS: kernel file 0x0 present — system clean
[    0.345678] Nebuline: boot attestation started
[    0.345679] Nebuline: 1/5 SELinux mode: ENFORCING ✅
[    0.345680] Nebuline: 2/5 Verified Boot: GREEN ✅
[    0.345681] Nebuline: 3/5 su binary: NOT FOUND ✅
[    0.345682] Nebuline: 4/5 /system hash: MATCH ✅
[    0.345683] Nebuline: 5/5 init hash: MATCH ✅
[    0.345684] Nebuline: attestation passed. ATNLFS: 0x0
[    0.456789] Zygote64: starting...
[    0.567890] Surface Drawer: initialized
[    0.678901] Audio Drawer: initialized
[    0.789012] tpexd: mounting /tpex modules...
[    1.000000] Tengrux: boot complete 🐺
```

### Boot State System

| State | Condition | Behavior |
|-------|-----------|----------|
| 🟢 **GREEN** | Fully verified | Normal boot — *SYSTEM SECURED & OPTIMIZED* |
| 🟡 **YELLOW** | User-signed key | Boot with warning — developer/custom ROM |
| 🟠 **ORANGE** | Bootloader unlocked | Warranty burned — persistent warning screen |
| 🔴 **RED** | ATNLFS `0x1` triggered | Force wipe → warning splash → limited mode |

#### 🔴 RED State — Detailed Behavior

When Nebuline writes ATNLFS `0x1`:

1. **Immediate force wipe** — `/data` partition wiped
2. **Warning splash** displayed before every boot until reflashed:

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                        ⚠️  Warning                          │
│                                                              │
│   This desktop is not running Tengrux's official software.  │
│   You may have problems with features or security,          │
│   and you won't be able to install software updates.        │
│                                                              │
│                      [ I Understand ]                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

3. System **continues to boot** — user is not hard-locked
4. Banking apps and critical system apps **refuse to launch**
5. General-purpose apps continue to function normally
6. **Reset path:** `fastboot flash atnlfs atnlfs.img` (wipes data, restores `0x0`)

---

## Security Architecture

### SETengrux

SETengrux is Tengrux's security enforcement framework — built on SELinux (Linux mainline) with Tengrux-specific MCS policy, the TVC audit engine, and deep Nebuline integration.

```
SELinux (Linux kernel — GPL v2)
    └── Tengrux MCS policy        (Tengrux Proprietary)
    └── TVC audit engine          (replaces avc:)
    └── Nebuline integration
    └── TVD isolation categories
    ═══════════════════════════
    = SETengrux
```

#### TVC Audit Engine

Replaces Android's `avc: denied` with **Tengrux Vector Control**:

```
tvc: denied { connectto } for pid=1234 comm="my_app"
    scontext=u:r:untrusted_app:s0:c0,c1
    tcontext=u:r:local_network_service:s0:c2,c3
    tclass=unix_stream_socket
```

#### MCS Process Isolation

```
Zygote64 (sealed)
    ├── u0_a<UID>  s0:c0,c1      → Application Layer (isolated sandbox per app)
    ├── u0_i<UID>  s0:c2,c3      → Isolated Services (computation-only, no resources)
    └── tvd_vm     s0:c512,c513  → TVD virtual machine instances
```

### Rollback Protection Index (RPI)

API-level version downgrade is blocked. A device running API level 2 cannot be rolled back to API level 1. Enforced through the secure boot chain.

---

## Nebuline Gatekeeper

Nebuline is Tengrux's **Knox-equivalent software warranty and security layer**. It runs at every boot — analogous to `fsck` but for system security integrity rather than filesystem consistency.

### Boot Attestation — 5 Checks Per Boot

| # | Check | Pass Condition | Fail Result |
|---|-------|---------------|-------------|
| 1 | SELinux enforcement mode | Must be `ENFORCING` | ATNLFS `0x1` |
| 2 | Verified Boot state | Must be `GREEN` | ATNLFS `0x1` |
| 3 | `su` binary presence | Must **not** exist in any `PATH` location | ATNLFS `0x1` |
| 4 | `/system` partition integrity | dm-verity hash must match | ATNLFS `0x1` |
| 5 | `init` binary integrity | Hash must match expected value | ATNLFS `0x1` |

Any single failure triggers the full RED state sequence.

### Runtime Responsibilities

- **USB TDB scanning** — malware and threat detection on every USB insertion
- **App Center install scanning** — cryptographic signature + permission risk verification
- **Permission risk analysis** — detects dangerous permission combinations (e.g., `RECORD_AUDIO` + `INTERNET` + `READ_CONTACTS`)
- **`tengrux.security.attestation` API** — exposes `isSystemIntegrity()` → `true`/`false` for third-party apps
- **pKVM VM launch authorization** — only Nebuline-approved VM images can start
- **Vendor Partner Program** — OEM ROMs can obtain Nebuline signing to retain GREEN/YELLOW state

---

## ATNLFS

**Advanced Tengrux Nebuline File System** — a **Triggered WORM** (Write Once, Read Many) filesystem.

Unlike classic WORM which locks individual files after write, ATNLFS locks the **entire filesystem** based on the presence of a single kernel-managed trigger file.

### How It Works

```
Mount point: /atnlfs   (dm-7, 64KB)

Clean state:
  -rw-------. 1 root atnlfs 0 Mar 16 07:00 0x0   ← kernel file (green in TTY)

Violated state:
  -rw-------. 1 root atnlfs 0 Mar 16 07:00 0x1   ← kernel file (permanent, green in TTY)
```

### State Transitions

| Transition | Trigger | Reversible? |
|------------|---------|-------------|
| `0x0` → `0x1` | Nebuline attestation failure | ❌ No — permanent WORM lock |
| `0x1` → `0x0` | `fastboot flash atnlfs atnlfs.img` | ✅ Yes — but wipes data |

### Access Control Matrix

| Entity | Read | Write (`0x0` state) | Write (`0x1` state) |
|--------|------|--------------------|--------------------|
| End user / Apps | ❌ | ❌ | ❌ |
| `root` | ✅ | ✅ | ❌ |
| Nebuline daemon | ✅ | ✅ | ❌ |
| `atnlfs` kernel driver | ✅ | ✅ | ❌ |

### Effect on Applications

| ATNLFS State | Banking Apps | System Updates | General Apps |
|-------------|-------------|---------------|--------------|
| `0x0` | ✅ Work normally | ✅ Available | ✅ Work |
| `0x1` | ❌ Refuse to launch | ❌ Disabled | ✅ Work |

### OEM Cost Advantage

Physical eFUSE chips cost **$0.50–$2.00 per device** plus PCB redesign overhead. ATNLFS delivers equivalent warranty protection entirely in software, saving hardware vendors significant per-unit cost at scale.

---

## IPC Architecture — BinderFS

Tengrux uses **BinderFS** (Linux mainline, kernel 5.0+) as its primary IPC mechanism. Three isolated Binder domains are maintained:

| Domain | Path | Purpose |
|--------|------|---------|
| `binder` | `/dev/binderfs/binder0` | Application ↔ System Services |
| `hwbinder` | `/dev/binderfs/hwbinder0` | Hardware Abstraction Layer (HAL) |
| `vndbinder` | `/dev/binderfs/vndbinder0` | Vendor Services ↔ System |

Each domain carries its own SETengrux label set, maintaining strict isolation between layers.

---

## Tengrux Libc

A custom C library — **musl libc fork** — governed by two absolute architectural rules:

> **App Scoped Only** — No library lives in a global namespace. Every library belongs exclusively to its application.

> **Self-Dynamic Only** — Every application carries its own dynamic linker instance (`tlx-linker64`). There is no system-wide linker.

### tlx-linker64

Per-application dynamic linker written from scratch:

```
/data/app/<package.name>-<random_id>/
├── lib64/
│   ├── libtengrux.so      ← app's own libc instance
│   └── libfoo.so
├── bin/
│   └── myapp
└── linker/
    └── tlx-linker64       ← app's own linker instance
```

ELF `PT_INTERP` field: `/data/app/<package>-<id>/linker/tlx-linker64`

Zygote64 resolves and injects the UUID path before fork:

```c
setenv("TENGRUX_APP_ROOT",        "/data/app/com.example-A8F2D1", 1);
setenv("TENGRUX_LD_LIBRARY_PATH", "/data/app/com.example-A8F2D1/lib64", 1);
```

### Library Search Hierarchy

```
/system/lib64
/system/lib                              → symlink → /system/lib64
/vendor/lib64
/vendor/lib                              → symlink → /vendor/lib64
/product/lib64
/product/lib                             → symlink → /product/lib64
/data/app/<uuid>/lib64
/data/app/<uuid>/lib                     → symlink
/data/data/<uuid>/lib64
/system/app/<uuid>/lib64
/system/priv-app/<uuid>/lib64
/system/vendor/app/<uuid>/lib64
/system/vendor/priv-app/<uuid>/lib64
/system/product/app/<uuid>/lib64
/system/product/priv-app/<uuid>/lib64
```

### System Resource Isolation

```
/system/usr/
├── alsa/     → ALSA isolation layer   (Android convention)
└── nouveau/  → Nouveau GPU isolation layer
```

---

## Display & Audio Stack

### Surface Drawer

SurfaceFlinger equivalent — built on a **Wayland fork** (Tengrux Display Protocol).

- Bare-metal GPU access — no virtualization overhead
- Minimal title bar: app icon + name (left), `□` `X` buttons (right), upper edge slightly thicker
- Window snapping: drag to top → maximize; drag to sides → snap
- `Alt + drag` → move window from anywhere on its surface
- Nebuline alert mode: `#440000` glow border + `UNTRUSTED APP` title label
- Window open/close animations: 150–200ms

**Default fallback resolution (unrecognized display):** `1920×1080 @ 120Hz`

| Resolution | Refresh | Target |
|-----------|---------|--------|
| 1920×1080 (FHD) | 120Hz (fallback default) | All modern laptops |
| 2560×1440 (QHD/2K) | 120Hz+ | Mid-range |
| 3840×2160 (4K/UHD) | 120Hz+ | High-end |
| 7680×4320 (8K) | 120Hz+ | Future |
| 15360×8640 (16K) | 120Hz+ | Long-term |

### Audio Drawer

AudioFlinger equivalent — **written from scratch**.
- Multi-application audio stream mixing
- Device routing via `/system/usr/alsa/` isolation layer

### GPU Driver Support

| Vendor | Driver | Status |
|--------|--------|--------|
| Intel | `i915` (kernel mainline) | Default |
| AMD | `amdgpu` (kernel mainline) | Default |
| NVIDIA | Nouveau fork | Default (open) |
| NVIDIA | Proprietary | Optional — installed via SetupWizard / App Center |

---

## SystemUI & Launcher

Unlike Android's split model, Tengrux **SystemUI and Launcher are a single integrated process**: `com.tengrux.systemui`

```
com.tengrux.systemui
├── Wallpaper / Desktop layer
├── Launcher popup  ← Super key
│   ├── Folders      (desktop icons hidden while Launcher open — no Tab conflict)
│   ├── Fixed Apps   (pinned applications)
│   ├── App Drawer   (full application list)
│   └── Recently Used
├── Taskbar          (open application list with icons + labels)
└── System Tray      (network, audio, power, clock/date)
```

### Navigation Model

| Input | Action |
|-------|--------|
| Super key (press) | Open Launcher |
| Super key + type | Instant search |
| Enter | Launch selected app |
| `Alt + drag` | Move any window |
| Touchpad + `TOUCH_DRAW` permission | Pen/stylus mode |

---

## Application Layer

### Package Formats

| Format | Android Equivalent | Description |
|--------|--------------------|-------------|
| `.tpk` | `.apk` | Tengrux Package — single-piece application |
| `.tpks` | `.apks` | Split packages (language packs, feature modules) |
| `.xtpk` | `.xapk` | Application + large external data (games, offline content) |
| `.tab` | `.aab` | Tengrux App Bundle — build-time format, App Center optimizes |

### TRT — Tengrux RunTime

ART equivalent. **Written entirely from scratch** — not a fork of AOSP ART. Zero ART source code. Functionally equivalent runtime for Kotlin/VM-based `.tpk` applications. Fully proprietary.

### App Center

- `.tab` → `.tpk` conversion and x86_64 optimization
- Nebuline integration — cryptographic signature and permission risk verification on every install
- NVIDIA proprietary driver — optional installation flow
- Hybrid telemetry control: overview panel (App Center) + per-app controls (Settings)

### Tengrux Pony EXpress — tpex

APEX equivalent. Loop-mounted modular system components under `/tpex`. Managed by `tpexd` — written from scratch, no `apexd` dependency. Enables core system components (Tengrux Libc, TRT, media codecs) to be updated without reflashing `super.img`.

---

## System Tooling

| Tool | Role |
|------|------|
| **Toybox** | POSIX utilities — `ls`, `cp`, `mv`, `chmod`, `cat`... |
| **Toolbox** | Android-layer tools — `getprop`, `setprop`, `start`, `stop`, `logcat`, `am`, `pm` |
| **mksh** | System shell |
| **am** | Activity Manager — application and activity lifecycle management |
| **pm** | Package Manager — `.tpk` install, remove, permission management |
| **TDB** | Tengrux Debug Bridge — ADB equivalent |

---

## Image Set

Tengrux is distributed as **multiple `.img` files** — similar to Android's fastboot model. No ISO.

| Image | Location | Description |
|-------|----------|-------------|
| `boot.img` | XBOOTLDR | GKI kernel + GKI initramfs |
| `init_boot.img` | XBOOTLDR | Tengrux init ramdisk |
| `vendor_empty_boot.img` | — | **Stock placeholder** — vendors replace with `vendor_boot.img` |
| `vbmeta.img` | dm | Verified boot metadata |
| `vbmeta_system.img` | dm | system partition vbmeta |
| `vbmeta_vendor.img` | dm | vendor partition vbmeta |
| `vbmeta_product.img` | dm | product partition vbmeta |
| `super.img` | dm-0~3 | system + vendor + product container |
| `userdata.img` | dm-4~6 | Encrypted user data |
| `atnlfs.img` | dm-7 | ATNLFS WORM partition (64KB) |
| `persist.img` | dm-8 | Persistent calibration & DRM data |
| `metadata.img` | dm-9 | System metadata |
| `recovery.img` | dm-10 | Recovery environment |
| `tpex.img` | dm-11 | Tengrux Pony EXpress modules |
| `pvmfw.img` | dm-12 | Protected VM firmware |

---

## pKVM, TVD & DebTerm

### pKVM — Protected KVM

- Host Tengrux **cannot** inspect VM memory contents
- Only **Tengrux-signed** VM images can boot
- Nebuline authorizes every VM launch request
- Kernel does **not** support third-party hypervisors (VirtualBox, QEMU, VMware) — only pKVM is active

### TVD — Tengrux Virtual Device

AVD equivalent for Tengrux application development.

- TVD images only boot inside a signed TVD Host Hypervisor
- `vbmeta`: open-source base structure + Tengrux proprietary signing layer (closed)
- Provides a complete Tengrux development environment with TDB, `dev.tvc.viewer`, and developer tools enabled

### DebTerm

Crostini-equivalent protected Linux VM:

- **Debian** (stripped-down) + **MCS Enforcing SETengrux**
- Only `apt.tengrux.com` repositories — no standard Debian repos
- `com.tengrux.app.terminal` → mksh shell with `debterm` command to switch into VM
- `com.tengrux.app.debterm` → full VM manager (start, stop, storage, package management)
- Both visible in App Drawer

---

## Cell Broadcast

Emergency alert system — optional module, active only on laptops equipped with an LTE modem.

- Package: `com.tengrux.cell.broadcast`
- Stack: ModemManager + libmbim / libqmi
- Permission: `tengrux.permission.CELL_BROADCAST_RECEIVE` — system service only
- Alert display: Surface Drawer full-screen overlay with Audio Drawer alarm

---

## SetupWizard

First-boot experience:

| Step | Screen | Notes |
|------|--------|-------|
| 1 | Language Selection | System language |
| 2 | Theme Selection | `#440000` default + alternatives |
| 3 | Wi-Fi Connection | Optional — skippable |
| 4 | Tengrux Account | Optional — prompted twice; skipped after second refusal |
| 5 | Privacy + EULA + Nebuline Permissions | Nebuline permissions require explicit acceptance |
| 6 | Desktop | Boot logo fade-out → desktop fade-in |

---

## License Strategy

| Component | Base License | Tengrux License |
|-----------|-------------|----------------|
| Linux Kernel | GPL v2 | GPL v2 *(kernel level only — userspace unaffected)* |
| Tengrux Libc | MIT (musl fork) | Tengrux Proprietary |
| Tengrux Init | — (scratch) | Tengrux Proprietary |
| TRT | — (scratch) | Tengrux Proprietary |
| Surface Drawer | MIT (Wayland fork) | Tengrux Proprietary |
| Audio Drawer | — (scratch) | Tengrux Proprietary |
| ATNLFS | — (scratch) | Tengrux Proprietary |
| Nebuline | — (scratch) | Tengrux Proprietary |
| SETengrux policy + TVC | — (scratch) | Tengrux Proprietary |
| Limine bootloader | BSD-2-Clause | BSD-2-Clause |
| Toybox | BSD / Public Domain | Unchanged |
| mksh | BSD | Unchanged |
| ALSA | GPL v2 | Kernel level — userspace unaffected |
| Nouveau | GPL v2 | Kernel level — userspace unaffected |

---

## System Package List

All system packages follow the `com.tengrux.*` namespace convention.

### 🔴 Core System (~40 packages)
`zygote64` · `init` · `tpexd` · `servicemanager` · `hwservicemanager` · `vndservicemanager` · `surface.drawer` · `audio.drawer` · `nebuline` · `property.service` · `keystore` · `vold` · `installd` · `bootanim` · `recovery` · `fastbootd` · `pkvm`

### 🟠 Runtime & Libc (~20 packages)
`trt` · `libc` · `libc.crypto` · `libc.ssl` · `libc.media` · `libc.graphics` · `libc.net` · `linker64`

### 🟡 SystemUI & Launcher (~15 packages)
`systemui` · `wallpaper` · `setupwizard` · `lockscreen` · `notification` · `quicksettings` · `cell.broadcast` · `accessibility`

### 🟢 System Applications (~50 packages)
`app.files` · `app.thispc` · `app.storage` · `app.browser` · `app.mail` · `app.calendar` · `app.camera` · `app.gallery` · `app.music` · `app.video` · `app.recorder` · `app.notes` · `app.calculator` · `app.clock` · `app.contacts` · `app.settings` · `app.terminal` · `app.appcenter` · `app.taskmanager` · `app.updater` · `app.debterm`

### 🔵 Security & Privacy (~20 packages)
`security.nebuline.tdb` · `security.keyguard` · `security.permissionmgr` · `security.firewall` · `security.vpn` · `security.biometric` · `security.backup`

### 🟣 Hardware & HAL (~40 packages)
`hal.gpu.intel` · `hal.gpu.amd` · `hal.gpu.nouveau` · `hal.gpu.nvidia.installer` · `hal.audio.alsa` · `hal.audio.usb` · `hal.input.keyboard` · `hal.input.mouse` · `hal.input.touchpad` · `hal.input.touchscreen` · `hal.net.ethernet` · `hal.net.wifi` · `hal.net.bluetooth` · `hal.net.lte` · `hal.power.battery` · `hal.power.acpi` · `hal.thermal` · `hal.virt`

### ⚪ Services (~30 packages)
`service.location` · `service.print` · `service.sync` · `service.search` · `service.clipboard` · `service.font` · `service.time` · `service.dns` · `service.telemetry`

### 🔶 Developer Tools (~20 packages)
`dev.tdb` · `dev.fastboot` · `dev.logcat` · `dev.tvc.viewer` · `dev.shell` · `dev.bootstate`

> **Total: ~235 core packages + ~15–65 optional = 250–300 packages**

---

## Visual Identity

| Property | Value |
|----------|-------|
| **Theme Color** | `#440000` · ARGB: `#FF440000` · Deep crimson |
| **Mascot** | Bozkurt (Grey Wolf) — low-poly, deep crimson/burgundy |
| **Normal Boot Logo** | Frontal symmetric wolf · *SYSTEM SECURED & OPTIMIZED* · *Powered by TENGRUX* |
| **Kernel Panic Logo** | Side-profile wolf, exposed internal circuitry, neon red warning triangle, blue electric arcs · *No command* |
| **Boot Sequence** | Board POST screen → Limine (hidden) → Tengrux boot logo (center-bottom) → Desktop |
| **Boot Animation** | `/system/media/boot/bootanimation.zip` |

---

## Easter Egg

Tap the build number **7 times** in **Settings → About Tengrux** to unlock:

A snake game where:
- Eating the **Android mascot** → `GAME OVER`
- Eating the **Tengrux wolf** → screen flashes `#440000`, wolf logo appears, *"Congratulations, you beat Android!"*

---

## Development Roadmap

| Period | Phase |
|--------|-------|
| **2026 Q1–Q2** | Architecture & planning *(current phase)* |
| **July 2026** | Full development begins — internal prototyping, core system implementation |
| **Late 2026** | First experimental builds available to contributors |

---

## Contributing

Tengrux follows a **semi-open development model**.

- Core architecture decisions are maintained by the project lead
- Technical discussions are public via [GitHub Discussions](https://github.com/XPR01423/tengrux/discussions)
- Code contributions will open once the first internal prototype exists

**Right now you can help by:**

- ⭐ Starring the repository to show interest
- 💬 Joining architecture discussions
- 🔍 Reviewing the technical specification and providing feedback
- 🐛 Opening issues for architectural concerns or questions

---

## Project Status

> Tengrux is in early architectural research. No production builds exist yet.
> Everything in this repository is experimental and subject to change.

---

<div align="center">

*Built for the Future. Powered by Tengrux.*

**github.com/XPR01423/tengrux**

</div>

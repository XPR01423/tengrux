# Tengrux OS
### A Hybrid x86_64 Desktop & Laptop Operating System

> **Status:** 🏗️ Architecture & Planning Phase
> **Target:** Modern x86_64 Desktop & Laptop Hardware
> **Kernel:** Linux (Mainline)
> **Theme:** `#440000`
> **Distribution Format:** `.img` (not ISO) — flashed via `fastboot` or `dd`

---

## What is Tengrux?

Tengrux is an experimental hybrid operating system built on the Linux kernel, designed exclusively for modern x86_64 desktop and laptop hardware.

It is not a Linux distribution. It is a ground-up rethinking of the Linux user-space — combining the structural discipline and security model of Android's system architecture with the performance characteristics of minimalist Linux systems, without carrying Android's mobile assumptions or Google's dependencies.

**Name origin:** Tengri (Göktanrı — Turkic sky god) + Unix = **Tengrux**

---

## Core Design Philosophy

> *"Do not carry someone else's assumptions."*

Every component in Tengrux is either purpose-built from scratch or carefully forked and stripped of upstream dependencies that do not belong on a desktop system. This applies to the C library, the dynamic linker, the package runtime, the init system, and the security framework.

- x86_64 only — no legacy 32-bit support (`/lib` → `/lib64` symlink for compatibility)
- Immutable system core (EROFS, read-only partitions)
- Android-hybrid security and isolation model
- Redistributable OS — no activation, no license server
- Global target — multi-language via per-app Kotlin i18n
- `locale=C` system-wide — language management delegated to the application layer
- No physical eFUSE chip required — ATNLFS provides software-equivalent warranty

---

## Filesystem Hierarchy (system-as-root)

Tengrux uses Android-style system-as-root. `/` is directly mounted from `dm-1` (system, EROFS). `/system` is a symlink to `/`.

```
/ (= /system, dm-1, EROFS, read-only)
├── atnlfs        → dm-7  | ATNLFS Triggered WORM partition
├── tpex          → dm-11 | Tengrux Pony EXpress (APEX equivalent)
├── bin           →        | symlink to /system/bin
├── cache         →        | tmpfs
├── d             →        | symlink to /sys/kernel/debug
├── data          → dm-5  | Encrypted user data (ext4/F2FS, RW)
├── debug_ramdisk →        | Active only in userdebug/eng builds
├── dev           →        | devtmpfs
├── etc           →        | symlink to /system/etc
├── mnt           →        | Mount points
├── oem           →        | STUB — OEM customization placeholder
├── persist       → dm-8  | Persistent calibration & DRM data (ext4, RW)
├── proc          →        | procfs
├── product       → dm-3  | Product overlay (EROFS, RO)
├── recovery      → dm-10 | Recovery environment (EROFS, RO)
├── root          →        | STUB — root home placeholder
├── sbin          →        | Critical system binaries (root only)
├── xbin          →        | Extended binaries (tcpdump, sqlite3...)
├── sdcard        →        | symlink to /storage/emulated/0
├── storage       → dm-6  | External & emulated storage (RW)
├── super         → dm-0  | Dynamic partition container symlink
├── sys           →        | sysfs
├── system        →        | symlink to /
├── tmp           →        | tmpfs
└── vendor        → dm-2  | Hardware drivers & HAL (EROFS, RO)
```

---

## Disk Architecture

### Physical Partitions (GPT — 2 partitions only)

| Partition | Role | Contents |
|-----------|------|----------|
| `sda1` | ESP — EFI System Partition | Limine bootloader (minimal) |
| `sda2` | XBOOTLDR — Extended Boot Loader | `boot.img` + `init_boot.img` |

### Device Mapper Layout (dm-0 ~ dm-57)

All system volumes live under Device Mapper, initialized by `dm_linear_setup` inside initramfs:

```
Physical disk (LBA addresses)
    │
    ├── dm-0  (super)          Container — system/vendor/product
    │     ├── dm-1  (system)        EROFS      /            RO
    │     ├── dm-2  (vendor)        EROFS      /vendor      RO
    │     └── dm-3  (product)       EROFS      /product     RO
    │
    ├── dm-4  (userdata)       Container — data/storage
    │     ├── dm-5  (data)          ext4/F2FS  /data        RW
    │     └── dm-6  (storage)       ext4/F2FS  /storage     RW
    │
    ├── dm-7  (atnlfs)         ATNLFS     /atnlfs      RW→RO
    ├── dm-8  (persist)        ext4       /persist      RW
    ├── dm-9  (metadata)       -          /metadata     RW
    ├── dm-10 (recovery)       EROFS      /recovery     RO
    ├── dm-11 (tpex)           -          /tpex         RO
    ├── dm-12 (pvmfw)          -          /pvmfw        RO
    │
    └── dm-13 ~ dm-57          OEM optional partitions
```

---

## Boot Chain

```
UEFI Firmware
    └── ESP (sda1) → Limine [hidden, timeout=0]
            └── XBOOTLDR (sda2)
                    ├── boot.img      (kernel + initramfs)
                    └── init_boot.img (init ramdisk)
                            └── Linux Kernel
                                    └── initramfs: dm_linear_setup
                                            └── All dm devices created
                                                    └── Tengrux Init (PID 1)
                                                            ├── BinderFS mount
                                                            ├── SETengrux policy load
                                                            ├── Property Service
                                                            ├── tpexd
                                                            └── Zygote64
```

### Boot Log Format

```
[    0.123456] BinderFS: binder0 initialized
[    0.234567] ATNLFS: kernel file 0x0 present
[    0.345678] Nebuline: boot attestation started
[    0.345679] Nebuline: 1/5 SELinux mode: ENFORCING ✅
[    0.345680] Nebuline: 2/5 Verified Boot: GREEN ✅
[    0.345681] Nebuline: 3/5 su binary: NOT FOUND ✅
[    0.345682] Nebuline: 4/5 /system hash: MATCH ✅
[    0.345683] Nebuline: 5/5 init hash: MATCH ✅
[    0.345684] Nebuline: attestation passed. ATNLFS: 0x0
[    1.000000] Tengrux: boot complete 🐺
```

### Boot State System

| State | Condition | Result |
|-------|-----------|--------|
| 🟢 **GREEN** | Fully verified | Normal boot — *SYSTEM SECURED & OPTIMIZED* |
| 🟡 **YELLOW** | User key present | Boot with warning — developer/custom ROM |
| 🟠 **ORANGE** | Bootloader unlocked | Warranty burned — warning screen shown |
| 🔴 **RED** | ATNLFS `0x1` active | Force wipe → warning splash → limited boot |

#### RED State Behavior

When ATNLFS `0x1` is written:

1. **Force Wipe** — userdata partition wiped automatically
2. **Warning splash** shown before every subsequent boot:

```
⚠️  Warning

This desktop is not running Tengrux's official software.
You may have problems with features or security,
and you won't be able to install software updates.
```

3. System continues to boot — user is **not** locked out
4. Banking apps and critical system apps refuse to launch
5. General applications continue to work normally

---

## Security Architecture

### SETengrux

SETengrux is Tengrux's security enforcement framework — built on SELinux (Linux mainline) with Tengrux-specific MCS policy, audit engine, and Nebuline integration.

```
SELinux (kernel)
    └── + Tengrux MCS policy
    └── + TVC audit engine        (replaces avc:)
    └── + Nebuline integration
    └── + TVD isolation categories
    = SETengrux
```

#### TVC Audit Engine

```
tvc: denied { connectto } for pid=1234 comm="my_app"
    scontext=u:r:untrusted_app:s0:c0,c1
    tcontext=u:r:local_network_service:s0:c2,c3
    tclass=unix_stream_socket
```

#### MCS Process Isolation

```
Zygote64 (sealed)
    ├── u0_a<UID>  s0:c0,c1     → Application Layer
    ├── u0_i<UID>  s0:c2,c3     → Isolated Services
    └── tvd_vm     s0:c512,c513 → TVD instances
```

### Rollback Protection Index (RPI)

API-level downgrade protection. Rolling back from API 2 → API 1 is blocked. Integrated with the secure boot chain.

---

## Nebuline Gatekeeper

Knox-equivalent software security and warranty layer. Runs at every boot like `fsck` — but for security integrity.

### Boot Attestation (5 checks per boot)

| Check | Target | Pass Condition |
|-------|--------|---------------|
| 1/5 | SELinux mode | Must be `ENFORCING` |
| 2/5 | Verified Boot State | Must be `GREEN` |
| 3/5 | `su` binary | Must NOT exist in PATH |
| 4/5 | `/system` hash | Must match dm-verity hash |
| 5/5 | `init` hash | Must match expected hash |

Any failure → ATNLFS `0x1` → force wipe → RED state

### Additional Responsibilities

- USB TDB scanning — malware detection on USB insertion
- App Center install scanning — signature & permission verification
- Permission risk analysis — dangerous combination detection
- `tengrux.security.attestation` API — `isSystemIntegrity()` → `true/false`
- pKVM VM launch authorization
- Vendor Partner Program — OEM ROMs can obtain Nebuline signing

---

## ATNLFS — Advanced Tengrux Nebuline File System

**Triggered WORM** filesystem. Locks the entire filesystem based on a kernel-level trigger file.

### State Model

```
Clean system:     -rw-------. 1 root atnlfs 0 Mar 16 07:00 0x0
Violation:        -rw-------. 1 root atnlfs 0 Mar 16 07:00 0x1  (permanent)
```

| State | Filesystem | Banking Apps |
|-------|-----------|-------------|
| `0x0` | RW — normal | ✅ Work |
| `0x1` | Permanently RO | ❌ Refused |

- Transition `0x0` → `0x1` is **irreversible** (only `fastboot flash atnlfs` resets it)
- Write access: `root`, `Nebuline`, `atnlfs` kernel driver only
- Size: **64KB** on dm-7
- **OEM advantage:** Eliminates physical eFUSE chip ($0.50–$2.00 saved per device)

---

## IPC Architecture — BinderFS

| Domain | Path | Purpose |
|--------|------|---------|
| `binder` | `/dev/binderfs/binder0` | Application ↔ System Services |
| `hwbinder` | `/dev/binderfs/hwbinder0` | HAL |
| `vndbinder` | `/dev/binderfs/vndbinder0` | Vendor Services ↔ System |

---

## Tengrux Libc

musl libc fork with two absolute rules:

**App Scoped Only** — No global namespace. Every library belongs to its application.

**Self-Dynamic Only** — Every app carries its own `tlx-linker64`. No system-wide linker.

```
/data/app/<package>-<id>/
├── lib64/libtengrux.so
├── bin/myapp
└── linker/tlx-linker64
```

`PT_INTERP`: `/data/app/<package>-<id>/linker/tlx-linker64`

---

## Display & Audio Stack

### Surface Drawer
Wayland fork — Tengrux Display Protocol.
- Default fallback: **1920×1080 @ 120Hz**
- Supported: FHD / QHD / 4K / 8K / 16K @ 120Hz+
- Nebuline alert: `#440000` glow border + `UNTRUSTED APP`

### Audio Drawer
Written from scratch. ALSA isolation via `/system/usr/alsa/`.

### GPU Support

| Vendor | Driver | Status |
|--------|--------|--------|
| Intel | i915 | Default |
| AMD | amdgpu | Default |
| NVIDIA | Nouveau fork | Default |
| NVIDIA | Proprietary | Optional via App Center |

---

## SystemUI & Launcher (Integrated)

Single process `com.tengrux.systemui` — unlike Android's split model.

- Launcher: Super key → open, type → search, Enter → launch
- Touchpad: `tengrux.permission.TOUCH_DRAW` → pen/stylus mode
- Desktop icons hidden while Launcher is open (no Tab conflict)

---

## Application Layer

| Format | Android Equiv. | Description |
|--------|---------------|-------------|
| `.tpk` | `.apk` | Tengrux Package |
| `.tpks` | `.apks` | Split packages |
| `.xtpk` | `.xapk` | App + external data |
| `.tab` | `.aab` | App Bundle (build-time) |

**TRT (Tengrux RunTime)** — ART equivalent, written entirely from scratch. Zero ART source code.

---

## pKVM, TVD & DebTerm

### TVD — Tengrux Virtual Device
AVD equivalent. TVD images only boot inside a signed TVD Host Hypervisor. Kernel does not support third-party hypervisors — only pKVM is active.

### DebTerm
Crostini-equivalent VM: Debian (stripped) + MCS SETengrux + `apt.tengrux.com` only.

---

## Image Set

| Image | Description |
|-------|-------------|
| `boot.img` | Kernel + initramfs → XBOOTLDR |
| `init_boot.img` | init ramdisk → XBOOTLDR |
| `vbmeta*.img` (×4) | Verified boot metadata |
| `super.img` | system + vendor + product → dm-0~3 |
| `userdata.img` | User data → dm-4~6 |
| `atnlfs.img` | WORM partition → dm-7 (64KB) |
| `persist.img` | Calibration → dm-8 |
| `metadata.img` | Metadata → dm-9 |
| `recovery.img` | Recovery → dm-10 |
| `tpex.img` | TPEx modules → dm-11 |
| `pvmfw.img` | VM firmware → dm-12 |

---

## License Strategy

| Component | License |
|-----------|---------|
| Linux Kernel | GPL v2 (kernel level only) |
| Tengrux Libc, Init, TRT, Surface Drawer, Audio Drawer, ATNLFS, Nebuline, SETengrux | Tengrux Proprietary |
| Limine | BSD-2-Clause |
| Toybox, mksh | BSD / Public Domain |
| ALSA, Nouveau | GPL v2 (kernel level — userspace unaffected) |

---

## Development Roadmap

| Period | Phase |
|--------|-------|
| 2026 Q1–Q2 | Architecture planning *(current)* |
| July 2026 | Full development begins |
| Late 2026 | First experimental builds |

---

## Project Status

No production builds exist yet. Everything here is experimental and subject to change.

---

*Built for the Future. Powered by Tengrux.*

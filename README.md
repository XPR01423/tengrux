Tengrux OS
A Hybrid x86_64 Operating System — Android Architecture Meets Desktop Linux
Status: 🏗️ Architecture & Planning Phase
Target: Modern x86_64 Desktop Hardware
Kernel: Linux (Mainline)
Theme: #440000
What is Tengrux?
Tengrux is an experimental hybrid operating system built on the Linux kernel, designed exclusively for modern x86_64 desktop hardware.
It is not a Linux distribution. It is a rethinking of the Linux user-space from the ground up — combining the structural discipline and security model of Android's system architecture with the performance characteristics of minimalist Linux systems.
Tengrux borrows proven concepts from Android (RootFS hierarchy, BinderFS IPC, dm-verity, EROFS immutable partitions, dynamic partitions via Device Mapper) and re-engineers them for the desktop without carrying Android's mobile assumptions or Google's dependencies.
Core Design Philosophy
"Do not carry someone else's assumptions."
Every component in Tengrux is either purpose-built or carefully forked and cleaned of upstream dependencies that do not belong on a desktop system. This applies to the C library, the dynamic linker, the package runtime, and the init system.
Filesystem Hierarchy
/
├── tpex           → Tengrux Pony EXpress (modular system packages, like APEX)
├── bin            → Symlink to /system/bin (POSIX shebang compatibility)
├── cache          → Temporary system cache
├── d              → Symlink to /sys/kernel/debug (developer shortcut)
├── data           → Encrypted user data and application storage
├── debug_ramdisk  → Active only in userdebug/eng builds; empty in production
├── dev            → Device nodes
├── etc            → System configuration
├── mnt            → Mount points
├── oem            → Read-only OEM customization layer (wallpapers, configs)
├── proc           → Kernel process information (procfs)
├── product        → Product-specific overlays (read-only, EROFS)
├── recovery       → Recovery environment
├── root           → Root home directory
├── sbin           → Critical system binaries (init, mount, mke2fs — root only)
├── xbin           → Extended binaries (tcpdump, sqlite3, advanced shell tools)
├── sdcard         → Symlink to user storage
├── storage        → External and emulated storage mount points
├── sys            → Kernel sysfs interface
├── system         → Immutable core OS (read-only, EROFS)
├── tmp            → Temporary files
└── vendor         → Hardware-specific drivers and HAL components (read-only, EROFS)
Directory Notes
Directory
Description
/tpex
Tengrux Pony EXpress — equivalent to Android's /apex. Hosts modular, independently updatable system components mounted as loop devices. Managed by tpexd.
/xbin
Extended binaries for power users and system tooling. Keeps /sbin clean and minimal.
/oem
Read-only OEM layer. Hardware vendors can ship customizations without touching the core system image.
/debug_ramdisk
Mounted only in userdebug and eng build variants. Not present in production.
/d
Symlink to /sys/kernel/debug. Fast debugfs access for kernel developers.
/bin
Symlink to /system/bin. Ensures compatibility with traditional POSIX scripts using #!/bin/sh.
Disk Architecture
Tengrux uses a two-partition physical layout with all logical volumes managed by the Linux Device Mapper.
Physical Partitions (GPT)
Partition
Role
sda1
ESP — EFI System Partition
sda2
XBOOTLDR — Extended Boot Loader partition (kernel + initramfs)
Logical Volumes (Device Mapper)
All system volumes live under Device Mapper (/dev/block/dm-0 through dm-57):
/dev/block/
├── dm-0   → super (container)
├── dm-1   → system   (EROFS, read-only, dm-verity protected)
├── dm-2   → vendor   (EROFS, read-only, dm-verity protected)
├── dm-3   → product  (EROFS, read-only, dm-verity protected)
├── dm-4   → userdata (ext4/F2FS, read-write, encrypted)
├── dm-5   → recovery
│   ...
└── dm-57  → (last logical volume)
This design keeps the physical partition table minimal and clean while retaining full flexibility through Device Mapper.
Boot Architecture
Bootloader
Bootloader: systemd-boot (ESP) — silent, no menu shown to end users
XBOOTLDR: Hosts kernel images and initramfs
Boot behavior: timeout 0 — instant, invisible boot for production builds
GRUB: Absent from normal boot chain; reserved for recovery scenarios only
Boot Chain
UEFI Firmware
    └── ESP (sda1) → systemd-boot [hidden]
            └── XBOOTLDR (sda2) → kernel + initramfs
                    └── Linux Kernel
                            └── init (PID 1) — Android init fork, cleaned
                                    ├── BinderFS mount
                                    ├── SELinux policy load
                                    ├── Property Service
                                    ├── tpexd (Tengrux Pony EXpress daemon)
                                    └── Zygote64
Verified Boot
dm-verity: Block-level integrity verification on all read-only partitions
vbmeta: Kernel and system image signature verification
RBPI (Rollback Protection Index): Prevents downgrade attacks via secure boot chain integration
Security Architecture
MLS SELinux
Tengrux enforces Multi-Level Security SELinux across all system and user processes. Label-based policy enforcement governs every IPC channel, file access, and process boundary.
Process Isolation & UID Hierarchy
Zygote64 (sealed)
    ├── u0_a<UID>   → Application Layer
    │                 Dynamically assigned UIDs
    │                 Each app lives in its own isolated sandbox
    │
    └── u0_i<UID>   → Isolated Services Layer
                      Low-privilege, computation-only services
                      No direct system resource access
                      Bypasses Zygote for daemon workloads
All child processes are forked from a sealed Zygote64 instance with explicitly defined Linux Capabilities.
Nebuline Gatekeeper
Nebuline is Tengrux's planned security and IPC regulation layer.
Its responsibilities:
Regulate inter-process communication across BinderFS channels
Enforce application permission boundaries at runtime
Provide an additional security check layer above SELinux policy
Nebuline is currently in early design. Its architecture will be defined during the core development phase.
IPC Architecture — BinderFS
Tengrux uses BinderFS (Linux mainline, kernel 5.0+) as its primary IPC mechanism.
Three isolated Binder domains are maintained:
Domain
Path
Purpose
binder
/dev/binderfs/binder0
Application ↔ System Services
hwbinder
/dev/binderfs/hwbinder0
Hardware Abstraction Layer (HAL)
vndbinder
/dev/binderfs/vndbinder0
Vendor Services ↔ System
Each domain carries its own SELinux label set, maintaining strict isolation between layers.
Software Stack
System Tooling
Tool
Role
Toybox
POSIX utilities (ls, cp, mv, chmod, cat...)
Toolbox
Android-layer tools (getprop, setprop, start, stop, logcat, am, pm)
mksh
System shell
Property Service
Tengrux inherits Android's property service model via the init fork:
init (PID 1)
    └── property_service
            └── /dev/socket/property_service
                    ├── setprop (write)
                    └── getprop (read)
SELinux enforces which processes may read or write which properties.
Service Managers
servicemanager     → binder0   (Application ↔ System)
hwservicemanager   → hwbinder0 (HAL layer)
vndservicemanager  → vndbinder0 (Vendor layer)
Tengrux Libc
Tengrux Libc is a custom C library — a musl fork, rebuilt from the ground up with two absolute architectural rules:
App Scoped Only: No library lives in a global namespace. Every library belongs to its application.
Self-Dynamic Only: Every application carries its own dynamic linker instance. There is no system-wide linker.
tlx-linker64
tlx-linker64 is Tengrux's custom dynamic linker. It replaces the system-wide ld-musl with a per-application linker namespace manager.
/data/app/<uuid>/
├── lib64/
│   ├── libtengrux.so    ← application's own libc instance
│   └── libfoo.so
├── bin/
│   └── myapp
└── linker/
    └── tlx-linker64     ← application's own linker
ELF binaries reference their own linker via PT_INTERP:
PT_INTERP: /data/app/<uuid>/linker/tlx-linker64
This eliminates shared library conflicts at the system level entirely.
Design Targets
Property
Target
Base
musl libc fork
Footprint
< 1MB
Namespace model
App-Scoped (no global namespace)
Linker model
Self-Dynamic (per-app linker instance)
Syscall model
Direct kernel syscalls (musl-style)
Tengrux Pony EXpress (tpex)
/tpex hosts modular, independently updatable system components — conceptually equivalent to Android's /apex.
Each module is a .tpk package, loop-mounted at boot, managed by tpexd.
This allows core system components (Tengrux Libc, ART, media codecs) to be updated without reflashing the system image.
tpexd
tpexd is the Tengrux Pony EXpress daemon — written from scratch, with no apexd dependency.
Its responsibilities:
Mount /tpex modules at boot
Verify module integrity
Manage module lifecycle (install, update, remove)
Application Runtime — Tengrux ART
Tengrux targets Kotlin/VM-based .tpk application packages.
The runtime is based on AOSP ART with x86_64 backend — actively maintained by Google for the Android Emulator, ChromeOS (ARC++), and GSI targets.
This is not a port — AOSP ART already ships a production-grade x86_64 backend. Tengrux forks and cleans it of Android-specific dependencies, producing Tengrux ART: a standalone ART runtime for x86_64 desktop systems.
Image Set
Image
Description
boot.img
Kernel + initramfs
init_boot.img
init ramdisk (separated from kernel)
vbmeta.img
Verified boot metadata
super.img
Dynamic partition container (system + vendor + product)
userdata.img
User data partition
recovery.img
Recovery environment
pvmfw.img
Protected VM firmware
Visual Identity
Theme Color: #440000 (ARGB: #FF440000)
Mascot: The Tengrux Wolf — a low-poly wolf rendered in deep crimson tones.
Two canonical forms:
Variant
Context
Description
Boot Logo
Normal boot
Frontal, symmetric wolf. Monospaced typography: SYSTEM SECURED & OPTIMIZED / Powered by / Tengrux
Kernel Panic
System fault
Side-profile wolf with exposed internal circuitry — gold circuit traces, neon red warning triangle, blue electric arcs. Pure black background.
Development Roadmap
Period
Phase
2026 Q1–Q2
Architecture planning — RootFS, libc, security model, IPC design
July 2026
Full development begins — internal prototyping, core system implementation
Late 2026
First experimental builds for contributors
Contribution Model
Tengrux follows a semi-open development model.
Core architecture decisions are maintained by the project lead
Technical discussions are public
Contributors can participate via Issues and Discussions
At this stage, you can help by:
⭐ Starring the repository
💬 Participating in technical discussions
🔍 Reviewing the architecture and providing feedback
Project Status
Tengrux is in early architectural research. No production builds exist yet.
Everything here is experimental and subject to change.
Built for the Future. Powered by Tengrux.

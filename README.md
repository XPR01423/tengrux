TENGRUX: A Modern x86_64 User-Space Experiment
Status: 🏗️ [Planning / Roadmap Phase]
TENGRUX is an independent operating system project built on the Linux kernel, specifically designed for x86_64 architecture. It aims to combine the structural robustness of Android's system hierarchy with the flexibility and performance of minimalist Linux distributions.
🚀 Core Philosophy (The Plan)
Tengrux is not just another distribution; it's a re-imagining of the Linux user-space.
x86_64-Only: Focus is entirely on modern x86_64 hardware. No legacy 32-bit bloat. Optimized for x86-64-v3 and above.
Immutable System: Leveraging an immutable /system partition (EROFS) to ensure stability and security.
Android-Inspired Isolation: Implementing u0_a style application sandboxing at the kernel level for advanced security.
Custom Libc Architecture: A specialized musl libc based environment featuring an app-scoped linker, inspired by Android’s Bionic.
🛠 Planned Architecture
1. RootFS Hierarchy
Tengrux moves away from traditional /etc hantallığı. We are planning a clean, partition-based logic:
/system: Immutable core files.
/data: Encrypted user workspace.
/vendor: Hardware-specific drivers and blobs.
2. Security (Nebuline Gatekeeper)
The Nebuline layer is being designed as the primary gatekeeper for process communication and permissions, keeping the system lightweight and secure.
📅 Roadmap (2026 Strategy)
Q1-Q2 2026: Finalizing technical specifications, Libc research, and RootFS architecture design. (Current Phase)
July 2026: Official start of the full-scale development phase and internal prototyping.
Late 2026: Early experimental builds for contributors.
🤝 Community & Contribution
Since we are in the Planning Phase, the best way to contribute right now is:
Star the repo to follow the development progress.
Join the discussions on technical architecture (Libc, Init systems, etc.).
"Built for the Future. Powered by TENGRUX."

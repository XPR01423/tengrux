Tengrux OS

A Modern x86_64 User-Space Experiment

Status: 🏗️ Planning / Architecture Phase

Tengrux is an experimental operating system project built on the Linux kernel and designed specifically for modern x86_64 hardware.
The goal of the project is to explore a new Linux user-space model that combines the structural discipline of Android's system architecture with the simplicity and performance of minimalist Linux systems.

Rather than being just another Linux distribution, Tengrux is an architectural experiment focused on security, isolation, and long-term system stability.

---

Vision

The long-term goal of Tengrux is to rethink how Linux user-space is structured on desktop hardware.

The project explores ideas such as:

- immutable core systems
- application-level isolation
- simplified filesystem hierarchy
- predictable system updates

Tengrux aims to create a clean and modern system design inspired by Android while remaining fully compatible with the Linux ecosystem.

---

Core Design Principles

x86_64 Focus

Tengrux targets modern x86_64 systems only.

Legacy 32-bit compatibility layers are intentionally excluded to keep the system smaller, faster, and easier to maintain.

Planned optimization targets:

- x86-64-v3 baseline
- modern CPU instruction sets
- contemporary desktop hardware

---

Immutable Core System

The system core will reside in an immutable "/system" partition powered by EROFS.

Benefits include:

- improved reliability
- predictable upgrades
- protection against accidental system modification
- stronger security guarantees

User data and runtime state remain fully writable.

---

Android-Inspired Isolation

Tengrux explores Android-style application sandboxing.

Applications are intended to run under dedicated UID namespaces similar to Android’s "u0_aXXXX" model, providing stronger process isolation compared to traditional desktop environments.

The goal is to significantly reduce the impact of compromised applications.

---

Custom Libc Environment

Tengrux plans to use a musl-based libc environment with architectural changes inspired by Android’s Bionic runtime.

Concepts being explored:

- application-scoped dynamic linker
- isolated runtime environments
- simplified dependency resolution

This layer is still under heavy research.

---

System Architecture (Concept)

Planned filesystem layout:

/system   → Immutable core operating system
/data     → Encrypted user data and application storage
/vendor   → Hardware specific drivers and components

This model aims to provide a clean separation between system integrity and user space flexibility.

---

Nebuline Gatekeeper (Security Layer)

Tengrux introduces a planned security component called Nebuline.

Nebuline is designed as a lightweight process communication and permission control layer.

Its role is to:

- regulate inter-process communication
- enforce application boundaries
- provide additional security checks

The design is still experimental and subject to change.

---

Development Roadmap

2026 Q1 – Q2

Architecture planning phase

- RootFS design
- libc architecture research
- security model exploration

July 2026

Start of full development phase

- internal prototyping
- core system implementation

Late 2026

First experimental builds for contributors

---

Contribution Model

Tengrux follows a semi-open development model similar to projects like Android.

This means:

- core architecture decisions are maintained by the project lead
- development discussions remain public
- contributors can participate through issues, discussions, and future code contributions

At the current planning stage, you can help by:

- starring the repository
- participating in technical discussions
- sharing architectural feedback

---

Project Status

Tengrux is currently an early architectural research project.

No production-ready builds exist yet.

Everything in this repository should be considered experimental.

---

License

License information will be defined once the development phase begins.

---

Built for the Future.
Powered by Tengrux.

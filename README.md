# µHTTP (uhttp)

> *Status: Active Pre-Beta Development — Core Networking Engine for the µSystems Ecosystem*

![file_read](./examples/fileread.png)

A bare-metal, zero-dependency, zero-copy, no-AI-slop, highly concurrent HTTP/1.1 framework written in pure x86-64 assembly for Linux. No libc, no runtime, no bloated dependencies. Just direct syscalls, raw registers, and maximum hardware efficiency.

Originally conceived as a pure deep-dive exercise in x86-64 assembly, **µHTTP** has evolved into the foundational networking layer for [µSystems](https://github.com/u-systems) and will serve as the production HTTP engine under the hood of [µShield](https://github.com/u-systems/ushield).

---

## What?

`µHTTP` is a web server engineered in pure assembly from scratch. It utilizes a shared-nothing, process-per-core architecture where each worker pins to a CPU core, managing incoming requests inside fixed-size ring buffers without touching the heap or depending on external C libraries.

## Why?

* **From Fun Project to Core Infrastructure:** What started as a challenge to see how far raw assembly could be pushed is now a critical building block. Instead of relying on third-party C libraries or bulky runtimes, `µHTTP` provides a completely dependency-free, high-throughput networking layer for the entire `µSystems` stack.
* **For Discipline and First Principles:** In today's tech world, everything has become absurdly cushioned by layers upon layers of abstractions, package managers, and AI assistants doing the heavy lifting. This project goes back to the roots to explore what the CPU and kernel can do when nothing sits in between. *"Hard time make strong man, strong man make good time, good time make weak man, weak man write asm."*
* **Tired of Modern Stack Bloat:** It is ridiculous that modern backend stacks require a 500 MB+ download, hundreds of megabytes of resident RAM, and thousands of nested function calls just to listen on a TCP socket and serve a small payload. `µHTTP` proves a complete web server can live in single-digit kilobytes of memory and less.

---

## How?

* **100% Handwritten:** Crafted instruction by instruction in GNU Assembler (`as`).
* **No AI Code Generation:** Built manually by reading kernel dev man pages (`man 2 socket`, `man 2 sendfile`, `man 2 sched_setaffinity`) and digging through System V ABI documentation just like in the good ol' days.
* **Zero libc & Zero Dependencies:** No C runtime startup code, no `printf`, and no dynamic allocators. Every syscall uses `syscall` instructions directly.

---

## Technical Targets & Goals

* **Peak Physical Throughput:** Push requests-per-second directly to the physical limits of the network interface.
* **Minimal Memory Footprint:** Under 150 KB of total resident memory across all static ring buffers and state structs. All sizes are hardcoded and easily tunable.
* **Near-Zero Disk Footprint:** An executable measured in hundreds of bytes rather than megabytes (~300 Bytes target for the entire ELF binary).
* **Zero-Overhead RFC Security:** Strict protocol validation and exploit defense baked directly into parser bitmasks without sacrificing CPU cycles.
* **Native Ecosystem Integration:** Designed to plug directly into `µShield` as an unprivileged, self-sealed networking engine (`ushieldd-http`).

---

## What Can It Already Do? (Pre-Beta Prototype)

* **Raw Socket Lifecycle:** Full setup using `sys_socket`, `sys_setsockopt` (`SO_REUSEADDR`), `sys_bind`, and `sys_listen`.
* **Zero-Copy HTTP Parser:** Custom parser decoding verbs (`GET`, `POST`, `HEAD`, `PUT`, `DELETE`), protocol versions, paths, query strings, headers, and bodies directly off the wire.
* **RFC 9112 Request Smuggling Prevention:** Strict compliance with RFC 9112 Section 6.1 by detecting and rejecting requests containing both `Transfer-Encoding: chunked` and `Content-Length` via `REQ_F_ERR_SMUGGLING`.
* **Host Header Injection Defense:** Immediate detection and flagging of duplicate `Host` headers (`REQ_F_ERR_MULTI_HOST`) to block host spoofing and cache poisoning.
* **Path Traversal Scanning:** Inline scanning for `../` sequences during URI parsing to flag directory traversal attempts (`REQ_F_ERR_BAD_URI`).
* **Payload & Header Bounds Protection:** Strict enforcement of maximum header counts (`MAX_OTHER_HDRS`), body limits (`MAX_BODY_SIZE`), and bad protocol versions with instant rejection routing via `REQ_F_ERR_MASK`.
* **64-Byte Aligned Structs:** Cache-line friendly `http_request` state blocks matched 1:1 with 2 KB wire buffers.
* **Bitmask Slot Allocator:** Fast, lock-free slot claiming via single-cycle bitwise instructions (`tzcnt`, `bts`, `btr`).
* **True Zero-Copy File Serving:** Fast disk streaming using `sys_open`, `sys_fstat` for dynamic file sizing, and `sys_sendfile64` directly out of the page cache.
* **Vector Responses:** Scatter-gather response header construction and streaming via `sys_writev`.
* **Core Pinning:** Multi-process worker orchestration with `sys_sched_setaffinity`.

---

## Development Roadmap & Next Steps

- [ ] **Asynchronous epoll Loop:** Edge-triggered (`EPOLLET`) event loops to handle thousands of concurrent idle connections per core.
- [ ] **Direct DMA / Kernel-Bypass:** Bypassing standard socket queues via `io_uring` or `AF_XDP` rings for hardware-level delivery.
- [ ] **Handcrafted ELF Header:** Replacing `GNU ld` output with a custom binary header crafted byte-by-byte in assembly to drop file size down to absolute physical minimums.
- [ ] **Developer DSL:** Ergonomic assembly macros for defining routes, custom middleware, and status returns cleanly.

---

## License

MIT License. Developed independently by [tralsesec](https://github.com/tralsesec) under [µSystems](https://github.com/u-systems).

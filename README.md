# Metronome

A small command-line metronome for Linux that I wrote for my drumming practice.

It utilizes the ALSA (Advanced Linux Sound Architecture) API for audio playback and Unix timers for interval management.

## Features

- Direct ALSA PCM interface for low-latency audio.
- Precise timing using `SIGALRM` and `setitimer`.
- Support for custom BPM and time signatures.
- Minimalist implementation with a custom WAV parser and allocator wrapper.

## Prerequisites

- Zig 0.15.2 or later.
- ALSA development headers (e.g., `libasound2-dev` on Ubuntu/Debian or `alsa-lib` on Arch Linux).

## Building

To build the project using the Zig build system, run:

```bash
zig build -Doptimize=ReleaseSmall
```

The executable will be located at `zig-out/bin/metronome`.

Alternatively, a `Makefile` is provided for convenience. The default target builds and runs the
application in `Debug` mode. Available commands:

```bash
make          # Build and run (default: OPTIMIZE=Debug)
make debug    # Build for debugging
make release  # Build for ReleaseSmall
make clean    # Remove build artifacts
```

## Usage

The application provides an interactive command-line interface. The following commands are available:

- `<num>`: Set the tempo in Beats Per Minute (BPM). Example: `120`.
- `/sig <num>`: Set the time signature (beats per measure). Example: `/sig 4`.
- `q`: Terminate the application.

## Implementation Details

- **Audio:** The engine opens the default ALSA PCM device and writes 16-bit signed little-endian
  (S16_LE) samples.
- **Timing:** Intervals are managed by the Linux kernel via `setitimer(ITIMER_REAL)`, which triggers
  `SIGALRM` at calculated intervals based on the BPM.
- **Memory:** A custom allocator wrapper switches between `std.heap.DebugAllocator` in debug builds
  and `std.heap.c_allocator` in release builds for optimal performance.

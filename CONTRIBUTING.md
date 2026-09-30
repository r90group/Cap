# Cap Contributor Guide

## Introduction

### What is Cap?

Cap is an open source and privacy focused alternative to Loom. It's a video messaging tool that allows you to record, edit and share videos in seconds.

The development of Cap is still in its early stages, so please bare with us as we build out this guide.

### What is this guide?

This guide is for anyone who wants to contribute to Cap. It's a work in progress, and will be updated regularly.

### How can I contribute?

There are many ways to contribute to Cap. You can:

- [Report a bug](https://github.com/CapSoftware/cap/issues/new)
- [Suggest a feature (via Discord)](https://discord.com/invite/y8gdQ3WRN3)
- Submit a PR

## Runing Cap

### Development Requirements

Before anything else, make sure you have the following installed:

- Node Version 20+
- Rust 1.88.0+
- pnpm 8.10.5+
- Docker ([OrbStack](https://orbstack.dev/) recommended)

### General Setup

Run `pnpm install`, then run `pnpm cap-setup` to install native dependencies such as FFmpeg.

On Windows, Visual Studio's C++ and LLVM tools and VCPKG must be installed.
On MacOS, cmake must be installed.
`pnpm cap-setup` does not yet install these dependencies for you.

Run `pnpm env-setup` to generate a `.env` file configured for your environment.
It will ask you which apps you intend to run, whether you'd like to use Docker to run S3 (MinIO) and MySQL locally,
and allow you to provide overrides as needed.

To run both `@cap/desktop` and `@cap/web` together, use `pnpm dev`.
To run only one of them, use `pnpm dev:desktop` or `pnpm dev:web` respectively.

### `@cap/desktop` (desktop app)

When running `@cap/desktop` from a terminal on macOS,
you will need to grant permissions (screen recording, microphone, etc.) to the terminal, not the Cap app.
For example, if you run `pnpm dev:desktop` in the macOS `Terminal.app`,
you will need to grant permissions to it instead of `Cap - Development.app`.

#### Native Rust workspace builds

Run workspace builds on a host matching the target: `aarch64-apple-darwin` on Apple Silicon, `x86_64-apple-darwin` on Intel macOS, or `x86_64-pc-windows-msvc` on x64 Windows. CI uses `macos-15-intel` for the Intel target instead of cross-compiling on Apple Silicon.

After installing pnpm dependencies, run the following from the repository root in Bash (Git Bash on Windows), changing `RUST_TARGET_TRIPLE` to the native target:

```bash
export RUST_TARGET_TRIPLE=aarch64-apple-darwin
pnpm cap-setup
bash scripts/build-cap-muxer.sh "$RUST_TARGET_TRIPLE"
cargo build --all --target "$RUST_TARGET_TRIPLE"
pnpm turbo build --filter @cap/desktop
cargo check --all --release --target "$RUST_TARGET_TRIPLE"
cargo clippy --workspace --all-features --locked --target "$RUST_TARGET_TRIPLE" -- -D warnings
```

The setup target selects the matching native FFmpeg dependencies. The sidecar script builds and copies the real target-suffixed `cap-muxer` binary required by Tauri. Direct Cargo commands do not run Tauri's `beforeBuildCommand`; build the desktop frontend before release checks so `apps/desktop/.output/public` contains the real assets.

On Windows, `pnpm cap-setup` writes `LIBCLANG_PATH` and `CLANG_PATH` into `.cargo/config.toml` using the same resolved Visual Studio LLVM directory. Bindgen's loaded DLL and header-detecting compiler must match; do not pair Visual Studio's `libclang.dll` with standalone LLVM's `clang.exe` from `PATH`. If overriding these paths in PowerShell, set both:

```powershell
$vsInstall = & "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe" -latest -property installationPath
$llvmBin = Join-Path ($vsInstall.Trim()) "VC/Tools/LLVM/x64/bin"
$env:LIBCLANG_PATH = Join-Path $llvmBin "libclang.dll"
$env:CLANG_PATH = Join-Path $llvmBin "clang.exe"
```

Rust cache jobs also run for Rust-related pull requests and manual CI runs. Cache saving remains restricted to the main ref.

#### Where are my recordings stored?

You can find your recordings at `~/Library/Application Support/so.cap.desktop.dev/recordings` on macOS,
and `%programfiles%/so.cap.desktop.dev/recordings` on Windows.

### `@cap/web` (cap.so website)

When running `pnpm dev` or `pnpm dev:web`, a MySQL database and MinIO S3 server will also be using Docker.
If you want to _only_ run the `@cap/web` NextJS app, `cd` into `./apps/web` and run `pnpm dev`.

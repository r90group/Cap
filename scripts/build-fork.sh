#!/usr/bin/env bash
set -euo pipefail

target="${1:?Target triple is required}"
mode="${2:?Build mode is required}"
args=(--target "$target" --config src-tauri/tauri.prod.conf.json)
case "$mode" in
    preflight) args+=(--no-bundle) ;;
    signed) ;;
    *) printf 'Unknown build mode: %s\n' "$mode" >&2; exit 2 ;;
esac

export RUST_TARGET_TRIPLE="$target"
export CARGO_PROFILE_RELEASE_DEBUG=0
export CI=false
pnpm -w cap-setup
bash scripts/build-cap-muxer.sh "$target"
pnpm --dir apps/desktop build:tauri "${args[@]}"

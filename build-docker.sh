#!/bin/bash
set -e

# RUST_TARGET is set by each architecture-specific Dockerfile (e.g. aarch64-unknown-linux-gnu)
RUST_TARGET="${RUST_TARGET:-aarch64-unknown-linux-gnu}"

# Ensure cargo is in PATH (sources rustup env if present, then check common paths)
for f in /root/.cargo/env /usr/local/cargo/env; do
  if [ -f "$f" ]; then
    set +e
    . "$f"
    set -e
    break
  fi
done
for d in /root/.cargo/bin /usr/local/cargo/bin; do
  if [ -x "$d/cargo" ]; then
    export PATH="$d:$PATH"
    break
  fi
done
if ! command -v cargo >/dev/null 2>&1; then
  echo "ERROR: cargo not found. Checked /root/.cargo and /usr/local/cargo"
  exit 1
fi

cd /workspace

if [ ! -d "slipstream-rust" ]; then
    echo "ERROR: slipstream-rust directory not found. It should be mounted as a volume."
    exit 1
fi

cd slipstream-rust

echo "Building picoquic for $RUST_TARGET..."
bash scripts/build_picoquic.sh

export PICOQUIC_DIR=/workspace/slipstream-rust/vendor/picoquic
export PICOQUIC_BUILD_DIR=/workspace/slipstream-rust/.picoquic-build
export PICOQUIC_FETCH_PTLS=ON
export PICOQUIC_AUTO_BUILD=1

# MIPS: no pre-built std; use vendored OpenSSL and -Z build-std with nightly
CARGO_FEATURES=""
CARGO_EXTRA=""
case "$RUST_TARGET" in
  mips64-*|mips64el-*|mips-*|mipsel-*)
    CARGO_FEATURES="--features openssl-vendored"
    CARGO_EXTRA="-Z build-std=std,panic_abort"
    ;;
  *-unknown-linux-musl)
    CARGO_FEATURES="--features openssl-vendored"
    ;;
esac

# 32-bit MIPS: std has no AtomicU64; use portable_atomic
if [ "$RUST_TARGET" = "mips-unknown-linux-gnu" ] || [ "$RUST_TARGET" = "mipsel-unknown-linux-gnu" ]; then
  CORE_TOML="crates/slipstream-core/Cargo.toml"
  INVARIANTS_RS="crates/slipstream-core/src/invariants.rs"
  if [ -f "$CORE_TOML" ] && ! grep -q 'portable-atomic' "$CORE_TOML"; then
    sed -i '/^\[dependencies\]$/a portable-atomic = "1.6"' "$CORE_TOML"
  fi
  if [ -f "$INVARIANTS_RS" ] && grep -q 'std::sync::atomic::{AtomicU64' "$INVARIANTS_RS"; then
    { printf '%s\n' '#[cfg(target_has_atomic = "64")]' 'use std::sync::atomic::{AtomicU64, Ordering};' '#[cfg(not(target_has_atomic = "64"))]' 'use portable_atomic::{AtomicU64, Ordering};' ''; tail -n +2 "$INVARIANTS_RS"; } > "$INVARIANTS_RS.tmp" && mv "$INVARIANTS_RS.tmp" "$INVARIANTS_RS"
  fi
fi

echo "Building slipstream binaries for $RUST_TARGET..."
if [ -n "$CARGO_EXTRA" ]; then
  cargo +nightly build --release $CARGO_EXTRA --target "$RUST_TARGET" -p slipstream-client -p slipstream-server $CARGO_FEATURES
else
  cargo build --release --target "$RUST_TARGET" -p slipstream-client -p slipstream-server $CARGO_FEATURES
fi

mkdir -p /workspace/output
cp "target/$RUST_TARGET/release/slipstream-client" /workspace/output/
cp "target/$RUST_TARGET/release/slipstream-server" /workspace/output/

echo "Build complete! Binaries are in /workspace/output/"

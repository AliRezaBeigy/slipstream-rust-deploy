#!/bin/bash
set -e

cd /workspace

if [ ! -d "slipstream-rust" ]; then
    echo "ERROR: slipstream-rust directory not found. It should be mounted as a volume."
    exit 1
fi

cd slipstream-rust

echo "Building picoquic..."
bash scripts/build_picoquic.sh

export PICOQUIC_DIR=/workspace/slipstream-rust/vendor/picoquic
export PICOQUIC_BUILD_DIR=/workspace/slipstream-rust/.picoquic-build
export PICOQUIC_FETCH_PTLS=ON
export PICOQUIC_AUTO_BUILD=1

echo "Building slipstream binaries..."
cargo build --release --target aarch64-unknown-linux-gnu -p slipstream-client -p slipstream-server

mkdir -p /workspace/output
cp target/aarch64-unknown-linux-gnu/release/slipstream-client /workspace/output/
cp target/aarch64-unknown-linux-gnu/release/slipstream-server /workspace/output/

echo "Build complete! Binaries are in /workspace/output/"

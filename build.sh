#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Building Glance SDK ==="

# Build the CLI binary (universal macOS binary)
echo "→ Compiling Swift CLI..."
swift build -c release --product glance 2>&1 | tail -5

BINARY=".build/release/glance"

if [ ! -f "$BINARY" ]; then
    echo "✗ Build failed — binary not found"
    exit 1
fi

echo "→ Binary size: $(du -h "$BINARY" | cut -f1)"

# Copy binary to npm and python packages
echo "→ Copying binary to npm package..."
cp "$BINARY" packages/npm/bin/glance
chmod +x packages/npm/bin/glance

echo "→ Copying binary to python package..."
cp "$BINARY" packages/python/glance_sdk/bin/glance
chmod +x packages/python/glance_sdk/bin/glance

echo ""
echo "=== Done ==="
echo ""
echo "Test it:"
echo "  .build/release/glance                  # LLM-ready text"
echo "  .build/release/glance screen --json    # Full JSON"
echo "  .build/release/glance find \"Submit\"    # Find element"
echo ""
echo "Packages ready at:"
echo "  packages/npm/       → npm publish"
echo "  packages/python/    → pip install -e ."

#!/usr/bin/env bash
# Fetches the prebuilt llama.cpp xcframework used by the offline GGUF provider.
# The binary (~178 MB zip / ~568 MB extracted) is gitignored; this script makes a
# fresh clone buildable. Run once before building the OpenPilot scheme:
#   ios/scripts/bootstrap-gguf.sh
set -euo pipefail

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$IOS_DIR/Vendor/CLlama"
URL="https://github.com/ggml-org/llama.cpp/releases/download/b8851/llama-b8851-xcframework.zip"
SHA256="f5eb26820b9890ae026aee4963cd4f43af1c567d39534012f2685601a59c2519"

mkdir -p "$DEST"
if [ -d "$DEST/llama.xcframework" ]; then
    echo "llama.xcframework already present at $DEST — nothing to do."
    exit 0
fi

ZIP="$DEST/llama-b8851-xcframework.zip"
echo "Downloading llama.cpp b8851 xcframework (~178 MB)…"
curl -L --fail --retry 3 -o "$ZIP" "$URL"

echo "Verifying checksum…"
echo "$SHA256  $ZIP" | shasum -a 256 -c -

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
mv "$TMP/build-apple/llama.xcframework" "$DEST/llama.xcframework"
rm -f "$ZIP"

echo "Done: $DEST/llama.xcframework"
echo "Now run: cd ios && xcodegen generate && xcodebuild build -scheme OpenPilot"

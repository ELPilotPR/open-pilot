// swift-tools-version:5.9
import PackageDescription

// Thin local wrapper around the prebuilt llama.cpp xcframework (b8851).
// Exposes the stable C API (llama.h) via `import llama` — no C++ interop.
let package = Package(
    name: "CLlama",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CLlama", targets: ["llama"])
    ],
    targets: [
        .binaryTarget(name: "llama", path: "llama.xcframework")
    ]
)

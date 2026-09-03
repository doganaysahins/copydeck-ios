// swift-tools-version: 5.9
import PackageDescription

// macOS de destekleniyor: boylece `swift test` simulator olmadan,
// komut satirinda calisir. Cekirdek modul saf Foundation'dir.
let package = Package(
    name: "Copydeck",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Copydeck", targets: ["Copydeck"])
    ],
    targets: [
        .target(name: "Copydeck"),
        .testTarget(name: "CopydeckTests", dependencies: ["Copydeck"])
    ]
)

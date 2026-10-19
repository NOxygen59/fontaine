// swift-tools-version: 5.10
// FontCore: the font catalog, installing fonts system-wide, collections and the app's three
// languages. Compiled into the Fontaine iPad app (App/) and tested here on the Mac.
import PackageDescription

let package = Package(
    name: "Fontaine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "FontCore", targets: ["FontCore"])],
    targets: [
        .target(name: "FontCore"),
        .testTarget(name: "FontCoreTests", dependencies: ["FontCore"]),
    ]
)

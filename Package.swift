// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "R0M",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "R0M",
            path: "Sources/R0M",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)

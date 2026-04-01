// swift-tools-version: 5.9
/* @source cursor @line_count 14 @branch main */
import PackageDescription

let package = Package(
    name: "CopyLists",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CopyLists",
            path: "Sources/CopyLists"
        )
    ]
)

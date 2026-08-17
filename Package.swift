// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "switch-mac-os",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwitchMacOS", targets: ["SwitchMacOS"]),
        .library(name: "SwitchCore", targets: ["SwitchCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tigase/Martin.git", branch: "master"),
        .package(url: "https://github.com/tigase/MartinOMEMO.git", branch: "master"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.3.0"),
        // Tree-sitter syntax highlighting
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", from: "0.25.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterPythonFix",
            dependencies: [],
            path: "Sources/TreeSitterPythonFix",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("include")]
        ),
        .target(
            name: "SwitchCore",
            dependencies: [
                .product(name: "Martin", package: "Martin"),
                .product(name: "MartinOMEMO", package: "MartinOMEMO"),
            ]
        ),
        .executableTarget(
            name: "SwitchMacOS",
            dependencies: [
                "SwitchCore",
                .product(name: "Highlightr", package: "Highlightr"),
                // Tree-sitter
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                "TreeSitterPythonFix",
                .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
            ]
        ),
    ]
)

// swift-tools-version:5.6

//
// This source file is part of the Apodini open source project
// 
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "OASToAPIDocumentConverter",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "OASToAPIDocumentConverter", targets: ["OASToAPIDocumentConverter"]),
        .executable(name: "OASToAPIDocumentConverterCLI", targets: ["OASToAPIDocumentConverterCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "3.0.0-alpha.4"),
        .package(url: "https://github.com/Apodini/ApodiniMigrator", from: "0.3.0"),
        .package(url: "https://github.com/RougeWare/Swift-SemVer", from: "3.0.0-Beta.5"),
        
        // we use <1.0.0 argument parser as migrator (and Apodini) aren't updated yet (there are some issues to resolve)!
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "OASToAPIDocumentConverter",
            dependencies: [
                .product(name: "SemVer", package: "Swift-SemVer"),
                .product(name: "OpenAPIKit30", package: "OpenAPIKit"),
                .product(name: "ApodiniMigratorCore", package: "ApodiniMigrator")
            ]
        ),
        
        .executableTarget(
            name: "OASToAPIDocumentConverterCLI",
            dependencies: [
                .target(name: "OASToAPIDocumentConverter"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        
        .testTarget(
            name: "OASToAPIDocumentConverterTests",
            dependencies: [
                .target(name: "OASToAPIDocumentConverter")
            ]
        )
    ]
)

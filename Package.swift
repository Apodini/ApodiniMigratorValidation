// swift-tools-version:5.6

//
// This source file is part of the Apodini open source project
// 
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
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
        .executable(name: "oas-to-api-document", targets: ["OASToAPIDocumentConverterCLI"])
    ],
    targets: [
        .target(name: "OASToAPIDocumentConverter"),
        .executableTarget(name: "OASToAPIDocumentConverterCLI"),
        .testTarget(
            name: "OASToAPIDocumentConverterTests",
            dependencies: [
                .target(name: "OASToAPIDocumentConverter")
            ]
        )
    ]
)

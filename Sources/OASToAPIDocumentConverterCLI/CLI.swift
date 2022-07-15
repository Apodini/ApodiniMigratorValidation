//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OASToAPIDocumentConverter

@main
public struct CLI {
    public static func main() async throws {
        let converter = Converter()
        print(try await converter.greet("Migrator users 🚀"))
    }
}

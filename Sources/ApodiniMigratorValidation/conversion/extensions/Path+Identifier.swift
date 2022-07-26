//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OpenAPIKit30

extension OpenAPI.Path {
    var identifier: String {
        var components = components
        let first = components.removeFirst()
        
        return first.lowercased() + components
            .map { $0.lowercased().upperFirst }
            .joined()
    }
}

//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCore

extension ApodiniMigratorCore.Operation {
    var httpMethod: String {
        switch self {
        case .read:
            return "GET"
        case .create:
            return "POST"
        case .update:
            return "PUT"
        case .delete:
            return "DELETE"
        }
    }
}

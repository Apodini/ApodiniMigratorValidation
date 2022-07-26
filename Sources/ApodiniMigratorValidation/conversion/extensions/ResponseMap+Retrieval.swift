//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OpenAPIKit30

extension OpenAPI.Response.Map {
    // see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#2xx_success
    private static let successCodes = [
        200,
        201,
        202,
        204,
        205,
        206,
        207,
        208
    ]
    
    var someSuccessfulResponse: Self.Value? {
        for code in Self.successCodes {
            guard let responseEither = self[status: .init(integerLiteral: code)] else {
                continue
            }
            return responseEither
        }
        
        return nil
    }
}

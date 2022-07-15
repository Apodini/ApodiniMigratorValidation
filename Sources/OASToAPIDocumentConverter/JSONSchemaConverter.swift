//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OpenAPIKit30
import ApodiniMigratorCore

public struct JSONSchemaConverter {
    private let schema: JSONSchema
    
    private let components: OpenAPI.Components
    
    public init(from reference: Either<JSONReference<JSONSchema>, JSONSchema>, with references: OpenAPI.Components) throws {
        self.init(from: try references.lookup(reference), with: references)
    }
    
    public init(from schema: JSONSchema, with references: OpenAPI.Components) {
        self.schema = schema
        self.components = references
    }
    
    public func convert() -> TypeInformation {
        // TODO TRADEOFF: we probably loose a lot of information here as well, our typeInformation is definitley
        //  not as powerful (e.g. we don't support stuff like polymorphism or value range definitions)
        //  refer to https://swagger.io/specification/#schema-object
    
        .scalar(.string) // TODO implement!
    }
}

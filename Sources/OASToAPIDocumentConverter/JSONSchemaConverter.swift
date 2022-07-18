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
    
    private func ensureDereferenced(_ schema: JSONSchema) throws -> JSONSchema {
        switch schema.value {
        case let .reference(reference, context):
            // TODO context captures "required"?.
            return try components.lookup(reference)
        default:
            return schema
        }
    }
    
    private func convert(schema: JSONSchema) throws -> TypeInformation {
        // TODO TRADEOFF: we probably loose a lot of information here as well, our typeInformation is definitley
        //  not as powerful (e.g. we don't support stuff like polymorphism or value range definitions)
        //  refer to https://swagger.io/specification/#schema-object
    
        switch schema.value {
        case let .boolean(coreContext):
            return .scalar(.bool)
        case let .number(coreContext, numericContext):
            // TODO what type of number is this?
            return .scalar(.double)
        case let .integer(coreContext, integerContext):
            // TODO parse context to group int intX bzw uintx
        
            return .scalar(.int)
        case let .string(coreContext, stringContext):
            return .scalar(.string)
        case let .object(coreContext, objectContext):
            let properties = try objectContext.properties
                .mapValues(ensureDereferenced)
            // TODO TRADEOFF: ignore additional properties?
        case let .array(coreContext, arrayContext):
            // TODO TRADEOFF: we ignore `maxItems`, `minItems`, `uniqueItems` (in array context)
            guard let items = arrayContext.items else {
                preconditionFailure("Encountered array schema without a description for the item type: \(schema)")
            }
        
            return .repeated(element: try convert(schema: ensureDereferenced(items)))
        case let .all(schema, coreContext),
             let .one(schema, coreContext),
             let .any(schema, coreContext):
            // TODO <#code#>
            break
        case let .not(schema, coreContext):
            // TODO <#code#>
            break
        case let .reference(reference, referenceContext): // TODO this shouldn't exists!
            preconditionFailure("Encountered JSONSchema reference even after dereferencing: \(schema)")
        case .fragment(_):
            // TODO <#code#>
            break
        }
        
        preconditionFailure() // TODO remove once all cases are handled
    }
    
    public func convert() throws -> TypeInformation {
        try convert(schema: schema)
    }
}

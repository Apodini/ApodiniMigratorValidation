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
import Logging

private let logger = Logger(label: "schema-converter")

public class JSONSchemaConverter {
    public static let emptyObject: TypeInformation = .object(name: .init(rawValue: "Empty"), properties: [])
    public static let recursiveTypeTerminator: TypeInformation = .object(name: .init(rawValue: "ApodiniRecursionTerminator"), properties: [])
    
    private let schema: JSONSchema
    
    private let components: OpenAPI.Components
    
    private var dereferencePath: [String] = []
    
    public convenience init(from reference: Either<JSONReference<JSONSchema>, JSONSchema>, with components: OpenAPI.Components) {
        switch reference {
        case let .a(reference):
            // we wrap it into a JSONSchema, we dereference on demand!
            self.init(from: JSONSchema.reference(reference), with: components)
        case let .b(schema):
            self.init(from: schema, with: components)
        }
    }
    
    public init(from schema: JSONSchema, with references: OpenAPI.Components) {
        self.schema = schema
        self.components = references
    }
    
    private func convert(schema potentiallyReferencedSchema: JSONSchema, fallbackNamingMaterial: String) throws -> TypeInformation {
        // refer to https://swagger.io/specification/#schema-object
        
        // TODO TRADEOFF: (current) of the CoreContext
        //  - `nullable`
        //  - `permissions` (readOnly, writeOnly, readWrite)
        //  - `deprecated`
        //  - `title`
        //  - `description`
        //  - `discriminator`
        //  - `externalDocs`
        //  - `allowedValues`
        //  - `defaultValue`
        //  - `example`
        
        let objectName: String
        let schema: JSONSchema
        
        if case let .reference(reference, _) = potentiallyReferencedSchema.value {
            schema = try components.lookup(reference)
    
            // field is present, otherwise the call above would have failed
            // swiftlint:disable:next force_unwrapping
            objectName = reference.name!
            
            guard !dereferencePath.contains(objectName) else {
                // The ApodiniTypeInformation framework doesn't currently support recursive types (https://github.com/Apodini/ApodiniTypeInformation/issues/5).
                // With this tool we are only interested in generating a document capable of doing change comparison on.
                // Therefore, we terminate the recursive type by inserting a custom empty type.
                logger.warning("""
                               Encountered recursive type definition for '\(fallbackNamingMaterial)' with dereference path: \(dereferencePath). \
                               We break the recursive chain by replacing '\(objectName)' with a custom and empty type `ApodiniRecursionTerminator`.
                               """)
                return Self.recursiveTypeTerminator
            }
            
            dereferencePath.append(objectName)
        } else {
            objectName = fallbackNamingMaterial
            schema = potentiallyReferencedSchema
        }
        
        defer {
            if potentiallyReferencedSchema.isReference {
                let last = dereferencePath.removeLast()
                precondition(last == objectName)
            }
        }
    
        // swiftlint:disable:next closure_body_length
        let conversion = { () throws -> TypeInformation in
            switch schema.value {
            case let .boolean(coreContext):
                if case let .other(identifier) = coreContext.format {
                    logger.debug("Encountered unknown .boolean format '\(identifier)'")
                }
                return .scalar(.bool)
            case let .number(coreContext, _):
                // TODO TRADEOFF: numeric context missing
                //  - `multipleOf`
                //  - `minimum`
                //  - `maximum`
    
                // TODO log enums of numbers
        
                switch coreContext.format {
                case .generic, .double:
                    return .scalar(.double)
                case .float:
                    return .scalar(.float)
                case let .other(identifier):
                    logger.debug("Encountered unknown .number format '\(identifier)'")
                    return .scalar(.double)
                }
            case let .integer(coreContext, _):
                // TODO TRADEOFF: integer context missing
                //  - `multipleOf`
                //  - `minimum`
                //  - `maximum`
                
                // TODO log enums of integers
                
                switch coreContext.format {
                case .int32:
                    return .scalar(.int32)
                case .int64:
                    return .scalar(.int64)
                case .generic:
                    return .scalar(.int)
                case let .other(identifier):
                    switch identifier {
                    case JSONTypeFormat.IntegerFormat.Extended.uint32.rawValue:
                        return .scalar(.uint32)
                    case JSONTypeFormat.IntegerFormat.Extended.uint64.rawValue:
                        return .scalar(.uint64)
                    default:
                        logger.debug("Encountered unknown .integer format '\(identifier)'")
                        return .scalar(.int)
                    }
                }
            case let .string(coreContext, stringContext):
                // TODO TRADEOFF: string context missing
                //  - `maxLength`
                //  - `minLength`
                //  - `pattern`
                
                if let values = coreContext.allowedValues {
                    let cases = values
                        .map { $0.description } // we know those are strings, we can just map them to strings!
                        .map { EnumCase($0) }
                    
                    return .enum(name: .init(rawValue: objectName), rawValueType: .scalar(.string), cases: cases)
                }
        
                switch coreContext.format {
                case .generic, .password: // password is just a UI hint
                    return .scalar(.string)
                case .date, .dateTime:
                    // we may not ensure that this is actually `Foundation.Date` parsable,
                    // but ensure that we can detect changes by mapping it to a distinct type
                    return .scalar(.date)
                case .byte, .binary: // same reasoning as for `.date` above!
                    // byte – base64-encoded characters, for example, U3dhZ2dlciByb2Nrcw==
                    // binary – binary data, used to describe files (see Files below)
                    return .scalar(.data)
                case let .other(identifier):
                    switch identifier {
                    case JSONTypeFormat.StringFormat.Extended.uuid.rawValue:
                        return .scalar(.uuid)
                    case JSONTypeFormat.StringFormat.Extended.uri.rawValue,
                         "uri-template": // used by github
                        return .scalar(.url)
                    case "timestamp": // used by github
                        return .scalar(.date)
                    case JSONTypeFormat.StringFormat.Extended.email.rawValue,
                         JSONTypeFormat.StringFormat.Extended.ipv4.rawValue,
                         JSONTypeFormat.StringFormat.Extended.ipv6.rawValue,
                         JSONTypeFormat.StringFormat.Extended.hostname.rawValue,
                         JSONTypeFormat.StringFormat.Extended.uriReference.rawValue:
                        // we don't want to omit a warning for those known/common formats
                        return .scalar(.string)
                    default:
                        logger.debug("Encountered unknown .string format '\(identifier)'")
                        return .scalar(.string)
                    }
                }
            case let .object(_, objectContext):
                // TODO TRADEOFF: ignored objectContext properties
                //  - `additionalProperties`
                //  - `maxProperties`
                //  - `minProperties`
        
                let properties = try objectContext.properties
                    .map { name, schema -> TypeProperty in
                        let type = try self.convert(schema: schema, fallbackNamingMaterial: "\(objectName)#\(name)")
                        return TypeProperty(name: name, type: type)
                    }
                
                if properties.isEmpty {
                    return Self.emptyObject
                }
                
                return .object(name: .init(rawValue: objectName), properties: properties)
            case let .array(_, arrayContext):
                // TODO TRADEOFF: ignored array context parameters
                //  - `maxItems`
                //  - `minItems`
                //  - `uniqueItems`
                guard let items = try arrayContext.items.map({ try self.convert(schema: $0, fallbackNamingMaterial: objectName) }) else {
                    fatalError("Encountered array schema without a description for the item type: \(schema)")
                }
    
                return .repeated(element: items)
            case let .all(of, _):
                guard let first = of.first else {
                    preconditionFailure("`allOf` didn't contain anything: \(schema)")
                }
                
                if of.count == 1 {
                    return try self.convert(schema: first, fallbackNamingMaterial: objectName)
                }
                
                let combinedProperties = try of
                    .map { try self.convert(schema: $0, fallbackNamingMaterial: objectName) } // we throw away the object name anyways!
                    .flatMap { information -> [TypeProperty] in
                        guard case let .object(_, properties, _) = information else {
                            preconditionFailure("Encountered `allOf` which contains schemas different to objects: \(schema)")
                        }
                        
                        return properties
                    }
                
                return .object(name: .init(rawValue: objectName), properties: combinedProperties)
            case let .one(of, _), let .any(of, _):
                // TODO TRADEOFF: can't represent in APIDocument
                // TODO log occurences of those!!
                
                // `oneOf` declares that the type matches >exactly< one sub-schema!
                // `anyOf` declares that the type matches >one or more> sub-schemas!
                
                // use to encode multiple different representations for the same value
                // (e.g. bool encoded as bool or string; or a simple and a complex object type)
                guard let first = of.first else {
                    preconditionFailure("`oneOf`/`anyOf` didn't contain anything: \(schema)")
                }
    
                if of.count == 1 {
                    return try self.convert(schema: first, fallbackNamingMaterial: objectName)
                }
                
                // TODO do we have different strategies (e.g. merge parameters?)
                return try self.convert(schema: first, fallbackNamingMaterial: objectName)
            case .not:
                // TODO TRADEOFF: can't encode in APIDocument!
                
                // not is really not widely used!
                fatalError("Encountered unsupported JSONSchema type (.all, .one, .any or .not) within \(objectName): \(schema)")
            case .reference:
                preconditionFailure("Encountered JSONSchema .reference even after dereferencing within \(objectName): \(schema)")
            case .fragment:
                return Self.emptyObject
            }
        }
    
        let typeInfo = try conversion()
        guard let context = schema.coreContext else {
            preconditionFailure("Assumption broke. Encountered a .reference where we know that there can't be one: \(schema)")
        }
        
        if !context.required {
            return .optional(wrappedValue: typeInfo)
        }
        
        return typeInfo
    }
    
    public func convert(fallbackNamingMaterial: String) throws -> TypeInformation {
        try convert(schema: schema, fallbackNamingMaterial: fallbackNamingMaterial)
    }
}

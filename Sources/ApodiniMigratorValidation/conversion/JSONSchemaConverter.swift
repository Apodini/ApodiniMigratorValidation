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

/// The JSONSchemaConverter is used to convert `JSONSchema` instances to the `TypeInformation` representation.
///
/// The aim is to convert to a `TypeInformation` which is comparable (meaning any conversion will always
/// result in the same representation). Though, we don't guarantee that the resulting `TypeInformation` representation
/// actually describes the same data model (e.g. when resolving recursive data structures).
/// Any ignored properties and tradeoffs are describe below.
///
/// ## Ignored Schema Context properties
/// The following properties of `JSONSchema` are ignored:
/// ###`CoreContext`:
/// - `nullable`
/// - `permissions`
/// - `deprecated`
/// - `title`
/// - `description`
/// - `discriminator`
/// - `externalDocs`
/// - `allowedValues` (only considered for `string` types)
/// - `defaultValue`
/// - `example`
///
/// ###`NumericContext`:
/// - `multipleOf`
/// - `minimum`
/// - `maximum`
///
/// ###`IntegerContext`:
/// - `multipleOf`
/// - `minimum`
/// - `maximum`
///
/// ###`StringContext`:
///  - `maxLength`
///  - `minLength`
///  - `pattern`
///
/// ###`ObjectContext`:
/// - `additionalProperties`
/// - `maxProperties`
/// - `minProperties`
///
/// ###`ArrayContext`:
/// - `maxItems`
/// - `minItems`
/// - `uniqueItems`
///
/// ## Other Tradeoffs
/// JSONSchema has additional schema representations which can't be represented within the `TypeInformation` framework.
/// For better oversight, those occurrences are counted in the global ``ConversionStats`` object in the ``stats`` property.
///
/// ### `not`:
/// `not` schemas cannot be represented and the converter will return the predefined ``errorType`` type.
///
/// ### `oneOf` and `anyOf`:
/// Both of those schemas can't be represented within the `TypeInformation` framework.
/// To be able to map at least some information, we will always take the first sub-schema.
///
/// ### Recursive References:
/// The `TypeStore` doesn't support describing recursive models. Therefore, we break recursive JSONSchema definitions
/// by inserting the common `recursiveTypeTerminator` type once we encounter a cyclic reference.
public class JSONSchemaConverter {
    /// Predefined `TypeInformation` `object` named `"Empty"` to represent any objects without properties.
    public static let emptyObject: TypeInformation = .object(name: .init(rawValue: "Empty"), properties: [])
    /// Predefined `TypeInformation` `object` named `"ApodiniRecursionTerminator"` to unwind recursive
    /// reference in `JSONSchema` definitions.
    public static let recursiveTypeTerminator: TypeInformation = .object(name: .init(rawValue: "ApodiniRecursionTerminator"), properties: [])
    /// Predefined `TypeInformation` `object` named `"ApodiniConversionError"` to represent JSONSchemas which can't be converted.
    public static let errorType: TypeInformation = .object(name: .init(rawValue: "ApodiniConversionError"), properties: [])
    
    private let schema: JSONSchema
    private let components: OpenAPI.Components
    private var dereferencePath: [String] = []
    
    /// Access the ``ConversionStats``. Stats will only be collected after ``convert(fallbackNamingMaterial:)`` has been called.
    public static var stats = ConversionStats()
    
    /// Initializes a new ``JSONSchemaConverter``.
    ///
    /// - Parameters:
    ///   - either: Either a ``JSONReference<JSONSchema>`` or a `JSONSchema` which is to be converted.
    ///   - components: The `OpenAPI.Components` object which is used to lookup references.
    public convenience init(from either: Either<JSONReference<JSONSchema>, JSONSchema>, with components: OpenAPI.Components) {
        switch either {
        case let .a(reference):
            // we wrap it into a JSONSchema, we dereference on demand!
            self.init(from: JSONSchema.reference(reference), with: components)
        case let .b(schema):
            self.init(from: schema, with: components)
        }
    }
    
    /// Initializes a new ``JSONSchemaConverter``.
    ///
    /// - Parameters:
    ///   - schema: The `JSONSchema` which is to be converted.
    ///   - components: The ``OpenAPI.Components`` object which is used to lookup references.
    public init(from schema: JSONSchema, with components: OpenAPI.Components) {
        self.schema = schema
        self.components = components
    }
    
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func convert(schema potentiallyReferencedSchema: JSONSchema, fallbackNamingMaterial: String) throws -> TypeInformation {
        // refer to https://swagger.io/specification/#schema-object
        
        // TRADEOFF: Ignored properties of the `CoreContext`
        //  - `permissions` (readOnly, writeOnly, readWrite)
        //  - `deprecated`
        //  - `title`
        //  - `description`
        //  - `discriminator`
        //  - `externalDocs`
        //  - `allowedValues` (we use it only for strings to map enums!)
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
                Self.stats.terminatedCyclicReferences += 1
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
                // TRADEOFF: Ignored properties of the `NumericContext`
                //  - `multipleOf`
                //  - `minimum`
                //  - `maximum`
        
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
                // TRADEOFF: Ignored properties of the `IntegerContext`
                //  - `multipleOf`
                //  - `minimum`
                //  - `maximum`
                
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
            case let .string(coreContext, _):
                // TRADEOFF: Ignored properties of the `StringContext`
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
                         JSONTypeFormat.StringFormat.Extended.uriReference.rawValue,
                         "uri-template": // used by github
                        return .scalar(.url)
                    case "timestamp": // used by github
                        return .scalar(.date)
                    case JSONTypeFormat.StringFormat.Extended.email.rawValue,
                         JSONTypeFormat.StringFormat.Extended.ipv4.rawValue,
                         JSONTypeFormat.StringFormat.Extended.ipv6.rawValue,
                         JSONTypeFormat.StringFormat.Extended.hostname.rawValue:
                        // we don't want to omit a warning for those known/common formats
                        return .scalar(.string)
                    default:
                        logger.debug("Encountered unknown .string format '\(identifier)'")
                        return .scalar(.string)
                    }
                }
            case let .object(_, objectContext):
                // TRADEOFF: Ignored properties of the `ObjectContext`
                //  - `additionalProperties`
                //  - `maxProperties`
                //  - `minProperties`
        
                let properties = try objectContext.properties
                    .map { name, schema -> TypeProperty in
                        let type = try self.convert(schema: schema, fallbackNamingMaterial: "\(objectName)#\(name)")
                        return TypeProperty(name: name, type: type)
                    }
                    // There is a case where github lists a parameter name in the list of required parameters
                    // but doesn't specify the parameter schema. In then appeared as a schema fragment.
                    // We want to filter those occurrences to properly model any changes.
                    .filter { $0.type != Self.emptyObject }
                
                if properties.isEmpty {
                    return Self.emptyObject
                }
                
                return .object(name: .init(rawValue: objectName), properties: properties)
            case let .array(_, arrayContext):
                // TRADEOFF: Ignored properties of the `ArrayContext`
                //  - `maxItems`
                //  - `minItems`
                //  - `uniqueItems`
                guard let items = try arrayContext.items.map({ try self.convert(schema: $0, fallbackNamingMaterial: objectName) }) else {
                    fatalError("Encountered array schema without a description for the item type: \(schema) (in: \(objectName))")
                }
    
                return .repeated(element: items)
            case let .all(of, _):
                guard !of.isEmpty else {
                    preconditionFailure("`allOf` didn't contain anything: \(schema)")
                }
                
                let convertedSchemas = try of
                    .map { try self.convert(schema: $0, fallbackNamingMaterial: objectName) }
                    .filter { $0 != Self.emptyObject }
                
                if convertedSchemas.isEmpty { // there were only empty schemas, we filtered them above!
                    return Self.emptyObject
                } else if convertedSchemas.count == 1 {
                    return convertedSchemas[0]
                }
                
                let combinedProperties = convertedSchemas
                    .flatMap { information -> [TypeProperty] in
                        guard case let .object(_, properties, _) = information else {
                            preconditionFailure("Encountered `allOf` which contains schemas different to .object: \(schema) (in: \(objectName))")
                        }
    
                        return properties
                    }
                    .filter { $0.type != Self.emptyObject }
                
                return .object(name: .init(rawValue: objectName), properties: combinedProperties)
            case let .one(of, _), let .any(of, _):
                // TRADEOFF: "oneOf" or "anyOf" cannot be fully represented in an APIDocument.
                
                // `oneOf` declares that the type matches >exactly< one sub-schema!
                // `anyOf` declares that the type matches >one or more> sub-schemas!
                
                if case .one = schema.value {
                    Self.stats.oneOfEncountersArray.append(of.count)
                } else {
                    Self.stats.anyOfEncountersArray.append(of.count)
                }
                
                // use to encode multiple different representations for the same value
                // (e.g. bool encoded as bool or string; or a simple and a complex object type)
                guard let first = of.first else {
                    preconditionFailure("`oneOf`/`anyOf` didn't contain anything: \(schema)")
                }
    
                if of.count == 1 {
                    return try self.convert(schema: first, fallbackNamingMaterial: objectName)
                }
                
                return try self.convert(schema: first, fallbackNamingMaterial: objectName)
            case .not:
                // TRADEOFF: "not" cannot be represented in an APIDocument.
    
                Self.stats.notEncounters += 1
                
                // not is really not widely used!
                logger.error("Encountered unsupported JSONSchema type `.not` within \(objectName): \(schema)")
                return Self.errorType
            case .reference:
                preconditionFailure("Encountered JSONSchema .reference even after dereferencing within \(objectName): \(schema)")
            case .fragment:
                return Self.emptyObject
            }
        }
    
        let typeInfo = try conversion()
        guard let context = schema.coreContext else {
            preconditionFailure("Assumption broke. Encountered a `.reference` where we know that there can't be one: \(schema)")
        }
        
        if !context.required || context.nullable || context.defaultValue != nil {
            return .optional(wrappedValue: typeInfo)
        }
        
        return typeInfo
    }
    
    /// Convert the `JSONSchema` passed to the initializer to the `TypeInformation` representation.
    ///
    /// - Parameter fallbackNamingMaterial: A fallback name to uniquely name a object (if encountered any) in
    ///     the case we can't automatically derive the name through resolved references.
    /// - Returns: The converted `TypeInformation` representation.
    /// - Throws: If we encounter a reference which cannot be resolved within the ``OpenAPI.Components`` object.
    public func convert(fallbackNamingMaterial: String = "UNKNOWN") throws -> TypeInformation {
        try convert(schema: schema, fallbackNamingMaterial: fallbackNamingMaterial)
    }
}

// MARK: ConversionStats
extension JSONSchemaConverter {
    /// Object capturing stats collected within the conversion algorithm.
    /// Currently it only captures stats of conversions which either can't be represented within the `TypeInformation`
    /// representation or can only be partly represented.
    public struct ConversionStats {
        /// Array capturing any encounters of `"anyOf"`.
        /// An entry in this array represents a single `"anyOf"` encounter. The integer value represents the
        /// sub-schemas present in the `"anyOf"` occurrence.
        public fileprivate(set) var anyOfEncountersArray: [Int] = []
        /// Array capturing any encounters of `"oneOf"`.
        /// An entry in this array represents a single `"oneOf"` encounter. The integer value represents the
        /// sub-schemas present in the `"oneOf"` occurrence.
        public fileprivate(set) var oneOfEncountersArray: [Int] = []
        /// Integer capturing encounters of "not" schemas.
        public fileprivate(set) var notEncounters: Int = 0
        /// The count of cyclic references that were terminated.
        public fileprivate(set) var terminatedCyclicReferences: Int = 0
    
        /// Count of `"anyOf"` encounters
        public var anyOfEncounters: Int {
            anyOfEncountersArray.count
        }
    
        /// Count of `"oneOf"` encounters
        public var oneOfEncounters: Int {
            oneOfEncountersArray.count
        }
        
        /// The count of schemas occurring inside of `"anyOf"` definitions which we didn't convert.
        /// This stat represents the amount of lost information due to the inability to fully map `"anyOf"`
        public var missedAnyOfSubSchemas: Int {
            anyOfEncountersArray.reduce(0) { partialResult, next in
                precondition(next >= 1)
                return partialResult + (next - 1) // we subtract 1, as we always convert the first schema
            }
        }
    
        /// The count of schemas occurring inside of `"oneOf"` definitions which we didn't convert.
        /// This stat represents the amount of lost information due to the inability to fully map `"oneOf"`
        public var missedOneOfSubSchemas: Int {
            oneOfEncountersArray.reduce(0) { partialResult, next in
                precondition(next >= 1)
                return partialResult + (next - 1) // we subtract 1, as we always convert the first schema
            }
        }
        
        /// Initialize a new fresh stats object.
        public init() {}
    }
}

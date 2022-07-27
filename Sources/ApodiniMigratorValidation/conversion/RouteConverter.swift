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

private let logger = Logger(label: "router-converter")

/// The RouteConverter is used to convert `OpenAPI.Document.Route` instances to multiple `Endpoint` instances.
public struct RouteConverter {
    private let route: OpenAPI.Document.Route
    
    private let components: OpenAPI.Components
    
    /// Initialize a new ``RouteConverter``.
    ///
    /// - Parameters:
    ///   - route: The `Route` we want to convert.
    ///   - components: The `OpenAPI.Components` object which is used to lookup type references.
    public init(from route: OpenAPI.Document.Route, with components: OpenAPI.Components = .init()) {
        self.route = route
        self.components = components
    }
    
    private func convert(
        parameters: [OpenAPI.Parameter],
        of operationId: String
    ) throws -> [ApodiniMigratorCore.Parameter] {
        var mappedParameters: [ApodiniMigratorCore.Parameter] = []
        
        for parameter in parameters {
            let name = parameter.name
            let isRequired: Bool
            let type: ParameterType
        
            switch parameter.context {
            case let .query(required, _), let .header(required), let .cookie(required):
                // TRADEOFF: `.header` and `.cookie` parameters are represented as `.lightweight` parameter type.
                isRequired = required
                type = .lightweight
            case .path:
                isRequired = true
                type = .path
            }
            
            let typeInfo: TypeInformation
            let namingMaterial = "\(operationId)#\(name)"
            
            switch parameter.schemaOrContent {
            case let .a(schemaContext):
                // we ignore `.style` and `.explode` parameters (see https://swagger.io/specification/#parameter-object)
                let schemaConverter = JSONSchemaConverter(from: schemaContext.schema, with: components)
                typeInfo = try schemaConverter.convert(fallbackNamingMaterial: namingMaterial)
            case let .b(contentMap):
                // TRADEOFF: we only handle a single MimeType (trying `application/json` first, if available)
                if let schema = contentMap.jsonOrFirstContentSchema {
                    let schemaConverter = JSONSchemaConverter(from: schema, with: components)
                    typeInfo = try schemaConverter.convert(fallbackNamingMaterial: namingMaterial)
                } else {
                    logger.warning("Parameter '\(name)' of \(operationId) doesn't define an appropriate content type. Using 'Empty' type as fallback.")
                    typeInfo = JSONSchemaConverter.emptyObject
                }
            }
        
            mappedParameters.append(Parameter(name: name, typeInformation: typeInfo, parameterType: type, isRequired: isRequired))
        }
        
        return mappedParameters
    }
    
    private func convert(
        requestBody: Either<JSONReference<OpenAPI.Request>, OpenAPI.Request>,
        of operationId: String,
        into mappedParameters: inout [ApodiniMigratorCore.Parameter]
    ) throws {
        let requestBody = try components.lookup(requestBody)
    
        // TRADEOFF: we have a fixed name for the request body parameter
        let name = "_requestBody"
    
        var typeInfo: TypeInformation
        let fallbackName = "\(operationId)#\(name)"
    
        // TRADEOFF: we only handle a single MimeType (trying `application/json` first, if available)
        if let schema = requestBody.content.jsonOrFirstContentSchema {
            let schemaConverter = JSONSchemaConverter(from: schema, with: components)
            typeInfo = try schemaConverter.convert(fallbackNamingMaterial: fallbackName)
        } else {
            logger.warning("Request body '\(name)' of \(operationId) doesn't define an appropriate content type. Using 'Empty' type as fallback.")
            typeInfo = JSONSchemaConverter.emptyObject
        }
        
        let optional = !requestBody.required || typeInfo.isOptional
        
        if typeInfo.isOptional {
            typeInfo = typeInfo.unwrapped
        }
        
        if typeInfo == JSONSchemaConverter.emptyObject {
            // We match model changes by its name. In order to properly encode added properties
            // to a previously empty request body, we ensure that we use the proper name to make that possible.
            typeInfo = .object(name: .init(rawValue: fallbackName), properties: [])
        }
        
        mappedParameters.append(Parameter(name: name, typeInformation: typeInfo, parameterType: .content, isRequired: !optional))
    }
    
    private func convert(
        of operation: OpenAPI.Operation,
        at path: OpenAPI.Path,
        named operationId: String
    ) throws -> TypeInformation {
        // TRADEOFF: we can only document a single response (we grab the first 2xx success code we find)
        guard let responseEither = operation.responses.someSuccessfulResponse else {
            logger.warning("\(operationId) doesn't define a response for any 2xx success status code. Using 'Empty' type as fallback.")
            return JSONSchemaConverter.emptyObject
        }
    
        let response: OpenAPI.Response = try components.lookup(responseEither)
    
        // TRADEOFF: we only handle a single MimeType (trying `application/json` first, if available)
        guard let responseSchema = response.content.jsonOrFirstContentSchema else {
            logger.warning("Response of \(operationId) doesn't define an appropriate content type. Using 'Empty' type as fallback.")
            return JSONSchemaConverter.emptyObject
        }
    
        let responseSchemaConverter = JSONSchemaConverter(from: responseSchema, with: components)
        return try responseSchemaConverter.convert(fallbackNamingMaterial: "\(operationId)#_Response")
    }
    
    private func convert(
        _ operation: OpenAPI.Operation?,
        of operationType: ApodiniMigratorCore.Operation,
        into apiDocument: inout APIDocument
    ) throws {
        guard let operation = operation else {
            return
        }
        
        let resolvedGlobalParameters: [OpenAPI.Parameter] = try route.pathItem.parameters.map(components.lookup)
    
        let path = route.path
    
        // TRADEOFF: we derive the endpoint name from the path and http method if not specified.
        let operationId = operation.operationId ?? "\(path.identifier)_\(operationType.httpMethod.lowercased())"
        
        let parameters = try operation.parameters.map(components.lookup)
        var mappedParameters = try convert(parameters: resolvedGlobalParameters + parameters, of: operationId)
        
        if let requestBodyEither = operation.requestBody {
            try convert(requestBody: requestBodyEither, of: operationId, into: &mappedParameters)
        }
    
        let responseTypeInfo = try convert(of: operation, at: path, named: operationId)
        
        let endpoint = Endpoint(
            handlerName: operationId,
            deltaIdentifier: operationId,
            operation: operationType,
            communicationPattern: .requestResponse, // TRADEOFF: communication pattern is not an OAS concept
            absolutePath: path.rawValue,
            parameters: mappedParameters,
            response: responseTypeInfo,
            errors: [] // TRADEOFF: errors aren't documented.
        )
        
        logger.debug("Operation \(operationType.httpMethod) \(path.rawValue)#\(operationId) was converted to an APIDocument endpoint.")
        apiDocument.add(endpoint: endpoint)
    }
    
    /// Convert the provided `Route` to `Endpoint` instances and add them to the provided `APIDocument`.
    /// - Parameter apiDocument: The `APIDocument` to which we want the `Endpoint`s to be added.
    /// - Throws: If we encounter a reference which cannot be resolved within the `OpenAPI.Components` object.
    public func convert(into apiDocument: inout APIDocument) throws {
        let item = route.pathItem
        
        try convert(item.get, of: .read, into: &apiDocument)
        try convert(item.put, of: .update, into: &apiDocument)
        try convert(item.post, of: .create, into: &apiDocument)
        try convert(item.delete, of: .delete, into: &apiDocument)
        
        informAboutUnsupported(item.options, name: "OPTIONS")
        informAboutUnsupported(item.head, name: "HEAD")
        informAboutUnsupported(item.patch, name: "PATCH")
        informAboutUnsupported(item.trace, name: "TRACE")
    }
    
    private func informAboutUnsupported(_ operation: OpenAPI.Operation?, name: String) {
        if let operation = operation {
            let operationId = operation.operationId ?? "UNKNOWN"
            logger.debug("Ignoring operation \(name) \(route.path.rawValue)#\(operationId) as it can't be represented in the APIDocument!")
        }
    }
}

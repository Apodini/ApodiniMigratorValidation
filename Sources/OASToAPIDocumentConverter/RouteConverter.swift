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

public struct RouteConverter {
    private let route: OpenAPI.Document.Route
    
    private let components: OpenAPI.Components
    
    public init(from route: OpenAPI.Document.Route, with references: OpenAPI.Components) {
        self.route = route
        self.components = references
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
            case let .query(required, _):
                isRequired = required
                type = .lightweight
            case .path:
                isRequired = true
                type = .path
            case .header, .cookie:
                // TODO TRADEOFF: can't document header or cookie parameters
                logger.warning("Skipping parameter '\(name)' on \(operationId)! Can't be represented in APIDocument: \(parameter)")
                continue
            }
            
            let typeInfo: TypeInformation
            let namingMaterial = "\(operationId)#\(name)"
            
            switch parameter.schemaOrContent {
            case let .a(schemaContext):
                // we ignore `.style` and `.explode` parameters (see https://swagger.io/specification/#parameter-object)
                let schemaConverter = JSONSchemaConverter(from: schemaContext.schema, with: components)
                typeInfo = try schemaConverter.convert(fallbackNamingMaterial: namingMaterial)
            case let .b(contentMap):
                // TODO TRADEOFF: can only handle a single mimetype for a parameter (application/json?)
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
    
        // TODO TRADEOFF: no parameter names for the request body parameter
        let name = "_requestBody"
    
        let typeInfo: TypeInformation
    
        // TODO TRADEOFF: can only handle a single mimetype (application/json?) for the request body
        if let schema = requestBody.content.jsonOrFirstContentSchema {
            let schemaConverter = JSONSchemaConverter(from: schema, with: components)
            typeInfo = try schemaConverter.convert(fallbackNamingMaterial: "\(operationId)#\(name)")
        } else {
            logger.warning("Request body '\(name)' of \(operationId) doesn't define an appropriate content type. Using 'Empty' type as fallback.")
            typeInfo = JSONSchemaConverter.emptyObject
        }
    
        mappedParameters.append(Parameter(name: name, typeInformation: typeInfo, parameterType: .content, isRequired: requestBody.required))
    }
    
    private func convert(
        of operation: OpenAPI.Operation,
        at path: OpenAPI.Path,
        named operationId: String
    ) throws -> TypeInformation {
        // TODO TRADEOFF: we can only document one response type (an grab the first 2xx success code)
        guard let responseEither = operation.responses.someSuccessfulResponse else {
            logger.warning("\(operationId) doesn't define a response for any 2xx success status code. Using 'Empty' type as fallback.")
            return JSONSchemaConverter.emptyObject
        }
    
        let response: OpenAPI.Response = try components.lookup(responseEither)
    
        // TODO TRADEOFF: can only handle a single mimetype (application/json?) in the response!
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
    
        // TODO TRADEOFF: endpoint naming!
        let operationId = operation.operationId ?? path.identifier
        
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
            communicationPattern: .requestResponse, // TODO TRADEOFF: communication pattern is not an OAS concept
            absolutePath: path.rawValue,
            parameters: mappedParameters,
            response: responseTypeInfo,
            errors: [] // TODO TRADEOFF: no errors are documented!
        )
        
        logger.info("Operation \(operationType.httpMethod) \(path.rawValue)#\(operationId) was converted to an APIDocument endpoint.")
        apiDocument.add(endpoint: endpoint)
    }
    
    public func convert(into apiDocument: inout APIDocument) throws {
        let item = route.pathItem
        
        try convert(item.get, of: .read, into: &apiDocument)
        try convert(item.post, of: .create, into: &apiDocument)
        try convert(item.put, of: .update, into: &apiDocument)
        try convert(item.delete, of: .delete, into: &apiDocument)
        
        informAboutUnsupported(item.options, name: "OPTIONS")
        informAboutUnsupported(item.head, name: "HEAD")
        informAboutUnsupported(item.patch, name: "PATCH")
        informAboutUnsupported(item.trace, name: "TRACE")
    }
    
    private func informAboutUnsupported(_ operation: OpenAPI.Operation?, name: String) {
        if operation != nil {
            let operationId = operation?.operationId ?? "UNKNOWN"
            logger.warning("Ignoring operation \(name) \(route.path.rawValue)#\(operationId) as it can't be represented in the APIDocument!")
        }
    }
}

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

public struct RouteConverter {
    private let route: OpenAPI.Document.Route
    
    private let components: OpenAPI.Components
    
    public init(from route: OpenAPI.Document.Route, with references: OpenAPI.Components) {
        self.route = route
        self.components = references
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
    
        let path = route.path;
        // TODO parse path parameters?
    
        // TODO e.g. getBanner (its optional though?)
        let operationId = operation.operationId ?? "DEFAULT" // TODO generate unique default of operation and path!
        // TODO have a look at the Apodini extensions to derive original names???
        // TODO TRADEOFF: endpoint naming!
        
        let parameters = try operation.parameters.map(components.lookup) // TODO parameters
        let combinedParameters = resolvedGlobalParameters + parameters
        
        var mappedParameters: [ApodiniMigratorCore.Parameter] = [] // TODO make this a converter and use map?
        for parameter in combinedParameters {
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
            case .cookie, .header:
                print("Can't handle parameter: \(parameter)")
                // TODO TRADEOFF: can't document header or cookie parameters
                continue // TODO log warning!
            }
            
            let schemaConverter: JSONSchemaConverter
            switch parameter.schemaOrContent {
            case let .a(schemaContext):
                // TODO is the `.style` relevant?
                // TODO is the `.explode` relevant? (see https://swagger.io/specification/#parameter-object)
                schemaConverter = try JSONSchemaConverter(from: schemaContext.schema, with: components)
            case let .b(contentMap):
                guard let schema = contentMap.first?.value.schema else {
                    continue // TODO handle this more gracefully!
                }
                // TODO TRADEOFF: can only handle a single mimetype for a parameter (application/json?)
                schemaConverter = try JSONSchemaConverter(from: schema, with: components)
            }
            
            let typeInfo = try schemaConverter.convert()
    
            mappedParameters.append(Parameter(name: name, typeInformation: typeInfo, parameterType: type, isRequired: isRequired))
        }
        
        if let requestBodyEither = operation.requestBody {
            let requestBody = try components.lookup(requestBodyEither)
            
            let name = "_requestBody" // TODO TRADEOFF: no parameter names for the request body parameter
            
            guard let schema = requestBody.content.first?.value.schema else {
                print("didn't find schema for requestbody!") // TODO adjust
                return // TODO handle this more gracefully (like above!)
            }
            // TODO TRADEOFF: can only handle a single mimetype (application/json?) for the request body
            
            let schemaConverter = try JSONSchemaConverter(from: schema, with: components)
            let typeInfo = try schemaConverter.convert()
            
            mappedParameters.append(Parameter(name: name, typeInformation: typeInfo, parameterType: .content, isRequired: requestBody.required))
        }
    
        // TODO TRADEOFF: we can only document one response type
        // TODO instead of always grabbing, grab the first 2xx response code?
        guard let responseEither = operation.responses[status: 200] else {
            print("didn't find response for response: \(path.rawValue) + \(operationId)") // TODO adjust message
            return // TODO log and warn!
        }
        
        let response: OpenAPI.Response = try components.lookup(responseEither)
        
        guard let responseSchema = response.content.first?.value.schema else {
            print("didn't find schema for response!") // TODO adjust
            return // TODO handle this more gracefully (like above!)
        }
        // TODO TRADEOFF: can only handle a single mimetype (application/json?) in the response!
        
        let responseSchemaConverter = try JSONSchemaConverter(from: responseSchema, with: components)
        let responseTypeInfo = try responseSchemaConverter.convert()
        
        // TODO consider pulling out the errors for completeness (we just maintain error codes + description, nothing else)
        
        let endpoint = Endpoint(
            handlerName: operationId,
            deltaIdentifier: operationId,
            operation: operationType,
            communicationPattern: .requestResponse, // TODO TRADEOFF: communication pattern is not an OAS concept
            absolutePath: path.rawValue, // TODO check if we need to handle anything here still?
            parameters: mappedParameters,
            response: responseTypeInfo,
            errors: [] // TODO TRADEOFF: no errors are documented!
        )
        
        print("ADding endpoint for \(path.rawValue) + \(operationId)")
        apiDocument.add(endpoint: endpoint)
    }
    
    public func convert(into apiDocument: inout APIDocument) throws {
        let item = route.pathItem
        
        try convert(item.get, of: .read, into: &apiDocument)
        try convert(item.post, of: .create, into: &apiDocument)
        try convert(item.put, of: .update, into: &apiDocument)
        try convert(item.delete, of: .delete, into: &apiDocument)
        // TODO TRADEOFF: unsupported HTTP methods
        // TODO unsupported operations: `options`, `head`, `patch`, `trace` (log if they exist in the OAS)
    }
}

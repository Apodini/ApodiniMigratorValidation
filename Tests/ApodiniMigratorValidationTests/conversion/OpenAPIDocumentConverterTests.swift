//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import XCTest
@testable import ApodiniMigratorValidation
import ApodiniTypeInformation
import ApodiniMigratorCore
import OpenAPIKit30

private func AMAssertEqual(
    _ expression1: @autoclosure () throws -> APIDocument,
    _ expression2: @autoclosure () throws -> APIDocument,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let uuid = UUID()
    
    XCTAssertEqual(
        try { () throws -> APIDocument in
            var document = try expression1()
            overwriteDocumentId(of: &document, with: uuid)
            return document
        }(),
        try { () throws -> APIDocument in
            var document = try expression2()
            overwriteDocumentId(of: &document, with: uuid)
            return document
        }(),
        message(),
        file: file,
        line: line
    )
}

private func overwriteDocumentId(of document: inout APIDocument, with id: UUID) {
    withUnsafeMutableBytes(of: &document) { pointer in
        pointer[0] = id.uuid.0
        pointer[1] = id.uuid.1
        pointer[2] = id.uuid.2
        pointer[3] = id.uuid.3
        pointer[4] = id.uuid.4
        pointer[5] = id.uuid.5
        pointer[6] = id.uuid.6
        pointer[7] = id.uuid.7
        pointer[8] = id.uuid.8
        pointer[9] = id.uuid.9
        pointer[10] = id.uuid.10
        pointer[11] = id.uuid.11
        pointer[12] = id.uuid.12
        pointer[13] = id.uuid.13
        pointer[14] = id.uuid.14
        pointer[15] = id.uuid.15
    }
}

final class OpenAPIDocumentConverterTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testSimpleOpenAPISpecification() throws {
        let document: OpenAPI.Document = .init(
            info: .init(title: "TestService", version: "1.0.0"),
            // swiftlint:disable:next force_unwrapping
            servers: [.init(url: .init(string: "http://example.de")!)],
            paths: [
                "/test": .init(
                    get: .init(
                        operationId: "hello-world",
                        parameters: [
                            .b(.init(
                                name: "name",
                                context: .query(required: true),
                                schema: .string
                            )),
                            .a(.internal(.component(name: "age_param")))
                        ],
                        responses: [:]
                    ),
                    
                    put: .init(
                        parameters: [
                            .b(.init(
                                name: "param0",
                                context: .header(required: false),
                                content: [.json: .init(schema: .boolean)]
                            )),
                            .b(.init(
                                name: "param1",
                                context: .cookie(required: false),
                                content: [.xml: .init(schema: .fragment)]
                            )),
                            .b(.init(
                                name: "param2",
                                context: .query(required: true),
                                content: [:]
                            ))
                        ],
                        responses: [:]
                    ),
                    
                    post: .init(
                        requestBody: .init(
                            content: .init(),
                            required: true
                        ),
                        responses: [
                            .status(code: 200): .init(OpenAPI.Response(
                                description: "Description",
                                content: [:]
                            ))
                        ]
                    ),
                    
                    delete: .init(
                        operationId: "some-delete",
                        requestBody: .init(
                            content: [.json: .init(schema: .b(.string(required: false)))],
                            required: true
                        ),
                        responses: [
                            .status(code: 200): .init(OpenAPI.Response(
                                description: "Description",
                                content: [.json: .init(schema: .string)]
                            ))
                        ]
                    ),
                    
                    patch: .init(operationId: "ignored-test-vector", responses: [:]),
                    trace: .init(responses: [:])
                )
            ],
            components: .init(
                parameters: ["age_param": .init(name: "age", context: .path, schema: .integer)]
            )
        )
        
        let converter = OpenAPIDocumentConverter(from: document)
        
        let serviceInformation = ServiceInformation(version: Version(), http: HTTPInformation(protocol: .http, hostname: "example.de", port: 80))
        var expectedDocument = APIDocument(serviceInformation: serviceInformation)
    
        expectedDocument.add(endpoint: Endpoint(
            handlerName: "hello-world",
            deltaIdentifier: "hello-world",
            operation: .read,
            communicationPattern: .requestResponse,
            absolutePath: "/test",
            parameters: [
                Parameter(name: "name", typeInformation: .scalar(.string), parameterType: .lightweight, isRequired: true),
                Parameter(name: "age", typeInformation: .scalar(.int), parameterType: .path, isRequired: true)
            ],
            response: JSONSchemaConverter.emptyObject,
            errors: []
        ))
        
        expectedDocument.add(endpoint: Endpoint(
            handlerName: "test_put",
            deltaIdentifier: "test_put",
            operation: .update,
            communicationPattern: .requestResponse,
            absolutePath: "/test",
            parameters: [
                Parameter(name: "param0", typeInformation: .scalar(.bool), parameterType: .lightweight, isRequired: false),
                Parameter(name: "param1", typeInformation: JSONSchemaConverter.emptyObject, parameterType: .lightweight, isRequired: false),
                Parameter(name: "param2", typeInformation: JSONSchemaConverter.emptyObject, parameterType: .lightweight, isRequired: true)
            ],
            response: JSONSchemaConverter.emptyObject,
            errors: []
        ))
    
        expectedDocument.add(endpoint: Endpoint(
            handlerName: "test_post",
            deltaIdentifier: "test_post",
            operation: .create,
            communicationPattern: .requestResponse,
            absolutePath: "/test",
            parameters: [
                Parameter(
                    name: "_requestBody",
                    typeInformation: .object(name: .init(rawValue: "test_post#_requestBody"), properties: []),
                    parameterType: .content,
                    isRequired: true
                )
            ],
            response: JSONSchemaConverter.emptyObject,
            errors: []
        ))
    
        expectedDocument.add(endpoint: Endpoint(
            handlerName: "some-delete",
            deltaIdentifier: "some-delete",
            operation: .delete,
            communicationPattern: .requestResponse,
            absolutePath: "/test",
            parameters: [
                Parameter(name: "_requestBody", typeInformation: .scalar(.string), parameterType: .content, isRequired: false)
            ],
            response: .scalar(.string),
            errors: []
        ))
        
        
        let result = try converter.convert()
        AMAssertEqual(result, expectedDocument)
        
        // use below for easy diff checking!
        // print(result.json(prettyPrinted: true))
        // print(expectedDocument.json(prettyPrinted: true))
    }
    
    func testEmptyServerURLsAndNonSemverVersion() throws {
        let converter = OpenAPIDocumentConverter(from: .init(
            info: .init(title: "TestService", version: "SomeVersion"),
            servers: [],
            paths: ["/test": .init()],
            components: .init()
        ))
        
        AMAssertEqual(
            try converter.convert(),
            APIDocument(serviceInformation: ServiceInformation(
                version: Version(),
                http: HTTPInformation(protocol: .http, hostname: "example.com", port: 80)
            ))
        )
    }
}

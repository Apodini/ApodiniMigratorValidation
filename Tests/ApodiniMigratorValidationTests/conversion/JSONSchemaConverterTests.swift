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
import OpenAPIKit30
import XCTAssertCrash

func convert(
    _ schema: JSONSchema,
    fallbackNamingMaterial: String = "test",
    with components: OpenAPI.Components = .init()
) throws -> TypeInformation {
    let converter = JSONSchemaConverter(from: schema, with: components)
    return try converter.convert(fallbackNamingMaterial: fallbackNamingMaterial)
}

func AMAssertConversion(
    _ expression1: @autoclosure () throws -> JSONSchema,
    fallbackNamingMaterial: String = "test",
    _ expression2: @autoclosure () throws -> TypeInformation,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try XCTAssertEqual(convert(expression1(), fallbackNamingMaterial: fallbackNamingMaterial), expression2(), message(), file: file, line: line)
}

final class JSONSchemaConverterTests: XCTestCase {
    
    func testBoolConversion() throws {
        try AMAssertConversion(.boolean(format: .generic), .scalar(.bool))
        try AMAssertConversion(.boolean(format: .other("test-vector")), .scalar(.bool))
    }
    
    func testNumberConversion() throws {
        try AMAssertConversion(.number(format: .generic), .scalar(.double))
        try AMAssertConversion(.number(format: .float), .scalar(.float))
        try AMAssertConversion(.number(format: .double), .scalar(.double))
        try AMAssertConversion(.number(format: .other("test-vector")), .scalar(.double))
    }
    
    func testIntegerConversion() throws {
        try AMAssertConversion(.integer(format: .generic), .scalar(.int))
        try AMAssertConversion(.integer(format: .int32), .scalar(.int32))
        try AMAssertConversion(.integer(format: .int64), .scalar(.int64))
        try AMAssertConversion(.integer(format: .extended(.uint32)), .scalar(.uint32))
        try AMAssertConversion(.integer(format: .extended(.uint64)), .scalar(.uint64))
        try AMAssertConversion(.integer(format: .other("test-vector")), .scalar(.int))
    }
    
    func testStringConversion() throws {
        try AMAssertConversion(.string(format: .generic), .scalar(.string))
        try AMAssertConversion(.string(format: .byte), .scalar(.data))
        try AMAssertConversion(.string(format: .binary), .scalar(.data))
        try AMAssertConversion(.string(format: .date), .scalar(.date))
        try AMAssertConversion(.string(format: .dateTime), .scalar(.date))
        try AMAssertConversion(.string(format: .password), .scalar(.string))
    
        try AMAssertConversion(.string(format: .extended(.uuid)), .scalar(.uuid))
        try AMAssertConversion(.string(format: .extended(.email)), .scalar(.string))
        try AMAssertConversion(.string(format: .extended(.hostname)), .scalar(.string))
        try AMAssertConversion(.string(format: .extended(.ipv4)), .scalar(.string))
        try AMAssertConversion(.string(format: .extended(.ipv6)), .scalar(.string))
        try AMAssertConversion(.string(format: .extended(.uri)), .scalar(.url))
        try AMAssertConversion(.string(format: .extended(.uriReference)), .scalar(.url))
    
        try AMAssertConversion(.string(format: .other("uri-template")), .scalar(.url))
        try AMAssertConversion(.string(format: .other("timestamp")), .scalar(.date))
    
        try AMAssertConversion(.string(format: .other("test-vector")), .scalar(.string))
    }
    
    func testStringEnumConversion() throws {
        // test the `enum` property
        try AMAssertConversion(
            .string(allowedValues: "case1", "case2", "case3"),
            fallbackNamingMaterial: "TestEnum",
            .enum(name: TypeName(rawValue: "TestEnum"), rawValueType: .scalar(.string), cases: [
                EnumCase("case1"),
                EnumCase("case2"),
                EnumCase("case3")
            ])
        )
    }
    
    func testOptionalStringConversion() throws {
        try AMAssertConversion(.string(required: false), .optional(wrappedValue: .scalar(.string)))
    }
    
    func testObjectConversion() throws {
        try AMAssertConversion(.object(), JSONSchemaConverter.emptyObject)
        try AMAssertConversion(
            .object(properties: [
                "name": .string,
                "age": .integer,
                "address": .string(required: false)
            ]),
            fallbackNamingMaterial: "TestObject",
            .object(
                name: TypeName(rawValue: "TestObject"),
                properties: [
                    TypeProperty(name: "name", type: .scalar(.string)),
                    TypeProperty(name: "age", type: .scalar(.int)),
                    TypeProperty(name: "address", type: .optional(wrappedValue: .scalar(.string)))
                ]
            )
        )
    }
    
    func testObjectConversionWithNaming() throws {
        let components = OpenAPI.Components(schemas: [
            "Person": .object(properties: [
                "name": .string,
                "age": .integer,
                "car": .object(properties: ["electric": .boolean])
            ])
        ])
        
        // we test, that the name is properly pulled out of the reference name!
    
        XCTAssertEqual(
            try convert(.reference(.internal(.component(name: "Person"))), with: components),
            .object(
                name: TypeName(rawValue: "Person"),
                properties: [
                    TypeProperty(name: "name", type: .scalar(.string)),
                    TypeProperty(name: "age", type: .scalar(.int)),
                    TypeProperty(name: "car", type: .object(
                        name: TypeName(rawValue: "Person#car"),
                        properties: [TypeProperty(name: "electric", type: .scalar(.bool))]
                    ))
                ]
            )
        )
    }
    
    func testArrayConversion() throws {
        try AMAssertConversion(.array(items: .string()), .repeated(element: .scalar(.string)))
        XCTAssertCrash(try! convert(.array())) // swiftlint:disable:this force_try
    }
    
    func testAllOfConversion() throws {
        try AMAssertConversion(
            .all(of: [
                .object(properties: [
                    "name": .string,
                    "age": .integer
                ]),
                .object(properties: [
                    "address": .string(required: false)
                ])
            ]),
            fallbackNamingMaterial: "TestObject",
            .object(
                name: TypeName(rawValue: "TestObject"),
                properties: [
                    TypeProperty(name: "name", type: .scalar(.string)),
                    TypeProperty(name: "age", type: .scalar(.int)),
                    TypeProperty(name: "address", type: .optional(wrappedValue: .scalar(.string)))
                ]
            )
        )
        
        XCTAssertCrash(try! convert(.all(of: []))) // swiftlint:disable:this force_try
        XCTAssertCrash(try! convert(.all(of: .string, .integer))) // swiftlint:disable:this force_try
    }
    
    func testAllOfConversionWithRetainingReferenceName() throws {
        let components = OpenAPI.Components(schemas: [
            "Person": .object(properties: [
                "name": .string,
                "age": .integer
            ])
        ])
        
        // this tests ensures that the conversion algorithm pulls out the object name
        // from the reference name if we have a allOf with a single item
        
        XCTAssertEqual(
            try convert(.all(of: .reference(.internal(.component(name: "Person")))), with: components),
            .object(
                name: TypeName(rawValue: "Person"),
                properties: [
                    TypeProperty(name: "name", type: .scalar(.string)),
                    TypeProperty(name: "age", type: .scalar(.int))
                ]
            )
        )
    }
    
    func testUnsupportedConversions() throws {
        XCTAssertCrash(try! convert(.not(.string))) // swiftlint:disable:this force_try
    }
    
    // TODO test oneOf and anyOf
    
    // TODO test cyclic references!
    
    // TODO test convenience initializer
}

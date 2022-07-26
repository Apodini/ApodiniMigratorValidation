//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorValidation
import OpenAPIKit30
import PathKit
import ArgumentParser
import Logging
import ApodiniTypeInformation

private let logger = Logger(label: "main")

struct Convert: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Convert OpenAPI Specification documents to ApodiniMigrator APIDocuments."
    )
    
    @Option(name: .shortAndLong, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var input: String
    
    @Option(name: .shortAndLong, help: "The destination to write the resulting API Document.", completion: .file(extensions: ["json"]))
    var output: String
    
    mutating func run() throws {
        let inputPath = Path(input).absolute()
        let outputPath = Path(output).absolute()
        
        guard inputPath.exists else {
            throw ArgumentParser.ValidationError("The provided input file doesn't exists: \(input)")
        }
        
        logger.info("Reading OpenAPI Specification document from \(input)")
        let document = try OpenAPI.Document.decode(from: inputPath)
        
        let converter = OpenAPIDocumentConverter(from: document)
        let result = try converter.convert()
        
        logger.info("Writing resulting APIDocument to \(outputPath)")
        try outputPath.write(result.json)
        
        let stats = JSONSchemaConverter.stats
        
        var typeCount = result.typeStore.count
        
        let ignoredTypes: [TypeInformation] = [JSONSchemaConverter.errorType, JSONSchemaConverter.recursiveTypeTerminator]
        // swiftlint:disable:next force_unwrapping
        for type in ignoredTypes where result.typeStore.keys.contains(type.asReference().referenceKey!) {
            typeCount -= 1
        }
        
        print("""
              ---------------------------- STATS ----------------------------
              - "not" encounters:                 \(stats.notEncounters)
              - terminated cyclic references:     \(stats.terminatedCyclicReferences)

              - "anyOf" count:                    \(stats.anyOfEncounters)
              - "oneOf" count:                    \(stats.oneOfEncounters)
              - total:                            \(stats.anyOfEncounters + stats.oneOfEncounters)

              - missed "anyOf" sub-schemas:       \(stats.missedAnyOfSubSchemas)
              - missed "oneOf" sub-schemas:       \(stats.missedOneOfSubSchemas)
              - total missed sub-schemas:         \(stats.missedAnyOfSubSchemas + stats.missedOneOfSubSchemas)

              - total type count:                 \(typeCount)
              - total endpoint count:             \(result.endpoints.count)
              ---------------------------------------------------------------
              """)
    }
}

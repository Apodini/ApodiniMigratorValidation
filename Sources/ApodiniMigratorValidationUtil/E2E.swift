//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorValidation
import ApodiniMigratorCompare
import OpenAPIKit30
import PathKit
import ArgumentParser
import Logging

private let logger = Logger(label: "main")

struct E2E: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "e2e",
        abstract: "Print stats about a ApodiniMigrator MigrationGuide." // TODO describe!
    )
    
    @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var previous: String
    
    @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var current: String
    
    func convert(_ document: OpenAPI.Document) throws -> APIDocument {
        let converter = OpenAPIDocumentConverter(from: document)
        return try converter.convert() // TODO how to capture stats!
    }
    
    mutating func run() throws {
        let previousPath = Path(previous).absolute()
        let currentPath = Path(current).absolute()
        
        guard previousPath.exists else {
            throw ArgumentParser.ValidationError("The provided `previous` file doesn't exists: \(previousPath)")
        }
    
        guard currentPath.exists else {
            throw ArgumentParser.ValidationError("The provided `current` file doesn't exists: \(currentPath)")
        }
    
        logger.info("Reading `previous` OpenAPI Specification document from \(previousPath)")
        let previousOAS = try OpenAPI.Document.decode(from: previousPath)
        logger.info("Reading `current` OpenAPI Specification document from \(currentPath)")
        let currentOAS = try OpenAPI.Document.decode(from: currentPath)
        
        logger.info("Converting `previous` document...")
        let previousDocument = try convert(previousOAS)
        let stats0 = JSONSchemaConverter.stats
        logger.info("Converting `current` document...")
        let currentDocument = try convert(currentOAS)
        
        // TODO what stats to use!
        
        let migrationGuide = MigrationGuide(for: previousDocument, rhs: currentDocument)
    
        var changeStats = MigrationGuideStats()
        changeStats.analyze(document: migrationGuide)
        
        print(changeStats.formattedOutput)
        
        // TODO print(migrationGuide.json)
    
        let stats = JSONSchemaConverter.stats
    
        var typeCount0 = previousDocument.typeStore.count
        var typeCount = currentDocument.typeStore.count
    
        let ignoredTypes: [TypeInformation] = [JSONSchemaConverter.errorType, JSONSchemaConverter.recursiveTypeTerminator]
        for type in ignoredTypes {
            // swiftlint:disable:next force_unwrapping
            if currentDocument.typeStore.keys.contains(type.asReference().referenceKey!) {
                typeCount -= 1
            }
            // swiftlint:disable:next force_unwrapping
            if previousDocument.typeStore.keys.contains(type.asReference().referenceKey!) {
                typeCount0 -= 1
            }
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
              - total missed sub-schemas0:        \(stats0.missedAnyOfSubSchemas + stats0.missedOneOfSubSchemas)
              
              - total type count:                 \(typeCount)
              - total type count0:                \(typeCount0)
              - total endpoint count:             \(currentDocument.endpoints.count)
              ---------------------------------------------------------------
              """)
    }
}

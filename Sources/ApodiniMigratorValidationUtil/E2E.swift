//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
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
        abstract: "Convert two OAS documents, generate the MigrationGuide and output the latex table contents for the paper."
    )
    
    @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var previous: String
    
    @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var current: String
    
    func convert(_ document: OpenAPI.Document) throws -> (APIDocument, JSONSchemaConverter.ConversionStats) {
        let converter = OpenAPIDocumentConverter(from: document)
        return (try converter.convert(), JSONSchemaConverter.stats)
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
        let (previousDocument, previousStats) = try convert(previousOAS)
        logger.info("Converting `current` document...")
        let (currentDocument, currentStats) = try convert(currentOAS)
        
        let migrationGuide = MigrationGuide(for: previousDocument, rhs: currentDocument)
    
        var changeStats = MigrationGuideStats()
        changeStats.analyze(document: migrationGuide)
    
        var previousTypeCount = previousDocument.typeStore.count
        var currentTypeCount = currentDocument.typeStore.count
    
        let ignoredTypes: [TypeInformation] = [JSONSchemaConverter.errorType, JSONSchemaConverter.recursiveTypeTerminator]
        for type in ignoredTypes {
            // swiftlint:disable:next force_unwrapping
            if currentDocument.typeStore.keys.contains(type.asReference().referenceKey!) {
                currentTypeCount -= 1
            }
            // swiftlint:disable:next force_unwrapping
            if previousDocument.typeStore.keys.contains(type.asReference().referenceKey!) {
                previousTypeCount -= 1
            }
        }
    
        let endpoint = changeStats.endpointChangeStats
        let model = changeStats.modelChangeStats
        let scripts = changeStats.scriptStats
        
        print("""
              NAME & \(endpoint.additionStats.changeCount) & \(endpoint.removalStats.changeCount) \
              & \(endpoint.updateStats.changeCount + endpoint.idChangeStats.changeCount) & \(model.additionStats.changeCount) \
              & \(model.removalStats.changeCount) & \(model.updateStats.changeCount + model.idChangeStats.changeCount) \
              & \(scripts.scripts) & \(scripts.jsonValues) \\\\
              """)
        print("")
        
        let endpointStats = endpoint.allStats
        let modelStats = model.allStats
        
        print("""
              NAME & \(endpointStats.total(of: \.breaking)) & \(endpointStats.total(of: \.unsolvable)) \
              & \(modelStats.total(of: \.breaking)) & \(modelStats.total(of: \.unsolvable)) \
              & \(currentStats.missedAnyOfSubSchemas + currentStats.missedOneOfSubSchemas) \
              (\(previousStats.missedAnyOfSubSchemas + previousStats.missedOneOfSubSchemas)) \
              & \(currentTypeCount) (\(previousTypeCount)) \\\\
              """)
    }
}

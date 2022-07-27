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

struct E2E {
    private var migrationGuideOutputBasePath: Path?
    
    fileprivate var changeTableLines: [String] = []
    fileprivate var breakingSolvableTableLines: [String] = []
    
    init(migrationGuideOutputBasePath: Path? = nil) {
        self.migrationGuideOutputBasePath = migrationGuideOutputBasePath
    }
    
    // swiftlint:disable:next function_body_length
    fileprivate mutating func analyze(lhs: Path, rhs: Path, entry: Bulk.BulkEntry? = nil) throws {
        guard lhs.exists else {
            throw ArgumentParser.ValidationError("The provided `lhs` file doesn't exists: \(lhs)")
        }
    
        guard rhs.exists else {
            throw ArgumentParser.ValidationError("The provided `rhs` file doesn't exists: \(rhs)")
        }
    
        logger.info("Reading `previous` OpenAPI Specification document from \(lhs)")
        let previousOAS = try OpenAPI.Document.decode(from: lhs)
        logger.info("Reading `current` OpenAPI Specification document from \(rhs)")
        let currentOAS = try OpenAPI.Document.decode(from: rhs)
    
        logger.info("Converting `previous` document...")
        let (previousDocument, previousStats) = try convert(previousOAS)
        logger.info("Converting `current` document...")
        let (currentDocument, currentStats) = try convert(currentOAS)
    
        let migrationGuide = MigrationGuide(for: previousDocument, rhs: currentDocument)
    
        var changeStats = MigrationGuideStats()
        changeStats.analyze(document: migrationGuide)
    
        var previousTypeCount = previousDocument.typeStore.count
        var currentTypeCount = currentDocument.typeStore.count
    
        // swiftlint:disable:next force_unwrapping
        for key in [JSONSchemaConverter.errorType, JSONSchemaConverter.recursiveTypeTerminator].map({ $0.asReference().referenceKey! }) {
            if currentDocument.typeStore.keys.contains(key) {
                currentTypeCount -= 1
            }
        
            if previousDocument.typeStore.keys.contains(key) {
                previousTypeCount -= 1
            }
        }
    
        let endpoint = changeStats.endpointChangeStats
        let model = changeStats.modelChangeStats
        let scripts = changeStats.scriptStats
        
        changeTableLines.append("""
                                \(entry?.name ?? "NAME") (\(entry?.lhsVersion ?? previousOAS.info.version)\\textrightarrow \(entry?.rhsVersion ?? currentOAS.info.version)) \
                                & \(endpoint.additionStats.changeCount) & \(endpoint.removalStats.changeCount) \
                                & \(endpoint.updateStats.changeCount + endpoint.idChangeStats.changeCount) & \(model.additionStats.changeCount) \
                                & \(model.removalStats.changeCount) & \(model.updateStats.changeCount + model.idChangeStats.changeCount) \
                                & \(scripts.scripts) & \(scripts.jsonValues) \\\\
                                """)
    
        let endpointStats = endpoint.allStats
        let modelStats = model.allStats
    
        breakingSolvableTableLines.append("""
                                          \(entry?.name ?? "NAME") \
                                          & \(endpointStats.total(of: \.breaking)) & \(endpointStats.total(of: \.unsolvable)) \
                                          & \(endpointStats.total(of: \.changeCount)) \
                                          & \(modelStats.total(of: \.breaking)) & \(modelStats.total(of: \.unsolvable)) \
                                          & \(modelStats.total(of: \.changeCount)) \
                                          & \(currentStats.missedAnyOfSubSchemas + currentStats.missedOneOfSubSchemas) \
                                          (\(previousStats.missedAnyOfSubSchemas + previousStats.missedOneOfSubSchemas)) \
                                          & \(currentTypeCount) (\(previousTypeCount)) \\\\
                                          """)
        
        if let migrationGuideOutputBasePath = migrationGuideOutputBasePath {
            let name: String
            if let entryName = entry?.name {
                name = "migration-guide_\(entryName.replacingOccurrences(of: " ", with: "_")).json".lowercased()
            } else {
                name = "migration-guide.json"
            }
            
            let outputPath = migrationGuideOutputBasePath + Path(name)
            try outputPath.write(migrationGuide.json)
        }
    }
    
    func printTableEntries() {
        print("")
        print("")
        print("Change Table:")
        print(changeTableLines.joined(separator: "\n\\hline\n"))
        print("")
        print("Breaking/Solvable Table:")
        print(breakingSolvableTableLines.joined(separator: "\n\\hline\n"))
    }
    
    private func convert(_ document: OpenAPI.Document) throws -> (APIDocument, JSONSchemaConverter.ConversionStats) {
        let converter = OpenAPIDocumentConverter(from: document)
        return (try converter.convert(), JSONSchemaConverter.stats)
    }
    
    struct Bulk: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "e2e-bulk",
            abstract: "Convert multiple OAS documents, generate the MigrationGuide and output the latex table contents for the paper."
        )
        
        @Option(
            name: .shortAndLong,
            help: "Folder containing bulk of OAS documents and a `document.json` index file.",
            completion: .directory,
            transform: { Path($0) }
        )
        var documents = Path("./Documents")
        
        @Flag(name: .shortAndLong, help: "When specified, MigrationGuides will be written to the `migration-guides-output` directory.")
        var outputMigrationGuides = false
        
        fileprivate struct BulkEntry: Decodable {
            let name: String
            let lhs: String
            let lhsVersion: String?
            let lhsSource: String
            let rhs: String
            let rhsVersion: String?
            let rhsSource: String
    
            var skip: Bool? // swiftlint:disable:this discouraged_optional_boolean
        }
    
        mutating func run() throws {
            let absoluteDocuments = documents.absolute()
            guard absoluteDocuments.exists else {
                throw ArgumentParser.ValidationError("The provided `documents` directory doesn't exists: \(absoluteDocuments)")
            }
            
            let jsonFilePath = documents.absolute() + Path("documents.json")
            guard jsonFilePath.exists else {
                throw ArgumentParser.ValidationError("The provided `documents` directory must contain the index file `documents.json`!")
            }
            
            let migrationGuideOutput: Path?
            if outputMigrationGuides {
                let path = absoluteDocuments + "migration-guides-output"
                migrationGuideOutput = path
                if !path.exists {
                    try path.mkdir()
                }
            } else {
                migrationGuideOutput = nil
            }
            
            var e2e = E2E(migrationGuideOutputBasePath: migrationGuideOutput)
            let entries = try [BulkEntry]
                .decode(from: jsonFilePath)
                .filter { $0.skip != true }
                .sorted(by: \.name)
            
            for entry in entries {
                logger.info("Parsing bulk entry: `\(entry.name)`")
                try e2e.analyze(lhs: documents + Path(entry.lhs), rhs: documents + Path(entry.rhs), entry: entry)
            }
            
            e2e.printTableEntries()
        }
    }
    
    struct OneShot: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "e2e",
            abstract: "Convert two OAS documents, generate the MigrationGuide and output the latex table contents for the paper."
        )
    
        @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
        var previous: Path
    
        @Option(name: .long, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
        var current: Path
    
        mutating func run() throws {
            var e2e = E2E()
            
            try e2e.analyze(lhs: previous.absolute(), rhs: current.absolute())
            
            e2e.printTableEntries()
        }
    }
}

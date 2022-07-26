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
import PathKit
import ArgumentParser
import Logging

private let logger = Logger(label: "main")

struct Stats: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Print stats about a ApodiniMigrator MigrationGuide."
    )
    
    @Option(name: .shortAndLong, help: "The MigrationGuide you want to analyze.", completion: .file(extensions: ["json", "yaml"]))
    var input: String
    
    mutating func run() throws {
        let inputPath = Path(input).absolute()
    
        guard inputPath.exists else {
            throw ArgumentParser.ValidationError("The provided input file doesn't exists: \(input)")
        }
        
        let document = try MigrationGuide.decode(from: inputPath)
        
        var stats = MigrationGuideStats()
        stats.analyze(document: document)
        
        print(stats.formattedOutput)
    }
}

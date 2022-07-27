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
    
    @Flag(name: .shortAndLong, help: "Print the stats in the latex table format.")
    var latexTable = false
    
    mutating func run() throws {
        let inputPath = Path(input).absolute()
    
        guard inputPath.exists else {
            throw ArgumentParser.ValidationError("The provided input file doesn't exists: \(input)")
        }
        
        let document = try MigrationGuide.decode(from: inputPath)
        
        var stats = MigrationGuideStats()
        stats.analyze(document: document)
        
        if latexTable {
            let endpoint = stats.endpointChangeStats
            let model = stats.modelChangeStats
            let scripts = stats.scriptStats
    
            print("")
            print("")
            print("Change Table:")
            print("""
                  NAME \
                  & \(endpoint.additionStats.changeCount) & \(endpoint.removalStats.changeCount) \
                  & \(endpoint.updateStats.changeCount + endpoint.idChangeStats.changeCount) & \(model.additionStats.changeCount) \
                  & \(model.removalStats.changeCount) & \(model.updateStats.changeCount + model.idChangeStats.changeCount) \
                  & \(scripts.scripts) & \(scripts.jsonValues) \\\\
                  """)
    
            let endpointStats = endpoint.allStats
            let modelStats = model.allStats
    
            print("")
            print("Breaking/Solvable Table:")
            print("""
                  NAME \
                  & \(endpointStats.total(of: \.breaking)) & \(endpointStats.total(of: \.unsolvable)) \
                  & \(endpointStats.total(of: \.changeCount)) \
                  & \(modelStats.total(of: \.breaking)) & \(modelStats.total(of: \.unsolvable)) \
                  & \(modelStats.total(of: \.changeCount)) \
                  & - \
                  & - \\\\
                  """)
        } else {
            print(stats.formattedOutput)
        }
    }
}

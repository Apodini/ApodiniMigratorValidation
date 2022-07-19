//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorValidation
import PathKit
import OpenAPIKit30
import ArgumentParser
import Logging

private let logger = Logger(label: "main")

@main
public struct CLI: ParsableCommand {
    @Option(name: .shortAndLong, help: "The OpenAPI Specification document used as the input.", completion: .file(extensions: ["json", "yaml"]))
    var input: String
    
    @Option(name: .shortAndLong, help: "The destination to write the resulting API Document.", completion: .file(extensions: ["json"]))
    var output: String
    
    public init() {}
    
    public mutating func run() throws {
        // TODO integrate "migrator stats" command from the generate APIDocument!
        // TODO or make a validation utility out from this -> (convert, compare, stats)?
        
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
    }
}

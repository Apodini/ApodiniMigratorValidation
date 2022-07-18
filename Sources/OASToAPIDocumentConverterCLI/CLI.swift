//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OASToAPIDocumentConverter
import PathKit
import OpenAPIKit30

@main
public struct CLI {
    public static func main() async throws {
        // TODO integrate "migrator stats" command from the generate APIDocument!
        // TODO or make a validation utility out from this -> (convert, compare, stats)?
        
        let inPath = Path("/Users/andi/Downloads/GR-OAS/swagger.v3.json")
        let outPath = Path("/Users/andi/Downloads/GR-OAS/api-document.json")
        precondition(inPath.exists)
        
        let decoder = JSONDecoder()
        let document = try decoder.decode(OpenAPI.Document.self, from: try inPath.read())
        
        let converter = OpenAPIDocumentConverter(from: document)
        
        let result = try converter.convert()
        
        print(result)
        print("---------------------------------------------")
        print(result.json)
        try outPath.write(result.json)
    }
}

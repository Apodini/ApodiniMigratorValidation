//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

public struct ScriptStats {
    /// The count of type conversion scripts present in the Migration Guide document.
    private(set) var scripts: Int = 0
    /// The count of default/fallback values present in the Migration Guide document.
    private(set) var jsonValues: Int = 0
    /// The count of JSON object representations captured in the Migration Guide document.
    /// As of now, this are only used within the generation of encoding/decoding tests in the RESTMigrator.
    private(set) var objectJSONs: Int = 0
    
    public init() {}
    
    public mutating func record(document: MigrationGuide) {
        scripts = document.scripts.count
        jsonValues = document.jsonValues.count
        objectJSONs = document.objectJSONs.count
    }
    
    public var formattedOutput: String {
        """
        - scripts:     \(scripts) \t(type conversions)
        - jsonValues:  \(jsonValues) \t(default/fallback values)
        - objectJSONS: \(objectJSONs) \t(input for decoding tests)
        """
    }
}

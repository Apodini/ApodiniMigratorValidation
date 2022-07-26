//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

/// This structure captures stats about JSON scripts and values.
public struct ScriptStats {
    /// The count of type conversion scripts present in the Migration Guide document.
    public private(set) var scripts: Int = 0
    /// The count of default/fallback values present in the Migration Guide document.
    public private(set) var jsonValues: Int = 0
    /// The count of JSON object representations captured in the Migration Guide document.
    /// As of now, this are only used within the generation of encoding/decoding tests in the RESTMigrator.
    public private(set) var objectJSONs: Int = 0
    
    /// Initialize a new fresh ``ScriptStats``.
    public init() {}
    
    /// Count script stats of the provided `MigrationGuide`.
    public mutating func record(document: MigrationGuide) {
        scripts = document.scripts.count
        jsonValues = document.jsonValues.count
        objectJSONs = document.objectJSONs.count
    }
}

// MARK: Formatted Output
extension ScriptStats {
    /// Formatted string representation of the script stats.
    public var formattedOutput: String {
        """
        - scripts:     \(scripts) \t(type conversions)
        - jsonValues:  \(jsonValues) \t(default/fallback values)
        - objectJSONS: \(objectJSONs) \t(input for decoding tests)
        """
    }
}

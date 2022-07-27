//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

/// This structure captures stats about a `MigrationGuide`.
public struct MigrationGuideStats {
    /// Change stats for service information changes.
    public private(set) var serviceChangeStats: ChangeStats<ServiceInformation>
    /// Change stats for endpoint changes.
    public private(set) var endpointChangeStats: ChangeStats<Endpoint>
    /// Change stats for model changes.
    public private(set) var modelChangeStats: ChangeStats<TypeInformation>
    
    /// Change stats for script changes.
    public private(set) var scriptStats: ScriptStats
    
    /// Initializes a new fresh ``MigrationGuideStats`` instance.
    public init() {
        self.serviceChangeStats = ChangeStats()
        self.endpointChangeStats = ChangeStats()
        self.modelChangeStats = ChangeStats()
        
        self.scriptStats = ScriptStats()
    }
    
    /// Count stats of the provided `MigrationGuide`.
    /// - Parameter document: The `MigrationGuide` document we want to analyze.
    public mutating func analyze(document: MigrationGuide) {
        serviceChangeStats.record(changes: document.serviceChanges)
        endpointChangeStats.record(changes: document.endpointChanges)
        modelChangeStats.record(changes: document.modelChanges)
    
        scriptStats.record(document: document)
    }
}

// MARK: Formatted Output
extension MigrationGuideStats {
    /// Formatted string representation of the stats.
    public var formattedOutput: String {
        """
        --------------------------- SUMMARY ---------------------------
        -- SERVICE
          \(
            serviceChangeStats
                .formattedOutput
                .components(separatedBy: "\n")
                .joined(separator: "\n  ")
        )
        -- ENDPOINTS
          \(
            endpointChangeStats
                .formattedOutput
                .components(separatedBy: "\n")
                .joined(separator: "\n  ")
        )
        -- MODELS
          \(
            modelChangeStats
                .formattedOutput
                .components(separatedBy: "\n")
                .joined(separator: "\n  ")
        )
        -- SCRIPTS
          \(
            scriptStats
                .formattedOutput
                .components(separatedBy: "\n")
                .joined(separator: "\n  ")
        )
        ---------------------------------------------------------------
        """
    }
}

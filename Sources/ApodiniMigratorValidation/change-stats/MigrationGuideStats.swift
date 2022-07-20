//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

public struct MigrationGuideStats {
    private var serviceChangeStats: ChangeStats<ServiceInformation>
    private var endpointChangeStats: ChangeStats<Endpoint>
    private var modelChangeStats: ChangeStats<TypeInformation>
    
    private var scriptStats: ScriptStats
    
    public init() {
        self.serviceChangeStats = ChangeStats()
        self.endpointChangeStats = ChangeStats()
        self.modelChangeStats = ChangeStats()
        
        self.scriptStats = ScriptStats()
    }
    
    public mutating func analyze(document: MigrationGuide) {
        serviceChangeStats.record(changes: document.serviceChanges)
        endpointChangeStats.record(changes: document.endpointChanges)
        modelChangeStats.record(changes: document.modelChanges)
    
        scriptStats.record(document: document)
    }
}

// MARK: Formatted Output
extension MigrationGuideStats {
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

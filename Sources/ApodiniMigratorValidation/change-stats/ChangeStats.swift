//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

/// This structure captures stats about a particular `ChangeableElement`.
public struct ChangeStats<Element: ChangeableElement> {
    /// The stats of `.addition` changes.
    public private(set) var additionStats: ChangeTypeStats
    /// The stats of `.removal` changes.
    public private(set) var removalStats: ChangeTypeStats
    /// The stats of `.update` changes.
    public private(set) var updateStats: ChangeTypeStats
    /// The stats of `.idChange` changes.
    public private(set) var idChangeStats: ChangeTypeStats
    
    /// Array of all the above stats instances.
    /// Useful in combination with `Array#total(of:)` extension.
    public var allStats: [ChangeTypeStats] {
        [additionStats, removalStats, updateStats, idChangeStats]
    }
    
    /// Initializes a new fresh ``ChangeStats`` instance.
    public init() {
        self.additionStats = ChangeTypeStats(type: .addition)
        self.removalStats = ChangeTypeStats(type: .removal)
        self.updateStats = ChangeTypeStats(type: .update)
        self.idChangeStats = ChangeTypeStats(type: .idChange)
    }
    
    /// Count script stats of the provided `Change` array.
    /// - Parameter changes: The array of changes.
    public mutating func record(changes: [Change<Element>]) {
        for change in changes {
            record(change: change)
        }
    }
    
    /// Count script stats of the provided `Change`.
    /// - Parameter change: The `Change`.
    public mutating func record(change: Change<Element>) {
        switch change.type {
        case .addition:
            additionStats.record(change: change)
        case .removal:
            removalStats.record(change: change)
        case .update:
            updateStats.record(change: change)
        case .idChange:
            idChangeStats.record(change: change)
        }
    }
}

// MARK: Formatted Output
extension ChangeStats {
    /// Formatted string representation of the change stats.
    public var formattedOutput: String {
        let elements = allStats
        
        return """
               \(additionStats.formattedOutput)
               \(removalStats.formattedOutput)
               \(updateStats.formattedOutput)
               \(idChangeStats.formattedOutput)
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
               TOTAL:       \(elements.total(of: \.changeCount))\t(breaking: \(elements.total(of: \.breaking)) unsolvable: \(elements.total(of: \.unsolvable)))
               """
    }
}

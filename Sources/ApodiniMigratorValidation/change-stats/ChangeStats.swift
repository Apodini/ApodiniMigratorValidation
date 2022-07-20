//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

public struct ChangeStats<Element: ChangeableElement> {
    private(set) var additionStats: ChangeTypeStats
    private(set) var removalStats: ChangeTypeStats
    private(set) var updateStats: ChangeTypeStats
    private(set) var idChangeStats: ChangeTypeStats // TODO flag to combine those!
    
    public init() {
        self.additionStats = ChangeTypeStats(type: .addition)
        self.removalStats = ChangeTypeStats(type: .removal)
        self.updateStats = ChangeTypeStats(type: .update)
        self.idChangeStats = ChangeTypeStats(type: .idChange)
    }
    
    public mutating func record(changes: [Change<Element>]) {
        for change in changes {
            record(change: change)
        }
    }
    
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
    public var formattedOutput: String {
        let elements = [additionStats, removalStats, updateStats, idChangeStats]
        
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

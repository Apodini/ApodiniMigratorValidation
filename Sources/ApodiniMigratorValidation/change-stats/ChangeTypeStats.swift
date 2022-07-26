//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

/// This structure captures stats about a particular `ChangeType`.
public struct ChangeTypeStats {
    /// The `ChangeType` we capture stats for.
    private let type: ChangeType
    
    /// The overall change count.
    public private(set) var changeCount: Int = 0
    
    /// The amount of changes of ``changeCount`` which is classified as breaking.
    public private(set) var breaking: Int = 0
    /// The amount of changes of ``changeCount`` which is classified as solvable.
    public private(set) var solvable: Int = 0
    
    /// The amount of unsvolable changes.
    public var unsolvable: Int {
        changeCount - solvable
    }
    
    /// Initializes a new fresh ``ChangeTypeStats`` instance.
    /// - Parameter type: The `ChangeType` for which we count stats.
    public init(type: ChangeType) {
        self.type = type
    }
    
    /// Count script stats of the provided `Change`.
    public mutating func record<Element>(change: Change<Element>) {
        precondition(change.type == type)
        
        changeCount += 1
        if change.breaking {
            breaking += 1
        }
        if change.solvable {
            solvable += 1
        }
    }
}

// MARK: Formatted Output
extension ChangeTypeStats {
    /// Formatted string representation of the change stats.
    public var formattedOutput: String {
        "- \(type.namePrefix) \(changeCount)\t(breaking: \(breaking), unsolvable: \(unsolvable))"
    }
}

extension Array where Element == ChangeTypeStats {
    /// Given this array of `Element`s, count the the values of the provided `Int` keypath.
    /// - Parameter keyPath: The `Int` keypath we want to sum over.
    /// - Returns: The sum of the values.
    public func total(of keyPath: KeyPath<Element, Int>) -> Int {
        var total = 0
        
        for element in self {
            total += element[keyPath: keyPath]
        }
        
        return total
    }
}

private extension ChangeType {
    var namePrefix: String {
        switch self {
        case .addition:
            return "ADDITION: "
        case .removal:
            return "REMOVAL:  "
        case .update:
            return "UPDATE:   "
        case .idChange:
            return "IDCHANGE: "
        }
    }
}

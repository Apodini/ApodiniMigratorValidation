//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2021 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigratorCompare

public struct ChangeTypeStats {
    /// The `ChangeType` we capture stats for.
    private let type: ChangeType
    
    /// The overall change count.
    private(set) var changeCount: Int = 0
    
    /// The amount of changes of ``changeCount`` which is classified as breaking.
    private(set) var breaking: Int = 0
    /// The amount of changes of ``changeCount`` which is classified as solvable.
    private(set) var solvable: Int = 0
    
    public var unsolvable: Int {
        changeCount - solvable
    }
    
    public init(type: ChangeType) {
        self.type = type
    }
    
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
    public var formattedOutput: String {
        "- \(type.namePrefix) \(changeCount)\t(breaking: \(breaking), unsolvable: \(unsolvable))"
    }
}

extension Array where Element == ChangeTypeStats {
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

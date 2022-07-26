//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import XCTest
@testable import ApodiniMigratorValidation
@testable import ApodiniMigratorCompare

final class MigrationGuideStatsTests: XCTestCase {
    func testMigrationGuideTests() {
        let context = ChangeComparisonContext()
        
        context.serviceChanges.append(.update(
            id: "SC01",
            updated: .http(from: .init(hostname: "http://example.org"), to: .init(hostname: "http://example.de")),
            breaking: true,
            solvable: false
        ))
        context.serviceChanges.append(.removal(id: "SC02", breaking: false, solvable: true))
        
        context.endpointChanges.append(.addition(id: "EP01", added: .init(
            handlerName: "name",
            deltaIdentifier: "name",
            operation: .create,
            communicationPattern: .requestResponse,
            absolutePath: "/path",
            parameters: [],
            response: .scalar(.string),
            errors: []
        )))
        
        context.modelChanges.append(.idChange(from: "M01", to: "M02", similarity: 0.5))
        
        context.scripts[0] = .init(rawValue: "some-script")
        
        context.jsonValues[0] = .init(rawValue: "true")
        context.jsonValues[1] = .init(rawValue: "true")
        
        let migrationGuide = MigrationGuide(
            summary: "Some summary",
            id: UUID(),
            from: Version(),
            to: Version(),
            comparisonContext: context
        )
        
        var stats = MigrationGuideStats()
        stats.analyze(document: migrationGuide)
        
        XCTAssertEqual(
            stats.formattedOutput,
            """
            --------------------------- SUMMARY ---------------------------
            -- SERVICE
              - ADDITION:  0\t(breaking: 0, unsolvable: 0)
              - REMOVAL:   1\t(breaking: 0, unsolvable: 0)
              - UPDATE:    1\t(breaking: 1, unsolvable: 1)
              - IDCHANGE:  0\t(breaking: 0, unsolvable: 0)
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              TOTAL:       2\t(breaking: 1 unsolvable: 1)
            -- ENDPOINTS
              - ADDITION:  1\t(breaking: 0, unsolvable: 0)
              - REMOVAL:   0\t(breaking: 0, unsolvable: 0)
              - UPDATE:    0\t(breaking: 0, unsolvable: 0)
              - IDCHANGE:  0\t(breaking: 0, unsolvable: 0)
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              TOTAL:       1\t(breaking: 0 unsolvable: 0)
            -- MODELS
              - ADDITION:  0\t(breaking: 0, unsolvable: 0)
              - REMOVAL:   0\t(breaking: 0, unsolvable: 0)
              - UPDATE:    0\t(breaking: 0, unsolvable: 0)
              - IDCHANGE:  1\t(breaking: 0, unsolvable: 0)
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              TOTAL:       1\t(breaking: 0 unsolvable: 0)
            -- SCRIPTS
              - scripts:     1 \t(type conversions)
              - jsonValues:  2 \t(default/fallback values)
              - objectJSONS: 0 \t(input for decoding tests)
            ---------------------------------------------------------------
            """
        )
    }
}

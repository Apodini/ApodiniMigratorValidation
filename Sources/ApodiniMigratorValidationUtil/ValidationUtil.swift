//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ArgumentParser

@main
struct ValidationUtil: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Utilities used for the validation of ApodiniMigrator.",
        subcommands: [Convert.self, Stats.self, E2E.self]
    )
}

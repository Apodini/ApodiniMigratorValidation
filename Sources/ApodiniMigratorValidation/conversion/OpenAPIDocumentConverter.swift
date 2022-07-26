//
// This source file is part of the Apodini open source project
// 
// SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import OpenAPIKit30
import ApodiniMigratorCore
import SemVer
import Logging

private let logger = Logger(label: "document-converter")

/// A utility that converts `OpenAPI Specification` documents to ApodiniMigrator `APIDocument`s.
///
/// Conversion is done best effort and primarily for the effort to use the resulting document
/// as input for the ApodiniMigrator change comparison process.
/// Those documents (typically) can't be used to generate client stubs!
///
/// TODO list tradeoffs?
///
/// TODO link to JSONSchemaConverter and its tradeoffs?
public struct OpenAPIDocumentConverter {
    private let openAPIDocument: OpenAPI.Document
    
    /// Initialize a new ``OpenAPIDocumentConverter`` to convert a OpenAPI document.
    /// - Parameter document: The instance of the `OpenAPI.Document`.
    public init(from document: OpenAPI.Document) {
        self.openAPIDocument = document
    }
    
    private func convert() -> Version {
        // parse version field best effort, otherwise provide default "1.0.0"
        let semver = SemVer(openAPIDocument.info.version) ?? SemVer(major: 1, minor: 0, patch: 0)
        return Version(major: semver.major, minor: semver.minor, patch: semver.patch)
    }
    
    private func convert() -> HTTPInformation {
        guard let url = openAPIDocument.servers.first?.urlTemplate.absoluteString else {
            return HTTPInformation(protocol: .http, hostname: "example.com", port: 80)
        }
        
        let proto: HTTPProtocol = url.starts(with: "https") ? .https : .http
        
        let hostnameAndPort = url.components(separatedBy: "://")[1]
        let hostnameSplit = hostnameAndPort.components(separatedBy: ":")
        
        return HTTPInformation(protocol: proto, hostname: hostnameSplit[0], port: hostnameSplit.last.flatMap(Int.init) ?? 80)
    }
    
    private func convert() -> [_ExporterConfiguration] {
        []
    }
    
    private func convert() -> ServiceInformation {
        ServiceInformation(
            version: convert(),
            http: convert(),
            exporters: convert()
        )
    }
    
    /// Converts the OpenAPI Specification document to an `APIDocument`.
    /// - Returns: The resulting `APIDocument`
    /// - Throws: Throws exception on any conversion errors (e.g. ill-formed OpenAPI documents).
    public func convert() throws -> APIDocument {
        JSONSchemaConverter.stats = .init()
        
        var apiDocument = APIDocument(serviceInformation: convert())
        
        for route in openAPIDocument.routes {
            let converter = RouteConverter(from: route, with: openAPIDocument.components)
            try converter.convert(into: &apiDocument)
        }
        
        return apiDocument
    }
}

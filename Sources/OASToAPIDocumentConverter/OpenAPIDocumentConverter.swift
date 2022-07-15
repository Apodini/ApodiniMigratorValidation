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

public struct OpenAPIDocumentConverter {
    private let openAPIDocument: OpenAPI.Document
    
    public init(from document: OpenAPI.Document) {
        self.openAPIDocument = document
    }
    
    private func convert() -> Version {
        // parse version field best effort, otherwise provide default "1.0.0"
        let semver = SemVer(openAPIDocument.info.version) ?? SemVer(major: 1, minor: 0, patch: 0)
        // TODO TRADEOFF: semver parsing?
        return Version(major: semver.major, minor: semver.minor, patch: semver.patch)
    }
    
    private func convert() -> HTTPInformation {
        guard let url = openAPIDocument.servers.first?.urlTemplate.absoluteString else {
            return HTTPInformation(protocol: .http, hostname: "example.com", port: 80)
        }
        
        let proto: HTTPProtocol = url.starts(with: "https") ? .https : .http
        
        let hostname = url.components(separatedBy: "://")[1]
        // TODO parse port?
        
        return HTTPInformation(protocol: proto, hostname: hostname, port: 80)
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
    
    public func convert() throws -> APIDocument {
        var apiDocument = APIDocument(serviceInformation: convert())
        
        for route in openAPIDocument.routes {
            print("Handling route \(route.path.rawValue)")
            let converter = RouteConverter(from: route, with: openAPIDocument.components)
            try converter.convert(into: &apiDocument)
        }
        
        return apiDocument
    }
}

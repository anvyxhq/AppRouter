//
//  LinkRegistry.swift
//  AppRouter
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// A URL path template with `:named` parameters, e.g. `"/users/:id/posts/:postID"`.
/// Matches against a URL's path components and extracts the named values.
public struct LinkPattern: Sendable, Equatable {
    enum Segment: Sendable, Equatable {
        case literal(String)
        case parameter(String)
    }
    let segments: [Segment]

    public init(_ template: String) {
        segments = template.split(separator: "/").map { part in
            part.hasPrefix(":") ? .parameter(String(part.dropFirst())) : .literal(String(part))
        }
    }

    /// Extracted path parameters if `components` match, otherwise `nil`.
    func match(_ components: [String]) -> [String: String]? {
        guard components.count == segments.count else { return nil }
        var parameters: [String: String] = [:]
        for (segment, component) in zip(segments, components) {
            switch segment {
            case .literal(let expected): if expected != component { return nil }
            case .parameter(let name): parameters[name] = component
            }
        }
        return parameters
    }
}

/// The values extracted from a matched link — path parameters and query items.
public struct LinkParameters: Sendable {
    public let path: [String: String]
    public let query: [String: String]

    public init(path: [String: String], query: [String: String] = [:]) {
        self.path = path
        self.query = query
    }

    /// Value for `key`, preferring a path parameter over a query item.
    public func string(_ key: String) -> String? { path[key] ?? query[key] }
    public func int(_ key: String) -> Int? { string(key).flatMap(Int.init) }
    public subscript(_ key: String) -> String? { string(key) }
}

/// A declarative universal-link registry: register URL path templates and map the
/// extracted parameters to routes. Conforms to ``DeepLinkParser``, so it drops
/// straight into ``Router/open(_:using:)`` or a ``DeepLinkResolver``.
///
/// ```swift
/// var links = LinkRegistry<AppRoute>(hosts: ["example.com"])
/// links.register("/users/:id") { $0.int("id").map { .push(.user(id: $0)) } }
/// links.register("/products/:sku") { .push(.product(sku: $0["sku"] ?? "")) }
/// router.open(incomingURL, using: links)
/// ```
public struct LinkRegistry<R: Route>: DeepLinkParser {
    private struct Entry: Sendable {
        let pattern: LinkPattern
        let build: @Sendable (LinkParameters) -> DeepLinkDestination<R>?
    }

    private var entries: [Entry] = []
    private let hosts: Set<String>

    /// - Parameter hosts: if non-empty, only URLs whose host is in this set match
    ///   (universal-link domain allowlist). Leave empty to accept any host / custom scheme.
    public init(hosts: [String] = []) {
        self.hosts = Set(hosts)
    }

    /// Register a path template and how to turn its parameters into a destination.
    public mutating func register(
        _ template: String,
        to build: @escaping @Sendable (LinkParameters) -> DeepLinkDestination<R>?
    ) {
        entries.append(Entry(pattern: LinkPattern(template), build: build))
    }

    public func parse(_ url: URL) -> DeepLinkDestination<R>? {
        if !hosts.isEmpty, !(url.host.map(hosts.contains) ?? false) { return nil }

        let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let query = Self.queryItems(url)
        for entry in entries {
            guard let pathParameters = entry.pattern.match(components) else { continue }
            if let destination = entry.build(LinkParameters(path: pathParameters, query: query)) {
                return destination
            }
        }
        return nil
    }

    private static func queryItems(_ url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return items.reduce(into: [:]) { result, item in
            if let value = item.value { result[item.name] = value }
        }
    }
}

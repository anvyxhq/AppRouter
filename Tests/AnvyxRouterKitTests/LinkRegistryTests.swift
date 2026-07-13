//
//  LinkRegistryTests.swift
//  AppRouter
//
//  Created by AnhPT on 13/07/2026.
//

import XCTest
@testable import AnvyxRouterKit

private enum LinkRoute: Route {
    case user(id: Int)
    case post(user: Int, id: Int)
    case product(sku: String)
    case home
}

@MainActor
final class LinkRegistryTests: XCTestCase {

    private func url(_ string: String) -> URL { URL(string: string)! }

    private func makeRegistry(hosts: [String] = []) -> LinkRegistry<LinkRoute> {
        var registry = LinkRegistry<LinkRoute>(hosts: hosts)
        registry.register("/users/:id") { $0.int("id").map { .push(.user(id: $0)) } }
        registry.register("/users/:user/posts/:id") { params in
            guard let user = params.int("user"), let id = params.int("id") else { return nil }
            return .push(.post(user: user, id: id))
        }
        registry.register("/products/:sku") { .sheet(.product(sku: $0["sku"] ?? "")) }
        return registry
    }

    func testExtractsSinglePathParameter() {
        let destination = makeRegistry().parse(url("https://example.com/users/42"))
        guard case .push(.user(let id)) = destination else { return XCTFail("no match") }
        XCTAssertEqual(id, 42)
    }

    func testMatchesMultiSegmentTemplate() {
        let destination = makeRegistry().parse(url("https://example.com/users/7/posts/99"))
        guard case .push(.post(let user, let id)) = destination else { return XCTFail("no match") }
        XCTAssertEqual(user, 7)
        XCTAssertEqual(id, 99)
    }

    func testStringParameterAndPresentationStyle() {
        let destination = makeRegistry().parse(url("https://example.com/products/ABC-123"))
        guard case .sheet(.product(let sku)) = destination else { return XCTFail("no match") }
        XCTAssertEqual(sku, "ABC-123")
    }

    func testUnknownPathReturnsNil() {
        XCTAssertNil(makeRegistry().parse(url("https://example.com/unknown/path")))
        XCTAssertNil(makeRegistry().parse(url("https://example.com/users")))   // arity mismatch
    }

    func testInvalidParameterFailsBuild() {
        // "abc" isn't an Int, so the builder returns nil → no destination.
        XCTAssertNil(makeRegistry().parse(url("https://example.com/users/abc")))
    }

    func testHostAllowlist() {
        let registry = makeRegistry(hosts: ["example.com"])
        XCTAssertNotNil(registry.parse(url("https://example.com/users/1")))
        XCTAssertNil(registry.parse(url("https://evil.com/users/1")), "other hosts are rejected")
    }

    func testQueryParametersAreAvailable() {
        var registry = LinkRegistry<LinkRoute>()
        registry.register("/open") { $0.int("id").map { .push(.user(id: $0)) } }
        let destination = registry.parse(url("https://example.com/open?id=5&ref=email"))
        guard case .push(.user(let id)) = destination else { return XCTFail("no match") }
        XCTAssertEqual(id, 5)
    }

    func testIntegratesWithRouterOpen() {
        let router = Router<LinkRoute>()
        let handled = router.open(url("https://example.com/users/3"), using: makeRegistry())
        XCTAssertTrue(handled)
        XCTAssertEqual(router.path.count, 1)
    }
}

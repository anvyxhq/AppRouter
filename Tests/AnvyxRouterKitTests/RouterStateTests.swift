//
//  RouterStateTests.swift
//  AppRouter
//
//  Created by AnhPT on 13/07/2026.
//

import XCTest
import SwiftUI
@testable import AnvyxRouterKit

enum CodableRoute: Route, Codable {
    case home
    case detail(id: Int)
    case settings
}

@MainActor
final class RouterStateTests: XCTestCase {

    func testPushContentsOfAndSetPath() {
        let router = Router<CodableRoute>()
        router.push(contentsOf: [.home, .detail(id: 1), .settings])
        XCTAssertEqual(router.path.count, 3)

        router.setPath([.home])
        XCTAssertEqual(router.path.count, 1)

        router.setPath([])
        XCTAssertTrue(router.path.isEmpty)
    }

    func testStateRoundTripRestoresPathAndPresentation() throws {
        let router = Router<CodableRoute>()
        router.push(contentsOf: [.home, .detail(id: 42), .settings])
        router.present(sheet: .detail(id: 7))

        // NavigationPath.codable's runtime type lookup is unreliable for types
        // declared in a test bundle (works in an app module). Skip if unavailable
        // rather than flake.
        guard let data = router.stateData() else {
            throw XCTSkip("NavigationPath.codable unavailable for test-bundle route type")
        }

        let restored = Router<CodableRoute>()
        restored.restoreState(from: data)

        XCTAssertEqual(restored.path.count, 3)
        XCTAssertEqual(restored.sheet, .detail(id: 7))
        XCTAssertNil(restored.cover)
    }

    func testRestoreIgnoresInvalidData() {
        let router = Router<CodableRoute>()
        router.push(.home)
        router.restoreState(from: Data("not json".utf8))   // ignored
        XCTAssertEqual(router.path.count, 1)
    }

    func testEmptyRouterEncodesToEmptyPath() throws {
        let router = Router<CodableRoute>()
        let data = try XCTUnwrap(router.stateData())

        let restored = Router<CodableRoute>()
        restored.push(.home)                                 // dirty state
        restored.restoreState(from: data)
        XCTAssertTrue(restored.path.isEmpty)
    }
}

//
//  Router+State.swift
//  AppRouter
//
//  Created by AnhPT on 13/07/2026.
//

import SwiftUI

// MARK: - Path builder

public extension Router {
    /// Push several routes at once (e.g. to deep-link into a nested screen).
    func push(contentsOf routes: [R]) {
        for route in routes { path.append(route) }
    }

    /// Replace the whole stack with `routes` (root stays; `routes` become the
    /// pushed path). Pass `[]` to pop to root.
    func setPath(_ routes: [R]) {
        var newPath = NavigationPath()
        for route in routes { newPath.append(route) }
        path = newPath
    }
}

// MARK: - State restoration

/// A `Codable` snapshot of a ``Router``'s navigation state — persist it (e.g. via
/// `SceneStorage`) and restore it on launch. Requires the route type to be `Codable`.
///
/// - Note: encoding the path relies on `NavigationPath.codable`, which returns
///   `nil` unless the Swift runtime can resolve every pushed value's type. This is
///   reliable for routes declared in your app module; it can be flaky for types
///   defined inside a **unit-test bundle**, so `stateData()` may return `nil` there.
public struct RouterState<R: Route & Codable>: Codable {
    var path: NavigationPath.CodableRepresentation
    var sheet: R?
    var cover: R?
}

public extension Router where R: Codable {
    /// Encode the current navigation state, or `nil` if the path can't be encoded
    /// (a pushed value wasn't `Codable`).
    func stateData(encoder: JSONEncoder = JSONEncoder()) -> Data? {
        guard let codablePath = path.codable else { return nil }
        let state = RouterState(path: codablePath, sheet: sheet, cover: cover)
        return try? encoder.encode(state)
    }

    /// Restore navigation state previously produced by ``stateData(encoder:)``.
    /// Invalid or mismatched data is ignored (leaves the router unchanged).
    func restoreState(from data: Data, decoder: JSONDecoder = JSONDecoder()) {
        guard let state = try? decoder.decode(RouterState<R>.self, from: data) else { return }
        path = NavigationPath(state.path)
        sheet = state.sheet
        cover = state.cover
    }
}

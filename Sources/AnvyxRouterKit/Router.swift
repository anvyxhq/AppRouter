//
//  Router.swift
//  AppRouter
//
//  Created by AnhPT on 02/07/2026.
//

import SwiftUI
import Observation

/// A route is any value you push onto the navigation stack.
public protocol Route: Hashable {}

/// Observable navigation coordinator wrapping a `NavigationPath`, plus sheet and
/// full-screen-cover presentation, generic over your app's `Route` type.
///
/// ```swift
/// enum AppRoute: Route { case detail(id: String), settings }
///
/// @State private var router = Router<AppRoute>()
///
/// @Bindable var router = router   // for the path binding
/// NavigationStack(path: $router.path) {
///     HomeView()
///         .navigationDestination(for: AppRoute.self) { route in ... }
/// }
/// .environment(router)
/// ```
@MainActor
@Observable
public final class Router<R: Route> {
    public var path = NavigationPath() { didSet { notifyChange() } }
    public var sheet: R? { didSet { notifyChange() } }
    public var cover: R? { didSet { notifyChange() } }

    @ObservationIgnored
    private var changeObservers: [UUID: @MainActor () -> Void] = [:]

    public init() {}

    // MARK: Change observation

    /// Register `observer` to run after every change to ``path``, ``sheet`` or
    /// ``cover`` — including changes SwiftUI writes through the bindings (back
    /// swipe, interactive sheet dismissal). Returns an id for ``removeChangeObserver(_:)``.
    func addChangeObserver(_ observer: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        changeObservers[id] = observer
        return id
    }

    func removeChangeObserver(_ id: UUID) {
        changeObservers[id] = nil
    }

    private func notifyChange() {
        for observer in Array(changeObservers.values) { observer() }
    }

    // MARK: Stack

    public func push(_ route: R) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }

    // MARK: Presentation

    public func present(sheet route: R) {
        sheet = route
    }

    public func present(cover route: R) {
        cover = route
    }

    public func dismiss() {
        sheet = nil
        cover = nil
    }
}

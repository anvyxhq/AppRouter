//
//  RouterFlow.swift
//  AppRouter
//
//  Created by AnhPT on 02/07/2026.
//

import SwiftUI

/// Errors surfaced by ``RouterFlowPresenter``.
public enum FlowPresentationError: Error {
    /// The screen resolved a value whose type didn't match what the caller awaited.
    case resultTypeMismatch
    /// The presenter was deinitialised (or the token was cancelled) before a result arrived.
    case cancelled
}

/// Bridges the async ``FlowStepRunning`` world to SwiftUI navigation: presents a
/// route on a ``Router`` and suspends until the presented screen reports a result.
///
/// The presented screen resolves its step by calling ``resolve(token:with:)``
/// (or ``fail(token:with:)``) — typically from a button action or `onDisappear`,
/// using the same `token` the runner passed to ``present(_:token:style:expecting:)``.
///
/// ```swift
/// // in the runner:
/// let profile: Profile = try await presenter.present(.profile, token: step.id)
///
/// // in the presented view (token injected via init/environment):
/// Button("Continue") { presenter.resolve(token: token, with: profile) }
/// ```
@MainActor
public final class RouterFlowPresenter<R: Route> {
    public enum Style { case push, sheet, cover }

    private let router: Router<R>
    private var pending: [AnyHashable: CheckedContinuation<Any, Error>] = [:]

    public init(_ router: Router<R>) {
        self.router = router
    }

    deinit {
        // Continuations must always be resumed; fail any still pending.
        for cont in pending.values {
            cont.resume(throwing: FlowPresentationError.cancelled)
        }
    }

    /// Present `route` and suspend until a result is reported for `token`.
    ///
    /// - Parameter token: identifier the presented screen uses to resolve this
    ///   presentation (e.g. the step's `id`). Presenting twice with the same
    ///   unresolved token cancels the earlier one.
    public func present<Value>(
        _ route: R,
        token: AnyHashable,
        style: Style = .push,
        expecting _: Value.Type = Value.self
    ) async throws -> Value {
        // Cancel any earlier presentation still waiting on this token.
        if let stale = pending.removeValue(forKey: token) {
            stale.resume(throwing: FlowPresentationError.cancelled)
        }
        let any: Any = try await withCheckedThrowingContinuation { cont in
            pending[token] = cont
            switch style {
            case .push:  router.push(route)
            case .sheet: router.present(sheet: route)
            case .cover: router.present(cover: route)
            }
        }
        guard let value = any as? Value else {
            throw FlowPresentationError.resultTypeMismatch
        }
        return value
    }

    /// Report a successful result for the presentation awaiting `token`.
    public func resolve<Value>(token: AnyHashable, with value: Value) {
        pending.removeValue(forKey: token)?.resume(returning: value)
    }

    /// Report a failure for the presentation awaiting `token`.
    public func fail(token: AnyHashable, with error: Error) {
        pending.removeValue(forKey: token)?.resume(throwing: error)
    }
}

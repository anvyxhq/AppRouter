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
    /// The presented screen left the screen before reporting a result: its entry
    /// was popped off the stack (back button or swipe), or its sheet / cover was
    /// dismissed.
    case dismissedByUser
}

/// Bridges the async ``FlowStepRunning`` world to SwiftUI navigation: presents a
/// route on a ``Router`` and suspends until the presented screen reports a result.
///
/// The presented screen resolves its step by calling ``resolve(token:with:)``
/// (or ``fail(token:with:)``) — typically from a button action, using the same
/// `token` the runner passed to ``present(_:token:style:expecting:)``.
///
/// ```swift
/// // in the runner:
/// let profile: Profile = try await presenter.present(.profile, token: step.id)
///
/// // in the presented view (token injected via init/environment):
/// Button("Continue") { presenter.resolve(token: token, with: profile) }
/// ```
///
/// A presentation always finishes exactly once, with whichever of these comes first:
///
/// - ``resolve(token:with:)`` — returns the value;
/// - ``fail(token:with:)`` — throws the given error;
/// - the screen goes away without reporting (back button or swipe, sheet / cover
///   dismissal, ``Router/pop()``, ``Router/dismiss()``…) — throws
///   ``FlowPresentationError/dismissedByUser``;
/// - the awaiting task is cancelled — throws `CancellationError`;
/// - the token is presented again, or the presenter is deallocated — throws
///   ``FlowPresentationError/cancelled``.
///
/// Later reports for the same token are ignored. Because leaving the screen
/// counts as a dismissal, a screen that both reports a result and navigates
/// away must report first.
@MainActor
public final class RouterFlowPresenter<R: Route> {
    public enum Style { case push, sheet, cover }

    /// One suspended ``present(_:token:style:expecting:)`` call.
    private struct Pending {
        /// Identifies this call even if its token is later reused.
        let id: UUID
        let route: R
        let style: Style
        /// `path.count` once the route is pushed (`.push` only).
        let depth: Int
        let continuation: CheckedContinuation<Any, any Error>
    }

    private let router: Router<R>
    private var pending: [AnyHashable: Pending] = [:]
    private var observerID: UUID?

    /// Number of presentations still waiting for a result.
    var pendingCount: Int { pending.count }

    public init(_ router: Router<R>) {
        self.router = router
        observerID = router.addChangeObserver { [weak self] in
            self?.failDismissedPresentations()
        }
    }

    isolated deinit {
        if let observerID { router.removeChangeObserver(observerID) }
        // Continuations must always be resumed; fail any still pending.
        for entry in pending.values {
            entry.continuation.resume(throwing: FlowPresentationError.cancelled)
        }
    }

    /// Present `route` and suspend until a result is reported for `token`.
    ///
    /// - Parameter token: identifier the presented screen uses to resolve this
    ///   presentation (e.g. the step's `id`). Presenting twice with the same
    ///   unresolved token cancels the earlier one.
    /// - Throws: the error passed to ``fail(token:with:)``;
    ///   ``FlowPresentationError/dismissedByUser`` if the screen is popped or
    ///   dismissed before reporting; `CancellationError` if the calling task is
    ///   cancelled (the route is left on screen — pop or dismiss it yourself if
    ///   needed; nothing is presented when the task is already cancelled);
    ///   ``FlowPresentationError/resultTypeMismatch`` if the reported value is
    ///   not a `Value`.
    public func present<Value>(
        _ route: R,
        token: AnyHashable,
        style: Style = .push,
        expecting _: Value.Type = Value.self
    ) async throws -> Value {
        try Task.checkCancellation()
        // Cancel any earlier presentation still waiting on this token.
        if let stale = pending.removeValue(forKey: token) {
            stale.continuation.resume(throwing: FlowPresentationError.cancelled)
        }
        let id = UUID()
        let any: Any = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Register before presenting: presenting notifies the observer.
                pending[token] = Pending(
                    id: id,
                    route: route,
                    style: style,
                    depth: router.path.count + 1,
                    continuation: continuation
                )
                switch style {
                case .push:  router.push(route)
                case .sheet: router.present(sheet: route)
                case .cover: router.present(cover: route)
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelPresentation(id) }
        }
        guard let value = any as? Value else {
            throw FlowPresentationError.resultTypeMismatch
        }
        return value
    }

    /// Report a successful result for the presentation awaiting `token`.
    /// Ignored if that presentation already finished.
    public func resolve<Value>(token: AnyHashable, with value: sending Value) {
        pending.removeValue(forKey: token)?.continuation.resume(returning: value)
    }

    /// Report a failure for the presentation awaiting `token`.
    /// Ignored if that presentation already finished.
    public func fail(token: AnyHashable, with error: Error) {
        pending.removeValue(forKey: token)?.continuation.resume(throwing: error)
    }

    // MARK: Dismissal & cancellation

    /// Fail every pending presentation whose screen is no longer shown.
    private func failDismissedPresentations() {
        let dismissed = pending.filter { _, entry in
            switch entry.style {
            case .push:  router.path.count < entry.depth
            case .sheet: router.sheet != entry.route
            case .cover: router.cover != entry.route
            }
        }
        // Remove first so each continuation can only be resumed once.
        for token in dismissed.keys { pending[token] = nil }
        for entry in dismissed.values {
            entry.continuation.resume(throwing: FlowPresentationError.dismissedByUser)
        }
    }

    /// Fail the presentation started by call `id` after its task was cancelled.
    private func cancelPresentation(_ id: UUID) {
        guard let token = pending.first(where: { $0.value.id == id })?.key else { return }
        pending.removeValue(forKey: token)?.continuation.resume(throwing: CancellationError())
    }
}

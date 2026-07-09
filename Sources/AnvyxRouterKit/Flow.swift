//
//  Flow.swift
//  AppRouter
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// A single step in a multi-step flow (onboarding, checkout, a KYC pipeline…).
///
/// A step is just an identity — the work it performs lives in a
/// ``FlowStepRunning`` adapter, so the engine stays UI-framework-agnostic and
/// works equally under SwiftUI or UIKit.
public protocol FlowStep: Identifiable {}

/// Executes flow steps and decides which ones to skip.
///
/// The app provides one runner per flow. Under SwiftUI, a runner typically
/// drives a ``Router`` via ``RouterFlowPresenter`` to present each step's
/// screen and `await` its result before returning the updated state. Under
/// UIKit it would present view controllers instead — the ``Flow`` engine does
/// not care which.
public protocol FlowStepRunning {
    associatedtype Step: FlowStep
    associatedtype State

    /// Return `false` to skip `step` given the current `state` (default: run every step).
    func shouldRun(_ step: Step, in state: State) -> Bool

    /// Perform `step` and return the new accumulated state.
    ///
    /// Throws to abort the flow; ``Flow/run(from:onStateChange:)`` propagates
    /// the error to its caller without catching it.
    func run(_ step: Step, in state: State) async throws -> State
}

public extension FlowStepRunning {
    func shouldRun(_ step: Step, in state: State) -> Bool { true }
}

/// Generic, framework-agnostic engine that walks a list of ``FlowStep`` values
/// step-by-step, folding each result into an immutable state.
///
/// ```swift
/// enum SignupStep: String, FlowStep { case profile, verifyEmail, done; var id: String { rawValue } }
///
/// struct SignupRunner: FlowStepRunning {
///     let presenter: RouterFlowPresenter<AppRoute>
///     func run(_ step: SignupStep, in state: SignupState) async throws -> SignupState {
///         switch step {
///         case .profile:     return state.with(profile: try await presenter.present(.profile, token: step.id))
///         case .verifyEmail: return state.with(verified: try await presenter.present(.verifyEmail, token: step.id))
///         case .done:        return state
///         }
///     }
/// }
///
/// let final = try await Flow(steps: [.profile, .verifyEmail, .done], runner: runner).run(from: .initial)
/// ```
public struct Flow<Runner: FlowStepRunning> {
    public let steps: [Runner.Step]
    public let runner: Runner

    public init(steps: [Runner.Step], runner: Runner) {
        self.steps = steps
        self.runner = runner
    }

    /// Run every non-skipped step in order, starting from `initialState`.
    ///
    /// - Parameter onStateChange: called with the new state after each step completes,
    ///   e.g. to persist partial progress so a mid-flow failure can still surface it.
    /// - Returns: the final accumulated state.
    @discardableResult
    public func run(
        from initialState: Runner.State,
        onStateChange: ((Runner.State) -> Void)? = nil
    ) async throws -> Runner.State {
        var state = initialState
        for step in steps where runner.shouldRun(step, in: state) {
            state = try await runner.run(step, in: state)
            onStateChange?(state)
        }
        return state
    }
}

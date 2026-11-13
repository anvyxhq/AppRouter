//
//  FlowCompletionTests.swift
//  AppRouter
//

import XCTest
import SwiftUI
@testable import AnvyxRouterKit

@MainActor
final class FlowCompletionTests: XCTestCase {

    // MARK: Helpers

    /// Holds the outcome of one awaited presentation.
    @MainActor
    private final class Outcome {
        var result: Result<Int, any Error>?
        let done: XCTestExpectation
        var task: Task<Void, Never>?

        init(_ done: XCTestExpectation) { self.done = done }

        var error: (any Error)? {
            if case .failure(let error) = result { return error }
            return nil
        }

        var value: Int? { try? result?.get() }
    }

    /// Start awaiting a presentation and wait until `presented` holds.
    private func start(
        _ presenter: RouterFlowPresenter<TestRoute>,
        route: TestRoute = .a,
        token: String = "step",
        style: RouterFlowPresenter<TestRoute>.Style = .push,
        until presented: () -> Bool
    ) async -> Outcome {
        let outcome = Outcome(expectation(description: "presentation \(token) finished"))
        outcome.task = Task {
            do {
                let value: Int = try await presenter.present(route, token: token, style: style)
                outcome.result = .success(value)
            } catch {
                outcome.result = .failure(error)
            }
            outcome.done.fulfill()
        }
        for _ in 0..<100 where !presented() { await Task.yield() }
        XCTAssertTrue(presented(), "route was never presented")
        return outcome
    }

    private func finish(_ outcome: Outcome) async {
        await fulfillment(of: [outcome.done], timeout: 2)
    }

    // MARK: Dismissal

    func testPathPopResumesWithDismissedByUser() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter) { router.path.count == 1 }

        router.pop()   // what a back swipe does to the bound path

        await finish(outcome)
        XCTAssertEqual(outcome.error as? FlowPresentationError, .dismissedByUser)
        XCTAssertEqual(presenter.pendingCount, 0)
    }

    func testPopToRootDismissesEveryPushedStep() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let first = await start(presenter, route: .a, token: "first") { router.path.count == 1 }
        let second = await start(presenter, route: .b, token: "second") { router.path.count == 2 }

        router.popToRoot()

        await finish(first)
        await finish(second)
        XCTAssertEqual(first.error as? FlowPresentationError, .dismissedByUser)
        XCTAssertEqual(second.error as? FlowPresentationError, .dismissedByUser)
    }

    func testPushingAboveAPendingStepKeepsItWaiting() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter) { router.path.count == 1 }

        router.push(.b)                 // deeper screen on top of the step
        router.present(sheet: .b)       // unrelated presentation
        router.dismiss()
        router.pop()                    // back to the step's own screen
        XCTAssertEqual(presenter.pendingCount, 1)

        presenter.resolve(token: "step", with: 7)
        await finish(outcome)
        XCTAssertEqual(outcome.value, 7)
    }

    func testSheetSetToNilResumesWithDismissedByUser() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter, style: .sheet) { router.sheet == .a }

        router.sheet = nil   // what swiping the sheet down does to the binding

        await finish(outcome)
        XCTAssertEqual(outcome.error as? FlowPresentationError, .dismissedByUser)
        XCTAssertEqual(presenter.pendingCount, 0)
    }

    func testCoverSetToNilResumesWithDismissedByUser() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter, style: .cover) { router.cover == .a }

        router.dismiss()

        await finish(outcome)
        XCTAssertEqual(outcome.error as? FlowPresentationError, .dismissedByUser)
    }

    // MARK: Cancellation

    func testCancellingTheAwaitingTaskResumesWithCancellationError() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter) { router.path.count == 1 }

        outcome.task?.cancel()

        await finish(outcome)
        XCTAssertTrue(outcome.error is CancellationError)
        XCTAssertEqual(presenter.pendingCount, 0)

        // Late reports for the cleaned-up token are ignored.
        presenter.resolve(token: "step", with: 1)
        router.pop()
    }

    func testAlreadyCancelledTaskPresentsNothing() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let done = expectation(description: "finished")
        var caught: (any Error)?
        let task = Task {
            await Task.yield()   // let the cancel below land first
            do {
                let _: Int = try await presenter.present(.a, token: "step")
            } catch {
                caught = error
            }
            done.fulfill()
        }
        task.cancel()

        await fulfillment(of: [done], timeout: 2)
        XCTAssertTrue(caught is CancellationError)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(presenter.pendingCount, 0)
    }

    // MARK: Exactly-once completion

    func testDoubleCompletionIsIgnored() async {
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter) { router.path.count == 1 }

        presenter.resolve(token: "step", with: 1)
        presenter.resolve(token: "step", with: 2)                        // ignored
        presenter.fail(token: "step", with: FlowPresentationError.cancelled)   // ignored
        router.pop()                                                     // ignored
        outcome.task?.cancel()                                           // ignored

        await finish(outcome)
        XCTAssertEqual(outcome.value, 1)
        XCTAssertEqual(presenter.pendingCount, 0)
    }

    func testFailureWinsOverLaterDismissal() async {
        struct Boom: Error {}
        let router = Router<TestRoute>()
        let presenter = RouterFlowPresenter(router)
        let outcome = await start(presenter, style: .sheet) { router.sheet == .a }

        presenter.fail(token: "step", with: Boom())
        router.dismiss()

        await finish(outcome)
        XCTAssertTrue(outcome.error is Boom)
    }

    // MARK: Partial state

    private enum Step: Int, FlowStep {
        case one = 1, two, three
        var id: Int { rawValue }
    }

    private struct StepFailure: Error, Equatable { let step: Int }

    private struct SummingRunner: FlowStepRunning {
        var failing: Step?

        func run(_ step: Step, in state: [Int]) async throws -> [Int] {
            if step == failing { throw StepFailure(step: step.rawValue) }
            return state + [step.rawValue]
        }
    }

    func testFailingStepExposesPartialState() async {
        let flow = Flow(steps: [Step.one, .two, .three], runner: SummingRunner(failing: .three))
        do {
            _ = try await flow.runPreservingState(from: [0])
            XCTFail("expected the flow to fail")
        } catch {
            XCTAssertEqual(error.partialState, [0, 1, 2])
            XCTAssertEqual(error.underlying as? StepFailure, StepFailure(step: 3))
        }
    }

    func testRunPreservingStateReturnsFinalStateOnSuccess() async throws {
        let flow = Flow(steps: [Step.one, .two, .three], runner: SummingRunner())
        var seen: [[Int]] = []
        let final = try await flow.runPreservingState(from: []) { seen.append($0) }
        XCTAssertEqual(final, [1, 2, 3])
        XCTAssertEqual(seen, [[1], [1, 2], [1, 2, 3]])
    }

    func testRunStillThrowsTheStepErrorUnwrapped() async {
        let flow = Flow(steps: [Step.one, .two], runner: SummingRunner(failing: .two))
        do {
            _ = try await flow.run(from: [])
            XCTFail("expected the flow to fail")
        } catch {
            XCTAssertEqual(error as? StepFailure, StepFailure(step: 2))
        }
    }
}

import Combine
import Foundation
import os
import Testing

@MainActor
final class PublisherRecorder<Output: Sendable> {
    private struct Waiter {
        let condition: ([Output]) -> Bool
        let continuation: CheckedContinuation<[Output]?, Never>
        let timeoutTask: Task<Void, Never>
    }

    private var recordedValues: [Output] = []
    private var subscription: AnyCancellable?
    private var waiters: [Int: Waiter] = [:]
    private var lastWaiterID = 0
    private let offMainEmissionCount = OSAllocatedUnfairLock(initialState: 0)

    var values: [Output] {
        reportOffMainEmissions()
        return recordedValues
    }

    var latest: Output? { values.last }

    init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Never {
        subscription = publisher.sink { @Sendable [weak self, offMainEmissionCount] value in
            guard Thread.isMainThread else {
                offMainEmissionCount.withLock { $0 += 1 }
                return
            }
            MainActor.assumeIsolated {
                self?.record(value)
            }
        }
    }

    @discardableResult
    func wait(
        timeout: Duration = TestTimeout.condition,
        until condition: @escaping ([Output]) -> Bool,
        caller: String = #function
    ) async throws -> [Output] {
        guard !condition(values) else { return recordedValues }
        lastWaiterID += 1
        let waiterID = lastWaiterID
        let matchingValues = await withCheckedContinuation { continuation in
            let timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                self?.finishWaiter(waiterID, with: nil)
            }
            waiters[waiterID] = Waiter(condition: condition, continuation: continuation, timeoutTask: timeoutTask)
        }
        reportOffMainEmissions()
        guard let matchingValues else {
            throw WaitTimeoutError(description: "Condition not met within \(timeout) in \(caller); last value: \(String(describing: recordedValues.last))")
        }
        return matchingValues
    }

    @discardableResult
    func waitForLatest(
        timeout: Duration = TestTimeout.condition,
        caller: String = #function,
        where predicate: @escaping (Output) -> Bool
    ) async throws -> Output {
        let matchingValues = try await wait(timeout: timeout, until: { $0.last.map(predicate) ?? false }, caller: caller)
        guard let matching = matchingValues.last else { throw WaitTimeoutError(description: "No value recorded") }
        return matching
    }

    private func record(_ value: Output) {
        recordedValues.append(value)
        for (id, waiter) in waiters where waiter.condition(recordedValues) {
            finishWaiter(id, with: recordedValues)
        }
    }

    private func finishWaiter(_ id: Int, with matchingValues: [Output]?) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(returning: matchingValues)
    }

    private func reportOffMainEmissions() {
        let count = offMainEmissionCount.withLock { count in
            defer { count = 0 }
            return count
        }
        guard count > 0 else { return }
        Issue.record("\(count) value(s) of \(Output.self) were emitted off the main thread and not recorded")
    }
}

import os

enum TestTimeout {
    static let condition: Duration = .seconds(5)
}

struct WaitTimeoutError: Error, CustomStringConvertible {
    let description: String
}

final class EventLog<Event: Sendable>: Sendable {
    typealias Condition = @Sendable ([Event]) -> Bool

    private struct Waiter: Sendable {
        let id: Int
        let condition: Condition
        let continuation: CheckedContinuation<[Event], Never>
    }

    private struct State: Sendable {
        var events: [Event] = []
        var waiters: [Waiter] = []
        var abandonedWaiterIDs: Set<Int> = []
        var lastWaiterID = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var events: [Event] {
        state.withLock { $0.events }
    }

    func record(_ event: Event) {
        let (satisfied, events) = state.withLock { state in
            state.events.append(event)
            let events = state.events
            var satisfied: [Waiter] = []
            state.waiters.removeAll { waiter in
                guard waiter.condition(events) else { return false }
                satisfied.append(waiter)
                return true
            }
            return (satisfied, events)
        }
        satisfied.forEach { $0.continuation.resume(returning: events) }
    }

    @discardableResult
    func wait(
        timeout: Duration = TestTimeout.condition,
        until condition: @escaping Condition
    ) async throws -> [Event] {
        try await withThrowingTaskGroup(of: [Event].self) { group in
            group.addTask { await self.suspend(until: condition) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw WaitTimeoutError(description: "Condition not met within \(timeout); events: \(self.events)")
            }
            defer { group.cancelAll() }
            guard let events = try await group.next() else {
                throw WaitTimeoutError(description: "Wait finished without a result")
            }
            return events
        }
    }

    private func suspend(until condition: @escaping Condition) async -> [Event] {
        let waiterID = state.withLock { state in
            state.lastWaiterID += 1
            return state.lastWaiterID
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                register(Waiter(id: waiterID, condition: condition, continuation: continuation))
            }
        } onCancel: {
            abandonWaiter(waiterID)
        }
    }

    private func register(_ waiter: Waiter) {
        let immediateEvents = state.withLock { state -> [Event]? in
            if waiter.condition(state.events) || state.abandonedWaiterIDs.contains(waiter.id) {
                return state.events
            }
            state.waiters.append(waiter)
            return nil
        }
        if let immediateEvents {
            waiter.continuation.resume(returning: immediateEvents)
        }
    }

    private func abandonWaiter(_ id: Int) {
        let (waiter, events) = state.withLock { state -> (Waiter?, [Event]) in
            guard let index = state.waiters.firstIndex(where: { $0.id == id }) else {
                state.abandonedWaiterIDs.insert(id)
                return (nil, state.events)
            }
            return (state.waiters.remove(at: index), state.events)
        }
        waiter?.continuation.resume(returning: events)
    }
}

extension EventLog where Event: Equatable {
    func count(of event: Event) -> Int {
        events.count { $0 == event }
    }

    @discardableResult
    func wait(for event: Event, count: Int = 1) async throws -> [Event] {
        try await wait { events in events.count { $0 == event } >= count }
    }
}

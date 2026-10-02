import os
import Testing

final class ScriptedResponder<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct PendingCall: Sendable {
        let id: Int
        let continuation: CheckedContinuation<Value, any Error>
    }

    private struct State: Sendable {
        var queuedResults: [Key: [Result<Value, any Error>]] = [:]
        var pendingCalls: [Key: [PendingCall]] = [:]
        var pendingWaiters: [Key: [CheckedContinuation<Void, Never>]] = [:]
        var cancelledCallIDs: Set<Int> = []
        var calls: [Key] = []
        var nextCallID = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var calls: [Key] {
        state.withLock { $0.calls }
    }

    var pendingCallCount: Int {
        state.withLock { $0.pendingCalls.values.reduce(0) { $0 + $1.count } }
    }

    var unconsumedResultCount: Int {
        state.withLock { $0.queuedResults.values.reduce(0) { $0 + $1.count } }
    }

    func expectFullyConsumed(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(unconsumedResultCount == 0, "Scripted results were never consumed", sourceLocation: sourceLocation)
        #expect(pendingCallCount == 0, "Calls are still waiting for a scripted result", sourceLocation: sourceLocation)
    }

    func enqueue(_ result: Result<Value, any Error>, for key: Key) {
        state.withLock { $0.queuedResults[key, default: []].append(result) }
    }

    func waitForPendingCall(for key: Key) async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            let isAlreadyPending = state.withLock { state in
                guard state.pendingCalls[key, default: []].isEmpty else { return true }
                state.pendingWaiters[key, default: []].append(waiter)
                return false
            }
            if isAlreadyPending {
                waiter.resume()
            }
        }
    }

    @discardableResult
    func resolvePendingCall(for key: Key, with result: Result<Value, any Error>) -> Bool {
        let call = state.withLock { state -> PendingCall? in
            guard var calls = state.pendingCalls[key], !calls.isEmpty else { return nil }
            let oldest = calls.removeFirst()
            state.pendingCalls[key] = calls
            return oldest
        }
        call?.continuation.resume(with: result)
        return call != nil
    }

    func respond(to key: Key) async throws -> Value {
        let (callID, queued) = state.withLock { state -> (Int, Result<Value, any Error>?) in
            state.calls.append(key)
            state.nextCallID += 1
            guard var results = state.queuedResults[key], !results.isEmpty else { return (state.nextCallID, nil) }
            let result = results.removeFirst()
            state.queuedResults[key] = results
            return (state.nextCallID, result)
        }
        if let queued {
            return try queued.get()
        }
        return try await withTaskCancellationHandler {
            try await suspendAsPending(callID: callID, key: key)
        } onCancel: {
            cancelPendingCall(callID: callID, key: key)
        }
    }

    private func suspendAsPending(callID: Int, key: Key) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let (isCancelled, waiters) = state.withLock { state -> (Bool, [CheckedContinuation<Void, Never>]) in
                guard !state.cancelledCallIDs.contains(callID) else { return (true, []) }
                state.pendingCalls[key, default: []].append(PendingCall(id: callID, continuation: continuation))
                return (false, state.pendingWaiters.removeValue(forKey: key) ?? [])
            }
            if isCancelled {
                continuation.resume(throwing: CancellationError())
            }
            waiters.forEach { $0.resume() }
        }
    }

    private func cancelPendingCall(callID: Int, key: Key) {
        let call = state.withLock { state -> PendingCall? in
            guard let index = state.pendingCalls[key]?.firstIndex(where: { $0.id == callID }) else {
                state.cancelledCallIDs.insert(callID)
                return nil
            }
            return state.pendingCalls[key]?.remove(at: index)
        }
        call?.continuation.resume(throwing: CancellationError())
    }
}

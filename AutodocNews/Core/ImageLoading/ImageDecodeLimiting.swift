import os

protocol ImageDecodeLimiting: Sendable {
    func run<Value>(_ work: () throws -> Value) async throws -> Value
}

final class ImageDecodeLimiter: ImageDecodeLimiting {
    private typealias Waiter = CheckedContinuation<Void, any Error>

    private struct State {
        var freeSlots: Int
        var waiters: [(id: UInt64, continuation: Waiter)] = []
        private var lastID: UInt64 = 0

        init(freeSlots: Int) {
            self.freeSlots = freeSlots
        }

        mutating func makeID() -> UInt64 {
            lastID &+= 1
            return lastID
        }

        mutating func releaseSlot() -> Waiter? {
            guard !waiters.isEmpty else {
                freeSlots += 1
                return nil
            }
            return waiters.removeFirst().continuation
        }

        mutating func removeWaiter(_ id: UInt64) -> Waiter? {
            guard let index = waiters.firstIndex(where: { $0.id == id }) else { return nil }
            return waiters.remove(at: index).continuation
        }
    }

    private let state: OSAllocatedUnfairLock<State>

    init(maxConcurrentDecodes: Int) {
        state = OSAllocatedUnfairLock(initialState: State(freeSlots: maxConcurrentDecodes))
    }

    func run<Value>(_ work: () throws -> Value) async throws -> Value {
        try await acquireSlot()
        defer { releaseSlot() }
        return try work()
    }

    private func acquireSlot() async throws {
        let waiterID = state.withLock { $0.makeID() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(continuation, id: waiterID)
            }
        } onCancel: {
            state.withLock { $0.removeWaiter(waiterID) }?.resume(throwing: CancellationError())
        }
    }

    private func enqueue(_ continuation: Waiter, id: UInt64) {
        let outcome = state.withLock { state -> Result<Void, any Error>? in
            guard !Task.isCancelled else { return .failure(CancellationError()) }
            guard state.freeSlots > 0 else {
                state.waiters.append((id, continuation))
                return nil
            }
            state.freeSlots -= 1
            return .success(())
        }
        if let outcome {
            continuation.resume(with: outcome)
        }
    }

    private func releaseSlot() {
        state.withLock { $0.releaseSlot() }?.resume()
    }
}

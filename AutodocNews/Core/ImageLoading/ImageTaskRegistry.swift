import os
import UIKit

enum ImagePriorityBoost: Sendable {
    case escalate
    case restart

    static var platformDefault: ImagePriorityBoost {
        if #available(iOS 26.0, *) {
            return .escalate
        }
        return .restart
    }
}

final class ImageTaskRegistry: ImageTaskDeduplicating {
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let priorityBoost: ImagePriorityBoost

    init(priorityBoost: ImagePriorityBoost) {
        self.priorityBoost = priorityBoost
    }

    func image(for job: ImageLoadJob) async throws -> UIImage {
        let waiterID = state.withLock { $0.makeID() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                join(job, waiterID: waiterID, continuation: continuation)
            }
        } onCancel: {
            removeWaiter(waiterID, for: job.request)
        }
    }

    func prefetch(_ job: ImageLoadJob) {
        state.withLock { state in
            _ = startIfNeeded(job, in: &state)
            state.entries[job.request]?.isPrefetched = true
        }
    }

    func cancelPrefetch(_ request: ImageRequest) {
        let abandonedTask = state.withLock { $0.releasePrefetch(for: request) }
        abandonedTask?.cancel()
    }

    private func join(_ job: ImageLoadJob, waiterID: UInt64, continuation: Waiter) {
        let joined = state.withLock { state -> JoinOutcome? in
            guard !Task.isCancelled else { return nil }
            let supersededTask = restartIfUnderPrioritized(job, in: &state)
            let task = startIfNeeded(job, in: &state)
            state.entries[job.request]?.waiters[waiterID] = continuation
            return JoinOutcome(sharedTask: task, supersededTask: supersededTask)
        }
        guard let joined else {
            continuation.resume(throwing: CancellationError())
            return
        }
        joined.supersededTask?.cancel()
        escalate(joined.sharedTask, to: job.priority)
    }

    private func startIfNeeded(_ job: ImageLoadJob, in state: inout State) -> Task<Void, Never> {
        if let existing = state.entries[job.request] {
            return existing.task
        }
        let entryID = state.makeID()
        let task = Task(priority: job.priority) { [self] in
            let result = await Result { try await job.operation(job.request) }
            complete(job.request, entryID: entryID, with: result)
        }
        state.entries[job.request] = Entry(id: entryID, task: task, priority: job.priority)
        return task
    }

    private func restartIfUnderPrioritized(_ job: ImageLoadJob, in state: inout State) -> Task<Void, Never>? {
        guard
            priorityBoost == .restart,
            let entry = state.entries[job.request],
            entry.waiters.isEmpty,
            entry.priority < job.priority
        else { return nil }
        state.entries[job.request] = nil
        _ = startIfNeeded(job, in: &state)
        state.entries[job.request]?.isPrefetched = entry.isPrefetched
        return entry.task
    }

    private func escalate(_ task: Task<Void, Never>, to priority: TaskPriority) {
        guard priorityBoost == .escalate else { return }
        if #available(iOS 26.0, *) {
            task.escalatePriority(to: priority)
        }
    }

    private func complete(_ request: ImageRequest, entryID: UInt64, with result: Result<UIImage, any Error>) {
        let waiters = state.withLock { $0.removeEntry(for: request, entryID: entryID) }
        for waiter in waiters {
            waiter.resume(with: result)
        }
    }

    private func removeWaiter(_ waiterID: UInt64, for request: ImageRequest) {
        let removal = state.withLock { $0.removeWaiter(waiterID, for: request) }
        removal.waiter?.resume(throwing: CancellationError())
        removal.abandonedTask?.cancel()
    }
}

private extension ImageTaskRegistry {
    typealias Waiter = CheckedContinuation<UIImage, any Error>
    typealias WaiterRemoval = (waiter: Waiter?, abandonedTask: Task<Void, Never>?)

    struct JoinOutcome {
        let sharedTask: Task<Void, Never>
        let supersededTask: Task<Void, Never>?
    }

    struct Entry: Sendable {
        let id: UInt64
        let task: Task<Void, Never>
        let priority: TaskPriority
        var waiters: [UInt64: Waiter] = [:]
        var isPrefetched = false

        var isIdle: Bool { waiters.isEmpty && !isPrefetched }
    }

    struct State: Sendable {
        var entries: [ImageRequest: Entry] = [:]
        private var lastID: UInt64 = 0

        mutating func makeID() -> UInt64 {
            lastID &+= 1
            return lastID
        }

        mutating func removeEntry(for request: ImageRequest, entryID: UInt64) -> [Waiter] {
            guard entries[request]?.id == entryID else { return [] }
            return entries.removeValue(forKey: request).map { Array($0.waiters.values) } ?? []
        }

        mutating func removeWaiter(_ waiterID: UInt64, for request: ImageRequest) -> WaiterRemoval {
            guard let waiter = entries[request]?.waiters.removeValue(forKey: waiterID) else {
                return (nil, nil)
            }
            return (waiter, removeEntryIfIdle(for: request))
        }

        mutating func releasePrefetch(for request: ImageRequest) -> Task<Void, Never>? {
            guard entries[request]?.isPrefetched == true else { return nil }
            entries[request]?.isPrefetched = false
            return removeEntryIfIdle(for: request)
        }

        private mutating func removeEntryIfIdle(for request: ImageRequest) -> Task<Void, Never>? {
            guard let entry = entries[request], entry.isIdle else { return nil }
            entries[request] = nil
            return entry.task
        }
    }
}

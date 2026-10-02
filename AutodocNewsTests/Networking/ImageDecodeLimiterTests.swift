import Dispatch
import Foundation
import os
import Testing
@testable import AutodocNews

@Suite("ImageDecodeLimiter", .timeLimit(.minutes(1)))
struct ImageDecodeLimiterTests {
    private enum TestData {
        static let maxConcurrentDecodes = 2
        static let queuedWorkCount = maxConcurrentDecodes + 1
        static let result = 42
    }

    @Test("work runs and returns its value when a slot is free")
    func runsWork() async throws {
        let limiter = ImageDecodeLimiter(maxConcurrentDecodes: TestData.maxConcurrentDecodes)

        let value = try await limiter.run { TestData.result }

        #expect(value == TestData.result)
    }

    @Test("no more work runs at once than the limit")
    func respectsLimit() async throws {
        let limiter = ImageDecodeLimiter(maxConcurrentDecodes: TestData.maxConcurrentDecodes)
        let probe = ConcurrencyProbe()
        let gate = DispatchSemaphore(value: 0)
        let workers = (0..<TestData.queuedWorkCount).map { _ in
            Task { try await limiter.run { probe.runBlocked(on: gate) } }
        }

        try await probe.entries.wait { $0.count == TestData.maxConcurrentDecodes }
        workers.forEach { _ in gate.signal() }
        for worker in workers {
            try await worker.value
        }

        #expect(probe.maximumActiveCount == TestData.maxConcurrentDecodes)
        #expect(probe.entries.events.count == TestData.queuedWorkCount)
    }

    @Test("a cancelled waiter throws, never runs, and does not leak its slot")
    func cancelledWaiterNeverRuns() async throws {
        let limiter = ImageDecodeLimiter(maxConcurrentDecodes: 1)
        let probe = ConcurrencyProbe()
        let gate = DispatchSemaphore(value: 0)
        let holder = Task { try await limiter.run { probe.runBlocked(on: gate) } }
        try await probe.entries.wait { $0.count == 1 }

        let waiter = Task { try await limiter.run { probe.runBlocked(on: gate) } }
        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
        gate.signal()
        try await holder.value
        #expect(try await limiter.run { TestData.result } == TestData.result)
        #expect(probe.entries.events.count == 1)
    }

    @Test("work that throws releases its slot")
    func throwingWorkReleasesSlot() async throws {
        let limiter = ImageDecodeLimiter(maxConcurrentDecodes: 1)

        await #expect(throws: TestError.unexpected) {
            try await limiter.run { throw TestError.unexpected }
        }

        #expect(try await limiter.run { TestData.result } == TestData.result)
    }
}

@Suite("TransientRetryPolicy")
struct TransientRetryPolicyTests {
    private static let retryLeft = 1

    private let policy = TransientRetryPolicy(
        maxRetries: Constants.ImageLoading.transientRetryCount,
        delay: .zero,
        retryableCodes: Constants.ImageLoading.transientErrorCodes
    )

    @Test("a stalled or dropped connection is retried", arguments: [URLError.Code.timedOut, .networkConnectionLost])
    func retriesTransientFailures(code: URLError.Code) {
        #expect(policy.shouldRetry(URLError(code), retriesLeft: Self.retryLeft))
    }

    @Test("other failures are not retried", arguments: [
        URLError.Code.cancelled, .notConnectedToInternet, .badServerResponse, .cannotFindHost,
    ])
    func skipsOtherFailures(code: URLError.Code) {
        #expect(!policy.shouldRetry(URLError(code), retriesLeft: Self.retryLeft))
    }

    @Test("nothing is retried once the retries are used up")
    func stopsWhenExhausted() {
        #expect(!policy.shouldRetry(URLError(.timedOut), retriesLeft: 0))
    }
}

private final class ConcurrencyProbe: Sendable {
    private struct Counters {
        var active = 0
        var maximumActive = 0
    }

    let entries = EventLog<Void>()
    private let counters = OSAllocatedUnfairLock(initialState: Counters())

    var maximumActiveCount: Int {
        counters.withLock { $0.maximumActive }
    }

    func runBlocked(on gate: DispatchSemaphore) {
        counters.withLock { counters in
            counters.active += 1
            counters.maximumActive = max(counters.maximumActive, counters.active)
        }
        entries.record(())
        gate.wait()
        counters.withLock { $0.active -= 1 }
    }
}

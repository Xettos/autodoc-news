import Foundation
import Testing
import UIKit
@testable import AutodocNews

@Suite("ImageTaskRegistry", .timeLimit(.minutes(1)))
struct ImageTaskRegistryTests {
    private enum TestData {
        static let request = ImageRequest(url: URL(filePath: "/news/shared.jpg"))
        static let prefetchPriority = TaskPriority.background
        static let firstPriority = TaskPriority.utility
        static let secondPriority = TaskPriority.medium
        static let thirdPriority = TaskPriority.high
    }

    private let load = ScriptedImageLoad()

    @available(iOS 26.0, *)
    @Test("consumers of one request share a single load and receive the same image")
    func consumersShareOneLoad() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let image = UIImage()
        let (first, second) = try await startTwoJoinedConsumers(of: registry)

        load.responder.resolvePendingCall(for: TestData.request, with: .success(image))

        #expect(try await first.value === image)
        #expect(try await second.value === image)
        #expect(load.startCount == 1)
    }

    @available(iOS 26.0, *)
    @Test("a failure is delivered to every consumer")
    func failureFansOut() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let (first, second) = try await startTwoJoinedConsumers(of: registry)

        load.responder.resolvePendingCall(for: TestData.request, with: .failure(TestError.unexpected))

        await #expect(throws: TestError.unexpected) { try await first.value }
        await #expect(throws: TestError.unexpected) { try await second.value }
    }

    @available(iOS 26.0, *)
    @Test("a cancelled consumer stops waiting while the others still get the image")
    func cancellingOneConsumerKeepsTheLoad() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let image = UIImage()
        let (first, second) = try await startTwoJoinedConsumers(of: registry)

        first.cancel()

        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(load.responder.resolvePendingCall(for: TestData.request, with: .success(image)))
        #expect(try await second.value === image)
        #expect(load.count(of: .cancelled) == 0)
    }

    @available(iOS 26.0, *)
    @Test("cancelling every consumer cancels the shared load")
    func cancellingAllConsumersCancelsTheLoad() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let (first, second) = try await startTwoJoinedConsumers(of: registry)

        first.cancel()
        second.cancel()

        try await load.events.wait(for: .cancelled)
        await #expect(throws: CancellationError.self) { try await first.value }
        await #expect(throws: CancellationError.self) { try await second.value }
        #expect(load.responder.pendingCallCount == 0)
    }

    @Test("a consumer cancelled before it joins throws and leaves no waiter behind")
    func consumerCancelledBeforeJoining() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let job = makeJob(priority: TestData.firstPriority)

        let consumer = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await registry.image(for: job)
        }

        await #expect(throws: CancellationError.self) { try await consumer.value }
        registry.prefetch(makeJob(priority: TestData.prefetchPriority))
        registry.cancelPrefetch(TestData.request)
        try await load.events.wait(for: .cancelled)
    }

    @available(iOS 26.0, *)
    @Test("a display joining a prefetch shares its load")
    func displayJoinsPrefetch() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let image = UIImage()
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)

        let display = try await startJoinedConsumer(of: registry, priority: TestData.firstPriority)
        load.responder.resolvePendingCall(for: TestData.request, with: .success(image))

        #expect(try await display.value === image)
        #expect(load.startCount == 1)
    }

    @available(iOS 26.0, *)
    @Test("cancelling the prefetch while a display waits keeps the load running")
    func cancelPrefetchKeepsDisplayLoad() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        let image = UIImage()
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)
        let display = try await startJoinedConsumer(of: registry, priority: TestData.firstPriority)

        registry.cancelPrefetch(TestData.request)

        #expect(load.responder.resolvePendingCall(for: TestData.request, with: .success(image)))
        #expect(try await display.value === image)
    }

    @available(iOS 26.0, *)
    @Test("a display that leaves keeps a prefetched load running")
    func cancelledDisplayKeepsPrefetch() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)
        let display = try await startJoinedConsumer(of: registry, priority: TestData.firstPriority)

        display.cancel()

        await #expect(throws: CancellationError.self) { try await display.value }
        #expect(load.responder.resolvePendingCall(for: TestData.request, with: .success(UIImage())))
    }

    @Test("cancelling a prefetch nobody displays cancels its load")
    func cancelIdlePrefetch() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)

        registry.cancelPrefetch(TestData.request)

        try await load.events.wait(for: .cancelled)
        #expect(load.responder.pendingCallCount == 0)
    }

    @available(iOS 26.0, *)
    @Test("escalate: a display raises the prefetch's priority without restarting it")
    func escalateKeepsTheLoad() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .escalate)
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)

        let display = try await startJoinedConsumer(of: registry, priority: TestData.thirdPriority)
        load.responder.resolvePendingCall(for: TestData.request, with: .success(UIImage()))

        _ = try await display.value
        #expect(load.startCount == 1)
        #expect(load.count(of: .cancelled) == 0)
    }

    @Test("restart: a display restarts a lower-priority prefetch at its own priority")
    func restartReplacesThePrefetch() async throws {
        let registry = ImageTaskRegistry(priorityBoost: .restart)
        let image = UIImage()
        startPrefetch(on: registry)
        await load.responder.waitForPendingCall(for: TestData.request)

        let displayJob = makeJob(priority: TestData.firstPriority)
        let display = Task { try await registry.image(for: displayJob) }
        try await load.events.wait { $0.contains(.cancelled) && $0.count { $0 == .started } == 2 }
        await load.responder.waitForPendingCall(for: TestData.request)
        load.responder.resolvePendingCall(for: TestData.request, with: .success(image))

        #expect(try await display.value === image)
        load.responder.expectFullyConsumed()
    }

    @Test("the platform default boost is escalation where the OS supports it")
    func platformDefaultBoost() {
        if #available(iOS 26.0, *) {
            #expect(ImagePriorityBoost.platformDefault == .escalate)
        } else {
            #expect(ImagePriorityBoost.platformDefault == .restart)
        }
    }

    private func makeJob(priority: TaskPriority) -> ImageLoadJob {
        ImageLoadJob(request: TestData.request, priority: priority, operation: load.operation)
    }

    private func startPrefetch(on registry: ImageTaskRegistry) {
        registry.prefetch(makeJob(priority: TestData.prefetchPriority))
    }

    @available(iOS 26.0, *)
    private func startJoinedConsumer(
        of registry: ImageTaskRegistry,
        priority: TaskPriority
    ) async throws -> Task<UIImage, any Error> {
        let job = makeJob(priority: priority)
        return try await load.startJoiningConsumer(escalatingTo: priority) {
            Task { try await registry.image(for: job) }
        }
    }

    @available(iOS 26.0, *)
    private func startTwoJoinedConsumers(
        of registry: ImageTaskRegistry
    ) async throws -> (Task<UIImage, any Error>, Task<UIImage, any Error>) {
        let firstJob = makeJob(priority: TestData.firstPriority)
        let first = Task { try await registry.image(for: firstJob) }
        await load.responder.waitForPendingCall(for: TestData.request)
        let second = try await startJoinedConsumer(of: registry, priority: TestData.secondPriority)
        return (first, second)
    }
}

private extension ScriptedImageLoad {
    func count(of event: Event) -> Int {
        events.count(of: event)
    }
}

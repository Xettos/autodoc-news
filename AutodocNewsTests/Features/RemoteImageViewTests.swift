import Foundation
import Testing
import UIKit
@testable import AutodocNews

@MainActor
@Suite("RemoteImageView", .timeLimit(.minutes(1)))
struct RemoteImageViewTests {
    private enum TestData {
        static let url = URL(filePath: "/news/remote.jpg")
        static let request = ImageRequest(url: url, targetSize: CGSize(width: 100, height: 100), scale: 1)
        static let otherRequest = ImageRequest(url: URL(filePath: "/news/other.jpg"), targetSize: CGSize(width: 100, height: 100), scale: 1)
        static let interimRequest = ImageRequest(url: url, targetSize: CGSize(width: 400, height: 400), scale: 1)
        static let placeholderColor = UIColor.systemPink
    }

    private let view = RemoteImageView(frame: .zero)

    @Test("a memory-cache hit is shown synchronously without loading")
    func cacheHitIsShownSynchronously() {
        let loader = ScriptedImageLoader()
        let cached = UIImage()
        loader.cache(cached, for: TestData.request)

        view.setImage(TestData.request, using: loader)

        #expect(view.image === cached)
        #expect(view.loadTask == nil)
        #expect(loader.responder.calls.isEmpty)
    }

    @Test("a loaded image replaces the placeholder")
    func loadedImageIsShown() async throws {
        let loader = ScriptedImageLoader()
        let loaded = UIImage()

        let load = try await startLoad(TestData.request, using: loader)
        loader.responder.resolvePendingCall(for: TestData.request, with: .success(loaded))
        await load.value

        #expect(view.image === loaded)
        #expect(view.backgroundColor == nil)
        #expect(view.loadTask == nil)
    }

    @Test("an interim variant of the same image is shown while the requested size loads")
    func interimVariantIsShown() async throws {
        let loader = ScriptedImageLoader()
        let interim = UIImage()
        loader.cache(interim, for: TestData.interimRequest)

        _ = try await startLoad(TestData.request, using: loader)

        #expect(view.image === interim)
    }

    @Test("setting the same request again neither restarts the load nor clears the view")
    func sameRequestIsNotRestarted() async throws {
        let loader = ScriptedImageLoader()
        let load = try await startLoad(TestData.request, using: loader)

        view.setImage(TestData.request, using: loader)

        #expect(view.loadTask == load)
        #expect(loader.responder.calls == [TestData.request])
    }

    @Test("a late result for a replaced request is ignored")
    func replacedRequestResultIsIgnored() async throws {
        let loader = ScriptedImageLoader(cancellationBehavior: .ignored)
        let replacedLoad = try await startLoad(TestData.request, using: loader)
        let currentLoad = try await startLoad(TestData.otherRequest, using: loader)

        loader.responder.resolvePendingCall(for: TestData.request, with: .success(UIImage()))
        await replacedLoad.value

        #expect(view.image == nil)
        #expect(view.loadTask == currentLoad)
    }

    @Test("a late result of a cancelled load of the same request leaves the new load in charge")
    func cancelledSameRequestResultIsIgnored() async throws {
        let loader = ScriptedImageLoader(cancellationBehavior: .ignored)
        let fresh = UIImage()
        let cancelledLoad = try await startLoad(TestData.request, using: loader)
        view.cancelLoading()
        let currentLoad = try #require(startLoadWithoutWaiting(TestData.request, using: loader))

        loader.responder.resolvePendingCall(for: TestData.request, with: .success(UIImage()))
        await cancelledLoad.value

        #expect(view.image == nil)
        #expect(view.loadTask == currentLoad)
        await loader.responder.waitForPendingCall(for: TestData.request)
        loader.responder.resolvePendingCall(for: TestData.request, with: .success(fresh))
        await currentLoad.value
        #expect(view.image === fresh)
    }

    @Test("cancelLoading cancels the in-flight load and restores the placeholder")
    func cancelLoadingCancelsLoad() async throws {
        let loader = ScriptedImageLoader()
        view.placeholderColor = TestData.placeholderColor
        _ = try await startLoad(TestData.request, using: loader)

        view.cancelLoading()

        #expect(loader.responder.pendingCallCount == 0)
        #expect(view.loadTask == nil)
        #expect(view.image == nil)
        #expect(view.backgroundColor == TestData.placeholderColor)
    }

    @Test("a failed load without an image shows the failure icon")
    func failureShowsIcon() async throws {
        let loader = ScriptedImageLoader()

        try await failLoad(TestData.request, using: loader)

        #expect(view.image == nil)
        #expect(isShowingFailureIcon)
    }

    @Test("a failed load keeps the interim image instead of the failure icon")
    func failureKeepsInterimImage() async throws {
        let loader = ScriptedImageLoader()
        let interim = UIImage()
        loader.cache(interim, for: TestData.interimRequest)

        try await failLoad(TestData.request, using: loader)

        #expect(view.image === interim)
        #expect(!isShowingFailureIcon)
    }

    @Test("cancelLoading hides the failure icon")
    func resetHidesFailureIcon() async throws {
        let loader = ScriptedImageLoader()
        try await failLoad(TestData.request, using: loader)

        view.cancelLoading()

        #expect(!isShowingFailureIcon)
    }

    private var isShowingFailureIcon: Bool {
        view.subviews.contains { $0 is UIImageView && !$0.isHidden }
    }

    private func startLoad(_ request: ImageRequest, using loader: ScriptedImageLoader) async throws -> Task<Void, Never> {
        let load = try #require(startLoadWithoutWaiting(request, using: loader))
        await loader.responder.waitForPendingCall(for: request)
        return load
    }

    private func startLoadWithoutWaiting(_ request: ImageRequest, using loader: ScriptedImageLoader) -> Task<Void, Never>? {
        view.setImage(request, using: loader)
        return view.loadTask
    }

    private func failLoad(_ request: ImageRequest, using loader: ScriptedImageLoader) async throws {
        let load = try await startLoad(request, using: loader)
        loader.responder.resolvePendingCall(for: request, with: .failure(ImageLoadingError.httpStatus(404)))
        await load.value
    }
}

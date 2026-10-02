import Combine
import Testing
@testable import AutodocNews

@Suite("NewsFeedStateTransition")
struct NewsFeedStateTransitionTests {
    private let content = NewsFeedViewState(itemIDs: [1, 2], phase: .content, pagingFooter: .loading, contentRevision: 1)

    @Test("the first state requires a full reload")
    func firstStateReloads() {
        let transition = NewsFeedStateTransition(previous: nil, current: content)

        #expect(transition.changesContent)
        #expect(transition.changesPhase)
        #expect(transition.requiresFullReload)
    }

    @Test("toggling only the refresh flag does not change content")
    func refreshFlagIsNotContent() {
        var refreshing = content
        refreshing.isRefreshing = true

        let transition = NewsFeedStateTransition(previous: content, current: refreshing)

        #expect(!transition.changesContent)
    }

    @Test("appending a page changes content without a full reload")
    func appendIsIncremental() {
        var appended = content
        appended.itemIDs = [1, 2, 3]

        let transition = NewsFeedStateTransition(previous: content, current: appended)

        #expect(transition.changesContent)
        #expect(!transition.requiresFullReload)
    }

    @Test("a new content revision requires a full reload")
    func newRevisionReloads() {
        var replaced = content
        replaced.contentRevision = 2

        let transition = NewsFeedStateTransition(previous: content, current: replaced)

        #expect(transition.requiresFullReload)
        #expect(!transition.changesPhase)
    }

    @Test("a phase change requires a full reload")
    func phaseChangeReloads() {
        let transition = NewsFeedStateTransition(previous: NewsFeedViewState(), current: content)

        #expect(transition.changesPhase)
        #expect(transition.requiresFullReload)
    }

    @MainActor
    @Test("transitions pair every state with the previous one")
    func publisherPairsStates() {
        let subject = PassthroughSubject<NewsFeedViewState, Never>()
        let recorder = PublisherRecorder(subject.transitions())
        let initial = NewsFeedViewState()

        subject.send(initial)
        subject.send(content)

        #expect(recorder.values == [
            NewsFeedStateTransition(previous: nil, current: initial),
            NewsFeedStateTransition(previous: initial, current: content),
        ])
    }
}

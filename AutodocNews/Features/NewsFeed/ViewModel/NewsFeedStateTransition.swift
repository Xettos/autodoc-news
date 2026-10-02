import Combine

struct NewsFeedStateTransition: Equatable {
    let previous: NewsFeedViewState?
    let current: NewsFeedViewState

    var changesContent: Bool {
        guard let previous else { return true }
        return previous.itemIDs != current.itemIDs
            || previous.phase != current.phase
            || previous.pagingFooter != current.pagingFooter
            || previous.contentRevision != current.contentRevision
    }

    var changesPhase: Bool {
        previous?.phase != current.phase
    }

    var requiresFullReload: Bool {
        guard let previous else { return true }
        return previous.contentRevision != current.contentRevision || changesPhase
    }

    func advanced(to next: NewsFeedViewState) -> NewsFeedStateTransition {
        NewsFeedStateTransition(previous: current, current: next)
    }
}

extension Publisher where Output == NewsFeedViewState {
    func transitions() -> AnyPublisher<NewsFeedStateTransition, Failure> {
        scan(nil as NewsFeedStateTransition?) { last, state in
            last?.advanced(to: state) ?? NewsFeedStateTransition(previous: nil, current: state)
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}

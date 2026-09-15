import Testing
@testable import NotchStatusCore

private func s(_ state: SessionState, _ project: String, ts: Int = 100) -> SessionStatus {
    SessionStatus(state: state, project: project, ts: ts)
}

@Suite struct AggregatorTests {
    @Test func emptyIsNil() {
        #expect(Aggregator.aggregate([]) == nil)
    }

    @Test func singleSessionIsItself() {
        #expect(Aggregator.aggregate([s(.working, "a")]) == s(.working, "a"))
    }

    @Test func waitingBeatsEverything() {
        let sessions = [s(.working, "a"), s(.idle, "b"), s(.waiting, "c"), s(.done, "d")]
        #expect(Aggregator.aggregate(sessions)?.project == "c")
    }

    @Test func workingBeatsIdleAndDone() {
        let sessions = [s(.idle, "a"), s(.done, "b"), s(.working, "c")]
        #expect(Aggregator.aggregate(sessions)?.project == "c")
    }

    @Test func finishedSessionsPickMostRecentRegardlessOfIdleOrDone() {
        // idle 與 done 都代表「跑完了」，同一級，取最近觸發的
        #expect(Aggregator.aggregate([s(.done, "a", ts: 200), s(.idle, "b", ts: 100)])?.project == "a")
        #expect(Aggregator.aggregate([s(.done, "a", ts: 100), s(.idle, "b", ts: 200)])?.project == "b")
    }

    @Test func allDoneIsDone() {
        let sessions = [s(.done, "a"), s(.done, "b")]
        #expect(Aggregator.aggregate(sessions)?.state == .done)
    }

    @Test func sameStatePicksMostRecent() {
        let sessions = [s(.waiting, "old", ts: 100), s(.waiting, "new", ts: 200), s(.waiting, "mid", ts: 150)]
        #expect(Aggregator.aggregate(sessions)?.project == "new")
    }

    @Test func listSortsByUrgencyThenMostRecent() {
        let sessions = [
            s(.done, "done-old", ts: 1), s(.working, "work-old", ts: 2), s(.idle, "idle-new", ts: 9),
            s(.waiting, "wait", ts: 3), s(.working, "work-new", ts: 8)
        ]
        #expect(Aggregator.sortedForList(sessions).map(\.project)
                == ["wait", "work-new", "work-old", "idle-new", "done-old"])
    }

    @Test func listFirstIsTheAggregate() {
        let sessions = [s(.idle, "a", ts: 5), s(.working, "b", ts: 1), s(.done, "c", ts: 9)]
        #expect(Aggregator.sortedForList(sessions).first == Aggregator.aggregate(sessions))
    }

    @Test func orderOfInputDoesNotMatter() {
        let sessions = [s(.done, "a"), s(.working, "b", ts: 5), s(.idle, "c", ts: 50)]
        #expect(Aggregator.aggregate(sessions) == Aggregator.aggregate(sessions.reversed()))
    }
}

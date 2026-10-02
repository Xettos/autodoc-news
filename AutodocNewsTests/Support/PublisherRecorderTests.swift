import Combine
import Testing

@MainActor
@Suite("PublisherRecorder")
struct PublisherRecorderTests {
    private enum TestData {
        static let value = 1
    }

    private let subject = PassthroughSubject<Int, Never>()

    @Test("values sent on the main actor are recorded in order")
    func recordsMainActorValues() {
        let recorder = PublisherRecorder(subject)

        subject.send(TestData.value)
        subject.send(TestData.value + 1)

        #expect(recorder.values == [TestData.value, TestData.value + 1])
    }

    @Test("a value sent off the main thread is reported as an issue of the current test")
    func reportsOffMainEmission() async {
        let recorder = PublisherRecorder(subject)

        await sendOffMain(TestData.value)

        withKnownIssue {
            #expect(recorder.values.isEmpty)
        }
    }

    @Test("wait returns as soon as the condition holds")
    func waitReturnsWhenConditionHolds() async throws {
        let recorder = PublisherRecorder(subject)
        subject.send(TestData.value)

        let values = try await recorder.wait { $0.contains(TestData.value) }

        #expect(values == [TestData.value])
    }

    private func sendOffMain(_ value: Int) async {
        nonisolated(unsafe) let subject = subject
        await Task.detached {
            subject.send(value)
        }.value
    }
}

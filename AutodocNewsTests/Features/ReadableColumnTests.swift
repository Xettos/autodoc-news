import Testing
import UIKit
@testable import AutodocNews

@MainActor
@Suite("UIView.addReadableColumn")
struct ReadableColumnTests {
    private enum TestData {
        static let maximumWidth: CGFloat = 680
        static let height: CGFloat = 1000
    }

    @Test("a narrow container keeps the full readable width", arguments: [320.0, 402.0])
    func narrowContainerUsesReadableWidth(width: CGFloat) {
        let (container, column) = makeColumn(containerWidth: width)

        #expect(column.layoutFrame.width == container.readableContentGuide.layoutFrame.width)
        #expect(column.layoutFrame.width <= TestData.maximumWidth)
    }

    @Test("a wide container caps the column and centers it", arguments: [820.0, 1180.0, 1366.0])
    func wideContainerCapsWidth(width: CGFloat) {
        let (container, column) = makeColumn(containerWidth: width)
        let readableFrame = container.readableContentGuide.layoutFrame

        #expect(column.layoutFrame.width == min(TestData.maximumWidth, readableFrame.width))
        #expect(column.layoutFrame.midX == readableFrame.midX)
    }

    private func makeColumn(containerWidth: CGFloat) -> (UIView, UILayoutGuide) {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: TestData.height))
        let column = container.addReadableColumn(maximumWidth: TestData.maximumWidth)
        container.layoutIfNeeded()
        return (container, column)
    }
}

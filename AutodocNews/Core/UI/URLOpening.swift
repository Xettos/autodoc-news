import Foundation

@MainActor
protocol URLOpening {
    func open(url: URL)
}

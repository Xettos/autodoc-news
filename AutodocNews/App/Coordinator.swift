import UIKit

@MainActor
protocol Coordinator: AnyObject {
    var rootViewController: UIViewController { get }
    func start()
}

@MainActor
protocol CoordinatorFactory {
    func makeAppCoordinator() -> any Coordinator
}

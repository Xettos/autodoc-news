import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: (any Coordinator)?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let coordinatorFactory = (UIApplication.shared.delegate as? AppDelegate)?.coordinatorFactory else {
            assertionFailure(Constants.App.Diagnostics.missingCoordinatorFactory)
            return
        }

        let coordinator = coordinatorFactory.makeAppCoordinator()
        coordinator.start()
        window = makeWindow(in: windowScene, root: coordinator.rootViewController)
        self.coordinator = coordinator
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        coordinator = nil
        window = nil
    }

    private func makeWindow(in windowScene: UIWindowScene, root: UIViewController) -> UIWindow {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        return window
    }
}

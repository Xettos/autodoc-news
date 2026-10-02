import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    let coordinatorFactory: any CoordinatorFactory = AppDependencies()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: Constants.App.sceneConfigurationName, sessionRole: connectingSceneSession.role)
    }
}

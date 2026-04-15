import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: MainViewController())
        nav.navigationBar.tintColor = .systemOrange
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AlarmManager.shared.startBackgroundKeepAlive()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        AlarmManager.shared.stopBackgroundKeepAlive()
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

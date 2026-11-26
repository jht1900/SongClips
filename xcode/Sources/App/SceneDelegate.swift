//
//  SceneDelegate.swift
//  SongClips
//
//  Builds the window and navigation stack (formerly MainWindow.xib).
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let firstStop = FirstStopViewCtl()
        AppDelegate.shared.firstStopViewCtl = firstStop

        let navigationController = UINavigationController(rootViewController: firstStop)
        navigationController.navigationBar.barStyle = .black
        navigationController.navigationBar.isTranslucent = false

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window

        if let url = connectionOptions.urlContexts.first?.url {
            AppDelegate.shared.handleOpenURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AppDelegate.shared.handleOpenURL(url)
        // When the link arrives after the scene became active, act on it now.
        if scene.activationState == .foregroundActive {
            AppDelegate.shared.firstStopViewCtl?.becomeActive()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppDelegate.shared.firstStopViewCtl?.becomeActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SongList.shared.currentSong?.mediaMissingShown = false
    }
}

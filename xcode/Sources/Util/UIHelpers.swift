//
//  UIHelpers.swift
//  SongClips
//

import UIKit

extension UIColor {
    /// Green used for the "add" row and the current song title.
    static let songClipsGreen = UIColor(red: 4.0 / 255.0, green: 143.0 / 255.0, blue: 1.0 / 255.0, alpha: 1.0)
}

extension UIDevice {
    static var isPad: Bool { current.userInterfaceIdiom == .pad }
}

enum Alerts {
    /// Show a simple message with an OK button over whatever is on screen.
    static func show(_ message: String?, title: String?) {
        guard let presenter = topViewController() else {
            appLog.error("Alert with no presenter: \(title ?? "", privacy: .public) \(message ?? "", privacy: .public)")
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }

    static func showError(_ message: String) {
        show(message, title: "Error")
    }

    /// Ask a yes/no question. `handler` runs only when the user picks `confirmTitle`.
    static func confirm(
        title: String?, message: String?, confirmTitle: String,
        on presenter: UIViewController, handler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in handler() })
        presenter.present(alert, animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Open a web address in the user's browser.
func openInBrowser(_ urlString: String?) {
    guard let urlString, let url = URL(string: urlString) else {
        appLog.error("openInBrowser: bad url \(urlString ?? "nil", privacy: .public)")
        return
    }
    UIApplication.shared.open(url)
}

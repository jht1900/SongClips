//
//  UIHelpers.swift
//  SongClips4
//
//  Colors, bundle images, alerts and browser links shared by the SwiftUI screens.
//

import Observation
import SwiftUI
import UIKit

extension Color {
    /// Green used for the "add" row and the current song title.
    static let songClipsGreen = Color(red: 4.0 / 255.0, green: 143.0 / 255.0, blue: 1.0 / 255.0)
    /// Background of the player's control bars.
    static let controlBar = Color(white: 0.25)
}

extension UIDevice {
    static var isPad: Bool { current.userInterfaceIdiom == .pad }
}

/// An image file from the app bundle (the shared `Resources/img` PNGs are drawn at 2x).
nonisolated func bundleImage(_ name: String) -> Image {
    Image(uiImage: UIImage(named: name) ?? UIImage())
}

/// A message to show in an alert.
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

/// Alerts raised by model code; the root view presents `current`.
@Observable
final class Alerts {
    static let shared = Alerts()

    var current: AppAlert?

    static func show(_ message: String?, title: String?) {
        appLog.info("Alert: \(title ?? "", privacy: .public) \(message ?? "", privacy: .public)")
        shared.current = AppAlert(title: title ?? "", message: message)
    }

    static func showError(_ message: String) {
        show(message, title: "Error")
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

/// Button style that swaps to a highlighted image while pressed, like the UIKit buttons it replaces.
struct ImageButtonStyle: ButtonStyle {
    let normal: String
    let pressed: String
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        bundleImage(configuration.isPressed ? pressed : normal)
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}

/// Two-line navigation title: song label over details.
struct TitleView: View {
    let top: String
    let bottom: String

    var body: some View {
        VStack(spacing: 0) {
            Text(top)
                .font(.custom("Helvetica-Bold", size: 18))
            Text(bottom)
                .font(.custom("Helvetica", size: 14))
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(maxWidth: UIDevice.isPad ? 688 : 240)
        .background(Color(white: 0.667), in: RoundedRectangle(cornerRadius: 4))
    }
}

extension View {
    /// Black, opaque navigation bar, as in SongClips3.
    func songClipsNavigationBar() -> some View {
        toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

//
//  WebViewController.swift
//  SongClips
//
//  Shows a clip's linked page. Audio and video links open in the system player.
//

import AVKit
import UIKit
import WebKit

final class WebViewController: UIViewController {
    private let webView = WKWebView()

    /// Push a web page for `urlString` (adding `http://` if it has no scheme).
    static func show(urlString: String, from presenter: UIViewController) {
        guard let url = SiteClient.url(from: urlString) else { return }
        let controller = WebViewController()
        controller.title = url.lastPathComponent
        presenter.navigationController?.pushViewController(controller, animated: true)
        controller.webView.load(URLRequest(url: url))
    }

    override func loadView() {
        webView.backgroundColor = .white
        webView.navigationDelegate = self
        view = webView
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Safari", style: .plain, target: self, action: #selector(actionSafari))
    }

    @objc private func actionSafari() {
        openInBrowser(webView.url?.absoluteString)
    }

    private func playMedia(_ url: URL) {
        let player = AVPlayerViewController()
        player.player = AVPlayer(url: url)
        present(player, animated: true) {
            player.player?.play()
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let ext = url.pathExtension.lowercased()
        if MediaExtension.isMovie(ext) || MediaExtension.isAudio(ext) {
            decisionHandler(.cancel)
            playMedia(url)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    /// Report the error inside the web view.
    private func showError(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        let message = error.localizedDescription
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        webView.loadHTMLString(
            "<html><center><font size=+5 color='red'>An error occurred:<br>\(message)</font></center></html>",
            baseURL: nil)
    }
}

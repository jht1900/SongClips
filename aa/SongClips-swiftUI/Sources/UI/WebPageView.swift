//
//  WebPageView.swift
//  SongClips4
//
//  Shows a clip's linked page. Audio and video links open in a player.
//

import AVKit
import SwiftUI
import WebKit

struct WebPageView: View {
    let url: URL

    @State private var currentURL: URL?
    @State private var mediaURL: URL?

    var body: some View {
        WebView(url: url, currentURL: $currentURL, mediaURL: $mediaURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .songClipsNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Safari") {
                        openInBrowser((currentURL ?? url).absoluteString)
                    }
                }
            }
            .fullScreenCover(item: $mediaURL) { mediaURL in
                MediaPlayerView(url: mediaURL)
            }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Plays an audio or video link full screen.
private struct MediaPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .onAppear {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var currentURL: URL?
    @Binding var mediaURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .white
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

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
                parent.mediaURL = url
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.currentURL = webView.url
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showError(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(error, in: webView)
        }

        /// Report the error inside the web view.
        private func showError(_ error: Error, in webView: WKWebView) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            let message = error.localizedDescription
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
            webView.loadHTMLString(
                "<html><center><font size=+5 color='red'>An error occurred:<br>\(message)</font></center></html>",
                baseURL: nil)
        }
    }
}

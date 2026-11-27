//
//  SiteClient.swift
//  SongClips
//
//  HTTP access to the SongClips site (formerly Access, DD_Access, DD_HTTPManager, DD_RemoteSite).
//

import Foundation

enum SiteClient {
    struct HTTPError: LocalizedError {
        let statusCode: Int
        var errorDescription: String? { "HTTP error \(statusCode)" }
    }

    static var basicAuthorization: String {
        authorization(user: AppConfig.siteUsername, password: AppConfig.sitePassword)
    }

    static func authorization(user: String, password: String) -> String {
        "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    }

    /// Add `http://` when the string has no scheme.
    static func url(from string: String) -> URL? {
        let lower = string.lowercased()
        let full = lower.hasPrefix("http://") || lower.hasPrefix("https://") ? string : "http://" + string
        return URL(string: full)
    }

    /// Fetch a resource from the site with the site's credentials.
    static func fetch(_ urlString: String) async throws -> Data {
        guard let url = url(from: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.setValue(basicAuthorization, forHTTPHeaderField: "Authorization")
        appLog.debug("fetch \(url.absoluteString, privacy: .public)")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError(statusCode: http.statusCode)
        }
        return data
    }

    /// Store the site credentials so AVPlayer can stream from a protected URL.
    static func prepareStreamCredential(for url: URL) {
        guard let scheme = url.scheme, scheme != "file", let host = url.host() else { return }
        let credential = URLCredential(
            user: AppConfig.siteUsername, password: AppConfig.sitePassword, persistence: .forSession)
        let space = URLProtectionSpace(
            host: host, port: url.port ?? 0, protocol: scheme,
            realm: AppConfig.siteRealm, authenticationMethod: NSURLAuthenticationMethodHTTPDigest)
        URLCredentialStorage.shared.setDefaultCredential(credential, for: space)
    }
}

/// Downloads one file to disk and reports progress on the main actor.
@MainActor
final class FileDownloader: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let progress: @MainActor (Int64) -> Void
    private let completion: @MainActor (Error?) -> Void
    private var session: URLSession?

    init(
        destination: URL,
        progress: @escaping @MainActor (Int64) -> Void,
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        self.destination = destination
        self.progress = progress
        self.completion = completion
    }

    /// Start the download. The downloader keeps itself alive until it finishes.
    func start(from source: URL) {
        var request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        if let user = source.user(percentEncoded: false), !user.isEmpty {
            request.setValue(
                SiteClient.authorization(user: user, password: source.password(percentEncoded: false) ?? ""),
                forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(SiteClient.basicAuthorization, forHTTPHeaderField: "Authorization")
        }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        session.downloadTask(with: request).resume()
    }

    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        MainActor.assumeIsolated {
            progress(totalBytesWritten)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        // The temporary file is removed when this method returns, so move it now.
        MainActor.assumeIsolated {
            if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                appLog.error("download HTTP \(http.statusCode) \(downloadTask.originalRequest?.url?.absoluteString ?? "", privacy: .public)")
                return
            }
            let fm = FileManager.default
            Storage.createDirectory(destination.deletingLastPathComponent())
            try? fm.removeItem(at: destination)
            do {
                try fm.moveItem(at: location, to: destination)
            } catch {
                appLog.error("download move failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            if let error {
                appLog.error("download failed: \(error.localizedDescription, privacy: .public)")
            }
            completion(error)
            self.session?.finishTasksAndInvalidate()
            self.session = nil
        }
    }
}

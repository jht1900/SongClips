//
//  ExportScanner.swift
//  SongClips4
//
//  Line scanner for the SongClips text export format (formerly Scanner).
//

import Foundation

final class ExportScanner {
    private let scanner: Scanner
    private let string: String

    /// The line read by the last call to `nextLine()`.
    private(set) var line: String?

    init(string: String) {
        self.string = string
        scanner = Scanner(string: string)
    }

    var isAtEnd: Bool { scanner.isAtEnd }

    /// Read the next non-empty line. Leading whitespace and blank lines are skipped.
    @discardableResult
    func nextLine() -> Bool {
        line = scanner.scanUpToCharacters(from: .newlines)
        return line != nil
    }

    /// If the line starts with `prefix`, return the rest of it, trimmed.
    func value(after prefix: String) -> String? {
        guard let line, line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    /// If the line starts with `prefix`, parse the rest as "hh:mm:ss", "mm:ss" or "ss" seconds.
    func duration(after prefix: String) -> Double? {
        guard let text = value(after: prefix) else { return nil }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { Double($0) ?? 0 }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return nil
        }
    }

    /// Read a `Tag: text` line or a `Tag[` ... `]Tag` block.
    func textBlock(tag: String) -> String? {
        if let text = value(after: tag + ":") {
            return text
        }
        if value(after: tag + "[") != nil {
            return text(upTo: "\n]" + tag)
        }
        return nil
    }

    /// Return the raw text up to `endTag`, then skip past the line holding `endTag`.
    private func text(upTo endTag: String) -> String {
        let savedSkip = scanner.charactersToBeSkipped
        scanner.charactersToBeSkipped = nil
        defer { scanner.charactersToBeSkipped = savedSkip }

        guard !scanner.isAtEnd else { return "" }
        // Step past the newline that ends the opening line.
        scanner.currentIndex = string.index(after: scanner.currentIndex)

        let text = scanner.scanUpToString(endTag) ?? ""
        if !scanner.isAtEnd {
            scanner.currentIndex = string.index(after: scanner.currentIndex)
            _ = scanner.scanUpToCharacters(from: .newlines)
        }
        return text
    }
}

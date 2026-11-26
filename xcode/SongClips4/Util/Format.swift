//
//  Format.swift
//  SongClips4
//
//  Display and export formatting (formerly AppUtil).
//

import Foundation

enum Format {
    private static let minute = 60.0
    private static let hour = 60.0 * minute
    private static let day = 24.0 * hour

    /// Running time shown while playing: "m:ss.t" or "h:mm:ss.t". Under a minute: "12.3 secs".
    static func runningTime(_ seconds: Double) -> String {
        if seconds < minute { return duration(seconds) }
        var sec = seconds
        let h = Int(sec / hour)
        sec -= Double(h) * hour
        let m = Int(sec / minute)
        sec -= Double(m) * minute
        let wholeSec = Int(sec)
        let tenths = Int(sec * 10) % 10
        if h == 0 {
            return String(format: "%d:%02d.%01d", m, wholeSec, tenths)
        }
        return String(format: "%d:%02d:%02d.%01d", h, m, wholeSec, tenths)
    }

    /// Time code used in the text export format: "hh:mm:ss.ffff".
    static func exportDuration(_ seconds: Double) -> String {
        var sec = seconds
        let h = Int(sec / hour)
        sec -= Double(h) * hour
        let m = Int(sec / minute)
        sec -= Double(m) * minute
        let wholeSec = Int(sec)
        let fraction = Int(sec * 10000) % 10000
        return String(format: "%02d:%02d:%02d.%04d", h, m, wholeSec, fraction)
    }

    /// Human duration: "12 secs", "3.5 mins", "1.2 hours", "2 days".
    static func duration(_ seconds: Double) -> String {
        let (value, unit): (Double, String) = switch seconds {
        case ..<minute: (seconds, " secs")
        case ..<hour: (seconds / minute, " mins")
        case ..<day: (seconds / hour, " hours")
        default: (seconds / day, " days")
        }
        return number(value) + unit
    }

    /// Human byte count: "512 bytes", "1.5 KB", "3.2 MB", "1.1 GB".
    static func bytes(_ count: Double) -> String {
        let kilo = 1024.0, mega = kilo * kilo, giga = mega * kilo
        let (value, unit): (Double, String) = switch count {
        case ..<kilo: (count, " bytes")
        case ..<mega: (count / kilo, " KB")
        case ..<giga: (count / mega, " MB")
        default: (count / giga, " GB")
        }
        return number(value) + unit
    }

    /// Grouped number with one decimal place when it has a fraction.
    static func number(_ value: Double) -> String {
        let hasFraction = Double(Int64(value)) != value
        return value.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(hasFraction ? 1 : 0))
                .locale(Locale(identifier: "en_US"))
        )
    }
}

enum MediaExtension {
    static func isMovie(_ ext: String) -> Bool {
        ["m4v", "mov", "mp4", "3gp"].contains(ext)
    }

    static func isAudio(_ ext: String) -> Bool {
        ["mp3", "m4a", "wav", "aif"].contains(ext)
    }
}

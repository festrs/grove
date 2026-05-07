import Foundation
import Observation
import os

/// In-memory ring buffer of every backend request the app makes, plus
/// per-endpoint counters and a "burst" detector. Wired into `HTTPClient`'s
/// fetch/post — the entire app's network traffic flows through that one
/// chokepoint, so this captures every call without per-call-site bookkeeping.
///
/// The burst detector exists to catch runaway loops (a view that re-triggers
/// a refresh on every state change, etc.). When the same `METHOD path` fires
/// more than `burstThreshold` times within `burstWindow` seconds, a warning
/// is printed and surfaced in `NetworkInspectorView`.
@MainActor
@Observable
final class NetworkActivityLog {
    static let shared = NetworkActivityLog()

    /// `os.Logger` channel for backend traffic. Visible in Xcode's debug
    /// console and in Console.app on a physical device. Filter with
    /// `subsystem:com.felipepereira.Grove category:network`.
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.felipepereira.Grove",
        category: "network"
    )

    struct Event: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let method: String
        let path: String
        let status: Int?
        let durationMS: Int
        let success: Bool
    }

    struct EndpointStat: Identifiable, Equatable {
        var id: String { key }
        let key: String
        var total: Int = 0
        var succeeded: Int = 0
        var failed: Int = 0
        var lastStatus: Int?
        var lastTimestamp: Date = .distantPast
        var lastDurationMS: Int = 0
        var burstCount: Int = 0
    }

    private(set) var events: [Event] = []
    private(set) var stats: [String: EndpointStat] = [:]
    private(set) var burstWarnings: [String] = []

    private var timestampsByKey: [String: [Date]] = [:]
    private var lastBurstWarn: [String: Date] = [:]

    private let burstThreshold = 8
    private let burstWindow: TimeInterval = 10
    private let burstCooldown: TimeInterval = 5
    private let maxEvents = 500
    private let maxWarnings = 50

    private init() {}

    func record(method: String, path: String, status: Int?, durationMS: Int, success: Bool) {
        let now = Date()
        let key = "\(method) \(path)"

        let statusLabel = status.map(String.init) ?? "ERR"
        if success {
            Self.logger.debug("\(key, privacy: .public) → \(statusLabel, privacy: .public) in \(durationMS)ms")
        } else {
            Self.logger.error("\(key, privacy: .public) → \(statusLabel, privacy: .public) in \(durationMS)ms")
        }

        events.append(Event(
            timestamp: now,
            method: method,
            path: path,
            status: status,
            durationMS: durationMS,
            success: success
        ))
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }

        var stat = stats[key] ?? EndpointStat(key: key)
        stat.total += 1
        if success { stat.succeeded += 1 } else { stat.failed += 1 }
        stat.lastStatus = status
        stat.lastTimestamp = now
        stat.lastDurationMS = durationMS

        var ts = (timestampsByKey[key] ?? []) + [now]
        let cutoff = now.addingTimeInterval(-burstWindow)
        ts = ts.filter { $0 >= cutoff }
        if ts.count >= burstThreshold {
            let last = lastBurstWarn[key] ?? .distantPast
            if now.timeIntervalSince(last) > burstCooldown {
                let warn = "[BURST] \(key): \(ts.count) calls in \(Int(burstWindow))s"
                Self.logger.warning("\(warn, privacy: .public)")
                burstWarnings.append("\(Self.timeString(now)) \(warn)")
                if burstWarnings.count > maxWarnings {
                    burstWarnings.removeFirst(burstWarnings.count - maxWarnings)
                }
                lastBurstWarn[key] = now
                stat.burstCount += 1
            }
        }
        timestampsByKey[key] = ts
        stats[key] = stat
    }

    func reset() {
        events.removeAll()
        stats.removeAll()
        burstWarnings.removeAll()
        timestampsByKey.removeAll()
        lastBurstWarn.removeAll()
    }

    var totalCallsLastMinute: Int {
        let cutoff = Date().addingTimeInterval(-60)
        return events.reversed().prefix { $0.timestamp >= cutoff }.count
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

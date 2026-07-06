import Foundation

// MARK: - Pure-logic surface
//
// This module is intentionally free of AppKit / SwiftUI imports so it can be
// covered by XCTest on any platform. The main app vends shadow types in
// Models.swift that match these definitions — the long-term plan is to have
// the main app import this module directly, but until then both files are
// kept in lockstep.

// MARK: - Data point

public struct UsageHistoryPoint: Codable, Equatable {
    public let timestamp: Date
    public let sessionPercent: Double
    public let weeklyAllModelsPercent: Double

    public init(timestamp: Date, sessionPercent: Double, weeklyAllModelsPercent: Double) {
        self.timestamp = timestamp
        self.sessionPercent = sessionPercent
        self.weeklyAllModelsPercent = weeklyAllModelsPercent
    }
}

// MARK: - ETA prediction

public struct ETAResult: Equatable {
    public let seconds: TimeInterval
    public let formattedHours: Int
    public let formattedMinutes: Int

    public init(seconds: TimeInterval) {
        self.seconds = seconds
        self.formattedHours = Int(seconds) / 3600
        self.formattedMinutes = (Int(seconds) % 3600) / 60
    }
}

/// Estimate time-to-limit for the current 5-hour session based on burn rate.
///
/// - Returns: `nil` when prediction is unreliable (insufficient samples,
///   too little time span, flat usage, or projected ETA exceeds the session
///   reset time).
public func estimateSessionETA(
    history: [UsageHistoryPoint],
    currentPercent: Double,
    sessionResetSeconds: Int,
    now: Date = Date(),
    sessionLengthSeconds: Int = 18_000,
    minSpanSeconds: TimeInterval = 300,
    minPercentDelta: Double = 0.1
) -> ETAResult? {
    let elapsedInSession = TimeInterval(sessionLengthSeconds - sessionResetSeconds)
    guard elapsedInSession > 0 else { return nil }

    let sessionStart = now.addingTimeInterval(-elapsedInSession)
    let recent = history
        .filter { $0.timestamp >= sessionStart && $0.sessionPercent > 0 }
        .sorted { $0.timestamp < $1.timestamp }

    guard recent.count >= 2,
          let first = recent.first,
          let last = recent.last
    else { return nil }

    let deltaSec = last.timestamp.timeIntervalSince(first.timestamp)
    guard deltaSec >= minSpanSeconds else { return nil }

    let deltaPct = last.sessionPercent - first.sessionPercent
    guard deltaPct > minPercentDelta else { return nil }

    let burnRatePerSec = deltaPct / deltaSec
    let remaining = max(0, 100 - currentPercent)
    guard burnRatePerSec > 0 else { return nil }

    let etaSeconds = remaining / burnRatePerSec
    guard etaSeconds <= TimeInterval(sessionResetSeconds) else { return nil }
    return ETAResult(seconds: etaSeconds)
}

// MARK: - Sparkline bucketing

/// Computes evenly-bucketed sparkline samples for the last `span` seconds.
///
/// - Returns: empty array when there aren't enough samples to draw a
///   meaningful trend (< 2 distinct readings or total time span ≤ `minSpan`).
public func sparklineSamples(
    history: [UsageHistoryPoint],
    buckets: Int = 24,
    span: TimeInterval = 7 * 86_400,
    now: Date = Date(),
    minSpan: TimeInterval = 60
) -> [Double] {
    let start = now.addingTimeInterval(-span)
    let recent = history
        .filter { $0.timestamp >= start }
        .sorted { $0.timestamp < $1.timestamp }
    guard recent.count >= 2,
          let first = recent.first,
          let last = recent.last,
          last.timestamp.timeIntervalSince(first.timestamp) > minSpan
    else { return [] }

    var sums = [Double](repeating: 0, count: buckets)
    var counts = [Int](repeating: 0, count: buckets)
    for p in recent {
        let bucketF = p.timestamp.timeIntervalSince(start) / span * Double(buckets)
        let idx = min(buckets - 1, max(0, Int(bucketF)))
        sums[idx] += p.sessionPercent
        counts[idx] += 1
    }

    var out: [Double] = []
    out.reserveCapacity(buckets)
    var lastVal = first.sessionPercent  // seed leading empties with first known reading
    for i in 0..<buckets {
        if counts[i] > 0 {
            lastVal = sums[i] / Double(counts[i])
        }
        out.append(lastVal)
    }
    return out
}

// MARK: - Claude Code activity tiering
//
// v1.5.4 introduced a three-way state that drives the menu-bar face. The
// classification rule itself has no I/O so it lives here alongside other
// pure logic — the sub-process spawns that produce the two inputs are in
// the app target's Models.swift.

public enum ClaudeActivity: String, Equatable, CaseIterable {
    case idle
    case sleeping
    case active
}

/// Combine the two probe results into a single tier. This is intentionally
/// strict: any file-change signal wins, otherwise a live binary wins,
/// otherwise nothing.
public func classifyClaudeActivity(recentlyWorking: Bool, processAlive: Bool) -> ClaudeActivity {
    if recentlyWorking { return .active }
    if processAlive    { return .sleeping }
    return .idle
}

// MARK: - Token expiry (unit-detection)

/// Mirror of `UsageService.isCachedTokenExpired` so the regression case from
/// v1.4.2 is covered by XCTest.
///
/// Claude Code stored the OAuth token's `expiresAt` in **seconds** (10 digits)
/// historically and switched to **milliseconds** (13 digits) in newer builds.
/// The widget must work on both. Values > 1e11 are clearly milliseconds.
public func isOAuthTokenExpired(
    expiresAtRaw: Double,
    now: Date = Date(),
    bufferSeconds: TimeInterval = 30
) -> Bool {
    // Reject NaN / infinity from a corrupted credentials file. Treating them
    // as "not expired" is safer than as "expired" — the next sync will surface
    // any real auth failure via the server's 401/403 path.
    guard expiresAtRaw > 0, expiresAtRaw.isFinite else { return false }
    let expiresSec = expiresAtRaw > 1e11 ? expiresAtRaw / 1000 : expiresAtRaw
    let nowSec = now.timeIntervalSince1970
    return nowSec > (expiresSec - bufferSeconds)
}

// MARK: - Threshold validation

/// Clamp + reconcile two threshold values so `low < high` and both stay in
/// the supported sliders' ranges.
public func sanitizeThresholds(low: Int, high: Int) -> (low: Int, high: Int) {
    var l = max(50, min(95, low))
    var h = max(60, min(99, high))
    if l >= h { l = max(50, h - 10) }
    return (l, h)
}

// MARK: - Time formatting

public enum SupportedLanguage: String, CaseIterable {
    case en, ko, ja, zhCN
}

/// Format a (hours, minutes) tuple as the user-facing "Resets in …" string.
public func formatResetsIn(hours: Int, minutes: Int, lang: SupportedLanguage) -> String {
    switch lang {
    case .en:
        if hours > 0 { return "Resets in \(hours) hr \(minutes) min" }
        if minutes > 0 { return "Resets in \(minutes) min" }
        return "Resets soon"
    case .ko:
        if hours > 0 { return "\(hours)시간 \(minutes)분 후 초기화" }
        if minutes > 0 { return "\(minutes)분 후 초기화" }
        return "곧 초기화"
    case .ja:
        if hours > 0 { return "\(hours) 時間 \(minutes) 分でリセット" }
        if minutes > 0 { return "\(minutes) 分でリセット" }
        return "まもなくリセット"
    case .zhCN:
        if hours > 0 { return "\(hours) 小时 \(minutes) 分钟后重置" }
        if minutes > 0 { return "\(minutes) 分钟后重置" }
        return "即将重置"
    }
}


// MARK: - Menu bar text formatting

public enum MenuBarTextFormat: String, CaseIterable {
    case hidden, percent, time, both
}

/// Pure twin of the widget's menu-bar text logic so it can be unit-tested.
/// `percentValue` is whichever metric the user selected (session or weekly).
public func formatMenuBarText(
    format: MenuBarTextFormat,
    isConnected: Bool,
    percentValue: Double,
    resetSeconds: Int
) -> String {
    if format == .hidden { return "" }
    if !isConnected { return "--" }

    let pct = Int(percentValue)
    let hours = resetSeconds / 3600
    let minutes = (resetSeconds % 3600) / 60
    let timeStr: String = hours > 0
        ? (minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h")
        : "\(minutes)m"

    switch format {
    case .hidden:  return ""
    case .percent: return "\(pct)%"
    case .time:    return timeStr
    case .both:    return "\(pct)% · \(timeStr)"
    }
}

// MARK: - History CSV

/// Pure CSV builder — mirrors the app's export so the format is pinned by tests.
public func buildHistoryCSV(
    rows: [(timestamp: String, session: Double, weeklyAll: Double, weeklySonnet: Double?)]
) -> String {
    var lines = ["timestamp,session_percent,weekly_all_models_percent,weekly_sonnet_percent"]
    for r in rows {
        let sonnet = r.weeklySonnet.map { String($0) } ?? ""
        lines.append("\(r.timestamp),\(r.session),\(r.weeklyAll),\(sonnet)")
    }
    return lines.joined(separator: "\n") + "\n"
}

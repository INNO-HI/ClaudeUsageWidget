import XCTest
@testable import ClaudeUsageWidgetCore

final class ETAEstimationTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_returnsNil_whenHistoryEmpty() {
        let r = estimateSessionETA(history: [], currentPercent: 10, sessionResetSeconds: 14_000, now: now)
        XCTAssertNil(r)
    }

    func test_returnsNil_whenOnlyOnePoint() {
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-600), sessionPercent: 5, weeklyAllModelsPercent: 1),
        ]
        let r = estimateSessionETA(history: h, currentPercent: 10, sessionResetSeconds: 14_000, now: now)
        XCTAssertNil(r)
    }

    func test_returnsNil_whenSpanTooShort() {
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-200), sessionPercent: 5,  weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-100), sessionPercent: 10, weeklyAllModelsPercent: 1),
        ]
        let r = estimateSessionETA(history: h, currentPercent: 10, sessionResetSeconds: 14_000, now: now, minSpanSeconds: 300)
        XCTAssertNil(r)
    }

    func test_returnsETA_whenBurnRateLinear() {
        // 10% in 1800s → ETA for remaining 85% = 15,300s (4h 15m).
        // Pick sessionReset so the elapsed window includes both points AND the
        // projected ETA fits inside the remaining session.
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-1800), sessionPercent: 5,  weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now,                            sessionPercent: 15, weeklyAllModelsPercent: 1),
        ]
        let r = estimateSessionETA(history: h, currentPercent: 15, sessionResetSeconds: 16_000, now: now, sessionLengthSeconds: 18_000)
        XCTAssertNotNil(r)
        if let r = r {
            XCTAssertEqual(r.seconds, 15_300, accuracy: 1)
            XCTAssertEqual(r.formattedHours, 4)
            XCTAssertEqual(r.formattedMinutes, 15)
        }
    }

    func test_returnsNil_whenBurnIsNegative() {
        // A reset happened mid-window — last < first.
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-1800), sessionPercent: 50, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now,                            sessionPercent: 5,  weeklyAllModelsPercent: 1),
        ]
        let r = estimateSessionETA(history: h, currentPercent: 5, sessionResetSeconds: 17_999, now: now)
        XCTAssertNil(r)
    }

    func test_returnsNil_whenETAExceedsSessionReset() {
        // Very slow burn — ETA > sessionReset, should be suppressed.
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-1800), sessionPercent: 0,  weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now,                            sessionPercent: 1,  weeklyAllModelsPercent: 1),
        ]
        // 1% in 30 min → 99% remaining = 2970 min. Session reset only 600s.
        let r = estimateSessionETA(history: h, currentPercent: 1, sessionResetSeconds: 600, now: now, sessionLengthSeconds: 18_000)
        XCTAssertNil(r)
    }
}

final class SparklineSamplesTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_returnsEmpty_whenHistoryEmpty() {
        XCTAssertEqual(sparklineSamples(history: [], now: now), [])
    }

    func test_returnsEmpty_whenLessThanTwoPoints() {
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-3600), sessionPercent: 10, weeklyAllModelsPercent: 1),
        ]
        XCTAssertEqual(sparklineSamples(history: h, now: now), [])
    }

    func test_returnsEmpty_whenSpanBelowMinSpan() {
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-30), sessionPercent: 10, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now,                          sessionPercent: 20, weeklyAllModelsPercent: 1),
        ]
        XCTAssertEqual(sparklineSamples(history: h, now: now, minSpan: 60), [])
    }

    func test_returnsBucketsWithCorrectCount() {
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-7 * 86_400), sessionPercent: 10, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-3 * 86_400), sessionPercent: 50, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-86_400),     sessionPercent: 80, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now,                                  sessionPercent: 30, weeklyAllModelsPercent: 1),
        ]
        let s = sparklineSamples(history: h, buckets: 24, now: now)
        XCTAssertEqual(s.count, 24)
    }

    func test_leadingBucketsBaselineToFirstReading() {
        // First reading happens mid-window (around bucket 12). All buckets
        // before that should carry the first sample's value rather than 0.
        let h = [
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-3.5 * 86_400), sessionPercent: 42, weeklyAllModelsPercent: 1),
            UsageHistoryPoint(timestamp: now.addingTimeInterval(-100),          sessionPercent: 60, weeklyAllModelsPercent: 1),
        ]
        let s = sparklineSamples(history: h, buckets: 24, now: now)
        XCTAssertEqual(s.first, 42, "First bucket should baseline to first reading, not 0")
    }
}

final class ThresholdSanitizerTests: XCTestCase {
    func test_clampsLowAboveMin() {
        XCTAssertEqual(sanitizeThresholds(low: 30, high: 90).low, 50)
    }
    func test_clampsHighBelowMax() {
        XCTAssertEqual(sanitizeThresholds(low: 70, high: 120).high, 99)
    }
    func test_reorders_whenLowExceedsHigh() {
        let (l, h) = sanitizeThresholds(low: 90, high: 80)
        XCTAssertLessThan(l, h)
        XCTAssertEqual(h, 80)
        XCTAssertEqual(l, 70)
    }
    func test_passesThrough_whenInRange() {
        let (l, h) = sanitizeThresholds(low: 70, high: 85)
        XCTAssertEqual(l, 70)
        XCTAssertEqual(h, 85)
    }
}

final class FormatResetsInTests: XCTestCase {
    func test_englishHoursAndMinutes() {
        XCTAssertEqual(formatResetsIn(hours: 2, minutes: 30, lang: .en), "Resets in 2 hr 30 min")
    }
    func test_englishMinutesOnly() {
        XCTAssertEqual(formatResetsIn(hours: 0, minutes: 14, lang: .en), "Resets in 14 min")
    }
    func test_englishSoon() {
        XCTAssertEqual(formatResetsIn(hours: 0, minutes: 0, lang: .en), "Resets soon")
    }
    func test_korean() {
        XCTAssertEqual(formatResetsIn(hours: 1, minutes: 5, lang: .ko), "1시간 5분 후 초기화")
    }
    func test_japanese() {
        XCTAssertEqual(formatResetsIn(hours: 0, minutes: 7, lang: .ja), "7 分でリセット")
    }
    func test_chinese() {
        XCTAssertEqual(formatResetsIn(hours: 0, minutes: 0, lang: .zhCN), "即将重置")
    }
}

final class TokenExpiryTests: XCTestCase {
    // The v1.4.2 regression: code assumed expiresAt was milliseconds. If a
    // build of Claude Code stored it in seconds (10-digit Unix timestamp),
    // the comparison `nowMs > expiresAt - 30_000` would always be true and
    // every cached token would be treated as expired — re-prompting the
    // Keychain on every auto-sync. These tests pin the unit-detection
    // behaviour so it can't silently regress.

    private let now = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14

    func test_zeroExpiresAt_treatedAsNotExpired() {
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: 0, now: now))
    }

    func test_negativeExpiresAt_treatedAsNotExpired() {
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: -1, now: now))
    }

    func test_secondsFormat_inFuture_notExpired() {
        // expiresAt 1 hour ahead, in seconds (10 digits)
        let expiresAt = now.addingTimeInterval(3600).timeIntervalSince1970
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_secondsFormat_inPast_expired() {
        // expiresAt 5 min ago, seconds
        let expiresAt = now.addingTimeInterval(-300).timeIntervalSince1970
        XCTAssertTrue(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_msFormat_inFuture_notExpired() {
        // 1 hour ahead, milliseconds (13 digits)
        let expiresAt = now.addingTimeInterval(3600).timeIntervalSince1970 * 1000
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_msFormat_inPast_expired() {
        let expiresAt = now.addingTimeInterval(-300).timeIntervalSince1970 * 1000
        XCTAssertTrue(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_userActualReportedMsValue() {
        // The exact value captured from a real user (Claude Code stored ms):
        //   expiresAt=1781266616544 (13 digits)
        //   at the time of inspection now=1781240822 (seconds) → ~7 hr remaining.
        // Pre-1.4.2 ms-only check happened to work for this value; the new
        // unit-aware check must still return "not expired".
        let now = Date(timeIntervalSince1970: 1_781_240_822)
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: 1_781_266_616_544, now: now))
    }

    func test_secondsFormat_thatPre142WouldHaveCorrupted() {
        // A seconds-format token 1 hour from now: 10-digit value like 1781244422.
        // The pre-1.4.2 code did `nowMs > expiresAt - 30_000`. With
        // nowMs ≈ 1.78e12 and expiresAt ≈ 1.78e9, the comparison was always
        // true → token marked expired even though it's actually valid for 1h.
        // The new check correctly detects this is seconds and returns false.
        let now = Date(timeIntervalSince1970: 1_781_240_822)
        let expiresAtSeconds: Double = 1_781_244_422  // 1 hr ahead, in seconds
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: expiresAtSeconds, now: now))
    }

    func test_bufferRespected_secondsFormat() {
        // expiresAt is exactly 20s ahead — within the 30s buffer → expired.
        let expiresAt = now.addingTimeInterval(20).timeIntervalSince1970
        XCTAssertTrue(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_bufferRespected_msFormat() {
        let expiresAt = now.addingTimeInterval(20).timeIntervalSince1970 * 1000
        XCTAssertTrue(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now))
    }

    func test_customBuffer() {
        // 45s ahead, 60s buffer → expired; default 30s buffer → not expired.
        let expiresAt = now.addingTimeInterval(45).timeIntervalSince1970
        XCTAssertTrue(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now, bufferSeconds: 60))
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: expiresAt, now: now, bufferSeconds: 30))
    }

    func test_nan_treatedAsNotExpired() {
        // A corrupted credentials file could parse expiresAt as NaN.
        // We must not crash and must not silently treat the token as "fresh forever".
        // The chosen policy is `false` — let the server's 401/403 detect the
        // bad token and trigger a re-read rather than spam the Keychain.
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: .nan, now: now))
    }

    func test_infinity_treatedAsNotExpired() {
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: .infinity, now: now))
        XCTAssertFalse(isOAuthTokenExpired(expiresAtRaw: -.infinity, now: now))
    }
}

final class ClaudeActivityTests: XCTestCase {
    // v1.5.4 introduces a three-tier state driving the menu-bar face.
    // Precedence must hold: recent file change > binary alive > nothing.
    // These tests pin the classifier so a future refactor can't silently
    // regress it (e.g. by treating "processAlive without recent file"
    // as active again, which is exactly what v1.5.3 did wrong).

    func test_bothSignalsOff_isIdle() {
        XCTAssertEqual(classifyClaudeActivity(recentlyWorking: false, processAlive: false), .idle)
    }

    func test_onlyProcessAlive_isSleeping() {
        XCTAssertEqual(classifyClaudeActivity(recentlyWorking: false, processAlive: true), .sleeping)
    }

    func test_recentlyWorking_isActive_evenWithoutBinaryAlive() {
        // Corner case: `find` matched but pgrep didn't (Claude just exited
        // mid-tick, or a file was touched by something else). Recent file
        // activity is still the strongest signal.
        XCTAssertEqual(classifyClaudeActivity(recentlyWorking: true, processAlive: false), .active)
    }

    func test_bothSignalsOn_isActive() {
        XCTAssertEqual(classifyClaudeActivity(recentlyWorking: true, processAlive: true), .active)
    }

    func test_allCases_matchExpectedRawValues() {
        // The raw strings appear in os_log output; downstream users grep
        // for them, so they must stay stable.
        XCTAssertEqual(ClaudeActivity.idle.rawValue, "idle")
        XCTAssertEqual(ClaudeActivity.sleeping.rawValue, "sleeping")
        XCTAssertEqual(ClaudeActivity.active.rawValue, "active")
    }
}

final class UsageHistoryPointCodableTests: XCTestCase {
    func test_roundtrip() throws {
        let original = UsageHistoryPoint(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionPercent: 42.5,
            weeklyAllModelsPercent: 18.75
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(original)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(UsageHistoryPoint.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}


final class MenuBarTextTests: XCTestCase {
    func test_hidden_returnsEmpty() {
        XCTAssertEqual(formatMenuBarText(format: .hidden, isConnected: true, percentValue: 50, resetSeconds: 3600), "")
    }
    func test_disconnected_returnsDashes() {
        XCTAssertEqual(formatMenuBarText(format: .percent, isConnected: false, percentValue: 50, resetSeconds: 3600), "--")
    }
    func test_percent() {
        XCTAssertEqual(formatMenuBarText(format: .percent, isConnected: true, percentValue: 47.9, resetSeconds: 0), "47%")
    }
    func test_time_hoursAndMinutes() {
        XCTAssertEqual(formatMenuBarText(format: .time, isConnected: true, percentValue: 0, resetSeconds: 2*3600 + 13*60), "2h 13m")
    }
    func test_time_wholeHours() {
        XCTAssertEqual(formatMenuBarText(format: .time, isConnected: true, percentValue: 0, resetSeconds: 3*3600), "3h")
    }
    func test_time_minutesOnly() {
        XCTAssertEqual(formatMenuBarText(format: .time, isConnected: true, percentValue: 0, resetSeconds: 14*60), "14m")
    }
    func test_both() {
        XCTAssertEqual(formatMenuBarText(format: .both, isConnected: true, percentValue: 47, resetSeconds: 3600), "47% · 1h")
    }
}

final class HistoryCSVTests: XCTestCase {
    func test_headerRow_includesAllColumns() {
        let csv = buildHistoryCSV(rows: [])
        XCTAssertTrue(csv.hasPrefix("timestamp,session_percent,weekly_all_models_percent,weekly_sonnet_percent\n"))
    }
    func test_rowWithSonnet() {
        let csv = buildHistoryCSV(rows: [("2026-07-03T10:00:00Z", 42.5, 18.0, 3.5)])
        XCTAssertTrue(csv.contains("2026-07-03T10:00:00Z,42.5,18.0,3.5"))
    }
    func test_rowWithoutSonnet_hasEmptyLastColumn() {
        // Pre-v1.6.0 history points have no sonnet value — column must be
        // present but empty so the CSV stays rectangular.
        let csv = buildHistoryCSV(rows: [("2026-07-03T10:00:00Z", 42.5, 18.0, nil)])
        XCTAssertTrue(csv.contains("2026-07-03T10:00:00Z,42.5,18.0,\n"))
    }
    func test_trailingNewline() {
        XCTAssertTrue(buildHistoryCSV(rows: []).hasSuffix("\n"))
    }
}


final class ExtraWeeklyPoolTests: XCTestCase {
    func test_detectsFableAndMythos() {
        let keys = ["five_hour", "seven_day", "seven_day_sonnet", "seven_day_opus",
                    "seven_day_fable", "seven_day_mythos", "extra_usage"]
        XCTAssertEqual(extraWeeklyPoolSlugs(fromKeys: keys), ["fable", "mythos"])
    }
    func test_knownPoolsExcluded() {
        let keys = ["seven_day", "seven_day_sonnet", "seven_day_opus"]
        XCTAssertEqual(extraWeeklyPoolSlugs(fromKeys: keys), [])
    }
    func test_sortedOutput() {
        let keys = ["seven_day_zeta", "seven_day_alpha"]
        XCTAssertEqual(extraWeeklyPoolSlugs(fromKeys: keys), ["alpha", "zeta"])
    }
    func test_nonPoolKeysIgnored() {
        XCTAssertEqual(extraWeeklyPoolSlugs(fromKeys: ["five_hour", "extra_usage", "seven_dayish"]), [])
    }
}

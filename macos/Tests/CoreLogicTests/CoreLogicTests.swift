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

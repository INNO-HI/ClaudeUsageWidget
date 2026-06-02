import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case en = "EN"
    case ko = "KO"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        }
    }
}

// MARK: - Localized Strings

struct L {
    static var lang: AppLanguage = .en

    // Header
    static var appTitle: String { lang == .ko ? "Claude 사용량 위젯" : "Claude Usage Widget" }
    static var settings: String { lang == .ko ? "설정" : "Settings" }

    // Status
    static var checkingCredentials: String { lang == .ko ? "인증 정보 확인 중..." : "Checking credentials..." }
    static var connectedOAuth: String { lang == .ko ? "OAuth 연결됨" : "Connected via OAuth" }
    static var notLoggedIn: String { lang == .ko ? "Claude Code 로그인 필요" : "Claude Code not logged in" }

    // Settings
    static var credentials: String { lang == .ko ? "인증 정보" : "Credentials" }
    static var autoDetected: String { lang == .ko ? "키체인에서 자동 감지됨" : "Auto-detected from Keychain" }
    static var notFound: String { lang == .ko ? "찾을 수 없음" : "Not found" }
    static var refresh: String { lang == .ko ? "새로고침" : "Refresh" }
    static var toFixThis: String { lang == .ko ? "해결 방법:" : "To fix this:" }
    static var step1Terminal: String { lang == .ko ? "1. 터미널 열기" : "1. Open Terminal" }
    static var step2Login: String { lang == .ko ? "2. 실행: claude login" : "2. Run: claude login" }
    static var step3Refresh: String { lang == .ko ? "3. 위의 새로고침 클릭" : "3. Click Refresh above" }
    static var keepOnTop: String { lang == .ko ? "항상 위에 표시" : "Keep on Top" }
    static var launchAtLogin: String { lang == .ko ? "로그인 시 자동 시작" : "Launch at Login" }
    static var menuBarFormat: String { lang == .ko ? "메뉴바 표시" : "Menu bar text" }
    static var sevenDayTrend: String { lang == .ko ? "최근 7일 흐름" : "7-day trend" }
    static var loadingData: String { lang == .ko ? "데이터 불러오는 중..." : "Loading data..." }
    static var noTrendYet: String { lang == .ko ? "데이터가 더 쌓이면 트렌드가 표시됩니다" : "Trend will appear as data accumulates" }
    static var checkForUpdates: String { lang == .ko ? "업데이트 확인" : "Check for Updates" }
    static var openTerminal: String { lang == .ko ? "터미널 열기" : "Open Terminal" }
    static var sectionGeneral: String { lang == .ko ? "일반" : "General" }
    static var sectionNotifications: String { lang == .ko ? "알림" : "Notifications" }
    static var sectionUpdates: String { lang == .ko ? "업데이트" : "Updates" }
    static var sectionAccount: String { lang == .ko ? "계정" : "Account" }
    static var enableNotifications: String { lang == .ko ? "사용량 알림 (80% / 90%)" : "Usage Alerts (80% / 90%)" }
    static var showBuddy: String { lang == .ko ? "버디 표시" : "Show Buddy" }
    static var compactMode: String { lang == .ko ? "컴팩트 모드" : "Compact mode" }

    // Onboarding
    static var welcomeTitle: String { lang == .ko ? "Claude Usage Widget에 오신 것을 환영합니다" : "Welcome to Claude Usage Widget" }
    static var welcomeBody1: String { lang == .ko ? "메뉴바에서 Claude Code 사용량을 실시간으로 확인하세요. Claude에 메시지를 보내지 않아 토큰 비용은 0입니다." : "Track your Claude Code usage in real time from the menu bar. No messages are sent to Claude — zero token cost." }
    static var welcomeStep1: String { lang == .ko ? "터미널에서 'claude login' 실행이 필요합니다" : "Run 'claude login' in Terminal first" }
    static var welcomeStep2: String { lang == .ko ? "위젯이 ~/.claude/.credentials.json을 자동 감지합니다" : "The widget auto-detects ~/.claude/.credentials.json" }
    static var welcomeStep3: String { lang == .ko ? "옵션에서 자동 시작·알림·자동 업데이트 설정 가능" : "Auto-start, alerts, and auto-update can be enabled in Settings" }
    static var getStarted: String { lang == .ko ? "시작하기" : "Get Started" }
    static var alertTitle: String { lang == .ko ? "Claude 사용량 알림" : "Claude Usage Alert" }
    static func alertSession(percent: Int) -> String {
        lang == .ko
            ? "5시간 세션의 \(percent)%를 사용했습니다"
            : "You've used \(percent)% of your 5-hour session"
    }
    static var language: String { lang == .ko ? "언어" : "Language" }

    // Current Session
    static var currentSession: String { lang == .ko ? "현재 세션" : "Current session" }
    static func resetsIn(hours: Int, minutes: Int) -> String {
        if lang == .ko {
            if hours > 0 { return "\(hours)시간 \(minutes)분 후 초기화" }
            if minutes > 0 { return "\(minutes)분 후 초기화" }
            return "곧 초기화"
        } else {
            if hours > 0 { return "Resets in \(hours) hr \(minutes) min" }
            if minutes > 0 { return "Resets in \(minutes) min" }
            return "Resets soon"
        }
    }

    // Weekly Limits
    static var weeklyLimits: String { lang == .ko ? "주간 사용량" : "Weekly limits" }
    static var learnMore: String { lang == .ko ? "사용량 제한 자세히 알아보기" : "Learn more about usage limits" }
    static var allModels: String { lang == .ko ? "전체 모델" : "All models" }
    static var sonnetOnly: String { lang == .ko ? "Sonnet 전용" : "Sonnet only" }
    static func resetsAt(_ date: String) -> String {
        lang == .ko ? "\(date)에 초기화" : "Resets \(date)"
    }

    // Auto Sync
    static var autoSync: String { lang == .ko ? "자동 동기화" : "Auto-sync" }
    static var syncNote: String { lang == .ko ? "참고: API 속도 제한 있음. 최소 5분 권장." : "Note: API has rate limits. Minimum 5min recommended." }

    // Footer
    static var sync: String { lang == .ko ? "동기화" : "sync" }
    static var quit: String { lang == .ko ? "종료" : "quit" }
    static var never: String { lang == .ko ? "동기화 안됨" : "never" }
    static func lastSync(_ time: String) -> String {
        lang == .ko ? "마지막 동기화 \(time)" : "last sync \(time)"
    }
}

import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case en = "EN"
    case ko = "KO"
    case ja = "JA"
    case zhCN = "ZH"

    var displayName: String {
        switch self {
        case .en:   return "English"
        case .ko:   return "한국어"
        case .ja:   return "日本語"
        case .zhCN: return "中文"
        }
    }
}

// MARK: - Localized Strings

struct L {
    static var lang: AppLanguage = .en

    /// 4-way string picker. Falls back to English when a translation is omitted.
    private static func t(_ en: String, ko: String? = nil, ja: String? = nil, zh: String? = nil) -> String {
        switch lang {
        case .en:   return en
        case .ko:   return ko ?? en
        case .ja:   return ja ?? en
        case .zhCN: return zh ?? en
        }
    }

    // Header
    static var appTitle: String { t("Claude Usage Widget", ko: "Claude 사용량 위젯", ja: "Claude 使用量ウィジェット", zh: "Claude 用量小工具") }
    static var settings: String { t("Settings", ko: "설정", ja: "設定", zh: "设置") }

    // Status
    static var checkingCredentials: String { t("Checking credentials...", ko: "인증 정보 확인 중...", ja: "認証情報を確認中...", zh: "正在检查凭证...") }
    static var connectedOAuth: String { t("Connected via OAuth", ko: "OAuth 연결됨", ja: "OAuth で接続済み", zh: "已通过 OAuth 连接") }
    static var notLoggedIn: String { t("Claude Code not logged in", ko: "Claude Code 로그인 필요", ja: "Claude Code にログインしていません", zh: "未登录 Claude Code") }

    // Settings
    static var credentials: String { t("Credentials", ko: "인증 정보", ja: "認証情報", zh: "凭证") }
    static var autoDetected: String { t("Auto-detected from Keychain", ko: "키체인에서 자동 감지됨", ja: "キーチェーンから自動検出", zh: "已从钥匙串自动检测") }
    static var credentialPath: String { t("Credentials file", ko: "인증 파일", ja: "認証ファイル", zh: "凭证文件") }
    static var customPath: String { t("Custom…", ko: "직접 지정…", ja: "カスタム…", zh: "自定义…") }
    static var defaultPath: String { t("Default", ko: "기본", ja: "デフォルト", zh: "默认") }
    static var clearOverride: String { t("Reset to default", ko: "기본으로 복원", ja: "デフォルトに戻す", zh: "恢复默认") }
    static var notFound: String { t("Not found", ko: "찾을 수 없음", ja: "見つかりません", zh: "未找到") }
    static var refresh: String { t("Refresh", ko: "새로고침", ja: "再読み込み", zh: "刷新") }
    static var toFixThis: String { t("To fix this:", ko: "해결 방법:", ja: "解決方法:", zh: "解决方法:") }
    static var step1Terminal: String { t("1. Open Terminal", ko: "1. 터미널 열기", ja: "1. ターミナルを開く", zh: "1. 打开终端") }
    static var step2Login: String { t("2. Run: claude login", ko: "2. 실행: claude login", ja: "2. 実行: claude login", zh: "2. 运行: claude login") }
    static var step3Refresh: String { t("3. Click Refresh above", ko: "3. 위의 새로고침 클릭", ja: "3. 上の再読み込みをクリック", zh: "3. 点击上方刷新") }
    static var keepOnTop: String { t("Keep on Top", ko: "항상 위에 표시", ja: "常に手前に表示", zh: "保持在顶部") }
    static var launchAtLogin: String { t("Launch at Login", ko: "로그인 시 자동 시작", ja: "ログイン時に起動", zh: "登录时启动") }
    static var menuBarFormat: String { t("Menu bar text", ko: "메뉴바 표시", ja: "メニューバー表示", zh: "菜单栏文字") }
    static var sevenDayTrend: String { t("7-day trend", ko: "최근 7일 흐름", ja: "直近 7 日間の推移", zh: "最近 7 天趋势") }
    static var loadingData: String { t("Loading data...", ko: "데이터 불러오는 중...", ja: "データを読み込み中...", zh: "正在加载数据...") }
    static var noTrendYet: String { t("Trend will appear as data accumulates", ko: "데이터가 더 쌓이면 트렌드가 표시됩니다", ja: "データが集まると推移が表示されます", zh: "积累更多数据后将显示趋势") }
    static var checkForUpdates: String { t("Check for Updates", ko: "업데이트 확인", ja: "アップデートを確認", zh: "检查更新") }
    static var sectionData: String { t("Data", ko: "데이터", ja: "データ", zh: "数据") }
    static var exportCSV: String { t("Export CSV", ko: "CSV로 내보내기", ja: "CSV エクスポート", zh: "导出 CSV") }
    static var exportJSON: String { t("Export JSON", ko: "JSON으로 내보내기", ja: "JSON エクスポート", zh: "导出 JSON") }
    static var clearHistory: String { t("Clear history", ko: "기록 삭제", ja: "履歴を削除", zh: "清除历史") }
    static var copySummary: String { t("Copy summary", ko: "요약 복사", ja: "概要をコピー", zh: "复制摘要") }
    static var copiedSummary: String { t("Copied!", ko: "복사됨!", ja: "コピーしました!", zh: "已复制!") }
    static var menuBarMetric: String { t("Menu bar metric", ko: "메뉴바 지표", ja: "メニューバー指標", zh: "菜单栏指标") }
    static var metricSession: String { t("Session", ko: "세션", ja: "セッション", zh: "会话") }
    static var metricWeekly: String { t("Weekly", ko: "주간", ja: "週間", zh: "每周") }
    static var syncManual: String { t("manual", ko: "수동", ja: "手動", zh: "手动") }
    static var clearHistoryConfirm: String { t("Delete all usage history?", ko: "모든 사용량 기록을 삭제하시겠습니까?", ja: "すべての使用履歴を削除しますか?", zh: "确定要删除所有用量历史?") }
    static var deleteAction: String { t("Delete", ko: "삭제", ja: "削除", zh: "删除") }
    static var cancelAction: String { t("Cancel", ko: "취소", ja: "キャンセル", zh: "取消") }
    static func historyCount(_ count: Int) -> String {
        switch lang {
        case .en:   return "\(count) data points"
        case .ko:   return "\(count)건 기록"
        case .ja:   return "\(count) 件のデータ"
        case .zhCN: return "\(count) 条数据"
        }
    }
    static var openTerminal: String { t("Open Terminal", ko: "터미널 열기", ja: "ターミナルを開く", zh: "打开终端") }
    static var sectionGeneral: String { t("General", ko: "일반", ja: "一般", zh: "通用") }
    static var sectionNotifications: String { t("Notifications", ko: "알림", ja: "通知", zh: "通知") }
    static var sectionUpdates: String { t("Updates", ko: "업데이트", ja: "アップデート", zh: "更新") }
    static var sectionAccount: String { t("Account", ko: "계정", ja: "アカウント", zh: "账户") }
    static var enableNotifications: String { t("Usage Alerts", ko: "사용량 알림", ja: "使用量アラート", zh: "用量提醒") }
    static var alertThresholds: String { t("Alert thresholds", ko: "알림 임계치", ja: "アラートしきい値", zh: "提醒阈值") }
    static func thresholdLabel(low: Int, high: Int) -> String {
        "\(low)% · \(high)%"
    }
    static var alertLow: String { t("1st alert", ko: "1차 알림", ja: "1次アラート", zh: "首次提醒") }
    static var alertHigh: String { t("2nd alert", ko: "2차 알림", ja: "2次アラート", zh: "次级提醒") }
    static var showBuddy: String { t("Show Buddy", ko: "버디 표시", ja: "バディを表示", zh: "显示伙伴") }
    static var compactMode: String { t("Compact mode", ko: "컴팩트 모드", ja: "コンパクトモード", zh: "紧凑模式") }
    static var menuBarExpressions: String { t("Animated menu-bar face", ko: "메뉴바 표정 애니메이션", ja: "メニューバーの表情アニメ", zh: "菜单栏表情动画") }

    // Onboarding
    static var welcomeTitle: String { t("Welcome to Claude Usage Widget", ko: "Claude Usage Widget에 오신 것을 환영합니다", ja: "Claude Usage Widget へようこそ", zh: "欢迎使用 Claude Usage Widget") }
    static var welcomeBody1: String { t("Track your Claude Code usage in real time from the menu bar. No messages are sent to Claude — zero token cost.", ko: "메뉴바에서 Claude Code 사용량을 실시간으로 확인하세요. Claude에 메시지를 보내지 않아 토큰 비용은 0입니다.", ja: "メニューバーから Claude Code の使用量をリアルタイムで確認できます。Claude にメッセージを送信しないためトークン費用は 0 です。", zh: "在菜单栏中实时追踪 Claude Code 用量。不会向 Claude 发送任何消息 — 零 token 成本。") }
    static var welcomeStep1: String { t("Run 'claude login' in Terminal first", ko: "터미널에서 'claude login' 실행이 필요합니다", ja: "ターミナルで 'claude login' を実行してください", zh: "请先在终端中运行 'claude login'") }
    static var welcomeStep2: String { t("The widget auto-detects ~/.claude/.credentials.json", ko: "위젯이 ~/.claude/.credentials.json을 자동 감지합니다", ja: "ウィジェットが ~/.claude/.credentials.json を自動検出します", zh: "小工具会自动检测 ~/.claude/.credentials.json") }
    static var welcomeStep3: String { t("Auto-start, alerts, and auto-update can be enabled in Settings", ko: "옵션에서 자동 시작·알림·자동 업데이트 설정 가능", ja: "自動起動・アラート・自動アップデートは設定で有効化できます", zh: "可在设置中启用自动启动、提醒和自动更新") }
    static var getStarted: String { t("Get Started", ko: "시작하기", ja: "はじめる", zh: "开始") }
    static var nextStep: String { t("Next", ko: "다음", ja: "次へ", zh: "下一步") }
    static var backStep: String { t("Back", ko: "이전", ja: "戻る", zh: "上一步") }
    static var skipStep: String { t("Skip", ko: "건너뛰기", ja: "スキップ", zh: "跳过") }
    static var pageOfPages: String { t("Step", ko: "단계", ja: "ステップ", zh: "步骤") }
    static var loginPageTitle: String { t("Confirm Claude Code login", ko: "Claude Code 로그인 확인", ja: "Claude Code のログインを確認", zh: "确认 Claude Code 登录") }
    static var loginPageBody: String { t("Just one command in Terminal. The widget will auto-detect your login.", ko: "터미널에 한 줄만 입력하면 끝납니다. 위젯이 자동으로 인증을 감지합니다.", ja: "ターミナルで 1 行入力するだけです。ウィジェットが自動的に認証を検出します。", zh: "在终端中输入一行命令即可。小工具会自动检测您的登录状态。") }
    static var loginPageCopy: String { t("Copy command", ko: "명령 복사", ja: "コマンドをコピー", zh: "复制命令") }
    static var copied: String { t("Copied!", ko: "복사됨!", ja: "コピーしました!", zh: "已复制!") }
    static var notifPageTitle: String { t("Get notified before you run out", ko: "알림 받으시겠어요?", ja: "上限前に通知を受け取りますか?", zh: "在用尽前接收通知?") }
    static var notifPageBody: String { t("We'll send a macOS notification as you approach your limit. You can turn it off anytime in Settings.", ko: "한도에 가까워지면 macOS 알림으로 알려드릴게요. 나중에 설정에서 끌 수 있습니다.", ja: "上限に近づくと macOS の通知でお知らせします。設定からいつでもオフにできます。", zh: "接近上限时会发送 macOS 通知。可随时在设置中关闭。") }
    static var notifPageEnable: String { t("Enable alerts", ko: "알림 켜기", ja: "アラートを有効化", zh: "启用提醒") }
    static var notifPageSkip: String { t("Maybe later", ko: "나중에", ja: "あとで", zh: "稍后") }

    static var alertTitle: String { t("Claude Usage Alert", ko: "Claude 사용량 알림", ja: "Claude 使用量アラート", zh: "Claude 用量提醒") }
    static var newSessionTitle: String { t("New session started", ko: "새 세션 시작", ja: "新しいセッション開始", zh: "新会话已开始") }
    static var newSessionBody: String { t("Your 5-hour usage window has reset.", ko: "5시간 사용량 창이 초기화되었습니다.", ja: "5 時間の使用枠がリセットされました。", zh: "您的 5 小时用量窗口已重置。") }
    static var notifyNewSession: String { t("Notify when session resets", ko: "세션 초기화 시 알림", ja: "セッションリセット時に通知", zh: "会话重置时通知") }
    static func alertSession(percent: Int) -> String {
        switch lang {
        case .en:   return "You've used \(percent)% of your 5-hour session"
        case .ko:   return "5시간 세션의 \(percent)%를 사용했습니다"
        case .ja:   return "5 時間セッションの \(percent)% を使用しました"
        case .zhCN: return "您已使用 5 小时会话的 \(percent)%"
        }
    }
    static var language: String { t("Language", ko: "언어", ja: "言語", zh: "语言") }

    // Current Session
    static var currentSession: String { t("Current session", ko: "현재 세션", ja: "現在のセッション", zh: "当前会话") }
    static func resetsIn(hours: Int, minutes: Int) -> String {
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

    // Weekly Limits
    static var weeklyLimits: String { t("Weekly limits", ko: "주간 사용량", ja: "週間使用量", zh: "周用量") }
    static var learnMore: String { t("Learn more about usage limits", ko: "사용량 제한 자세히 알아보기", ja: "使用量制限の詳細", zh: "了解用量限制") }
    static var allModels: String { t("All models", ko: "전체 모델", ja: "全モデル", zh: "全部模型") }
    static var sonnetOnly: String { t("Sonnet only", ko: "Sonnet 전용", ja: "Sonnet のみ", zh: "仅 Sonnet") }
    static var opusOnly: String { t("Opus only", ko: "Opus 전용", ja: "Opus のみ", zh: "仅 Opus") }
    static var extraUsageOn: String { t("Extra usage on", ko: "추가 사용 켜짐", ja: "追加使用オン", zh: "已启用额外用量") }
    static func resetsAt(_ date: String) -> String {
        switch lang {
        case .en:   return "Resets \(date)"
        case .ko:   return "\(date)에 초기화"
        case .ja:   return "\(date) にリセット"
        case .zhCN: return "于 \(date) 重置"
        }
    }

    // Auto Sync
    static var autoSync: String { t("Auto-sync", ko: "자동 동기화", ja: "自動同期", zh: "自动同步") }
    static var syncNote: String { t("Note: API has rate limits. Minimum 5min recommended.", ko: "참고: API 속도 제한 있음. 최소 5분 권장.", ja: "注: API には制限があります。最小 5 分を推奨。", zh: "注意: API 有速率限制,建议至少 5 分钟。") }

    // Footer
    static var sync: String { t("sync", ko: "동기화", ja: "同期", zh: "同步") }
    static var quit: String { t("quit", ko: "종료", ja: "終了", zh: "退出") }
    static var never: String { t("never", ko: "동기화 안됨", ja: "未同期", zh: "尚未同步") }
    static func lastSync(_ time: String) -> String {
        switch lang {
        case .en:   return "last sync \(time)"
        case .ko:   return "마지막 동기화 \(time)"
        case .ja:   return "最終同期 \(time)"
        case .zhCN: return "上次同步 \(time)"
        }
    }

    // Error banners
    static var errorCredentialsTitle: String { t("Claude Code login required", ko: "Claude Code 로그인이 필요합니다", ja: "Claude Code のログインが必要です", zh: "需要登录 Claude Code") }
    static var errorCredentialsBody: String { t("Run 'claude login' in Terminal, then refresh.", ko: "터미널에서 'claude login' 한 줄을 실행한 뒤 새로고침해주세요.", ja: "ターミナルで 'claude login' を実行してから再読み込みしてください。", zh: "请在终端中运行 'claude login' 后刷新。") }
    static var errorRateTitle: String { t("Rate-limited — backing off", ko: "잠시 후 다시 시도합니다", ja: "レート制限中 — 自動的に再試行します", zh: "已达速率限制 — 将自动重试") }
    static var errorRateBody: String { t("API limit reached. We'll retry with longer intervals automatically.", ko: "API 호출이 너무 잦았어요. 자동으로 간격을 늘려 재시도합니다.", ja: "API の上限に達しました。間隔を伸ばして自動的に再試行します。", zh: "已达到 API 上限。将以更长间隔自动重试。") }
    static var errorNetworkTitle: String { t("Can't reach the network", ko: "네트워크에 닿을 수 없습니다", ja: "ネットワークに接続できません", zh: "无法连接网络") }
    static var errorNetworkBody: String { t("Check your internet connection and try again.", ko: "인터넷 연결을 확인하고 다시 시도해주세요.", ja: "インターネット接続を確認してから再試行してください。", zh: "请检查网络连接后重试。") }
    static var errorServerTitle: String { t("Server isn't responding", ko: "서버가 응답하지 않습니다", ja: "サーバーが応答しません", zh: "服务器无响应") }
    static var errorServerBody: String { t("Likely an Anthropic-side issue. Try again in a moment.", ko: "Anthropic 서버 측 문제일 수 있어요. 잠시 후 다시 시도해보세요.", ja: "Anthropic 側の問題の可能性があります。しばらくしてから再試行してください。", zh: "可能是 Anthropic 服务端问题,请稍后重试。") }
    static var errorUnknownTitle: String { t("Something went wrong", ko: "알 수 없는 오류", ja: "不明なエラー", zh: "出现错误") }
    static var retryNow: String { t("Retry now", ko: "다시 시도", ja: "再試行", zh: "立即重试") }
    static var tooltipClaudeActive: String { t("● Claude Code — active", ko: "● Claude Code — 작업 중", ja: "● Claude Code — 動作中", zh: "● Claude Code — 运行中") }
    static var tooltipClaudeSleeping: String { t("· Claude Code — sleeping", ko: "· Claude Code — 대기 중", ja: "· Claude Code — スリープ", zh: "· Claude Code — 休眠") }
    // Buddy strings that were hardcoded in BuddyViews
    static var hatchPrompt: String { t("Hatch your buddy!", ko: "버디를 부화시키세요!", ja: "バディを孵化させよう!", zh: "孵化你的伙伴!") }
    static var hatching: String { t("Hatching...", ko: "부화 중...", ja: "孵化中...", zh: "孵化中...") }
    static var petBuddy: String { t("Pet buddy", ko: "버디 쓰다듬기", ja: "バディをなでる", zh: "抚摸伙伴") }
    static var feedBuddy: String { t("Feed buddy", ko: "버디 밥 주기", ja: "バディに餌をやる", zh: "喂养伙伴") }
    static func buddyMood(_ mood: Int) -> String {
        switch lang {
        case .en:   return "Mood \(mood) of 5"
        case .ko:   return "기분 \(mood)/5"
        case .ja:   return "気分 \(mood)/5"
        case .zhCN: return "心情 \(mood)/5"
        }
    }
    static var dismissError: String { t("Dismiss", ko: "닫기", ja: "閉じる", zh: "关闭") }
}

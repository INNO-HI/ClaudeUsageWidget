import Foundation
import Combine
import ServiceManagement
import UserNotifications
import os.log

/// Unified-logging channel for Claude Code activity detection. Stream with:
///   log stream --predicate 'subsystem == "com.innohi.claudeusagewidget" AND category == "activity"' --style compact
private let activityLog = OSLog(subsystem: "com.innohi.claudeusagewidget", category: "activity")

/// Unified-logging channel for the sync scheduler (was NSLog).
private let syncLog = OSLog(subsystem: "com.innohi.claudeusagewidget", category: "sync")

// MARK: - Cached formatters
//
// DateFormatter / ISO8601DateFormatter construction is expensive (~ms each).
// These were being rebuilt on every call site — every sync tick, every mood
// decay, every footer re-render. Cache once; all uses are main-thread or
// read-only after init.
enum CachedFormatters {
    /// "h:mm a" — footer last-sync stamp.
    static let hourMinute: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    /// "yyyy-MM-dd" — buddy feed day tracking.
    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    /// ISO8601 with fractional seconds — history persistence.
    static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()
}

// MARK: - Data Models

struct UsageData {
    var sessionUsagePercent: Double = 0
    var sessionResetSeconds: Int = 0
    var weeklyAllModelsPercent: Double = 0
    var weeklyAllModelsResetDate: String = ""
    var weeklySonnetPercent: Double = 0
    /// seven_day_opus utilization — only present on plans with an Opus pool.
    var weeklyOpusPercent: Double = 0
    var hasOpusLimit: Bool = false
    /// extra_usage.is_enabled — pay-per-use overflow is switched on.
    var extraUsageEnabled: Bool = false
    var lastSyncTime: Date? = nil
    var isConnected: Bool = false
    var planName: String = "Max"
}

// MARK: - Menu Bar Format

enum MenuBarFormat: String, CaseIterable {
    case hidden    // icon only
    case percent   // "47%"
    case time      // "2h 13m"
    case both      // "47% · 2h"

    var displayName: String {
        switch (L.lang, self) {
        case (.ko, .hidden):   return "숨김"
        case (.ko, .time):     return "시간"
        case (.ko, .both):     return "%·시간"
        case (.ja, .hidden):   return "オフ"
        case (.ja, .time):     return "時間"
        case (.ja, .both):     return "%·時間"
        case (.zhCN, .hidden): return "关闭"
        case (.zhCN, .time):   return "时间"
        case (.zhCN, .both):   return "%·时间"
        case (_, .hidden):     return "Off"
        case (_, .time):       return "Time"
        case (_, .both):       return "Both"
        case (_, .percent):    return "%"
        }
    }
}

// MARK: - Usage History Point

struct UsageHistoryPoint: Codable {
    let timestamp: Date
    let sessionPercent: Double
    let weeklyAllModelsPercent: Double
    /// Added in v1.6.0 — optional so pre-existing history files still decode.
    var weeklySonnetPercent: Double?
}

// MARK: - Sync Interval

enum SyncInterval: String, CaseIterable {
    case manual = "manual"
    case min1 = "1m"
    case min5 = "5m"
    case min10 = "10m"
    case min30 = "30m"
    case hour1 = "1h"

    var seconds: Double? {
        switch self {
        case .manual: return nil
        case .min1: return 60
        case .min5: return 300
        case .min10: return 600
        case .min30: return 1800
        case .hour1: return 3600
        }
    }
}

// MARK: - Buddy State

enum BuddyState: String {
    case off        // Not hatched yet / sleeping
    case egg        // Hatching animation
    case idle       // Normal standing
    case happy      // Just petted
    case working    // Syncing data
    case sleepy     // Going to sleep
}

// MARK: - Buddy Species

enum BuddySpecies: String, CaseIterable {
    case axolotl, blob, cactus, capybara, cat, chonk, dragon, duck
    case ghost, goose, mushroom, octopus, owl, penguin, rabbit, robot, snail, turtle

    var emoji: String {
        switch self {
        case .axolotl:  return "\u{1F98E}"  // lizard
        case .blob:     return "\u{1FAE7}"  // bubbles
        case .cactus:   return "\u{1F335}"
        case .capybara: return "\u{1F9AB}"  // beaver
        case .cat:      return "\u{1F431}"
        case .chonk:    return "\u{1F408}"
        case .dragon:   return "\u{1F409}"
        case .duck:     return "\u{1F986}"
        case .ghost:    return "\u{1F47B}"
        case .goose:    return "\u{1FABF}"
        case .mushroom: return "\u{1F344}"
        case .octopus:  return "\u{1F419}"
        case .owl:      return "\u{1F989}"
        case .penguin:  return "\u{1F427}"
        case .rabbit:   return "\u{1F430}"
        case .robot:    return "\u{1F916}"
        case .snail:    return "\u{1F40C}"
        case .turtle:   return "\u{1F422}"
        }
    }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

// MARK: - Buddy Rarity

enum BuddyRarity: String {
    case common, uncommon, rare, epic, legendary

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Minimum total stat points for this rarity
    var statRange: (min: Int, max: Int) {
        switch self {
        case .common:    return (15, 25)
        case .uncommon:  return (22, 32)
        case .rare:      return (28, 38)
        case .epic:      return (34, 44)
        case .legendary: return (40, 50)
        }
    }
}

// MARK: - Buddy Hat

enum BuddyHat: String, CaseIterable {
    case none, crown, tophat, propeller, halo, wizard, beanie, tinyduck

    var emoji: String {
        switch self {
        case .none:      return ""
        case .crown:     return "\u{1F451}"
        case .tophat:    return "\u{1F3A9}"
        case .propeller: return "\u{1FA81}"  // kite as propeller
        case .halo:      return "\u{1F607}"
        case .wizard:    return "\u{1F9D9}"
        case .beanie:    return "\u{1F9E2}"
        case .tinyduck:  return "\u{1F425}"
        }
    }

    /// Minimum rarity to unlock this hat
    static func availableHats(for rarity: BuddyRarity) -> [BuddyHat] {
        switch rarity {
        case .common:    return [.none, .beanie]
        case .uncommon:  return [.none, .beanie, .propeller]
        case .rare:      return [.none, .beanie, .propeller, .tophat, .halo]
        case .epic:      return [.none, .beanie, .propeller, .tophat, .halo, .wizard, .crown]
        case .legendary: return BuddyHat.allCases
        }
    }
}

// MARK: - Buddy Stats

struct BuddyStats {
    var debugging: Int  // 1-10
    var patience: Int
    var chaos: Int
    var wisdom: Int
    var snark: Int

    var total: Int { debugging + patience + chaos + wisdom + snark }

    static var statNames: [String] {
        switch L.lang {
        case .ko:   return ["디버깅", "인내심", "혼돈", "지혜", "독설"]
        case .ja:   return ["デバッグ", "忍耐", "カオス", "知恵", "毒舌"]
        case .zhCN: return ["调试", "耐心", "混沌", "智慧", "毒舌"]
        case .en:   return ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]
        }
    }

    var asArray: [Int] { [debugging, patience, chaos, wisdom, snark] }
}

// MARK: - Buddy Spec (Full deterministic buddy)

struct BuddySpec {
    var species: BuddySpecies
    var rarity: BuddyRarity
    var isShiny: Bool
    var eyes: String
    var hat: BuddyHat
    var stats: BuddyStats
    var name: String
}

// MARK: - Mulberry32 PRNG

struct Mulberry32 {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed
    }

    mutating func next() -> UInt32 {
        state &+= 0x6D2B79F5
        var z = state
        z = (z ^ (z >> 15)) &* (z | 1)
        z ^= z &+ (z ^ (z >> 7)) &* (z | 61)
        return z ^ (z >> 14)
    }

    /// Returns a float in [0, 1)
    mutating func nextFloat() -> Double {
        return Double(next()) / Double(UInt32.max)
    }

    /// Returns an integer in [0, max)
    mutating func nextInt(max: Int) -> Int {
        guard max > 0 else { return 0 }
        return Int(nextFloat() * Double(max))
    }
}

// MARK: - Buddy Generation

func hashStringToSeed(_ input: String) -> UInt32 {
    // Simple djb2 hash
    var hash: UInt32 = 5381
    for char in input.utf8 {
        hash = ((hash << 5) &+ hash) &+ UInt32(char)
    }
    return hash
}

func generateBuddy(userId: String) -> BuddySpec {
    let seedString = userId + "friend-2026-401"
    let seed = hashStringToSeed(seedString)
    var rng = Mulberry32(seed: seed)

    // Species (uniform across 18)
    let speciesIndex = rng.nextInt(max: BuddySpecies.allCases.count)
    let species = BuddySpecies.allCases[speciesIndex]

    // Rarity: Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 1%
    let rarityRoll = rng.nextFloat() * 100.0
    let rarity: BuddyRarity
    if rarityRoll < 1.0 {
        rarity = .legendary
    } else if rarityRoll < 5.0 {
        rarity = .epic
    } else if rarityRoll < 15.0 {
        rarity = .rare
    } else if rarityRoll < 40.0 {
        rarity = .uncommon
    } else {
        rarity = .common
    }

    // Shiny: 1% chance
    let isShiny = rng.nextFloat() < 0.01

    // Eyes (6 styles)
    let eyeStyles = ["\u{00B7}", "\u{2726}", "\u{00D7}", "\u{25C9}", "@", "\u{00B0}"]
    let eyeIndex = rng.nextInt(max: eyeStyles.count)
    let eyes = eyeStyles[eyeIndex]

    // Hat (based on rarity)
    let availableHats = BuddyHat.availableHats(for: rarity)
    let hatIndex = rng.nextInt(max: availableHats.count)
    let hat = availableHats[hatIndex]

    // Stats: 5 stats, 1-10 each, total in rarity range
    let (minTotal, maxTotal) = rarity.statRange
    let targetTotal = minTotal + rng.nextInt(max: maxTotal - minTotal + 1)

    // Distribute points
    var rawStats = [1, 1, 1, 1, 1]  // minimum 1 each
    let remaining = targetTotal - 5
    for _ in 0..<remaining {
        let idx = rng.nextInt(max: 5)
        if rawStats[idx] < 10 {
            rawStats[idx] += 1
        } else {
            // Find another stat to increment
            for j in 0..<5 {
                let k = (idx + j) % 5
                if rawStats[k] < 10 {
                    rawStats[k] += 1
                    break
                }
            }
        }
    }

    let stats = BuddyStats(
        debugging: rawStats[0],
        patience: rawStats[1],
        chaos: rawStats[2],
        wisdom: rawStats[3],
        snark: rawStats[4]
    )

    // Name: combine adjective + noun deterministically
    let adjectives = [
        "Tiny", "Brave", "Fuzzy", "Clever", "Sleepy", "Sneaky", "Jolly", "Mighty",
        "Cosmic", "Wiggly", "Sparkle", "Turbo", "Pixel", "Glitch", "Zen", "Hyper",
        "Chill", "Bouncy", "Mystic", "Crispy", "Noodle", "Wobble", "Zippy", "Cozy"
    ]
    let nouns = [
        "Byte", "Bean", "Puff", "Sprout", "Chip", "Mochi", "Pip", "Dot",
        "Boop", "Flop", "Nugget", "Twig", "Blip", "Fuzz", "Squish", "Snoot",
        "Plop", "Wisp", "Crumb", "Zap", "Bonk", "Fizz", "Toot", "Glub"
    ]
    let adjIndex = rng.nextInt(max: adjectives.count)
    let nounIndex = rng.nextInt(max: nouns.count)
    let name = "\(adjectives[adjIndex]) \(nouns[nounIndex])"

    return BuddySpec(
        species: species,
        rarity: rarity,
        isShiny: isShiny,
        eyes: eyes,
        hat: hat,
        stats: stats,
        name: name
    )
}

// MARK: - User ID Resolution

func resolveBuddyUserId() -> String {
    // Try reading from ~/.claude/.credentials.json
    let credPath = NSHomeDirectory() + "/.claude/.credentials.json"
    if let data = try? Data(contentsOf: URL(fileURLWithPath: credPath)),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        // Try claudeAiOauth section for user info
        if let oauth = json["claudeAiOauth"] as? [String: Any] {
            if let userId = oauth["userId"] as? String, !userId.isEmpty {
                return userId
            }
            if let sub = oauth["sub"] as? String, !sub.isEmpty {
                return sub
            }
            // Try decoding JWT subject from access token
            if let accessToken = oauth["accessToken"] as? String {
                if let subject = decodeJWTSubject(accessToken) {
                    return subject
                }
            }
        }
    }
    // Fallback: machine hostname
    return ProcessInfo.processInfo.hostName
}

private func decodeJWTSubject(_ jwt: String) -> String? {
    let parts = jwt.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    var base64 = String(parts[1])
    // Pad to multiple of 4
    while base64.count % 4 != 0 { base64 += "=" }
    // URL-safe to standard base64
    base64 = base64.replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sub = json["sub"] as? String else {
        return nil
    }
    return sub
}

// MARK: - ViewModel

class UsageViewModel: ObservableObject {
    @Published var usage = UsageData()
    @Published var syncInterval: SyncInterval = .min5
    @Published var isSyncing: Bool = false
    @Published var keepOnTop: Bool = false
    @Published var launchAtLogin: Bool = false {
        didSet {
            applyLaunchAtLogin()
            saveConfig()
        }
    }
    @Published var showMenuBarText: Bool = true {
        didSet { saveConfig() }
    }
    @Published var menuBarFormat: MenuBarFormat = .percent {
        didSet {
            showMenuBarText = (menuBarFormat != .hidden)
            saveConfig()
        }
    }
    /// Which percentage the menu-bar text shows: 5-hour session or 7-day weekly.
    enum MenuBarMetric: String { case session, weekly }
    @Published var menuBarMetric: MenuBarMetric = .session {
        didSet { saveConfig() }
    }
    @Published var usageHistory: [UsageHistoryPoint] = []
    @Published var notificationsEnabled: Bool = false {
        didSet {
            if notificationsEnabled && !isLoadingConfig { requestNotificationAuthorization() }
            saveConfig()
        }
    }
    @Published var alertThresholdLow: Int = 80 {
        didSet { saveConfig() }
    }
    /// Fire a notification when the 5-hour window resets (usage back to 0).
    @Published var notifyOnSessionReset: Bool = false {
        didSet { saveConfig() }
    }
    @Published var alertThresholdHigh: Int = 90 {
        didSet { saveConfig() }
    }
    /// Optional override for the OAuth credentials file. nil = default path.
    @Published var credentialPathOverride: String? = nil {
        didSet {
            service.credentialFilePath = credentialPathOverride ?? (NSHomeDirectory() + "/.claude/.credentials.json")
            saveConfig()
        }
    }
    @Published var showBuddy: Bool = true {
        didSet { saveConfig() }
    }
    @Published var compactMode: Bool = false {
        didSet { saveConfig() }
    }
    /// When true (default), the menu-bar icon shows three different expressions
    /// (idle / syncing / Claude active). When false, the static idle face is
    /// used regardless of state. Useful if the blink is distracting.
    @Published var showMenuBarExpressions: Bool = true {
        didSet { saveConfig() }
    }
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { saveConfig() }
    }
    @Published var showSettings: Bool = false
    @Published var errorMessage: String? = nil
    @Published var errorKind: ErrorKind? = nil
    @Published var credentialStatus: CredentialStatus = .checking
    /// Detected state of the local Claude Code CLI. Single @Published property
    /// (rather than two Bools) so AppDelegate observes exactly one transition
    /// per detection tick — no momentary inconsistency between "isActive" and
    /// "isSleeping" that would otherwise force the icon through a stale
    /// intermediate face on the way from ACTIVE → SLEEPING or vice-versa.
    enum ClaudeActivity: String {
        case idle       // claude binary not running
        case sleeping   // running, but no session file changed in last 60 s
        case active     // session file modified within last 60 s
    }
    @Published var claudeActivity: ClaudeActivity = .idle

    /// Legacy accessors kept for view-model consumers that read individual
    /// Bools. They forward to `claudeActivity` so all callers see a
    /// consistent view.
    var claudeActivelyRunning: Bool { claudeActivity == .active }
    var claudeSleeping: Bool        { claudeActivity == .sleeping }

    enum ErrorKind {
        case credentials   // not logged in / token expired
        case rateLimited   // server told us to slow down
        case network       // offline / DNS / timeout
        case server        // generic 5xx
        case unknown
    }
    @Published var buddyState: BuddyState = .off
    @Published var buddyMood: Int = 3  // 1~5 hearts
    @Published var buddySpec: BuddySpec? = nil
    @Published var buddyBonusStats: [Int] = [0, 0, 0, 0, 0]  // feed로 올린 보너스
    @Published var lastFeedDate: String = ""  // "yyyy-MM-dd"
    @Published var canFeed: Bool = true
    @Published var language: AppLanguage = .en {
        didSet {
            L.lang = language
            saveConfig()
        }
    }

    enum CredentialStatus {
        case checking
        case found
        case notFound
    }

    private let service = ClaudeUsageService()
    /// True while loadConfig() replays persisted values into @Published
    /// properties. Guards against ~15 redundant saveConfig() disk writes and
    /// an unintended SMAppService register/unregister cascade at every launch.
    private var isLoadingConfig = false
    private var syncTimer: Timer?
    private var moodTimer: Timer?
    private var claudeActivityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var consecutiveFailures: Int = 0  // for exponential backoff
    // Notification de-dupe per session (reset when a new session starts)
    private var notifiedLow: Bool = false
    private var notifiedHigh: Bool = false
    private var lastSessionResetSeconds: Int = 0

    deinit {
        syncTimer?.invalidate()
        moodTimer?.invalidate()
        claudeActivityTimer?.invalidate()
    }

    /// Block (briefly) until queued config/history writes hit disk. Called
    /// from applicationWillTerminate — GCD drops pending blocks at exit, so
    /// a setting toggled right before Quit would otherwise be lost.
    func flushPendingWrites() {
        configIOQueue.sync {}
        historyIOQueue.sync {}
    }

    init() {
        loadConfig()
        loadHistory()
        L.lang = language
        checkCredentials()
        // Delay timer setup to ensure we're on main RunLoop
        DispatchQueue.main.async { [weak self] in
            self?.setupAutoSync()
            self?.setupMoodDecay()
            self?.setupClaudeActivityWatch()
        }

        $syncInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveConfig()
                self?.setupAutoSync()
            }
            .store(in: &cancellables)
    }

    /// Re-validate credentials. By default uses the cached in-memory copy if
    /// available; pass `forceRefresh: true` from user-initiated actions
    /// (Refresh button, multi-account picker) to drop the cache and re-read.
    func checkCredentials(forceRefresh: Bool = false) {
        credentialStatus = .checking
        if forceRefresh {
            service.invalidateCachedCredentials()
        }
        if service.readCredentialsFromKeychain() != nil {
            credentialStatus = .found
        } else {
            credentialStatus = .notFound
            errorMessage = L.notLoggedIn
        }
    }

    func fetchUsage() {
        isSyncing = true
        errorMessage = nil
        if buddyState == .idle { buddyState = .working }

        service.fetchUsage { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncing = false
                if self.buddyState == .working { self.buddyState = .idle }
                switch result {
                case .success(let data):
                    // Single @Published assignment → one repaint per sync
                    // instead of three (each emission re-rasterizes the
                    // menu-bar icon and rebuilds the tooltip).
                    var d = data
                    d.lastSyncTime = Date()
                    d.isConnected = true
                    self.usage = d
                    self.credentialStatus = .found
                    self.errorMessage = nil
                    self.errorKind = nil
                    self.consecutiveFailures = 0
                    self.recordHistoryPoint()
                    self.evaluateUsageAlerts()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.usage.isConnected = false
                    // Classify and back off on transient errors
                    if let svcErr = error as? ClaudeUsageService.ServiceError {
                        switch svcErr {
                        case .noCredentials, .unauthorized, .keychainError:
                            self.errorKind = .credentials
                        case .rateLimited:
                            self.errorKind = .rateLimited
                            self.consecutiveFailures = min(self.consecutiveFailures + 1, 4)
                        case .networkError:
                            self.errorKind = .network
                            self.consecutiveFailures = min(self.consecutiveFailures + 1, 4)
                        case .httpError:
                            self.errorKind = .server
                            self.consecutiveFailures = min(self.consecutiveFailures + 1, 4)
                        case .parseError:
                            self.errorKind = .unknown
                        }
                    } else {
                        self.errorKind = .unknown
                    }
                }
                self.scheduleNextFetch()
            }
        }
    }

    func setupAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        consecutiveFailures = 0

        guard syncInterval.seconds != nil else {
            os_log("auto-sync: manual mode, no timer", log: syncLog, type: .info)
            return
        }

        // Initial fetch with 0–2s random delay to avoid thundering herd
        let startDelay = Double.random(in: 0...2)
        os_log("auto-sync starting in %{public}.2fs (jittered start)", log: syncLog, type: .info, startDelay)
        let initial = Timer(timeInterval: startDelay, repeats: false) { [weak self] _ in
            self?.fetchUsage()
        }
        initial.tolerance = max(0.5, startDelay * 0.1)  // let the OS coalesce wakeups
        RunLoop.main.add(initial, forMode: .common)
        syncTimer = initial
    }

    /// Schedule the next fetch after a completion. Adds ±10% jitter on success,
    /// or applies exponential backoff (2× → 16× cap) on consecutive transient failures.
    private func scheduleNextFetch() {
        syncTimer?.invalidate()
        syncTimer = nil

        guard let base = syncInterval.seconds else { return }

        let multiplier = consecutiveFailures > 0
            ? min(pow(2.0, Double(consecutiveFailures)), 16.0)
            : 1.0
        let jitter = base * Double.random(in: -0.1...0.1)
        let delay = max(5.0, base * multiplier + jitter)

        os_log("next fetch in %{public}.0fs (failures=%{public}d, multiplier=%{public}.1fx)", log: syncLog, type: .info, delay, consecutiveFailures, multiplier)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.fetchUsage()
        }
        timer.tolerance = max(1.0, delay * 0.1)  // battery: allow wakeup coalescing
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    // MARK: - Usage Alerts (UserNotifications)

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                os_log("notification auth error: %{public}@", log: syncLog, type: .error, String(describing: error))
            }
            os_log("notification permission granted: %{public}@", log: syncLog, type: .info, granted ? "yes" : "no")
        }
    }

    /// Detect new sessions (reset counter goes UP, meaning a fresh window started)
    /// and fire low/high threshold notifications once per session.
    private func evaluateUsageAlerts() {
        // Detect new session — server's resetSeconds jumped up by a meaningful margin.
        // (When time passes, the value naturally decreases; a jump up means session reset.)
        if usage.sessionResetSeconds > lastSessionResetSeconds + 60 {
            notifiedLow = false
            notifiedHigh = false
            // A jump UP in resetSeconds means a fresh 5-hour window started.
            // lastSessionResetSeconds == 0 is app launch, not a real reset.
            if notifyOnSessionReset, notificationsEnabled, lastSessionResetSeconds > 0 {
                sendSessionResetNotification()
            }
        }
        lastSessionResetSeconds = usage.sessionResetSeconds

        guard notificationsEnabled else { return }

        let pct = usage.sessionUsagePercent
        if pct >= Double(alertThresholdHigh) && !notifiedHigh {
            sendUsageNotification(percent: alertThresholdHigh, identifier: "session-high")
            notifiedHigh = true
            notifiedLow = true  // suppress low if we already crossed high
        } else if pct >= Double(alertThresholdLow) && !notifiedLow {
            sendUsageNotification(percent: alertThresholdLow, identifier: "session-low")
            notifiedLow = true
        }
    }

    private func sendSessionResetNotification() {
        let content = UNMutableNotificationContent()
        content.title = L.newSessionTitle
        content.body = L.newSessionBody
        content.sound = .default
        let request = UNNotificationRequest(identifier: "session-reset", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("session-reset notification error: %{public}@", log: syncLog, type: .error, String(describing: error))
            }
        }
    }

    /// Plain-text summary for the clipboard (Copy summary button / ⌘⇧C).
    var usageSummaryText: String {
        var lines = ["Claude Code usage — \(CachedFormatters.hourMinute.string(from: Date()))"]
        lines.append("Session: \(Int(usage.sessionUsagePercent))% (\(sessionResetText))")
        lines.append("Weekly (all models): \(Int(usage.weeklyAllModelsPercent))%")
        if usage.hasOpusLimit {
            lines.append("Weekly (Opus): \(Int(usage.weeklyOpusPercent))%")
        }
        lines.append("Weekly (Sonnet): \(Int(usage.weeklySonnetPercent))%")
        if usage.extraUsageEnabled { lines.append("Extra usage: enabled") }
        return lines.joined(separator: "\n")
    }

    private func sendUsageNotification(percent: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = L.alertTitle
        content.body = L.alertSession(percent: percent)
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("notification add error: %{public}@", log: syncLog, type: .error, String(describing: error))
            }
        }
    }

    // MARK: - Launch at Login (macOS 13+)

    private func applyLaunchAtLogin() {
        if isLoadingConfig { return }  // reconciliation happens via refreshLaunchAtLoginStatus()
        if #available(macOS 13.0, *) {
            do {
                let svc = SMAppService.mainApp
                if launchAtLogin {
                    if svc.status != .enabled { try svc.register() }
                } else {
                    if svc.status == .enabled { try svc.unregister() }
                }
                os_log("launch-at-login: %{public}@ (status=%{public}d)", log: syncLog, type: .info, launchAtLogin ? "on" : "off", svc.status.rawValue)
            } catch {
                os_log("launch-at-login error: %{public}@", log: syncLog, type: .error, String(describing: error))
                errorMessage = "Login Item: \(error.localizedDescription)"
            }
        }
    }

    /// Sync internal flag with the actual system state (e.g. user removed it from System Settings).
    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let actuallyEnabled = SMAppService.mainApp.status == .enabled
            if actuallyEnabled != launchAtLogin {
                // Update without triggering didSet → register/unregister loop
                _silentSetLaunchAtLogin(actuallyEnabled)
            }
        }
    }

    private func _silentSetLaunchAtLogin(_ value: Bool) {
        // Bypass didSet by temporarily ignoring; simplest: use objectWillChange + property
        // Swift's @Published didSet always fires, so we just write and accept the no-op register call.
        // (register() is idempotent; status check guards against repeats.)
        launchAtLogin = value
    }

    var sessionResetText: String {
        let hours = usage.sessionResetSeconds / 3600
        let minutes = (usage.sessionResetSeconds % 3600) / 60
        return L.resetsIn(hours: hours, minutes: minutes)
    }

    var lastSyncText: String {
        guard let date = usage.lastSyncTime else { return L.never }
        return L.lastSync(CachedFormatters.hourMinute.string(from: date).lowercased())
    }

    var menuBarText: String {
        if menuBarFormat == .hidden { return "" }
        if !usage.isConnected { return "--" }

        let pct = menuBarMetric == .weekly
            ? Int(usage.weeklyAllModelsPercent)
            : Int(usage.sessionUsagePercent)
        let hours = usage.sessionResetSeconds / 3600
        let minutes = (usage.sessionResetSeconds % 3600) / 60
        let timeStr: String = {
            if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
            return "\(minutes)m"
        }()

        switch menuBarFormat {
        case .hidden:  return ""
        case .percent: return "\(pct)%"
        case .time:    return timeStr
        case .both:    return "\(pct)% · \(timeStr)"
        }
    }

    /// Estimated time until session limit is reached at current burn rate.
    /// Returns nil if rate is unknown, too low to predict, or limit already reached.
    var estimatedTimeToLimit: TimeInterval? {
        // Need at least 2 history points in current session window
        let now = Date()
        let sessionStart = now.addingTimeInterval(-Double(18000 - usage.sessionResetSeconds))
        let recent = usageHistory.filter { $0.timestamp >= sessionStart && $0.sessionPercent > 0 }
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last,
              last.timestamp.timeIntervalSince(first.timestamp) >= 300 // need >5min of data
        else { return nil }

        let deltaPct = last.sessionPercent - first.sessionPercent
        let deltaSec = last.timestamp.timeIntervalSince(first.timestamp)

        guard deltaPct > 0.1, deltaSec > 0 else { return nil }
        let burnRatePerSec = deltaPct / deltaSec   // percent per second
        let remaining = max(0, 100 - usage.sessionUsagePercent)
        guard burnRatePerSec > 0 else { return nil }
        let etaSeconds = remaining / burnRatePerSec
        // Cap at session reset; if eta > reset, no risk
        if etaSeconds > Double(usage.sessionResetSeconds) { return nil }
        return etaSeconds
    }

    var etaText: String? {
        guard let eta = estimatedTimeToLimit else { return nil }
        let h = Int(eta) / 3600
        let m = (Int(eta) % 3600) / 60
        switch L.lang {
        case .ko:
            if h > 0 { return "이 속도면 \(h)시간 \(m)분 후 한도 도달" }
            return "이 속도면 \(m)분 후 한도 도달"
        case .ja:
            if h > 0 { return "このペースで \(h) 時間 \(m) 分後に上限" }
            return "このペースで \(m) 分後に上限"
        case .zhCN:
            if h > 0 { return "按当前速度,\(h) 小时 \(m) 分钟后达到上限" }
            return "按当前速度,\(m) 分钟后达到上限"
        case .en:
            if h > 0 { return "At this rate: limit in \(h)h \(m)m" }
            return "At this rate: limit in \(m)m"
        }
    }

    /// Record a usage data point; trim history to last 7 days.
    private func recordHistoryPoint() {
        let point = UsageHistoryPoint(
            timestamp: Date(),
            sessionPercent: usage.sessionUsagePercent,
            weeklyAllModelsPercent: usage.weeklyAllModelsPercent,
            weeklySonnetPercent: usage.weeklySonnetPercent
        )
        usageHistory.append(point)
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        usageHistory.removeAll { $0.timestamp < cutoff }
        saveHistory()
    }

    private var historyPath: String {
        NSHomeDirectory() + "/.claude-usage-widget-history.json"
    }

    private let historyIOQueue = DispatchQueue(
        label: "com.innohi.claudeusagewidget.history-io",
        qos: .utility
    )

    private func saveHistory() {
        let snapshot = usageHistory  // value-type copy on the main thread
        let path = historyPath
        historyIOQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    /// Convert usageHistory to CSV string (timestamp, session_pct, weekly_all_pct).
    func exportHistoryCSV() -> String {
        var lines = ["timestamp,session_percent,weekly_all_models_percent,weekly_sonnet_percent"]
        let iso = CachedFormatters.iso8601
        for p in usageHistory {
            let sonnet = p.weeklySonnetPercent.map { String($0) } ?? ""
            lines.append("\(iso.string(from: p.timestamp)),\(p.sessionPercent),\(p.weeklyAllModelsPercent),\(sonnet)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Convert usageHistory to pretty-printed JSON string.
    func exportHistoryJSON() -> String {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(usageHistory),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "[]"
    }

    /// Wipe persisted history and reset in-memory state. The file removal is
    /// routed through historyIOQueue so an in-flight async save can't land
    /// after the delete and resurrect the file.
    func clearHistory() {
        usageHistory.removeAll()
        let path = historyPath
        historyIOQueue.async {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: historyPath)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let points = try? decoder.decode([UsageHistoryPoint].self, from: data) {
            let cutoff = Date().addingTimeInterval(-7 * 86400)
            usageHistory = points.filter { $0.timestamp >= cutoff }
        }
    }

    // MARK: - Buddy Actions

    func buddyHatch() {
        guard buddyState == .off else { return }
        // Generate buddy spec deterministically
        let userId = resolveBuddyUserId()
        buddySpec = generateBuddy(userId: userId)
        buddyState = .egg
        // Hatch after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.buddyState = .idle
            self?.buddyMood = 3
            self?.saveConfig()
        }
    }

    func buddyPet() {
        guard buddyState == .idle || buddyState == .happy else { return }
        buddyState = .happy
        buddyMood = min(5, buddyMood + 1)
        saveConfig()
        // Return to idle after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.buddyState == .happy {
                self?.buddyState = .idle
            }
        }
    }

    func buddySleep() {
        guard buddyState != .off else { return }
        buddyState = .sleepy
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.buddyState = .off
            self?.saveConfig()
        }
    }

    func buddyFeed() {
        guard buddyState == .idle || buddyState == .happy else { return }
        guard canFeed else { return }

        // 랜덤 속성 +1
        let idx = Int.random(in: 0..<5)
        buddyBonusStats[idx] = min(buddyBonusStats[idx] + 1, 5) // 보너스 최대 +5

        // 기분도 올라감
        buddyMood = min(5, buddyMood + 1)

        // 오늘 날짜 기록 → 하루 1회 제한
        lastFeedDate = CachedFormatters.dayKey.string(from: Date())
        canFeed = false

        buddyState = .happy
        saveConfig()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.buddyState == .happy {
                self?.buddyState = .idle
            }
        }
    }

    // MARK: - Claude Code activity watch (drives the menu-bar face)

    /// Polling cadence — 10 s is fast enough to feel live without spawning
    /// pgrep every few seconds. "Claude is running" doesn't flip back and
    /// forth at sub-second scale, so going lower buys nothing.
    private static let claudeActivityPollSec: TimeInterval = 10
    // Subprocess timeout is passed via runProcessWithTimeout(timeout:).
    // Hard-capped at 5 s so a hung `find` on a network mount can't stack.
    /// Reentrancy guard — if the previous tick's Process(es) still haven't
    /// returned, skip this tick rather than piling on more subprocesses.
    private let claudeActivityQueryQueue = DispatchQueue(
        label: "com.innohi.claudeusagewidget.activity",
        qos: .utility
    )
    private var claudeActivityQueryInFlight = false

    private func setupClaudeActivityWatch() {
        claudeActivityTimer?.invalidate()
        scheduleClaudeActivityQuery()  // initial check
        let timer = Timer(timeInterval: Self.claudeActivityPollSec, repeats: true) { [weak self] _ in
            self?.scheduleClaudeActivityQuery()
        }
        timer.tolerance = 2.0  // 10s cadence; ±2s is invisible to the face swap
        RunLoop.main.add(timer, forMode: .common)
        claudeActivityTimer = timer
    }

    /// Serialised entry point. Skips if the previous query is still running,
    /// or if the animated face is disabled — in which case the state is reset
    /// to .idle so the tooltip / VoiceOver label don't report a stale
    /// "Claude active" forever.
    private func scheduleClaudeActivityQuery() {
        guard showMenuBarExpressions else {
            if claudeActivity != .idle { claudeActivity = .idle }
            return
        }
        claudeActivityQueryQueue.async { [weak self] in
            guard let self = self else { return }
            if self.claudeActivityQueryInFlight { return }
            self.claudeActivityQueryInFlight = true
            self.queryClaudeRunning()
            self.claudeActivityQueryInFlight = false
        }
    }

    /// Three-tier detection — the result drives the menu-bar face:
    ///
    ///   ACTIVE  — a file under ~/.claude/projects/ was modified in the
    ///             last 60 s (Claude is streaming a response or you just
    ///             sent a message).
    ///   SLEEPING — the `claude` CLI binary is running but no session
    ///              file changed in the last 60 s (Claude is idle but
    ///              available, e.g. VS Code extension parked open).
    ///   IDLE    — `claude` isn't running at all.
    ///
    /// Must run off the main thread. Hops back to main to publish the result.
    private func queryClaudeRunning() {
        let projectsDir = NSHomeDirectory() + "/.claude/projects"
        var recentlyWorking = false
        var processAlive = false

        // 1) Any project files modified within the last minute?
        if FileManager.default.fileExists(atPath: projectsDir) {
            recentlyWorking = runProcessWithTimeout(
                launchPath: "/usr/bin/find",
                arguments: [
                    projectsDir,
                    "-type", "f",
                    "-mmin", "-1",       // less than 1 minute since modification
                    "-print", "-quit"    // first match wins, exit early
                ],
                captureStdout: true
            ).stdoutNonEmpty
        }

        // 2) Independent: is the `claude` binary itself running?
        processAlive = runProcessWithTimeout(
            launchPath: "/usr/bin/pgrep",
            arguments: ["-x", "claude"],
            captureStdout: false
        ).exitCodeZero

        let newActivity: ClaudeActivity
        if recentlyWorking      { newActivity = .active }
        else if processAlive    { newActivity = .sleeping }
        else                    { newActivity = .idle }

        os_log("claude → %{public}@ (recentFile=%{public}@ procAlive=%{public}@)",
               log: activityLog, type: .info,
               newActivity.rawValue,
               recentlyWorking ? "yes" : "no",
               processAlive ? "yes" : "no")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if newActivity != self.claudeActivity {
                self.claudeActivity = newActivity
            }
        }
    }

    /// Runs a subprocess with a hard timeout. If the process exceeds the
    /// timeout we SIGTERM (then SIGKILL) it so a hung `find` on a network
    /// mount can't stack up across ticks.
    private struct ProcessResult {
        let exitCodeZero: Bool
        let stdoutNonEmpty: Bool
    }
    private func runProcessWithTimeout(
        launchPath: String,
        arguments: [String],
        captureStdout: Bool,
        timeout: TimeInterval = 5.0
    ) -> ProcessResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        let stdoutPipe = Pipe()
        task.standardOutput = captureStdout ? stdoutPipe : Pipe()
        task.standardError = Pipe()

        // Event-driven completion — zero wakeups while the subprocess runs
        // (the previous implementation polled isRunning at 20 Hz).
        let done = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in done.signal() }
        do {
            try task.run()
        } catch {
            return ProcessResult(exitCodeZero: false, stdoutNonEmpty: false)
        }

        if done.wait(timeout: .now() + timeout) == .timedOut {
            task.terminate()
            if done.wait(timeout: .now() + 0.2) == .timedOut {
                kill(task.processIdentifier, SIGKILL)
                task.waitUntilExit()
            }
            os_log("subprocess timeout: %{public}@", log: activityLog, type: .info, launchPath)
            return ProcessResult(exitCodeZero: false, stdoutNonEmpty: false)
        }

        let stdoutNonEmpty = captureStdout
            ? !stdoutPipe.fileHandleForReading.readDataToEndOfFile().isEmpty
            : false
        return ProcessResult(exitCodeZero: task.terminationStatus == 0,
                             stdoutNonEmpty: stdoutNonEmpty)
    }

    // MARK: - Mood Decay (30분마다 기분 -1, 0이면 보너스 스탯 -1)

    private func setupMoodDecay() {
        moodTimer?.invalidate()
        let timer = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self = self, self.buddyState != .off else { return }

            // 기분 감소
            if self.buddyMood > 0 {
                self.buddyMood -= 1
            }

            // 기분 0이면 보너스 능력치도 감소
            if self.buddyMood == 0 {
                for i in 0..<5 {
                    if self.buddyBonusStats[i] > 0 {
                        self.buddyBonusStats[i] -= 1
                        break // 한번에 1개만
                    }
                }
            }

            // 하루 지났으면 밥 줄 수 있게 리셋
            let today = CachedFormatters.dayKey.string(from: Date())
            if self.lastFeedDate != today {
                self.canFeed = true
            }

            self.saveConfig()
        }
        timer.tolerance = 120  // 30-min cadence; ±2 min is fine for mood decay
        RunLoop.main.add(timer, forMode: .common)
        moodTimer = timer

        // 시작 시 오늘 날짜 체크
        let today = CachedFormatters.dayKey.string(from: Date())
        if lastFeedDate != today {
            canFeed = true
        }
    }

    // MARK: - Config Persistence

    private let configPath = NSHomeDirectory() + "/.claude-usage-widget-config.json"
    private let legacyConfigPath = NSHomeDirectory() + "/.claude-monitor-config.json"

    private func loadConfig() {
        isLoadingConfig = true
        var migratedFromLegacy = false
        defer {
            isLoadingConfig = false
            // The isLoadingConfig guard suppresses every save during load, so a
            // legacy-path migration must be persisted explicitly once.
            if migratedFromLegacy { saveConfig() }
        }
        // Migration: prefer the new path, fall back to the legacy one (pre-1.1.0 Bundle ID rename).
        let primary = URL(fileURLWithPath: configPath)
        let legacy = URL(fileURLWithPath: legacyConfigPath)

        let sourceURL: URL
        if FileManager.default.fileExists(atPath: configPath) {
            sourceURL = primary
        } else if FileManager.default.fileExists(atPath: legacyConfigPath) {
            sourceURL = legacy
            os_log("migrating config from legacy path", log: syncLog, type: .info)
            migratedFromLegacy = true
        } else {
            return
        }

        guard let data = try? Data(contentsOf: sourceURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let interval = config["syncInterval"] as? String,
           let syncInt = SyncInterval(rawValue: interval) {
            syncInterval = syncInt
        }
        if let onTop = config["keepOnTop"] as? Bool {
            keepOnTop = onTop
        }
        if let showText = config["showMenuBarText"] as? Bool {
            showMenuBarText = showText
        }
        if let fmt = config["menuBarFormat"] as? String,
           let format = MenuBarFormat(rawValue: fmt) {
            menuBarFormat = format
        } else {
            // Legacy fallback (pre-v1.2 configs): derive from showMenuBarText
            menuBarFormat = showMenuBarText ? .percent : .hidden
        }
        if let metric = config["menuBarMetric"] as? String,
           let m = MenuBarMetric(rawValue: metric) {
            menuBarMetric = m
        }
        if let resetNotify = config["notifyOnSessionReset"] as? Bool {
            notifyOnSessionReset = resetNotify
        }
        if let launch = config["launchAtLogin"] as? Bool {
            // Set without triggering register() during load — let refreshLaunchAtLoginStatus reconcile.
            launchAtLogin = launch
        }
        if let notif = config["notificationsEnabled"] as? Bool {
            notificationsEnabled = notif
        }
        if let low = config["alertThresholdLow"] as? Int, (50...95).contains(low) {
            alertThresholdLow = low
        }
        if let high = config["alertThresholdHigh"] as? Int, (60...99).contains(high) {
            alertThresholdHigh = high
        }
        if let path = config["credentialPathOverride"] as? String {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                credentialPathOverride = trimmed
            }
        }
        // Keep low < high
        if alertThresholdLow >= alertThresholdHigh {
            alertThresholdLow = max(50, alertThresholdHigh - 10)
        }
        if let buddy = config["showBuddy"] as? Bool {
            showBuddy = buddy
        }
        if let compact = config["compactMode"] as? Bool {
            compactMode = compact
        }
        if let expr = config["showMenuBarExpressions"] as? Bool {
            showMenuBarExpressions = expr
        }
        if let onboarded = config["hasCompletedOnboarding"] as? Bool {
            hasCompletedOnboarding = onboarded
        } else {
            // Existing pre-1.1.0 users: a config file exists, so they already know the app.
            // Skip onboarding for them.
            hasCompletedOnboarding = true
        }
        if let lang = config["language"] as? String,
           let appLang = AppLanguage(rawValue: lang) {
            language = appLang
        }
        if let buddy = config["buddyState"] as? String {
            // Restore buddy if it was alive
            if buddy == "idle" || buddy == "happy" {
                buddyState = .idle
                // Regenerate buddy spec on restore
                let userId = resolveBuddyUserId()
                buddySpec = generateBuddy(userId: userId)
            } else {
                buddyState = .off
            }
        }
        if let mood = config["buddyMood"] as? Int {
            buddyMood = max(0, min(5, mood))
        }
        if let bonus = config["buddyBonusStats"] as? [Int], bonus.count == 5 {
            buddyBonusStats = bonus
        }
        if let feed = config["lastFeedDate"] as? String {
            lastFeedDate = feed
        }
    }

    private let configIOQueue = DispatchQueue(
        label: "com.innohi.claudeusagewidget.config-io",
        qos: .utility
    )

    func saveConfig() {
        if isLoadingConfig { return }  // loading replays didSet; skip the echo
        let config: [String: Any] = [
            "syncInterval": syncInterval.rawValue,
            "keepOnTop": keepOnTop,
            "showMenuBarText": showMenuBarText,
            "menuBarFormat": menuBarFormat.rawValue,
            "menuBarMetric": menuBarMetric.rawValue,
            "notifyOnSessionReset": notifyOnSessionReset,
            "launchAtLogin": launchAtLogin,
            "notificationsEnabled": notificationsEnabled,
            "alertThresholdLow": alertThresholdLow,
            "alertThresholdHigh": alertThresholdHigh,
            "credentialPathOverride": credentialPathOverride ?? "",
            "showBuddy": showBuddy,
            "compactMode": compactMode,
            "showMenuBarExpressions": showMenuBarExpressions,
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "language": language.rawValue,
            "buddyState": buddyState.rawValue,
            "buddyMood": buddyMood,
            "buddyBonusStats": buddyBonusStats,
            "lastFeedDate": lastFeedDate
        ]

        let path = configPath
        configIOQueue.async {
            if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
                do {
                    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                } catch {
                    os_log("config write failed: %{public}@", log: syncLog, type: .error, String(describing: error))
                }
            }
        }
    }
}

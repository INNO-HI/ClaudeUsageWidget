import Foundation
import Combine
import ServiceManagement
import UserNotifications

// MARK: - Data Models

struct UsageData {
    var sessionUsagePercent: Double = 0
    var sessionResetSeconds: Int = 0
    var weeklyAllModelsPercent: Double = 0
    var weeklyAllModelsResetDate: String = ""
    var weeklySonnetPercent: Double = 0
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
        if L.lang == .ko {
            switch self {
            case .hidden:  return "숨김"
            case .percent: return "%"
            case .time:    return "시간"
            case .both:    return "%·시간"
            }
        }
        switch self {
        case .hidden:  return "Off"
        case .percent: return "%"
        case .time:    return "Time"
        case .both:    return "Both"
        }
    }
}

// MARK: - Usage History Point

struct UsageHistoryPoint: Codable {
    let timestamp: Date
    let sessionPercent: Double
    let weeklyAllModelsPercent: Double
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
        if L.lang == .ko {
            return ["디버깅", "인내심", "혼돈", "지혜", "독설"]
        }
        return ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"]
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
    @Published var usageHistory: [UsageHistoryPoint] = []
    @Published var notificationsEnabled: Bool = false {
        didSet {
            if notificationsEnabled { requestNotificationAuthorization() }
            saveConfig()
        }
    }
    @Published var showBuddy: Bool = true {
        didSet { saveConfig() }
    }
    @Published var compactMode: Bool = false {
        didSet { saveConfig() }
    }
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { saveConfig() }
    }
    @Published var showSettings: Bool = false
    @Published var errorMessage: String? = nil
    @Published var credentialStatus: CredentialStatus = .checking
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
    private var syncTimer: Timer?
    private var moodTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var consecutiveFailures: Int = 0  // for exponential backoff
    // Notification de-dupe per session (reset when a new session starts)
    private var notified80: Bool = false
    private var notified90: Bool = false
    private var lastSessionResetSeconds: Int = 0

    init() {
        loadConfig()
        loadHistory()
        L.lang = language
        checkCredentials()
        // Delay timer setup to ensure we're on main RunLoop
        DispatchQueue.main.async { [weak self] in
            self?.setupAutoSync()
            self?.setupMoodDecay()
        }

        $syncInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveConfig()
                self?.setupAutoSync()
            }
            .store(in: &cancellables)
    }

    func checkCredentials() {
        credentialStatus = .checking
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
                    self.usage = data
                    self.usage.lastSyncTime = Date()
                    self.usage.isConnected = true
                    self.credentialStatus = .found
                    self.errorMessage = nil
                    self.consecutiveFailures = 0
                    self.recordHistoryPoint()
                    self.evaluateUsageAlerts()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.usage.isConnected = false
                    // Only back off on transient errors (rate limit / network)
                    if let svcErr = error as? ClaudeUsageService.ServiceError {
                        switch svcErr {
                        case .rateLimited, .networkError, .httpError:
                            self.consecutiveFailures = min(self.consecutiveFailures + 1, 4)
                        default: break
                        }
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
            NSLog("[ClaudeUsageWidget] Auto-sync: manual mode, no timer")
            return
        }

        // Initial fetch with 0–2s random delay to avoid thundering herd
        let startDelay = Double.random(in: 0...2)
        NSLog("[ClaudeUsageWidget] Auto-sync starting in %.2fs (jittered start)", startDelay)
        let initial = Timer(timeInterval: startDelay, repeats: false) { [weak self] _ in
            self?.fetchUsage()
        }
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

        NSLog("[ClaudeUsageWidget] Next fetch in %.0fs (failures=%d, multiplier=%.1fx)", delay, consecutiveFailures, multiplier)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.fetchUsage()
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    // MARK: - Usage Alerts (UserNotifications)

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[ClaudeUsageWidget] Notification auth error: \(error)")
            }
            NSLog("[ClaudeUsageWidget] Notification permission granted: \(granted)")
        }
    }

    /// Detect new sessions (reset counter goes UP, meaning a fresh window started)
    /// and fire 80%/90% notifications once per session.
    private func evaluateUsageAlerts() {
        // Detect new session — server's resetSeconds jumped up by a meaningful margin.
        // (When time passes, the value naturally decreases; a jump up means session reset.)
        if usage.sessionResetSeconds > lastSessionResetSeconds + 60 {
            notified80 = false
            notified90 = false
        }
        lastSessionResetSeconds = usage.sessionResetSeconds

        guard notificationsEnabled else { return }

        let pct = usage.sessionUsagePercent
        if pct >= 90 && !notified90 {
            sendUsageNotification(percent: 90, identifier: "session-90")
            notified90 = true
            notified80 = true   // suppress 80 if we already crossed 90
        } else if pct >= 80 && !notified80 {
            sendUsageNotification(percent: 80, identifier: "session-80")
            notified80 = true
        }
    }

    private func sendUsageNotification(percent: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = L.alertTitle
        content.body = L.alertSession(percent: percent)
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[ClaudeUsageWidget] Notification add error: \(error)")
            }
        }
    }

    // MARK: - Launch at Login (macOS 13+)

    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                let svc = SMAppService.mainApp
                if launchAtLogin {
                    if svc.status != .enabled { try svc.register() }
                } else {
                    if svc.status == .enabled { try svc.unregister() }
                }
                NSLog("[ClaudeUsageWidget] Launch at Login: \(launchAtLogin) (status=\(svc.status.rawValue))")
            } catch {
                NSLog("[ClaudeUsageWidget] Launch at Login error: \(error)")
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
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return L.lastSync(formatter.string(from: date).lowercased())
    }

    var menuBarText: String {
        if menuBarFormat == .hidden { return "" }
        if !usage.isConnected { return "--" }

        let pct = Int(usage.sessionUsagePercent)
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
        if L.lang == .ko {
            if h > 0 { return "이 속도면 \(h)시간 \(m)분 후 한도 도달" }
            return "이 속도면 \(m)분 후 한도 도달"
        } else {
            if h > 0 { return "At this rate: limit in \(h)h \(m)m" }
            return "At this rate: limit in \(m)m"
        }
    }

    /// Record a usage data point; trim history to last 7 days.
    private func recordHistoryPoint() {
        let point = UsageHistoryPoint(
            timestamp: Date(),
            sessionPercent: usage.sessionUsagePercent,
            weeklyAllModelsPercent: usage.weeklyAllModelsPercent
        )
        usageHistory.append(point)
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        usageHistory.removeAll { $0.timestamp < cutoff }
        saveHistory()
    }

    private var historyPath: String {
        NSHomeDirectory() + "/.claude-usage-widget-history.json"
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(usageHistory) {
            try? data.write(to: URL(fileURLWithPath: historyPath))
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        lastFeedDate = formatter.string(from: Date())
        canFeed = false

        buddyState = .happy
        saveConfig()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.buddyState == .happy {
                self?.buddyState = .idle
            }
        }
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            if self.lastFeedDate != today {
                self.canFeed = true
            }

            self.saveConfig()
        }
        RunLoop.main.add(timer, forMode: .common)
        moodTimer = timer

        // 시작 시 오늘 날짜 체크
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        if lastFeedDate != today {
            canFeed = true
        }
    }

    // MARK: - Config Persistence

    private let configPath = NSHomeDirectory() + "/.claude-usage-widget-config.json"
    private let legacyConfigPath = NSHomeDirectory() + "/.claude-monitor-config.json"

    private func loadConfig() {
        // Migration: prefer the new path, fall back to the legacy one (pre-1.1.0 Bundle ID rename).
        let primary = URL(fileURLWithPath: configPath)
        let legacy = URL(fileURLWithPath: legacyConfigPath)

        let sourceURL: URL
        if FileManager.default.fileExists(atPath: configPath) {
            sourceURL = primary
        } else if FileManager.default.fileExists(atPath: legacyConfigPath) {
            sourceURL = legacy
            NSLog("[ClaudeUsageWidget] Migrating config from legacy path")
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
            // Legacy fallback: derive from showMenuBarText
            menuBarFormat = showMenuBarText ? .percent : .hidden
        }
        if let launch = config["launchAtLogin"] as? Bool {
            // Set without triggering register() during load — let refreshLaunchAtLoginStatus reconcile.
            launchAtLogin = launch
        }
        if let notif = config["notificationsEnabled"] as? Bool {
            notificationsEnabled = notif
        }
        if let buddy = config["showBuddy"] as? Bool {
            showBuddy = buddy
        }
        if let compact = config["compactMode"] as? Bool {
            compactMode = compact
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

    func saveConfig() {
        let config: [String: Any] = [
            "syncInterval": syncInterval.rawValue,
            "keepOnTop": keepOnTop,
            "showMenuBarText": showMenuBarText,
            "menuBarFormat": menuBarFormat.rawValue,
            "launchAtLogin": launchAtLogin,
            "notificationsEnabled": notificationsEnabled,
            "showBuddy": showBuddy,
            "compactMode": compactMode,
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "language": language.rawValue,
            "buddyState": buddyState.rawValue,
            "buddyMood": buddyMood,
            "buddyBonusStats": buddyBonusStats,
            "lastFeedDate": lastFeedDate
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: configPath))
        }
    }
}

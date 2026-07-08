import Foundation
import Security
import os.log

// MARK: - Claude Usage Service (OAuth-based)

/// Unified-logging channel for credential decisions. Stream live with:
///   log stream --predicate 'subsystem == "com.innohi.claudeusagewidget" AND category == "creds"' --style compact
/// Or pull recent history:
///   log show --predicate 'subsystem == "com.innohi.claudeusagewidget" AND category == "creds"' --last 30m --info
private let credsLog = OSLog(subsystem: "com.innohi.claudeusagewidget", category: "creds")

class ClaudeUsageService {

    private let usageURL = "https://api.anthropic.com/api/oauth/usage"

    // Cached formatters — DateFormatter/ISO8601DateFormatter init is expensive
    // and parseUsageResponse runs on every sync tick.
    private static let resetDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        f.locale = Locale(identifier: "en_US")
        return f
    }()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    enum ServiceError: LocalizedError {
        case noCredentials
        case keychainError(String)
        case networkError(String)
        case parseError(String)
        case unauthorized
        case rateLimited
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .noCredentials: return "Claude Code credentials not found. Please log in to Claude Code first."
            case .keychainError(let msg): return "Keychain: \(msg)"
            case .networkError(let msg): return "Network: \(msg)"
            case .parseError(let msg): return "Parse: \(msg)"
            case .unauthorized: return "Token expired. Please use Claude Code to refresh."
            case .rateLimited: return "Rate limited. Try again later."
            case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(100))"
            }
        }
    }

    // MARK: - OAuth Credentials

    struct OAuthCredentials {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Double
    }

    // MARK: - Read from macOS Keychain

    /// Path to the OAuth credentials file. Defaults to `~/.claude/.credentials.json`
    /// but can be overridden so users with multiple Claude accounts can point the
    /// widget at a per-profile copy. Setting this clears the cached credentials.
    var credentialFilePath: String = NSHomeDirectory() + "/.claude/.credentials.json" {
        didSet {
            if oldValue != credentialFilePath { invalidateCachedCredentials() }
        }
    }

    // MARK: - Credential cache
    //
    // Reading from the macOS Keychain triggers a permission prompt the first
    // time AND every time after that for ad-hoc / non-trusted signed builds.
    // We hold the parsed credentials in memory and only re-read when:
    //   1) the path changes,
    //   2) the access token is past its `expiresAt`,
    //   3) the server returns 401 / 403 (handled by callers via
    //      invalidateCachedCredentials()).
    //
    // All cache state is mutated only on the main thread. The URLSession
    // completion handler hops to main before calling invalidateCachedCredentials
    // — see fetchUsage().
    private var cachedCredentials: OAuthCredentials?
    /// If Keychain access was denied / cancelled, don't re-prompt on every
    /// auto-sync. Reset after `keychainDenialCooldownSec` so a user who clicks
    /// "Always Allow" in System Settings doesn't have to restart the app.
    private var keychainDeniedThisSession: Bool = false
    private var keychainDeniedAt: Date?
    private let keychainDenialCooldownSec: TimeInterval = 300  // 5 minutes

    /// Must be called on the main thread. Background callers (URLSession
    /// completion handler) hop via DispatchQueue.main.async.
    func invalidateCachedCredentials() {
        dispatchPrecondition(condition: .onQueue(.main))
        os_log("invalidate-cache", log: credsLog, type: .info)
        cachedCredentials = nil
        keychainDeniedThisSession = false
        keychainDeniedAt = nil
    }

    /// Read credentials, preferring the in-memory cache to avoid spamming the
    /// macOS Keychain prompt. Falls back to the file on disk, then the
    /// Keychain (at most once per session).
    ///
    /// Emits NSLog markers so the actual decision path is visible in
    /// Console.app / `log stream --process ClaudeUsageBar`:
    ///   [creds] cache-hit               (no Keychain access)
    ///   [creds] cache-expired           (token rotation imminent)
    ///   [creds] file-hit                (disk read, no prompt)
    ///   [creds] file-miss               (about to query Keychain)
    ///   [creds] keychain-denied-cached  (cancelled earlier this session)
    ///   [creds] keychain-query START    (prompt may appear NOW)
    ///   [creds] keychain-query OK       (got the data)
    ///   [creds] keychain-query FAIL=N   (status code from SecItemCopyMatching)
    func readCredentialsFromKeychain() -> OAuthCredentials? {
        if let cached = cachedCredentials, !isCachedTokenExpired(cached) {
            os_log("cache-hit", log: credsLog, type: .info)
            return cached
        }
        if cachedCredentials != nil {
            os_log("cache-expired", log: credsLog, type: .info)
        }

        // 1) Disk file (no prompt). Re-read here also captures token rotation
        //    when Claude Code refreshes credentials between syncs.
        if let data = try? Data(contentsOf: URL(fileURLWithPath: credentialFilePath)),
           let creds = parseCredentials(data: data) {
            os_log("file-hit path=%{public}@", log: credsLog, type: .info, credentialFilePath)
            cachedCredentials = creds
            return creds
        }
        os_log("file-miss path=%{public}@", log: credsLog, type: .info, credentialFilePath)

        // 2) Keychain — at most once per cooldown window unless the cache was
        //    explicitly invalidated (e.g. by a 401 from the server). The
        //    cooldown means a user who clicks "Always Allow" in System
        //    Settings is picked up on the next retry without restarting.
        if keychainDeniedThisSession,
           let deniedAt = keychainDeniedAt,
           Date().timeIntervalSince(deniedAt) < keychainDenialCooldownSec {
            os_log("keychain-denied-cached (skipping prompt, %{public}.0fs since denial)",
                   log: credsLog, type: .info,
                   Date().timeIntervalSince(deniedAt))
            return nil
        }
        if keychainDeniedThisSession {
            os_log("keychain-denial-cooldown elapsed — retrying", log: credsLog, type: .info)
            keychainDeniedThisSession = false
            keychainDeniedAt = nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        os_log("keychain-query START — prompt may appear NOW", log: credsLog, type: .info)
        let start = Date()
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)

        if status == errSecSuccess, let data = result as? Data,
           let creds = parseCredentials(data: data) {
            os_log("keychain-query OK (%{public}dms)", log: credsLog, type: .info, elapsedMs)
            cachedCredentials = creds
            return creds
        }

        // Anything else (user cancelled, item missing, errSecAuthFailed)
        // — flag denied so the next sync doesn't immediately re-prompt.
        os_log("keychain-query FAIL status=%{public}d (%{public}dms)", log: credsLog, type: .info, Int(status), elapsedMs)
        keychainDeniedThisSession = true
        keychainDeniedAt = Date()
        return nil
    }

    /// Treat a token whose `expiresAt` is in the past (with a 30-second buffer)
    /// as expired so we re-read from disk and pick up Claude Code's refresh.
    ///
    /// Defensive about the unit: Claude Code historically stored `expiresAt` in
    /// **seconds** (10-digit Unix timestamp) but some versions ship it in
    /// **milliseconds** (13-digit). Values > 1e11 are clearly ms; below that
    /// we assume seconds. A wrongly-assumed unit would mark every cached token
    /// as expired and re-prompt on every sync — exactly the bug we're fighting.
    private func isCachedTokenExpired(_ creds: OAuthCredentials) -> Bool {
        // Defensive: reject NaN / Infinity from a corrupted credentials file,
        // and ignore zero/negative (= "no expiry data") rather than treating
        // them as already expired.
        guard creds.expiresAt > 0, creds.expiresAt.isFinite else { return false }
        let expiresSec = creds.expiresAt > 1e11 ? creds.expiresAt / 1000 : creds.expiresAt
        let nowSec = Date().timeIntervalSince1970
        let expired = nowSec > (expiresSec - 30)
        os_log("expires-check now=%{public}.0f expiresAt=%{public}.0f expiresSec=%{public}.0f expired=%{public}@",
               log: credsLog, type: .info,
               nowSec, creds.expiresAt, expiresSec, expired ? "YES" : "no")
        return expired
    }

    private func parseCredentials(data: Data) -> OAuthCredentials? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String else {
            return nil
        }

        let expiresAt = oauth["expiresAt"] as? Double ?? 0
        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }

    // MARK: - Status Line Bridge (preferred, no API call)

    /// Read usage data from ~/.claude-status.json written by the status line bridge.
    /// Returns nil if file doesn't exist or is stale (>2 min old).
    private func readFromStatusLineBridge() -> UsageData? {
        let path = NSHomeDirectory() + "/.claude-status.json"
        let url = URL(fileURLWithPath: path)

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }

        // Stale if older than 2 minutes (Claude Code inactive)
        if Date().timeIntervalSince(modDate) > 120 {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var usage = UsageData()
        usage.isConnected = true
        usage.lastSyncTime = modDate

        // rate_limits from Claude Code status line JSON
        if let rateLimits = json["rate_limits"] as? [String: Any] {
            if let fiveHour = rateLimits["five_hour"] as? [String: Any] {
                usage.sessionUsagePercent = fiveHour["used_percentage"] as? Double ?? 0
                if let resetsAt = fiveHour["resets_at"] as? Double {
                    usage.sessionResetSeconds = max(0, Int(resetsAt - Date().timeIntervalSince1970))
                }
            }
            if let sevenDay = rateLimits["seven_day"] as? [String: Any] {
                usage.weeklyAllModelsPercent = sevenDay["used_percentage"] as? Double ?? 0
                if let resetsAt = sevenDay["resets_at"] as? Double {
                    let date = Date(timeIntervalSince1970: resetsAt)
                    usage.weeklyAllModelsResetDate = Self.resetDateFormatter.string(from: date)
                }
            }
            // Bridge previously dropped the sonnet/opus pools, so the Sonnet
            // row showed 0% whenever the bridge was fresh. Parse them too.
            if let sonnet = rateLimits["seven_day_sonnet"] as? [String: Any] {
                usage.weeklySonnetPercent = sonnet["used_percentage"] as? Double ?? 0
            }
            if let opus = rateLimits["seven_day_opus"] as? [String: Any] {
                usage.weeklyOpusPercent = opus["used_percentage"] as? Double ?? 0
                usage.hasOpusLimit = true
            }
            // Dynamic pools from the bridge too (fable / mythos / future tiers)
            let knownPools: Set<String> = ["seven_day", "seven_day_sonnet", "seven_day_opus"]
            var extras: [(slug: String, percent: Double)] = []
            for (key, value) in rateLimits {
                guard key.hasPrefix("seven_day_"), !knownPools.contains(key),
                      let dict = value as? [String: Any] else { continue }
                let slug = String(key.dropFirst("seven_day_".count))
                extras.append((slug: slug, percent: dict["used_percentage"] as? Double ?? 0))
            }
            usage.extraWeeklyPools = extras.sorted { $0.slug < $1.slug }
        }

        return usage
    }

    // MARK: - Fetch Usage (bridge → API fallback)

    func fetchUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        // Try status line bridge first (instant, no API call, no rate limits)
        if let usage = readFromStatusLineBridge() {
            completion(.success(usage))
            return
        }

        // Fallback: hit the API (old behavior, may be rate limited)
        guard let credentials = readCredentialsFromKeychain() else {
            completion(.failure(ServiceError.noCredentials))
            return
        }

        guard let url = URL(string: usageURL) else {
            completion(.failure(ServiceError.networkError("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(ServiceError.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ServiceError.networkError("No HTTP response")))
                return
            }

            // READ-ONLY mode: do not refresh. Let Claude Code handle it.
            // Drop the cached token so the next sync re-reads the file (which
            // Claude Code should have rotated by then). Cache state is
            // main-thread-only, so hop before mutating.
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                DispatchQueue.main.async { self?.invalidateCachedCredentials() }
                completion(.failure(ServiceError.unauthorized))
                return
            }
            if httpResponse.statusCode == 429 {
                completion(.failure(ServiceError.rateLimited))
                return
            }

            guard httpResponse.statusCode == 200 else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No body"
                completion(.failure(ServiceError.httpError(httpResponse.statusCode, body)))
                return
            }

            guard let data = data else {
                completion(.failure(ServiceError.parseError("No data")))
                return
            }

            do {
                let usageData = try self?.parseUsageResponse(data: data) ?? UsageData()
                completion(.success(usageData))
            } catch {
                completion(.failure(ServiceError.parseError(error.localizedDescription)))
            }
        }.resume()
    }

    // MARK: - Parse Usage Response

    /*
     Expected response:
     {
       "five_hour": { "utilization": 37.0, "resets_at": "2026-02-08T04:59:59.000000+00:00" },
       "seven_day": { "utilization": 26.0, "resets_at": "2026-02-12T14:59:59.771647+00:00" },
       "seven_day_opus": null,
       "seven_day_sonnet": { "utilization": 1.0, "resets_at": "..." },
       "extra_usage": { "is_enabled": false, ... }
     }
    */
    private func parseUsageResponse(data: Data) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.parseError("Invalid JSON")
        }

        var usage = UsageData()
        usage.isConnected = true

        // Five-hour session
        if let fiveHour = json["five_hour"] as? [String: Any] {
            usage.sessionUsagePercent = fiveHour["utilization"] as? Double ?? 0
            if let resetsAt = fiveHour["resets_at"] as? String {
                usage.sessionResetSeconds = secondsUntil(isoDate: resetsAt)
            }
        }

        // Seven-day all models
        if let sevenDay = json["seven_day"] as? [String: Any] {
            usage.weeklyAllModelsPercent = sevenDay["utilization"] as? Double ?? 0
            if let resetsAt = sevenDay["resets_at"] as? String {
                usage.weeklyAllModelsResetDate = formatResetDate(isoDate: resetsAt)
            }
        }

        // Seven-day sonnet only
        if let sonnet = json["seven_day_sonnet"] as? [String: Any] {
            usage.weeklySonnetPercent = sonnet["utilization"] as? Double ?? 0
        }

        // Seven-day opus (null for plans without an opus pool)
        if let opus = json["seven_day_opus"] as? [String: Any] {
            usage.weeklyOpusPercent = opus["utilization"] as? Double ?? 0
            usage.hasOpusLimit = true
        }

        // Extra usage (pay-per-use overflow beyond plan limits)
        if let extraUsage = json["extra_usage"] as? [String: Any],
           let isEnabled = extraUsage["is_enabled"] as? Bool, isEnabled {
            usage.planName = "Max (Extra)"
            usage.extraUsageEnabled = true
        }

        // Dynamic per-model pools: any seven_day_<slug> key we don't already
        // model explicitly (fable, mythos, whatever ships next) gets its own
        // row in the Weekly Limits card without a widget update.
        let knownPools: Set<String> = ["seven_day", "seven_day_sonnet", "seven_day_opus"]
        var extras: [(slug: String, percent: Double)] = []
        for (key, value) in json {
            guard key.hasPrefix("seven_day_"), !knownPools.contains(key),
                  let dict = value as? [String: Any] else { continue }
            let slug = String(key.dropFirst("seven_day_".count))
            extras.append((slug: slug, percent: dict["utilization"] as? Double ?? 0))
        }
        usage.extraWeeklyPools = extras.sorted { $0.slug < $1.slug }

        return usage
    }

    // MARK: - Date Helpers

    private func secondsUntil(isoDate: String) -> Int {
        if let date = Self.isoFractional.date(from: isoDate) ?? Self.isoPlain.date(from: isoDate) {
            return max(0, Int(date.timeIntervalSinceNow))
        }
        return 0
    }

    private func formatResetDate(isoDate: String) -> String {
        guard let resetDate = Self.isoFractional.date(from: isoDate) ?? Self.isoPlain.date(from: isoDate) else { return "" }
        return Self.resetDateFormatter.string(from: resetDate)
    }
}

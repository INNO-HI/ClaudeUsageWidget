import Foundation
import Security

// MARK: - Claude Usage Service (OAuth-based)

class ClaudeUsageService {

    private let usageURL = "https://api.anthropic.com/api/oauth/usage"

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

    func readCredentialsFromKeychain() -> OAuthCredentials? {
        // Try file first (no Keychain prompt)
        let filePath = NSHomeDirectory() + "/.claude/.credentials.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            if let creds = parseCredentials(data: data) {
                return creds
            }
        }

        // Fallback: Keychain (triggers permission prompt on first access)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return parseCredentials(data: data)
        }

        return nil
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
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE h:mm a"
                    formatter.locale = Locale(identifier: "en_US")
                    usage.weeklyAllModelsResetDate = formatter.string(from: date)
                }
            }
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
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
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

        // Plan detection from extra_usage
        if let extraUsage = json["extra_usage"] as? [String: Any],
           let isEnabled = extraUsage["is_enabled"] as? Bool, isEnabled {
            usage.planName = "Max (Extra)"
        }

        return usage
    }

    // MARK: - Date Helpers

    private func secondsUntil(isoDate: String) -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoDate) {
            return max(0, Int(date.timeIntervalSinceNow))
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoDate) {
            return max(0, Int(date.timeIntervalSinceNow))
        }

        return 0
    }

    private func formatResetDate(isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: isoDate)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoDate)
        }

        guard let resetDate = date else { return "" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEE h:mm a"
        displayFormatter.locale = Locale(identifier: "en_US")
        return displayFormatter.string(from: resetDate)
    }
}

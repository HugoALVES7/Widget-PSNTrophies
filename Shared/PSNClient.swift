import AppKit
import Foundation
import ImageIO
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PSNTrophies", category: "psn")

enum PSNError: LocalizedError {
    case notConnected
    case invalidNPSSO
    case sessionExpired
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConnected: String(localized: "Not connected. Open the Widget PSNTrophies app to sign in.")
        case .invalidNPSSO: String(localized: "Invalid or expired NPSSO token. Sign in again on playstation.com and get a new token.")
        case .sessionExpired: String(localized: "PlayStation session expired. Sign in again from the app.")
        case let .http(code, url): String(localized: "Error \(code) while contacting \(url).")
        }
    }
}

/// Minimal client for the PlayStation Network trophy API.
struct PSNClient {
    private static let clientID = "09515159-7237-4370-9b40-3806e67c0891"
    private static let basicAuth = "MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A="
    private static let redirectURI = "com.scee.psxandroid.scecompcall://redirect"
    private static let scope = "psn:mobile.v2.core psn:clientapp"
    private static let authBase = "https://ca.account.sony.com/api/authz/v3/oauth"
    private static let apiBase = "https://m.np.playstation.com/api"

    // MARK: - Authentication

    /// Exchanges the NPSSO token (pasted by the user) for access tokens.
    func connect(npsso: String) async throws {
        var comps = URLComponents(string: "\(Self.authBase)/authorize")!
        comps.queryItems = [
            .init(name: "access_type", value: "offline"),
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
        ]
        var request = URLRequest(url: comps.url!)
        request.httpShouldHandleCookies = false
        request.setValue("npsso=\(npsso)", forHTTPHeaderField: "Cookie")

        let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              let location = http.value(forHTTPHeaderField: "Location"),
              let code = URLComponents(string: location)?.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw PSNError.invalidNPSSO }

        try await requestTokens([
            "code": code,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code",
            "token_format": "jwt",
        ])
    }

    private func refresh() async throws {
        guard let refreshToken = SharedStore.refreshToken else { throw PSNError.notConnected }
        do {
            try await requestTokens([
                "refresh_token": refreshToken,
                "grant_type": "refresh_token",
                "scope": Self.scope,
                "token_format": "jwt",
            ])
        } catch PSNError.http(let code, _) where (400 ..< 500).contains(code) {
            throw PSNError.sessionExpired
        }
    }

    private func requestTokens(_ params: [String: String]) async throws {
        var request = URLRequest(url: URL(string: "\(Self.authBase)/token")!)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("Basic \(Self.basicAuth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, url: request.url!)

        struct Tokens: Decodable {
            let access_token: String
            let expires_in: Double
            let refresh_token: String?
            let refresh_token_expires_in: Double?
        }
        let tokens = try JSONDecoder().decode(Tokens.self, from: data)
        SharedStore.accessToken = tokens.access_token
        SharedStore.accessExpiry = Date().addingTimeInterval(tokens.expires_in)
        if let refresh = tokens.refresh_token {
            SharedStore.refreshToken = refresh
            SharedStore.refreshExpiry = tokens.refresh_token_expires_in.map { Date().addingTimeInterval($0) }
        }
    }

    private func validAccessToken() async throws -> String {
        if let token = SharedStore.accessToken,
           let expiry = SharedStore.accessExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }
        try await refresh()
        guard let token = SharedStore.accessToken else { throw PSNError.notConnected }
        return token
    }

    // MARK: - Data

    func fetchSnapshot(recentCount: Int = 4) async throws -> PSNSnapshot {
        let token = try await validAccessToken()

        async let summaryTask: TrophySummary = get("\(Self.apiBase)/trophy/v1/users/me/trophySummary", token: token)
        async let titlesTask = fetchAllTitles(token: token)
        async let profileTask = fetchProfile(token: token)

        let summary = try await summaryTask
        let titles = try await titlesTask
        let profile = await profileTask

        let recent = titles.prefix(recentCount)
        var recentGames: [GameProgress] = []
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, title) in recent.enumerated() {
                group.addTask { (index, await Self.downloadThumbnail(title.trophyTitleIconUrl, maxPixel: 96)) }
            }
            var icons = [Int: Data]()
            for await (index, data) in group { icons[index] = data }
            recentGames = recent.enumerated().map { index, t in
                GameProgress(
                    id: t.npCommunicationId,
                    name: t.trophyTitleName,
                    platform: t.trophyTitlePlatform,
                    progress: t.progress,
                    earned: t.earnedTrophies,
                    defined: t.definedTrophies,
                    lastUpdated: t.lastUpdatedDateTime.flatMap(Self.parseDate),
                    iconData: icons[index]
                )
            }
        }

        let avatar = await Self.downloadThumbnail(profile?.avatarURL, maxPixel: 128)
        log.info("avatar: \(avatar?.count ?? 0, privacy: .public) bytes")
        let average = titles.isEmpty ? 0 : Double(titles.map(\.progress).reduce(0, +)) / Double(titles.count)

        return PSNSnapshot(
            onlineId: profile?.onlineId ?? String(localized: "My profile"),
            avatarData: avatar,
            level: summary.trophyLevel.value,
            levelProgress: summary.progress ?? 0,
            tier: summary.tier ?? 1,
            earned: summary.earnedTrophies,
            totalGames: titles.count,
            completedGames: titles.filter { $0.progress >= 100 }.count,
            averageCompletion: average,
            recentGames: recentGames,
            fetchedAt: Date()
        )
    }

    private func fetchAllTitles(token: String) async throws -> [TrophyTitle] {
        var all: [TrophyTitle] = []
        var offset = 0
        while true {
            let page: TitlesPage = try await get(
                "\(Self.apiBase)/trophy/v1/users/me/trophyTitles?limit=800&offset=\(offset)", token: token)
            all += page.trophyTitles
            guard let next = page.nextOffset, next > offset, all.count < page.totalItemCount else { break }
            offset = next
        }
        return all
    }

    private func fetchProfile(token: String) async -> (onlineId: String, avatarURL: String?)? {
        let rank = ["xl": 4, "l": 3, "m": 2, "s": 1]

        struct Avatar: Decodable { let size: String; let url: String }
        struct Profile: Decodable { let onlineId: String; let avatars: [Avatar]? }
        var onlineId: String?
        do {
            let p: Profile = try await get("\(Self.apiBase)/userProfile/v1/internal/users/me/profiles", token: token)
            onlineId = p.onlineId
            let best = p.avatars?.max { (rank[$0.size] ?? 0) < (rank[$1.size] ?? 0) }?.url
            log.info("profile: \(p.avatars?.count ?? -1, privacy: .public) avatars, url=\(best ?? "nil", privacy: .public)")
            if let best { return (p.onlineId, Self.https(best)) }
        } catch {
            log.error("profile (internal) failed: \(error.localizedDescription, privacy: .public)")
        }

        struct LegacyAvatar: Decodable { let size: String; let avatarUrl: String }
        struct LegacyProfile: Decodable { let onlineId: String; let avatarUrls: [LegacyAvatar]? }
        struct LegacyResponse: Decodable { let profile: LegacyProfile }
        do {
            let r: LegacyResponse = try await get(
                "https://us-prof.np.community.playstation.net/userProfile/v1/users/me/profile2?fields=onlineId,avatarUrls",
                token: token)
            let best = r.profile.avatarUrls?.max { (rank[$0.size] ?? 0) < (rank[$1.size] ?? 0) }?.avatarUrl
            log.info("legacy profile: url=\(best ?? "nil", privacy: .public)")
            return (r.profile.onlineId, best.map(Self.https))
        } catch {
            log.error("profile (legacy) failed: \(error.localizedDescription, privacy: .public)")
        }
        return onlineId.map { ($0, nil) }
    }

    /// Sony avatar URLs are sometimes http://, which macOS blocks.
    private static func https(_ url: String) -> String {
        url.hasPrefix("http://") ? "https://" + url.dropFirst(7) : url
    }

    private func get<T: Decodable>(_ urlString: String, token: String) async throws -> T {
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("fr-FR", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, url: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Helpers

    private static func check(_ response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw PSNError.http(http.statusCode, url.host ?? url.absoluteString)
        }
    }

    private static func parseDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: string)
    }

    /// Downloads an image and downsizes it (widgets have very little memory).
    static func downloadThumbnail(_ urlString: String?, maxPixel: Int) async -> Data? {
        if let urlString, urlString.contains("avatar") || urlString.contains("prof") { log.info("downloading avatar: \(urlString, privacy: .public)") }
        guard let urlString, let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary)
        else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

// MARK: - API responses

private struct FlexibleInt: Decodable {
    let value: Int
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i }
        else if let s = try? c.decode(String.self), let i = Int(s) { value = i }
        else { value = 0 }
    }
}

private struct TrophySummary: Decodable {
    let trophyLevel: FlexibleInt
    let progress: Int?
    let tier: Int?
    let earnedTrophies: TrophyCounts
}

private struct TrophyTitle: Decodable {
    let npCommunicationId: String
    let trophyTitleName: String
    let trophyTitleIconUrl: String?
    let trophyTitlePlatform: String
    let progress: Int
    let earnedTrophies: TrophyCounts
    let definedTrophies: TrophyCounts
    let lastUpdatedDateTime: String?
}

private struct TitlesPage: Decodable {
    let trophyTitles: [TrophyTitle]
    let totalItemCount: Int
    let nextOffset: Int?
}

/// Stops URLSession from following the redirect to the mobile app's URL scheme,
/// so the authorization code can be read from the Location header.
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}

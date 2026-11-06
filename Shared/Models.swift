import Foundation

struct TrophyCounts: Codable, Hashable {
    var bronze = 0
    var silver = 0
    var gold = 0
    var platinum = 0

    var total: Int { bronze + silver + gold + platinum }
}

struct GameProgress: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var platform: String
    var progress: Int
    var earned: TrophyCounts
    var defined: TrophyCounts
    var lastUpdated: Date?
    var iconData: Data?
}

struct PSNSnapshot: Codable, Hashable {
    var onlineId: String
    var avatarData: Data?
    var level: Int
    var levelProgress: Int
    var tier: Int
    var earned: TrophyCounts
    var totalGames: Int
    var completedGames: Int
    var averageCompletion: Double
    var recentGames: [GameProgress]
    var fetchedAt: Date
}

extension PSNSnapshot {
    static let sample = PSNSnapshot(
        onlineId: "Joueur_PSN",
        avatarData: nil,
        level: 427,
        levelProgress: 64,
        tier: 5,
        earned: TrophyCounts(bronze: 3124, silver: 812, gold: 266, platinum: 41),
        totalGames: 138,
        completedGames: 37,
        averageCompletion: 58.4,
        recentGames: [
            GameProgress(id: "1", name: "Astro Bot", platform: "PS5", progress: 100,
                         earned: TrophyCounts(bronze: 30, silver: 10, gold: 4, platinum: 1),
                         defined: TrophyCounts(bronze: 30, silver: 10, gold: 4, platinum: 1)),
            GameProgress(id: "2", name: "Elden Ring", platform: "PS5", progress: 81,
                         earned: TrophyCounts(bronze: 22, silver: 8, gold: 3, platinum: 0),
                         defined: TrophyCounts(bronze: 26, silver: 9, gold: 6, platinum: 1)),
            GameProgress(id: "3", name: "Ghost of Tsushima", platform: "PS5", progress: 47,
                         earned: TrophyCounts(bronze: 20, silver: 5, gold: 1, platinum: 0),
                         defined: TrophyCounts(bronze: 52, silver: 17, gold: 6, platinum: 1)),
            GameProgress(id: "4", name: "Gran Turismo 7", platform: "PS5", progress: 23,
                         earned: TrophyCounts(bronze: 12, silver: 2, gold: 0, platinum: 0),
                         defined: TrophyCounts(bronze: 40, silver: 12, gold: 4, platinum: 1)),
        ],
        fetchedAt: .now
    )
}

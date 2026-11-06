import Foundation

/// Stockage partagé entre l'app et le widget (App Group).
enum SharedStore {
    static var groupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "group.psntrophies"
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    private enum Key {
        static let accessToken = "accessToken"
        static let accessExpiry = "accessExpiry"
        static let refreshToken = "refreshToken"
        static let refreshExpiry = "refreshExpiry"
        static let snapshot = "snapshot"
    }

    static var accessToken: String? {
        get { defaults.string(forKey: Key.accessToken) }
        set { defaults.set(newValue, forKey: Key.accessToken) }
    }

    static var accessExpiry: Date? {
        get { defaults.object(forKey: Key.accessExpiry) as? Date }
        set { defaults.set(newValue, forKey: Key.accessExpiry) }
    }

    static var refreshToken: String? {
        get { defaults.string(forKey: Key.refreshToken) }
        set { defaults.set(newValue, forKey: Key.refreshToken) }
    }

    static var refreshExpiry: Date? {
        get { defaults.object(forKey: Key.refreshExpiry) as? Date }
        set { defaults.set(newValue, forKey: Key.refreshExpiry) }
    }

    static var snapshot: PSNSnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.snapshot) else { return nil }
            return try? JSONDecoder().decode(PSNSnapshot.self, from: data)
        }
        set {
            defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.snapshot)
        }
    }

    static var isConnected: Bool { refreshToken != nil }

    static func clear() {
        for key in [Key.accessToken, Key.accessExpiry, Key.refreshToken, Key.refreshExpiry, Key.snapshot] {
            defaults.removeObject(forKey: key)
        }
    }
}

import SwiftUI
import WidgetKit

/// Les photos suivent le style d'icônes du Mac (couleur, teinté, transparent), comme le Dock.
@ViewBuilder
private func photo(_ image: NSImage) -> some View {
    let base = Image(nsImage: image).resizable()
    if #available(macOS 15.0, *) {
        base.widgetAccentedRenderingMode(.accentedDesaturated).scaledToFill()
    } else {
        base.scaledToFill()
    }
}

// MARK: - Trophées

enum TrophyKind: CaseIterable {
    case platinum, gold, silver, bronze

    var label: String {
        switch self {
        case .platinum: "Platine"
        case .gold: "Or"
        case .silver: "Argent"
        case .bronze: "Bronze"
        }
    }

    var colors: [Color] {
        switch self {
        case .platinum: [Color(red: 0.86, green: 0.92, blue: 1.0), Color(red: 0.55, green: 0.66, blue: 0.84)]
        case .gold: [Color(red: 1.0, green: 0.85, blue: 0.40), Color(red: 0.85, green: 0.58, blue: 0.12)]
        case .silver: [Color(red: 0.90, green: 0.91, blue: 0.93), Color(red: 0.60, green: 0.63, blue: 0.68)]
        case .bronze: [Color(red: 0.93, green: 0.65, blue: 0.43), Color(red: 0.66, green: 0.38, blue: 0.20)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    func count(in counts: TrophyCounts) -> Int {
        switch self {
        case .platinum: counts.platinum
        case .gold: counts.gold
        case .silver: counts.silver
        case .bronze: counts.bronze
        }
    }

    /// Couleur du palier de niveau PSN (1–3 bronze, 4–6 argent, 7–9 or, 10 platine).
    static func forTier(_ tier: Int) -> TrophyKind {
        switch tier {
        case ...3: .bronze
        case 4 ... 6: .silver
        case 7 ... 9: .gold
        default: .platinum
        }
    }
}

struct TrophyIcon: View {
    let kind: TrophyKind
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(kind.gradient)
            .shadow(color: kind.colors[1].opacity(0.35), radius: 1.5, y: 1)
    }
}

struct TrophyStat: View {
    let kind: TrophyKind
    let count: Int
    var iconSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 8) {
            TrophyIcon(kind: kind, size: iconSize)
                .frame(width: iconSize + 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(count, format: .number)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(kind.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Niveau

struct LevelRing: View {
    let level: Int
    let progress: Int
    let tier: Int
    var size: CGFloat = 64

    var body: some View {
        let kind = TrophyKind.forTier(tier)
        let line = max(4, size * 0.08)
        ZStack {
            Circle().stroke(.quaternary, lineWidth: line)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 100)) / 100)
                .stroke(AngularGradient(colors: kind.colors + [kind.colors[0]], center: .center),
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(level)")
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("NIVEAU")
                    .font(.system(size: max(7, size * 0.11), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(line * 1.5)
        }
        .frame(width: size, height: size)
    }
}

struct AvatarView: View {
    let data: Data?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                photo(image)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Tailles du widget

struct SmallTrophyView: View {
    let snapshot: PSNSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                AvatarView(data: snapshot.avatarData, size: 20)
                Text(snapshot.onlineId)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            HStack(alignment: .center) {
                LevelRing(level: snapshot.level, progress: snapshot.levelProgress, tier: snapshot.tier, size: 62)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    TrophyIcon(kind: .platinum, size: 22)
                    Text(snapshot.earned.platinum, format: .number)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text("\(snapshot.earned.total.formatted()) trophées")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct MediumTrophyView: View {
    let snapshot: PSNSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                LevelRing(level: snapshot.level, progress: snapshot.levelProgress, tier: snapshot.tier, size: 76)
                Text(snapshot.onlineId)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(snapshot.earned.total.formatted()) trophées")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 104)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    TrophyStat(kind: .platinum, count: snapshot.earned.platinum)
                    TrophyStat(kind: .gold, count: snapshot.earned.gold)
                }
                GridRow {
                    TrophyStat(kind: .silver, count: snapshot.earned.silver)
                    TrophyStat(kind: .bronze, count: snapshot.earned.bronze)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LargeTrophyView: View {
    let snapshot: PSNSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(data: snapshot.avatarData, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.onlineId)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(snapshot.earned.total.formatted()) trophées")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LevelRing(level: snapshot.level, progress: snapshot.levelProgress, tier: snapshot.tier, size: 50)
            }

            Spacer(minLength: 16)

            HStack {
                ForEach(TrophyKind.allCases, id: \.self) { kind in
                    VStack(spacing: 4) {
                        TrophyIcon(kind: kind, size: 22)
                        Text(kind.count(in: snapshot.earned), format: .number)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text(kind.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 14)

            HStack(spacing: 0) {
                InlineStat(value: snapshot.totalGames.formatted(), label: "jeux")
                InlineStat(value: snapshot.completedGames.formatted(), label: "à 100 %")
                InlineStat(value: "\(Int(snapshot.averageCompletion.rounded())) %", label: "moyenne")
            }

            Spacer(minLength: 16)

            Text("RÉCEMMENT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 10) {
                ForEach(snapshot.recentGames.prefix(3)) { game in
                    GameRow(game: game)
                }
            }
        }
    }
}

struct InlineStat: View {
    let value: String
    let label: String

    var body: some View {
        (Text(value).fontWeight(.semibold) + Text(" \(label)").foregroundStyle(.secondary))
            .font(.caption)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct GameRow: View {
    let game: GameProgress

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let data = game.iconData, let image = NSImage(data: data) {
                    photo(image)
                } else {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.fill.tertiary)
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(game.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    if game.earned.platinum > 0 {
                        TrophyIcon(kind: .platinum, size: 9)
                    }
                    Spacer(minLength: 4)
                    Text("\(game.progress) %")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressBar(value: Double(game.progress) / 100,
                            kind: game.progress >= 100 ? .platinum : .gold)
            }
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let kind: TrophyKind

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.fill.tertiary)
                Capsule()
                    .fill(kind.gradient)
                    .frame(width: max(4, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
    }
}

struct DisconnectedView: View {
    var message = "Ouvre l'app Trophées PSN pour te connecter."

    var body: some View {
        VStack(spacing: 8) {
            TrophyIcon(kind: .platinum, size: 28)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

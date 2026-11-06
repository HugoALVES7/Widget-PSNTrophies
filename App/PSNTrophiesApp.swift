import SwiftUI
import WidgetKit

@main
struct PSNTrophiesApp: App {
    init() {
        // `--render-preview <dossier>` : exporte des aperçus PNG des 3 tailles puis quitte.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-preview"), i + 1 < args.count {
            PreviewRenderer.render(to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup("Trophées PSN") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

/// Simule l'apparence d'un widget du bureau (tailles macOS).
struct WidgetFrame<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(width: width, height: height)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }
}

@MainActor
enum PreviewRenderer {
    static func render(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let s = sampleWithImages()
        for scheme in [ColorScheme.light, .dark] {
            let wallpaper = scheme == .dark
                ? [Color(red: 0.10, green: 0.10, blue: 0.25), Color(red: 0.32, green: 0.20, blue: 0.48)]
                : [Color(red: 0.74, green: 0.84, blue: 0.98), Color(red: 0.96, green: 0.80, blue: 0.88)]
            let view = HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) {
                    WidgetFrame(width: 170, height: 170) { SmallTrophyView(snapshot: s) }
                    WidgetFrame(width: 364, height: 170) { MediumTrophyView(snapshot: s) }
                }
                WidgetFrame(width: 364, height: 382) { LargeTrophyView(snapshot: s) }
            }
            .padding(36)
            .background(LinearGradient(colors: wallpaper, startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, scheme)
            write(view, to: folder.appendingPathComponent("widgets-\(scheme == .dark ? "dark" : "light").png"))
        }
    }

    private static func write(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }

    /// Données fictives + fausses jaquettes (dégradés) pour les captures du README.
    private static func sampleWithImages() -> PSNSnapshot {
        func tile(_ colors: [Color], _ symbol: String, circle: Bool = false) -> Data? {
            let view = ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol).font(.system(size: 44, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 96, height: 96)
            .clipShape(circle ? AnyShape(Circle()) : AnyShape(Rectangle()))
            let r = ImageRenderer(content: view)
            guard let tiff = r.nsImage?.tiffRepresentation else { return nil }
            return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        }
        var s = PSNSnapshot.sample
        s.avatarData = tile([.orange, .pink], "person.fill", circle: true)
        let tiles: [([Color], String)] = [
            ([.cyan, .blue], "sparkles"), ([.yellow, .orange], "flame.fill"),
            ([.mint, .green], "leaf.fill"), ([.purple, .indigo], "car.fill"),
        ]
        for i in s.recentGames.indices where i < tiles.count {
            s.recentGames[i].iconData = tile(tiles[i].0, tiles[i].1)
        }
        return s
    }
}

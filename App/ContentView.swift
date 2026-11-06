import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var npsso = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var connected = SharedStore.isConnected
    @State private var snapshot = SharedStore.snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                TrophyIcon(kind: .platinum, size: 28)
                VStack(alignment: .leading) {
                    Text("PSN Trophies").font(.title2.bold())
                    (connected ? Text("Connected — the widget updates on its own.") : Text("Connect your PlayStation account"))
                        .foregroundStyle(.secondary)
                }
            }

            if connected {
                connectedSection
            } else {
                setupSection
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(24)
        .frame(width: 780)
        .task { if connected { refresh() } }
    }

    // MARK: Sign in

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Step(number: 1) {
                Text("Sign in to your account on ") + Text("[playstation.com](https://www.playstation.com/)")
            }
            Step(number: 2) {
                Text("In the same browser, open ") +
                    Text("[ca.account.sony.com/api/v1/ssocookie](https://ca.account.sony.com/api/v1/ssocookie)")
            }
            Step(number: 3) {
                Text("Copy the “npsso” value (64 characters) or the whole page, and paste it here:")
            }
            HStack {
                SecureField("NPSSO token", text: $npsso)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
                Button(action: connect) {
                    if isBusy { ProgressView().controlSize(.small) } else { Text("Connect") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(npsso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }
            Text("The token is only sent to Sony’s servers. The app only keeps a refresh token (valid for about 2 months), stored on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Connected

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let s = snapshot ?? .sample
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) {
                    WidgetFrame(width: 170, height: 170) { SmallTrophyView(snapshot: s) }
                    WidgetFrame(width: 364, height: 170) { MediumTrophyView(snapshot: s) }
                }
                WidgetFrame(width: 364, height: 382) { LargeTrophyView(snapshot: s) }
            }

            HStack {
                if let date = snapshot?.fetchedAt {
                    Text("Last updated: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sign Out", role: .destructive) {
                    SharedStore.clear()
                    snapshot = nil
                    connected = false
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button(action: refresh) {
                    if isBusy { ProgressView().controlSize(.small) } else { Label("Refresh", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
            }

            Text("To add the widget: right-click the desktop → Edit Widgets… → search for “PSN Trophies”.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func connect() {
        let token = Self.extractNPSSO(from: npsso)
        guard !token.isEmpty else { return }
        run {
            try await PSNClient().connect(npsso: token)
            npsso = ""
            connected = true
            try await loadSnapshot()
        }
    }

    private func refresh() {
        run { try await loadSnapshot() }
    }

    private func loadSnapshot() async throws {
        let fresh = try await PSNClient().fetchSnapshot()
        SharedStore.snapshot = fresh
        snapshot = fresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isBusy = true
        errorMessage = nil
        Task {
            do { try await work() } catch {
                errorMessage = error.localizedDescription
                if case PSNError.sessionExpired = error {
                    SharedStore.clear()
                    connected = false
                }
            }
            isBusy = false
        }
    }

    /// Accepts either the bare token or the full JSON `{"npsso":"..."}`.
    static func extractNPSSO(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = json["npsso"] as? String {
            return value
        }
        return trimmed
    }
}

private struct Step<Content: View>: View {
    let number: Int
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            content
        }
    }
}

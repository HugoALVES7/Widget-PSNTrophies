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
                    Text("Trophées PSN").font(.title2.bold())
                    Text(connected ? "Connecté — le widget se met à jour tout seul." : "Connecte ton compte PlayStation")
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

    // MARK: Connexion

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Step(number: 1) {
                Text("Connecte-toi à ton compte sur ") + Text("[playstation.com](https://www.playstation.com/)")
            }
            Step(number: 2) {
                Text("Dans le même navigateur, ouvre ") +
                    Text("[ca.account.sony.com/api/v1/ssocookie](https://ca.account.sony.com/api/v1/ssocookie)")
            }
            Step(number: 3) {
                Text("Copie la valeur de « npsso » (64 caractères) ou toute la page, et colle-la ici :")
            }
            HStack {
                SecureField("Jeton NPSSO", text: $npsso)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
                Button(action: connect) {
                    if isBusy { ProgressView().controlSize(.small) } else { Text("Connecter") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(npsso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }
            Text("Le jeton n'est envoyé qu'aux serveurs de Sony. L'app ne garde qu'un jeton de rafraîchissement (valable environ 2 mois), stocké sur ce Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Connecté

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
                    Text("Dernière mise à jour : \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Se déconnecter", role: .destructive) {
                    SharedStore.clear()
                    snapshot = nil
                    connected = false
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button(action: refresh) {
                    if isBusy { ProgressView().controlSize(.small) } else { Label("Actualiser", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
            }

            Text("Pour ajouter le widget : clic droit sur le bureau → Modifier les widgets… → cherche « Trophées PSN ».")
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

    /// Accepte soit le jeton seul, soit le JSON complet `{"npsso":"..."}`.
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

import SwiftUI
import ServiceManagement

struct VueReglages: View {
    @ObservedObject var moniteur: MoniteurGestes
    @ObservedObject var delegue: DelegueApp
    @ObservedObject var maj: GestionnaireMAJ
    @ObservedObject private var reglages = Reglages.partage
    @State private var auDemarrage = SMAppService.mainApp.status == .enabled
    @State private var erreurDemarrage: String?

    var body: some View {
        Form {
            Section("Geste") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $reglages.seuil, in: 0.04...0.30) {
                        Text("Amplitude")
                    } minimumValueLabel: {
                        Text("Court").font(.caption)
                    } maximumValueLabel: {
                        Text("Long").font(.caption)
                    }
                    Text("Distance à parcourir, trois doigts sur le trackpad, "
                         + "avant que la fenêtre ne descende dans le Dock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Test") { indicateur }

                Toggle("Agir aussi sur les fenêtres d’applications en arrière-plan",
                       isOn: $reglages.toutesLesFenetres)
            }

            Section("Système") {
                LabeledContent("Accessibilité") {
                    HStack(spacing: 8) {
                        Image(systemName: delegue.autorise
                              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(delegue.autorise ? .green : .orange)
                        Text(delegue.autorise ? "Accordée" : "Requise")
                        if !delegue.autorise {
                            Button("Ouvrir les Réglages Système") {
                                Autorisations.ouvrirReglagesSysteme()
                            }
                        }
                    }
                }

                Toggle("Lancer au démarrage", isOn: $auDemarrage)
                    .onChange(of: auDemarrage) { _, nouvelle in basculerDemarrage(nouvelle) }

                if let erreurDemarrage {
                    Text(erreurDemarrage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Mises à jour") {
                Toggle("Vérifier automatiquement chaque jour", isOn: $reglages.majAutomatique)

                LabeledContent("Version \(maj.versionActuelle)") { zoneMAJ }

                Link("Voir les versions publiées", destination: maj.pageDesVersions)
                    .font(.caption)
            }

            Section {
                Text("Si macOS déclenche aussi Exposé ou Mission Control, réglez ces gestes sur "
                     + "quatre doigts dans Réglages Système › Trackpad › Gestes supplémentaires.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 470)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { moniteur.surveillance = true }
        .onDisappear { moniteur.surveillance = false }
    }

    private var indicateur: some View {
        HStack(spacing: 10) {
            Text("\(moniteur.nombreDoigts) doigt\(moniteur.nombreDoigts > 1 ? "s" : "")")
                .monospacedDigit()
                .foregroundStyle(moniteur.nombreDoigts == 3 ? .primary : .secondary)
            ProgressView(value: moniteur.progression)
                .frame(width: 140)
        }
    }

    @ViewBuilder
    private var zoneMAJ: some View {
        switch maj.etat {
        case .repos:
            Button("Rechercher") { Task { await maj.verifier() } }
        case .verification:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Recherche…").foregroundStyle(.secondary)
            }
        case .aJour:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("À jour")
                Button("Rechercher") { Task { await maj.verifier() } }
            }
        case .disponible(let version):
            HStack(spacing: 8) {
                Text("\(version) disponible").bold()
                Button("Installer et relancer") { Task { await maj.installer() } }
            }
        case .telechargement:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Téléchargement…").foregroundStyle(.secondary)
            }
        case .installation:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Installation…").foregroundStyle(.secondary)
            }
        case .erreur(let message):
            HStack(spacing: 8) {
                Text(message).font(.caption).foregroundStyle(.orange)
                Button("Réessayer") { Task { await maj.verifier() } }
            }
        }
    }

    private func basculerDemarrage(_ actif: Bool) {
        erreurDemarrage = nil
        do {
            if actif {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            erreurDemarrage = "Impossible de modifier le lancement au démarrage : "
                            + error.localizedDescription
            auDemarrage = SMAppService.mainApp.status == .enabled
        }
    }
}

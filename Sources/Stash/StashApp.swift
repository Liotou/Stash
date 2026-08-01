import SwiftUI

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(DelegueApp.self) private var delegue

    var body: some Scene {
        MenuBarExtra {
            VueMenu(delegue: delegue, maj: delegue.maj)
        } label: {
            Image(systemName: "tray.and.arrow.down")
        }

        Settings {
            VueReglages(moniteur: delegue.moniteur, delegue: delegue, maj: delegue.maj)
        }
    }
}

private struct VueMenu: View {
    @ObservedObject var delegue: DelegueApp
    @ObservedObject var maj: GestionnaireMAJ

    var body: some View {
        if !delegue.autorise {
            Button("Autoriser l’accessibilité…") { Autorisations.ouvrirReglagesSysteme() }
            Divider()
        }

        if case .disponible(let version) = maj.etat {
            SettingsLink { Text("Mise à jour disponible : \(version)") }
            Divider()
        }

        SettingsLink { Text("Réglages…") }
            .keyboardShortcut(",", modifiers: .command)

        Button("Quitter Stash") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}

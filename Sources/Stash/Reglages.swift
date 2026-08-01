import Foundation

/// Préférences partagées, persistées dans UserDefaults.
final class Reglages: ObservableObject {
    static let partage = Reglages()

    private enum Cle {
        static let seuil = "seuil"
        static let toutesLesFenetres = "toutesLesFenetres"
        static let majAutomatique = "majAutomatique"
    }

    /// Distance verticale à parcourir, en fraction de la hauteur du trackpad (0,04 à 0,30).
    @Published var seuil: Double {
        didSet { UserDefaults.standard.set(seuil, forKey: Cle.seuil) }
    }

    /// Si faux, on ignore les fenêtres qui n'appartiennent pas à l'application active.
    @Published var toutesLesFenetres: Bool {
        didSet { UserDefaults.standard.set(toutesLesFenetres, forKey: Cle.toutesLesFenetres) }
    }

    /// Vérification quotidienne des nouvelles versions publiées sur GitHub.
    @Published var majAutomatique: Bool {
        didSet { UserDefaults.standard.set(majAutomatique, forKey: Cle.majAutomatique) }
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Cle.seuil: 0.12,
            Cle.toutesLesFenetres: true,
            Cle.majAutomatique: true
        ])
        seuil = d.double(forKey: Cle.seuil)
        toutesLesFenetres = d.bool(forKey: Cle.toutesLesFenetres)
        majAutomatique = d.bool(forKey: Cle.majAutomatique)
    }
}

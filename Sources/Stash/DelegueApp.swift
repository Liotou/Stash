import AppKit

@MainActor
final class DelegueApp: NSObject, NSApplicationDelegate, ObservableObject {

    let moniteur = MoniteurGestes()
    let maj = GestionnaireMAJ()
    private let reglages = Reglages.partage
    private var minuterieAutorisation: Timer?

    @Published private(set) var autorise = Autorisations.accessibiliteAccordee

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        moniteur.action = { [weak self] in
            guard let self else { return }
            AbaisseurFenetre.abaisserSousCurseur(toutesLesFenetres: self.reglages.toutesLesFenetres)
        }

        if !autorise {
            Autorisations.demanderAccessibilite()
        }
        demarrerLeGeste()

        if reglages.majAutomatique {
            maj.demarrerVerificationsAutomatiques()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        moniteur.arreter()
    }

    /// Le geste est la raison d'être de l'application : il tourne dès que l'autorisation
    /// d'accessibilité le permet, sans interrupteur.
    func demarrerLeGeste() {
        autorise = Autorisations.accessibiliteAccordee
        if !autorise || !moniteur.demarrer() {
            surveillerAutorisation()
        }
    }

    /// L'autorisation ne peut pas être attendue de façon synchrone : on repasse
    /// régulièrement jusqu'à ce que l'utilisateur l'accorde dans Réglages Système.
    private func surveillerAutorisation() {
        guard minuterieAutorisation == nil else { return }
        minuterieAutorisation = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {
            [weak self] minuterie in
            MainActor.assumeIsolated {
                guard let self else { minuterie.invalidate(); return }
                guard Autorisations.accessibiliteAccordee else { return }
                minuterie.invalidate()
                self.minuterieAutorisation = nil
                self.demarrerLeGeste()
            }
        }
    }
}

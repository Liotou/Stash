import AppKit
import ApplicationServices

/// Gestion de l'autorisation d'accessibilité, indispensable à la fois pour écouter
/// les gestes et pour agir sur les fenêtres des autres applications.
enum Autorisations {

    static var accessibiliteAccordee: Bool {
        AXIsProcessTrusted()
    }

    /// Affiche la demande système (une seule fois par application non autorisée).
    @discardableResult
    static func demanderAccessibilite() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func ouvrirReglagesSysteme() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

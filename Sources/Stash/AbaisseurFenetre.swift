import AppKit
import ApplicationServices

/// Trouve la fenêtre située sous le curseur et la réduit dans le Dock.
/// Le Dock étant partagé avec Stage Manager, le même geste fonctionne dans les deux cas.
enum AbaisseurFenetre {

    enum Resultat {
        case reussite
        case aucuneFenetre
        case refusee          // la fenêtre ne se laisse pas réduire (palette, fenêtre système…)
        case pasAutorise      // accessibilité non accordée
    }

    @discardableResult
    static func abaisserSousCurseur(toutesLesFenetres: Bool) -> Resultat {
        guard Autorisations.accessibiliteAccordee else { return .pasAutorise }

        let point = positionCurseur()
        guard let fenetre = fenetreALaPosition(point) else { return .aucuneFenetre }

        var pid: pid_t = 0
        guard AXUIElementGetPid(fenetre, &pid) == .success else { return .aucuneFenetre }

        // Ne jamais s'abaisser soi-même, ni toucher au Dock.
        guard pid != ProcessInfo.processInfo.processIdentifier else { return .aucuneFenetre }
        let application = NSRunningApplication(processIdentifier: pid)
        if application?.bundleIdentifier == "com.apple.dock" { return .aucuneFenetre }

        if !toutesLesFenetres, application?.isActive != true { return .aucuneFenetre }

        return reduire(fenetre)
    }

    // MARK: - Fenêtre sous le curseur

    /// Position du curseur en coordonnées globales Quartz (origine en haut à gauche),
    /// celles qu'attend l'API d'accessibilité.
    private static func positionCurseur() -> CGPoint {
        if let point = CGEvent(source: nil)?.location { return point }
        let cocoa = NSEvent.mouseLocation
        let hauteurPrincipale = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: cocoa.x, y: hauteurPrincipale - cocoa.y)
    }

    private static func fenetreALaPosition(_ point: CGPoint) -> AXUIElement? {
        let systeme = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systeme, Float(point.x), Float(point.y), &element)
                == .success, var courant = element else { return nil }

        // On remonte la hiérarchie jusqu'à trouver la fenêtre qui contient l'élément visé.
        for _ in 0..<15 {
            if chaine(courant, attribut: kAXRoleAttribute) == kAXWindowRole as String {
                return estFenetreUtilisateur(courant) ? courant : nil
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(courant, kAXParentAttribute as CFString, &parent)
                    == .success, let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else {
                return nil
            }
            courant = unsafeBitCast(parent, to: AXUIElement.self)
        }
        return nil
    }

    /// Écarte le bureau du Finder, les fenêtres système et autres surfaces non réductibles.
    private static func estFenetreUtilisateur(_ fenetre: AXUIElement) -> Bool {
        let sousRole = chaine(fenetre, attribut: kAXSubroleAttribute)
        let acceptees: Set<String> = [
            kAXStandardWindowSubrole as String,
            kAXDialogSubrole as String,
            kAXFloatingWindowSubrole as String
        ]
        if let sousRole { return acceptees.contains(sousRole) }
        // Pas de sous-rôle annoncé : on accepte si la fenêtre expose un bouton de réduction.
        var bouton: CFTypeRef?
        return AXUIElementCopyAttributeValue(
            fenetre, kAXMinimizeButtonAttribute as CFString, &bouton) == .success
    }

    // MARK: - Actions

    private static func reduire(_ fenetre: AXUIElement) -> Resultat {
        var modifiable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(fenetre, kAXMinimizedAttribute as CFString, &modifiable)
        guard modifiable.boolValue else { return .refusee }

        let code = AXUIElementSetAttributeValue(
            fenetre, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        return code == .success ? .reussite : .refusee
    }

    private static func chaine(_ element: AXUIElement, attribut: String) -> String? {
        var valeur: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribut as CFString, &valeur) == .success,
              let valeur, CFGetTypeID(valeur) == CFStringGetTypeID() else { return nil }
        return (valeur as! CFString) as String
    }
}

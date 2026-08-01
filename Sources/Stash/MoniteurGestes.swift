import AppKit

/// Écoute les événements de geste du trackpad au niveau de la session et reconnaît
/// un glissement de trois doigts vers le bas.
///
/// Le principe : un `CGEventTap` en écoute seule intercepte les événements de type
/// `NSEvent.EventType.gesture`, que macOS émet dès que des doigts touchent le trackpad.
/// On y relit les touches brutes (`NSTouch`) pour suivre nous-mêmes les trois doigts,
/// plutôt que de dépendre des gestes préconfigurés du système.
final class MoniteurGestes: ObservableObject {

    /// Appelé sur le fil principal quand le geste est reconnu.
    var action: (() -> Void)?

    /// Nombre de doigts actuellement posés (alimenté seulement si `surveillance` est vrai).
    @Published private(set) var nombreDoigts = 0
    /// Avancement du geste en cours, de 0 à 1 (idem).
    @Published private(set) var progression: Double = 0
    /// À activer quand la fenêtre de réglages est visible, pour l'indicateur de test.
    var surveillance = false

    private(set) var enMarche = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var depart: [NSObject: CGPoint] = [:]
    private var declenche = false
    private var dernierDeclenchement: TimeInterval = 0

    /// Types NSEvent : 19 = beginGesture, 20 = endGesture, 29 = gesture.
    private static let masque: CGEventMask =
        (1 << 19) | (1 << 20) | (1 << 29)

    // MARK: - Cycle de vie

    @discardableResult
    func demarrer() -> Bool {
        guard !enMarche else { return true }

        let pointeur = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.masque,
            callback: { _, type, event, refcon in
                if let refcon {
                    Unmanaged<MoniteurGestes>.fromOpaque(refcon)
                        .takeUnretainedValue()
                        .traiter(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointeur
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        enMarche = true
        return true
    }

    func arreter() {
        guard enMarche, let tap, let source else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        reinitialiser()
        enMarche = false
    }

    // MARK: - Reconnaissance

    private func traiter(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        let touches = nsEvent.touches(matching: .touching, in: nil)

        guard touches.count == 3 else {
            if !touches.isEmpty || !depart.isEmpty { reinitialiser(doigts: touches.count) }
            return
        }

        // Le geste a déjà agi : on attend que les doigts se lèvent.
        guard !declenche else { return }

        var sommeX: CGFloat = 0
        var sommeY: CGFloat = 0
        var suivis = 0

        for touche in touches {
            guard let cle = touche.identity as? NSObject else { continue }
            let position = touche.normalizedPosition
            if let origine = depart[cle] {
                sommeX += position.x - origine.x
                sommeY += position.y - origine.y
                suivis += 1
            } else {
                depart[cle] = position
            }
        }

        // Un doigt vient de rejoindre les autres : on repart de cette configuration.
        guard suivis == 3, depart.count == 3 else {
            if depart.count > 3 { depart.removeAll() }
            publier(doigts: 3, avancement: 0)
            return
        }

        let dy = sommeY / 3          // négatif = vers le bas
        let dx = sommeX / 3
        let seuil = max(0.02, Reglages.partage.seuil)

        publier(doigts: 3, avancement: min(1, Double(max(0, -dy) / CGFloat(seuil))))

        // Assez descendu, et nettement plus vertical qu'horizontal.
        guard -dy >= CGFloat(seuil), -dy > 1.6 * abs(dx) else { return }

        let maintenant = Date.timeIntervalSinceReferenceDate
        guard maintenant - dernierDeclenchement > 0.4 else { return }
        dernierDeclenchement = maintenant
        declenche = true

        DispatchQueue.main.async { [weak self] in self?.action?() }
    }

    private func reinitialiser(doigts: Int = 0) {
        depart.removeAll()
        declenche = false
        publier(doigts: doigts, avancement: 0)
    }

    private func publier(doigts: Int, avancement: Double) {
        guard surveillance else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.nombreDoigts != doigts { self.nombreDoigts = doigts }
            if abs(self.progression - avancement) > 0.01 || avancement == 0 {
                self.progression = avancement
            }
        }
    }
}

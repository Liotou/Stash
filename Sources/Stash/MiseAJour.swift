import AppKit

/// Vérifie les versions publiées sur GitHub et installe la plus récente.
///
/// Aucune clé ni jeton : l'API publique des « releases » suffit tant que le dépôt est public.
/// L'installation télécharge l'archive de la publication, la décompresse, remplace le bundle
/// courant puis relance l'application.
@MainActor
final class GestionnaireMAJ: ObservableObject {

    static let depot = "Liotou/Stash"

    enum Etat: Equatable {
        case repos
        case verification
        case aJour
        case disponible(String)
        case telechargement
        case installation
        case erreur(String)
    }

    @Published private(set) var etat: Etat = .repos

    private var publication: Publication?
    private var minuterie: Timer?

    var versionActuelle: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var pageDesVersions: URL {
        URL(string: "https://github.com/\(Self.depot)/releases")!
    }

    // MARK: - Vérification

    func demarrerVerificationsAutomatiques() {
        minuterie?.invalidate()
        minuterie = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.verifier(silencieux: true) }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            await verifier(silencieux: true)
        }
    }

    func arreterVerificationsAutomatiques() {
        minuterie?.invalidate()
        minuterie = nil
    }

    func verifier(silencieux: Bool = false) async {
        if silencieux && !Reglages.partage.majAutomatique { return }
        if !silencieux { etat = .verification }
        do {
            let derniere = try await recupererDernierePublication()
            publication = derniere
            if Self.estPlusRecente(derniere.version, que: versionActuelle) {
                etat = .disponible(derniere.version)
            } else if !silencieux {
                etat = .aJour
            } else {
                etat = .repos
            }
        } catch {
            if !silencieux { etat = .erreur(error.localizedDescription) }
        }
    }

    private func recupererDernierePublication() async throws -> Publication {
        var requete = URLRequest(
            url: URL(string: "https://api.github.com/repos/\(Self.depot)/releases/latest")!)
        requete.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        requete.setValue("Stash/\(versionActuelle)", forHTTPHeaderField: "User-Agent")
        requete.cachePolicy = .reloadIgnoringLocalCacheData

        let (donnees, reponse) = try await URLSession.shared.data(for: requete)
        guard let http = reponse as? HTTPURLResponse, http.statusCode == 200 else {
            throw Erreur.reseau((reponse as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(Publication.self, from: donnees)
    }

    /// Compare deux numéros de version « 1.2.3 », en ignorant un éventuel préfixe « v ».
    static func estPlusRecente(_ candidate: String, que reference: String) -> Bool {
        func morceaux(_ texte: String) -> [Int] {
            texte.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                 .split(separator: ".")
                 .map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        }
        let a = morceaux(candidate), b = morceaux(reference)
        for indice in 0..<max(a.count, b.count) {
            let gauche = indice < a.count ? a[indice] : 0
            let droite = indice < b.count ? b[indice] : 0
            if gauche != droite { return gauche > droite }
        }
        return false
    }

    // MARK: - Installation

    func installer() async {
        guard let publication, let archive = publication.archive else {
            etat = .erreur("Cette version ne fournit pas d’archive téléchargeable.")
            return
        }
        etat = .telechargement
        do {
            let dossier = try dossierTemporaire()
            let (fichier, _) = try await URLSession.shared.download(from: archive)
            let zip = dossier.appendingPathComponent("Stash.zip")
            try FileManager.default.moveItem(at: fichier, to: zip)

            etat = .installation
            let extrait = dossier.appendingPathComponent("extrait")
            try executer("/usr/bin/ditto", ["-x", "-k", zip.path, extrait.path])

            guard let nouvelle = try trouverBundle(dans: extrait) else {
                throw Erreur.archiveInvalide
            }
            let identifiant = Bundle(url: nouvelle)?.bundleIdentifier
            guard identifiant == Bundle.main.bundleIdentifier else {
                throw Erreur.identifiantInattendu(identifiant ?? "inconnu")
            }

            try remplacerEtRelancer(par: nouvelle, dossierTemporaire: dossier)
        } catch {
            etat = .erreur(error.localizedDescription)
        }
    }

    /// Le bundle ne peut pas se remplacer lui-même pendant qu'il tourne : un petit script
    /// attend la fin du processus, échange les dossiers puis rouvre l'application.
    private func remplacerEtRelancer(par nouvelle: URL, dossierTemporaire: URL) throws {
        let destination = Bundle.main.bundleURL
        let script = dossierTemporaire.appendingPathComponent("maj.sh")
        let contenu = """
        #!/bin/sh
        while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
            /bin/sleep 0.2
        done
        # L'archive vient d'Internet : sans cela, Gatekeeper refuserait la copie signée ad hoc.
        /usr/bin/xattr -dr com.apple.quarantine "\(nouvelle.path)"
        /bin/rm -rf "\(destination.path)"
        /usr/bin/ditto "\(nouvelle.path)" "\(destination.path)"
        /usr/bin/open "\(destination.path)"
        /bin/rm -rf "\(dossierTemporaire.path)"
        """
        try contenu.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: script.path)

        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/bin/sh")
        processus.arguments = [script.path]
        try processus.run()

        NSApp.terminate(nil)
    }

    private func dossierTemporaire() throws -> URL {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("maj-stash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier
    }

    private func trouverBundle(dans dossier: URL) throws -> URL? {
        let contenu = try FileManager.default.contentsOfDirectory(
            at: dossier, includingPropertiesForKeys: nil)
        if let direct = contenu.first(where: { $0.pathExtension == "app" }) { return direct }
        for sousDossier in contenu where sousDossier.hasDirectoryPath {
            if let trouve = try trouverBundle(dans: sousDossier) { return trouve }
        }
        return nil
    }

    @discardableResult
    private func executer(_ outil: String, _ arguments: [String]) throws -> Int32 {
        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: outil)
        processus.arguments = arguments
        try processus.run()
        processus.waitUntilExit()
        guard processus.terminationStatus == 0 else {
            throw Erreur.commandeEchouee(outil, processus.terminationStatus)
        }
        return processus.terminationStatus
    }

    // MARK: - Modèle

    struct Publication: Decodable {
        let version: String
        let notes: String?
        let actifs: [Actif]

        var archive: URL? {
            actifs.first { $0.nom.hasSuffix(".zip") }.flatMap { URL(string: $0.url) }
        }

        struct Actif: Decodable {
            let nom: String
            let url: String

            enum CodingKeys: String, CodingKey {
                case nom = "name"
                case url = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case version = "tag_name"
            case notes = "body"
            case actifs = "assets"
        }
    }

    enum Erreur: LocalizedError {
        case reseau(Int)
        case archiveInvalide
        case identifiantInattendu(String)
        case commandeEchouee(String, Int32)

        var errorDescription: String? {
            switch self {
            case .reseau(404):
                return "Aucune version publiée sur GitHub pour l’instant."
            case .reseau(let code):
                return "GitHub a répondu par le code \(code)."
            case .archiveInvalide:
                return "L’archive téléchargée ne contient pas d’application."
            case .identifiantInattendu(let identifiant):
                return "L’application téléchargée ne correspond pas à Stash (\(identifiant))."
            case .commandeEchouee(let outil, let code):
                return "\(outil) a échoué (code \(code))."
            }
        }
    }
}

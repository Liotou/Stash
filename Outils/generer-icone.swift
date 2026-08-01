// Génère Ressources/Stash.icns : pastille dégradée + symbole « ranger dans le tiroir ».
// Usage : swift Outils/generer-icone.swift
import AppKit

let racine = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = racine.appendingPathComponent("Stash.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let hautDegrade = NSColor(srgbRed: 0.42, green: 0.47, blue: 0.98, alpha: 1)
let basDegrade  = NSColor(srgbRed: 0.24, green: 0.20, blue: 0.72, alpha: 1)

func dessiner(cote: Int) -> NSBitmapImageRep {
    let c = CGFloat(cote)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: cote, pixelsHigh: cote,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: c, height: c)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Pastille arrondie, marge conforme aux gabarits d'icônes macOS.
    let marge = c * 0.055
    let cadre = NSRect(x: marge, y: marge, width: c - 2 * marge, height: c - 2 * marge)
    let pastille = NSBezierPath(roundedRect: cadre,
                                xRadius: cadre.width * 0.225,
                                yRadius: cadre.height * 0.225)
    NSGradient(starting: hautDegrade, ending: basDegrade)!.draw(in: pastille, angle: -90)

    // Liseré clair sur le bord supérieur, pour le relief.
    NSColor(white: 1, alpha: 0.18).setStroke()
    pastille.lineWidth = max(1, c * 0.006)
    pastille.stroke()

    // Symbole blanc au centre.
    let config = NSImage.SymbolConfiguration(pointSize: c * 0.46, weight: .medium)
    guard let symbole = NSImage(systemSymbolName: "tray.and.arrow.down.fill",
                               accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
        fatalError("Symbole introuvable")
    }
    let taille = symbole.size
    let zone = NSRect(x: (c - taille.width) / 2, y: (c - taille.height) / 2,
                      width: taille.width, height: taille.height)
    let blanc = NSImage(size: zone.size, flipped: false) { rect in
        symbole.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    blanc.draw(in: zone)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let variantes: [(nom: String, cote: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variante in variantes {
    let rep = dessiner(cote: variante.cote)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: iconset.appendingPathComponent("\(variante.nom).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path,
                      "-o", racine.appendingPathComponent("Ressources/Stash.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "✓ Ressources/Stash.icns" : "✗ iconutil a échoué")

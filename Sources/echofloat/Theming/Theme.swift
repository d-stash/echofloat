struct Theme: Identifiable, Equatable {
    enum Motif: Equatable {
        case none
        case neonGrid
    }

    let id: String
    let name: String
    let backgroundColors: [String]
    let accentColorHex: String
    let blurIntensity: Double
    let motif: Motif

    static let auroraGlass = Theme(
        id: "aurora-glass",
        name: "Aurora Glass",
        backgroundColors: ["#1C1C1E", "#2C2C2E"],
        accentColorHex: "#5AC8FA",
        blurIntensity: 0.6,
        motif: .none
    )

    static let neonArcade = Theme(
        id: "neon-arcade",
        name: "Neon Arcade",
        backgroundColors: ["#0D0221", "#190A33"],
        accentColorHex: "#FF2E92",
        blurIntensity: 0.8,
        motif: .neonGrid
    )

    static let builtIn: [Theme] = [.auroraGlass, .neonArcade]
}

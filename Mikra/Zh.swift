import Foundation

/// The language meanings are shown in. Hebrew, readings, and the interface stay as they are.
enum Language: String, CaseIterable, Identifiable {
    case en, zh
    var id: String { rawValue }
    var label: String { self == .zh ? "中文" : "English" }
}

/// Chinese for every English gloss, note, and lesson string, keyed by the English it translates.
/// gen-zh.py checks that nothing the app shows is missing. Verse lines come from Texts.json instead.
enum Zh {
    /// Set by the Store when the language changes, like Speech.pace.
    static var on = false

    static let strings: [String: String] = {
        let url = Bundle.main.url(forResource: "Zh", withExtension: "json")!
        return try! JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }()
}

/// `s` in the chosen language. A verse gloss like "and + to be" is translated a piece at a time,
/// and a lesson example like "da-VAR — word" keeps its reading and translates the meaning.
func tr(_ s: String) -> String {
    guard Zh.on else { return s }
    if let zh = Zh.strings[s] { return zh }
    if s.contains(" + ") {
        return s.components(separatedBy: " + ").map { Zh.strings[$0] ?? $0 }.joined(separator: " + ")
    }
    if let dash = s.range(of: " — ") {
        let meaning = String(s[dash.upperBound...])
        return s[..<dash.lowerBound] + " — " + (Zh.strings[meaning] ?? meaning)
    }
    return s
}

#if DEBUG
/// Smallest check that fails if the dictionary stops covering the deck or the piecewise rules break.
func zhSelfCheck() {
    Zh.on = true
    defer { Zh.on = false }
    assert(tr("to say") == "说", "plain lookup")
    assert(tr("and + to say") == "和、于是 + 说", "prefix pieces")
    assert(tr("da-VAR — word") == "da-VAR — 话语", "reading kept, meaning translated")
    assert(tr("no such string") == "no such string", "unknown strings pass through")
    let missing = wordDeck.map(\.g).filter { Zh.strings[$0] == nil }
    assert(missing.isEmpty, "deck glosses without Chinese: \(missing.prefix(5))")
    assert(lessons.allSatisfy { Zh.strings[$0.title] != nil }, "a lesson title has no Chinese")
    // gen-text.py asserts every verse of every book has one; here one book stands in for all 39
    assert(book(named: "Jonah").verses.allSatisfy { $0.zh != nil }, "a verse has no Chinese line")
}
#endif

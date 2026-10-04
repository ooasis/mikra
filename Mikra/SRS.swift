import Foundation

struct VerseProgress: Codable {
    var passive: Date? = nil // Assimil first wave: listened + read + understood
    var wave: Date? = nil    // second wave: read aloud cold, owned
}

/// A hand-made word set: ids into `wordCardByID`, in the order they were added.
struct WordSet: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var ids: [String] = []
}

/// "my-card", then "my-card-2", "my-card-3", … — the first name not already taken.
func nextSetName(taken: [String]) -> String {
    var n = 1
    while true {
        let name = n == 1 ? "my-card" : "my-card-\(n)"
        if !taken.contains(name) { return name }
        n += 1
    }
}

final class Store: ObservableObject {
    private struct Snapshot: Codable {
        var verses: [String: VerseProgress]? = nil
        var lastVerseDay: Date? = nil
        var currentBook: String? = nil
        var pace: String? = nil
        var appearance: String? = nil
        var sets: [WordSet]? = nil
        var language: String? = nil
        var verseHelp: String? = nil
        var recentBooks: [String]? = nil
        var known: [String]? = nil
    }

    @Published private(set) var verses: [String: VerseProgress] = [:]
    /// The book the daily ritual follows. Other books are readable, but don't drive Today or the wave.
    @Published private(set) var currentBook: String = books[0].name
    /// How verses are read aloud. Kept here rather than in UserDefaults, which
    /// would pull in a required-reason API and a privacy manifest.
    @Published private(set) var pace: Pace = .normal { didSet { Speech.pace = pace } }
    @Published private(set) var appearance: Appearance = .system
    /// Which language meanings are shown in; Zh.on mirrors it for the views' `tr`.
    @Published private(set) var language: Language = .en { didSet { Zh.on = language == .zh } }
    @Published private(set) var verseHelp: VerseHelp = .none
    @Published private(set) var sets: [WordSet] = []
    /// The last books opened, newest first; the home screen links to the first three.
    @Published private(set) var recentBooks: [String] = []
    /// Cards marked Got it: shown like any other, but the listening test skips them.
    @Published private(set) var known: Set<String> = []
    private var lastVerseDay: Date?

    private let url = URL.documentsDirectory.appending(path: "mikra.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            verses = Self.bookQualified(snap.verses ?? [:])
            lastVerseDay = snap.lastVerseDay
            if let saved = snap.currentBook, books.contains(where: { $0.name == saved }) {
                currentBook = saved
            }
            if let saved = snap.pace, let p = Pace(rawValue: saved) { pace = p }
            if let saved = snap.appearance, let a = Appearance(rawValue: saved) { appearance = a }
            sets = snap.sets ?? []
            if let saved = snap.language, let l = Language(rawValue: saved) { language = l }
            if let saved = snap.verseHelp, let h = VerseHelp(rawValue: saved) { verseHelp = h }
            recentBooks = (snap.recentBooks ?? []).filter { name in books.contains { $0.name == name } }
            known = Set(snap.known ?? [])
        }
        Speech.pace = pace
        Zh.on = language == .zh
    }

    /// Verse progress used to be keyed "1:3", from when Jonah was the only text.
    /// A second book makes that ambiguous, so old keys are stamped with Jonah's name.
    private static func bookQualified(_ saved: [String: VerseProgress]) -> [String: VerseProgress] {
        var out: [String: VerseProgress] = [:]
        for (key, progress) in saved {
            out[key.contains(" ") ? key : "Jonah " + key] = progress
        }
        return out
    }

    // — The daily reading (Assimil waves), through whichever book is current —

    static let waveOffset = 12 // second wave trails the passive wave by ~2 weeks

    var ritualVerses: [Verse] { book(named: currentBook).verses }

    func setPace(_ p: Pace) {
        pace = p
        save()
    }

    func setAppearance(_ a: Appearance) {
        appearance = a
        save()
    }

    func setLanguage(_ l: Language) {
        language = l
        save()
    }

    func setVerseHelp(_ h: VerseHelp) {
        verseHelp = h
        save()
    }

    func openedBook(_ name: String) {
        guard name != phraseBook else { return } // the phrase sets have their own tiles
        recentBooks = Array(([name] + recentBooks.filter { $0 != name }).prefix(3))
        save()
    }

    func setCurrentBook(_ name: String) {
        guard books.contains(where: { $0.name == name }) else { return }
        currentBook = name
        save()
    }

    /// Index of the next verse without a completed passive pass.
    var verseIndex: Int {
        ritualVerses.firstIndex { verses[$0.id]?.passive == nil } ?? ritualVerses.count
    }

    /// Today's new verse, or nil when the book is finished.
    var todaysVerse: Verse? {
        verseIndex < ritualVerses.count ? ritualVerses[verseIndex] : nil
    }

    /// One new verse per day — the Assimil rhythm.
    var verseDoneToday: Bool {
        lastVerseDay == Calendar.current.startOfDay(for: Date())
    }

    /// The oldest passive verse due for its active (read-aloud) pass.
    var waveVerse: Verse? {
        let all = ritualVerses
        let cap = verseIndex >= all.count ? all.count : verseIndex - Self.waveOffset
        guard cap > 0 else { return nil }
        return all.prefix(cap).first {
            verses[$0.id]?.passive != nil && verses[$0.id]?.wave == nil
        }
    }

    /// Last few passive verses, for the weekly-style replay.
    var recentVerses: [Verse] {
        Array(ritualVerses.filter { verses[$0.id]?.passive != nil }.suffix(6))
    }

    func completePassive(_ verse: Verse) {
        var p = verses[verse.id] ?? VerseProgress()
        let isNew = p.passive == nil
        let wasTodays = todaysVerse?.id == verse.id // read before the mutation moves the index
        p.passive = Date()
        verses[verse.id] = p
        // only the ritual's own next verse spends the day; a freely picked verse doesn't
        if isNew && wasTodays { lastVerseDay = Calendar.current.startOfDay(for: Date()) }
        save()
    }

    /// Done is a toggle in the reader: tapping it again takes the verse back out of the read pile.
    func clearPassive(_ verse: Verse) {
        verses[verse.id]?.passive = nil
        save()
    }

    func completeWave(_ verse: Verse) {
        var p = verses[verse.id] ?? VerseProgress()
        p.wave = Date()
        verses[verse.id] = p
        save()
    }

    // — Custom word sets —

    /// An empty name gets the next "my-card" name.
    @discardableResult
    func createSet(named name: String, with cardID: String? = nil) -> WordSet {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let set = WordSet(name: trimmed.isEmpty ? nextSetName(taken: sets.map(\.name)) : trimmed,
                          ids: cardID.map { [$0] } ?? [])
        sets.append(set)
        save()
        return set
    }

    /// Adds the word to the set, or takes it out again if it is already there.
    func toggle(_ cardID: String, in setID: String) {
        guard let i = sets.firstIndex(where: { $0.id == setID }) else { return }
        if let j = sets[i].ids.firstIndex(of: cardID) { sets[i].ids.remove(at: j) } else { sets[i].ids.append(cardID) }
        save()
    }

    func renameSet(_ setID: String, to name: String) {
        guard let i = sets.firstIndex(where: { $0.id == setID }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        sets[i].name = trimmed
        save()
    }

    func toggleKnown(_ cardID: String) {
        if !known.insert(cardID).inserted { known.remove(cardID) }
        save()
    }

    func deleteSet(_ setID: String) {
        sets.removeAll { $0.id == setID }
        save()
    }

    /// Wipes all progress (verses, sets, settings) — irreversible.
    func resetAll() {
        verses = [:]
        currentBook = books[0].name
        pace = .normal
        sets = []
        language = .en
        verseHelp = .none
        known = []
        lastVerseDay = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        let snap = Snapshot(verses: verses, lastVerseDay: lastVerseDay,
                            currentBook: currentBook, pace: pace.rawValue,
                            appearance: appearance.rawValue, sets: sets, language: language.rawValue,
                            verseHelp: verseHelp.rawValue, recentBooks: recentBooks, known: Array(known).sorted())
        try? JSONEncoder().encode(snap).write(to: url)
    }
}

#if DEBUG
/// Smallest check that fails if set naming breaks.
func storeSelfCheck() {
    assert(nextSetName(taken: []) == "my-card", "first set is my-card")
    assert(nextSetName(taken: ["my-card", "my-card-2"]) == "my-card-3", "set names count up")
}
#endif

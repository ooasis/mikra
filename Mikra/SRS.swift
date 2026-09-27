import Foundation

struct CardState: Codable {
    var ease = 2.5
    var intervalDays = 0.0
    var due = Date.distantPast
    var reps = 0
}

enum Grade { case again, good, easy }

enum SM2 {
    static func apply(_ grade: Grade, to state: CardState, now: Date = Date()) -> CardState {
        var s = state
        s.reps += 1
        switch grade {
        case .again:
            s.ease = max(1.3, s.ease - 0.2)
            s.intervalDays = 0
            s.due = now.addingTimeInterval(10 * 60)
        case .good:
            s.intervalDays = s.intervalDays < 1 ? 1 : s.intervalDays * s.ease
            s.due = now.addingTimeInterval(s.intervalDays * 86400)
        case .easy:
            s.ease += 0.05
            s.intervalDays = max(2, s.intervalDays * s.ease * 1.3)
            s.due = now.addingTimeInterval(s.intervalDays * 86400)
        }
        return s
    }
}

struct VerseProgress: Codable {
    var passive: Date? = nil // Assimil first wave: listened + read + understood
    var wave: Date? = nil    // second wave: read aloud cold, owned
}

final class Store: ObservableObject {
    private struct Snapshot: Codable {
        var states: [String: CardState] = [:]
        var streak = 0
        var lastStudyDay: Date? = nil
        var verses: [String: VerseProgress]? = nil
        var tapped: Set<String>? = nil
        var lastVerseDay: Date? = nil
        var currentBook: String? = nil
        var pace: String? = nil
        var appearance: String? = nil
    }

    @Published private(set) var states: [String: CardState] = [:]
    @Published private(set) var streak = 0
    @Published private(set) var verses: [String: VerseProgress] = [:]
    @Published private(set) var tapped: Set<String> = []
    /// The book the daily ritual follows. Other books are readable, but don't drive Today or the wave.
    @Published private(set) var currentBook: String = books[0].name
    /// How verses are read aloud. Kept here rather than in UserDefaults, which
    /// would pull in a required-reason API and a privacy manifest.
    @Published private(set) var pace: Pace = .normal { didSet { Speech.pace = pace } }
    @Published private(set) var appearance: Appearance = .system
    private var lastStudyDay: Date?
    private var lastVerseDay: Date?

    private let url = URL.documentsDirectory.appending(path: "mikra.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            states = snap.states
            streak = snap.streak
            lastStudyDay = snap.lastStudyDay
            verses = Self.bookQualified(snap.verses ?? [:])
            tapped = snap.tapped ?? []
            lastVerseDay = snap.lastVerseDay
            if let saved = snap.currentBook, books.contains(where: { $0.name == saved }) {
                currentBook = saved
            }
            if let saved = snap.pace, let p = Pace(rawValue: saved) { pace = p }
            if let saved = snap.appearance, let a = Appearance(rawValue: saved) { appearance = a }
        }
        Speech.pace = pace
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

    func grade(_ card: Card, _ grade: Grade) {
        states[card.id] = SM2.apply(grade, to: states[card.id] ?? CardState())
        bumpStreak()
        save()
    }

    var dueCards: [Card] {
        let now = Date()
        let drills = curriculum.filter { (states[$0.id]?.due ?? .distantFuture) <= now }
        let words = tapped.compactMap { enrolledCardsByID[$0] }
            .filter { (states[$0.id]?.due ?? .distantPast) <= now }
        return drills + words
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
        bumpStreak()
        save()
    }

    func completeWave(_ verse: Verse) {
        var p = verses[verse.id] ?? VerseProgress()
        p.wave = Date()
        verses[verse.id] = p
        bumpStreak()
        save()
    }

    /// Hand-picked words become SRS cards: tapped in the reader, or taken from the word deck.
    func enroll(_ id: String) {
        guard !tapped.contains(id) else { return }
        tapped.insert(id)
        save()
    }

    func tapWord(_ w: VerseWord) { enroll(verseWordCardID(w)) }

    /// Next unseen cards, in curriculum order.
    func newCards(limit: Int) -> [Card] {
        Array(curriculum.filter { states[$0.id] == nil }.prefix(limit))
    }

    /// Graded at least once and scheduled a day or more out.
    var learnedCount: Int {
        states.values.filter { $0.intervalDays >= 1 }.count
    }

    /// Wipes all progress (drills, verses, streak) — irreversible.
    func resetAll() {
        states = [:]
        streak = 0
        verses = [:]
        tapped = []
        currentBook = books[0].name
        pace = .normal
        lastStudyDay = nil
        lastVerseDay = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func bumpStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        guard lastStudyDay != today else { return }
        if let last = lastStudyDay,
           Calendar.current.date(byAdding: .day, value: 1, to: last) == today {
            streak += 1
        } else {
            streak = 1
        }
        lastStudyDay = today
    }

    private func save() {
        let snap = Snapshot(states: states, streak: streak, lastStudyDay: lastStudyDay,
                            verses: verses, tapped: tapped, lastVerseDay: lastVerseDay,
                            currentBook: currentBook, pace: pace.rawValue,
                            appearance: appearance.rawValue)
        try? JSONEncoder().encode(snap).write(to: url)
    }
}

#if DEBUG
/// Smallest check that fails if the scheduler breaks.
func srsSelfCheck() {
    let now = Date()
    let fresh = CardState()
    let good = SM2.apply(.good, to: fresh, now: now)
    assert(good.intervalDays == 1 && good.due > now, "first good -> 1 day")
    let good2 = SM2.apply(.good, to: good, now: now)
    assert(good2.intervalDays > good.intervalDays, "interval grows")
    let again = SM2.apply(.again, to: good2, now: now)
    assert(again.intervalDays == 0 && again.due < now.addingTimeInterval(3600), "again -> relearn soon")
    assert(again.ease < good2.ease, "again lowers ease")
    let easy = SM2.apply(.easy, to: fresh, now: now)
    assert(easy.intervalDays >= 2, "easy skips ahead")
}
#endif

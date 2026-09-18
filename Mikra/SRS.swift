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
    }

    @Published private(set) var states: [String: CardState] = [:]
    @Published private(set) var streak = 0
    @Published private(set) var verses: [String: VerseProgress] = [:]
    @Published private(set) var tapped: Set<String> = []
    private var lastStudyDay: Date?
    private var lastVerseDay: Date?

    private let url = URL.documentsDirectory.appending(path: "mikra.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            states = snap.states
            streak = snap.streak
            lastStudyDay = snap.lastStudyDay
            verses = snap.verses ?? [:]
            tapped = snap.tapped ?? []
            lastVerseDay = snap.lastVerseDay
        }
    }

    func grade(_ card: Card, _ grade: Grade) {
        states[card.id] = SM2.apply(grade, to: states[card.id] ?? CardState())
        bumpStreak()
        save()
    }

    var dueCards: [Card] {
        let now = Date()
        let drills = curriculum.filter { (states[$0.id]?.due ?? .distantFuture) <= now }
        let words = tapped.compactMap { jonahCardsByID[$0] }
            .filter { (states[$0.id]?.due ?? .distantPast) <= now }
        return drills + words
    }

    // — Jonah / Assimil —

    static let waveOffset = 12 // second wave trails the passive wave by ~2 weeks

    /// Index of the next verse without a completed passive pass.
    var verseIndex: Int {
        jonahVerses.firstIndex { verses[$0.id]?.passive == nil } ?? jonahVerses.count
    }

    /// Today's new verse, or nil when the book is finished.
    var todaysVerse: JonahVerse? {
        verseIndex < jonahVerses.count ? jonahVerses[verseIndex] : nil
    }

    /// One new verse per day — the Assimil rhythm.
    var verseDoneToday: Bool {
        lastVerseDay == Calendar.current.startOfDay(for: Date())
    }

    /// The oldest passive verse due for its active (read-aloud) pass.
    var waveVerse: JonahVerse? {
        let cap = verseIndex >= jonahVerses.count ? jonahVerses.count : verseIndex - Self.waveOffset
        guard cap > 0 else { return nil }
        return jonahVerses.prefix(cap).first {
            verses[$0.id]?.passive != nil && verses[$0.id]?.wave == nil
        }
    }

    /// Last few passive verses, for the weekly-style replay.
    var recentVerses: [JonahVerse] {
        Array(jonahVerses.filter { verses[$0.id]?.passive != nil }.suffix(6))
    }

    func completePassive(_ verse: JonahVerse) {
        var p = verses[verse.id] ?? VerseProgress()
        let isNew = p.passive == nil
        p.passive = Date()
        verses[verse.id] = p
        if isNew { lastVerseDay = Calendar.current.startOfDay(for: Date()) }
        bumpStreak()
        save()
    }

    func completeWave(_ verse: JonahVerse) {
        var p = verses[verse.id] ?? VerseProgress()
        p.wave = Date()
        verses[verse.id] = p
        bumpStreak()
        save()
    }

    /// Tapping an unknown word enrolls it as an SRS card.
    func tapWord(_ w: JonahWord) {
        guard !tapped.contains(jonahCardID(w)) else { return }
        tapped.insert(jonahCardID(w))
        save()
    }

    /// Next unseen cards, in curriculum order.
    func newCards(limit: Int) -> [Card] {
        Array(curriculum.filter { states[$0.id] == nil }.prefix(limit))
    }

    /// Graded at least once and scheduled a day or more out.
    var learnedCount: Int {
        states.values.filter { $0.intervalDays >= 1 }.count
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
                            verses: verses, tapped: tapped, lastVerseDay: lastVerseDay)
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

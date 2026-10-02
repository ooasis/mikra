import Foundation

enum Kind { case letter, vowel }

struct Card: Identifiable {
    let id: String
    let hebrew: String      // what's shown big
    let name: String        // reveal line 1 (letter/vowel name, or gloss for words)
    let sound: String       // reveal line 2 (how it sounds)
    let kind: Kind
    var namePron: String? = nil // how to say `name` out loud, e.g. "kah-MAHTS" (vowel names only)
    var note: String? = nil // confusable warnings etc.
    var tts: String? = nil  // override for what the synthesizer speaks; defaults to `hebrew` (vowels speak their name)
    // ponytail: tts strings untuned — if the he-IL voice mangles a card, set `tts` for it.

    var prompt: String {
        switch kind {
        case .letter: return "Name it and say its sound"
        case .vowel:  return "Say the syllable aloud"
        }
    }
    var speechText: String { tts ?? hebrew }

    /// Just the niqqud mark(s), no carrier letter. Empty for non-vowels.
    var vowelMark: String {
        guard kind == .vowel else { return "" }
        let marks = hebrew.unicodeScalars.filter { (0x05B0...0x05BB).contains($0.value) }
        return String(String.UnicodeScalarView(marks))
    }

    /// Display glyph: vowels show just the mark on a dotted circle, no carrier letter.
    var displayGlyph: String {
        kind == .vowel ? "◌" + vowelMark : hebrew
    }
}

// Curriculum order = introduction order. Letters (with dagesh/final variants),
// then vowels on the carrier letter bet, then first real Bible words.
let curriculum: [Card] = [
    // — Letters —
    Card(id: "alef", hebrew: "א", name: "Alef", sound: "silent", kind: .letter, tts: "אָלֶף"),
    Card(id: "bet", hebrew: "בּ", name: "Bet", sound: "b", kind: .letter, note: "The dot (dagesh) makes it B.", tts: "בֵּית"),
    Card(id: "vet", hebrew: "ב", name: "Vet", sound: "v", kind: .letter, note: "Same letter as בּ, no dot → V.", tts: "בֵית"),
    Card(id: "gimel", hebrew: "ג", name: "Gimel", sound: "g", kind: .letter, note: "Don't confuse with נ (nun).", tts: "גִּימֶל"),
    Card(id: "dalet", hebrew: "ד", name: "Dalet", sound: "d", kind: .letter, note: "Don't confuse with ר (resh) — dalet has a corner.", tts: "דָּלֶת"),
    Card(id: "he", hebrew: "ה", name: "He", sound: "h", kind: .letter, note: "Don't confuse with ח (chet) — he has a gap at the top left.", tts: "הֵא"),
    Card(id: "vav", hebrew: "ו", name: "Vav", sound: "v", kind: .letter, note: "Don't confuse with ן (final nun) or ז (zayin).", tts: "וָו"),
    Card(id: "zayin", hebrew: "ז", name: "Zayin", sound: "z", kind: .letter, note: "Don't confuse with ו (vav) — zayin's head crosses the stem.", tts: "זַיִן"),
    Card(id: "chet", hebrew: "ח", name: "Chet", sound: "kh (as in Bach)", kind: .letter, note: "Don't confuse with ה (he) — chet is closed.", tts: "חֵית"),
    Card(id: "tet", hebrew: "ט", name: "Tet", sound: "t", kind: .letter, tts: "טֵית"),
    Card(id: "yod", hebrew: "י", name: "Yod", sound: "y", kind: .letter, note: "The tiny one.", tts: "יוֹד"),
    Card(id: "kaf", hebrew: "כּ", name: "Kaf", sound: "k", kind: .letter, note: "Don't confuse with בּ (bet) — kaf is rounded.", tts: "כַּף"),
    Card(id: "khaf", hebrew: "כ", name: "Khaf", sound: "kh", kind: .letter, note: "Kaf without the dot → KH.", tts: "כַף"),
    Card(id: "khaf-final", hebrew: "ך", name: "Final Khaf", sound: "kh", kind: .letter, note: "Form of כ at the end of a word.", tts: "כַף סוֹפִית"),
    Card(id: "lamed", hebrew: "ל", name: "Lamed", sound: "l", kind: .letter, note: "The tall one.", tts: "לָמֶד"),
    Card(id: "mem", hebrew: "מ", name: "Mem", sound: "m", kind: .letter, tts: "מֵם"),
    Card(id: "mem-final", hebrew: "ם", name: "Final Mem", sound: "m", kind: .letter, note: "Form of מ at the end of a word. Don't confuse with ס (samekh).", tts: "מֵם סוֹפִית"),
    Card(id: "nun", hebrew: "נ", name: "Nun", sound: "n", kind: .letter, note: "Don't confuse with ג (gimel).", tts: "נוּן"),
    Card(id: "nun-final", hebrew: "ן", name: "Final Nun", sound: "n", kind: .letter, note: "Form of נ at the end of a word — drops below the line, unlike ו.", tts: "נוּן סוֹפִית"),
    Card(id: "samekh", hebrew: "ס", name: "Samekh", sound: "s", kind: .letter, note: "Don't confuse with ם (final mem) — samekh is round.", tts: "סָמֶךְ"),
    Card(id: "ayin", hebrew: "ע", name: "Ayin", sound: "silent", kind: .letter, note: "Like א, silent in Modern Israeli.", tts: "עַיִן"),
    Card(id: "pe", hebrew: "פּ", name: "Pe", sound: "p", kind: .letter, tts: "פֵּא"),
    Card(id: "fe", hebrew: "פ", name: "Fe", sound: "f", kind: .letter, note: "Pe without the dot → F.", tts: "פֵא"),
    Card(id: "fe-final", hebrew: "ף", name: "Final Fe", sound: "f", kind: .letter, note: "Form of פ at the end of a word.", tts: "פֵא סוֹפִית"),
    Card(id: "tsadi", hebrew: "צ", name: "Tsadi", sound: "ts", kind: .letter, tts: "צָדִי"),
    Card(id: "tsadi-final", hebrew: "ץ", name: "Final Tsadi", sound: "ts", kind: .letter, note: "Form of צ at the end of a word.", tts: "צָדִי סוֹפִית"),
    Card(id: "qof", hebrew: "ק", name: "Qof", sound: "k", kind: .letter, note: "Same sound as כּ in Modern Israeli.", tts: "קוֹף"),
    Card(id: "resh", hebrew: "ר", name: "Resh", sound: "r", kind: .letter, note: "Don't confuse with ד (dalet) — resh is rounded.", tts: "רֵישׁ"),
    Card(id: "shin", hebrew: "שׁ", name: "Shin", sound: "sh", kind: .letter, note: "Dot on the RIGHT → SH.", tts: "שִׁין"),
    Card(id: "sin", hebrew: "שׂ", name: "Sin", sound: "s", kind: .letter, note: "Dot on the LEFT → S.", tts: "שִׂין"),
    Card(id: "tav", hebrew: "ת", name: "Tav", sound: "t", kind: .letter, note: "Don't confuse with ח — tav has a foot on the left leg.", tts: "תָּו"),

    // — Vowels (niqqud), on the carrier letter bet —
    Card(id: "qamats", hebrew: "בָּ", name: "Qamats", sound: "ba (a as in father)", kind: .vowel, namePron: "kah-MAHTS", tts: "קָמָץ"),
    Card(id: "patach", hebrew: "בַּ", name: "Patach", sound: "ba (a as in father)", kind: .vowel, namePron: "pah-TAKH", note: "Sounds the same as qamats in Modern Israeli.", tts: "פַּתָּח"),
    Card(id: "tsere", hebrew: "בֵּ", name: "Tsere", sound: "be (e as in they)", kind: .vowel, namePron: "tseh-REH", tts: "צֵירֵי"),
    Card(id: "segol", hebrew: "בֶּ", name: "Segol", sound: "be (e as in bed)", kind: .vowel, namePron: "seh-GOL", note: "Three dots. Same as tsere in Modern Israeli.", tts: "סֶגּוֹל"),
    Card(id: "chirik", hebrew: "בִּ", name: "Chirik", sound: "bi (i as in machine)", kind: .vowel, namePron: "khee-REEK", tts: "חִירִיק"),
    Card(id: "cholam", hebrew: "בֹּ", name: "Cholam", sound: "bo", kind: .vowel, namePron: "kho-LAHM", note: "In the Bible often written with vav: בּוֹ.", tts: "חוֹלָם"),
    Card(id: "kubuts", hebrew: "בֻּ", name: "Kubuts", sound: "bu (u as in flute)", kind: .vowel, namePron: "koo-BOOTS", note: "Three diagonal dots → u. In the Bible often written as vav with a middle dot: בּוּ.", tts: "קֻבּוּץ"),
    Card(id: "sheva", hebrew: "בְּ", name: "Sheva", sound: "b / be (very short or silent)", kind: .vowel, namePron: "sh'VAH", tts: "שְׁוָא"),

]

let cardsByID = Dictionary(uniqueKeysWithValues: curriculum.map { ($0.id, $0) })

// — Letter groups: dagesh/final/dot variants of one base letter, shown as one tile —

struct LetterGroup: Identifiable {
    let id: String
    let cards: [Card]
}

private let letterGroupIDs: [[String]] = [
    ["alef"], ["bet", "vet"], ["gimel"], ["dalet"], ["he"], ["vav"], ["zayin"],
    ["chet"], ["tet"], ["yod"], ["kaf", "khaf", "khaf-final"], ["lamed"],
    ["mem", "mem-final"], ["nun", "nun-final"], ["samekh"], ["ayin"],
    ["pe", "fe", "fe-final"], ["tsadi", "tsadi-final"], ["qof"], ["resh"],
    ["shin", "sin"], ["tav"],
]

let letterGroups: [LetterGroup] = letterGroupIDs.map { ids in
    LetterGroup(id: ids[0], cards: ids.compactMap { cardsByID[$0] })
}

// — Vowel practice combos for flash cards —

struct Combo: Identifiable {
    let id: String
    let hebrew: String
    let caption: String // rough reading, e.g. "ba"
}

// niqqud mark + its sound, in teaching order
private let vowelMarks: [(id: String, mark: String, sound: String)] = [
    ("qamats", "\u{05B8}", "a"), ("patach", "\u{05B7}", "a"),
    ("tsere", "\u{05B5}", "e"), ("segol", "\u{05B6}", "e"),
    ("chirik", "\u{05B4}", "i"), ("cholam", "\u{05B9}", "o"),
    ("kubuts", "\u{05BB}", "u"), ("sheva", "\u{05B0}", "e(short)"),
]

// letters a vowel card practices on: (glyph, consonant sound)
private let practiceLetters: [(hebrew: String, sound: String)] = [
    ("בּ", "b"), ("ג", "g"), ("ד", "d"), ("ל", "l"),
    ("מ", "m"), ("ק", "k"), ("שׁ", "sh"), ("ת", "t"),
]

/// Consonant part of a letter's `sound` ("kh (as in Bach)" -> "kh", "silent" -> "").
private func consonant(of card: Card) -> String {
    card.sound == "silent" ? "" : String(card.sound.prefix(while: { $0 != " " }))
}

func combos(for card: Card) -> [Combo] {
    switch card.kind {
    case .letter where !card.id.hasSuffix("-final"):
        let c = consonant(of: card)
        return vowelMarks.map {
            Combo(id: "\(card.id)+\($0.id)", hebrew: card.hebrew + $0.mark, caption: c + $0.sound)
        }
    case .vowel:
        guard let v = vowelMarks.first(where: { $0.id == card.id }) else { return [] }
        return practiceLetters.map {
            Combo(id: "\($0.sound)+\(card.id)", hebrew: $0.hebrew + v.mark, caption: $0.sound + v.sound)
        }
    default:
        return [] // final forms end words; no vowel practice
    }
}

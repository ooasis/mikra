import Foundation

/// Modern Israeli reading of pointed Hebrew as a simple respelling: syllables split by
/// hyphens, the stressed syllable in capitals — "da-VAR", "e-lo-HIM", "RU-akh".
/// Stress is last syllable by default, with the common exceptions below.
/// ponytail: no full stress lexicon — directional ־ָה and a few suffixes still come out ultimate.
func pronounce(_ hebrew: String) -> String {
    hebrew.split(whereSeparator: { $0 == " " })
        .map { chain in
            // words joined by maqqef are one stress unit: only the last keeps its stress
            let parts = chain.split(separator: "\u{05BE}").map(String.init)
            return parts.enumerated().map { i, w in
                pronounceWord(w, stressed: i == parts.count - 1)
            }.joined(separator: "-")
        }
        .joined(separator: " ")
}

private struct Letter {
    let base: Character
    var dagesh = false
    var sin = false
    var vowel: Character? = nil
}

private let sheva: Character = "\u{05B0}"
private let hatafs: [Character: String] = ["\u{05B1}": "e", "\u{05B2}": "a", "\u{05B3}": "o"]
private let vowels: [Character: String] = [
    "\u{05B4}": "i", "\u{05B5}": "e", "\u{05B6}": "e", "\u{05B7}": "a", "\u{05B8}": "a",
    "\u{05B9}": "o", "\u{05BA}": "o", "\u{05BB}": "u", "\u{05C7}": "o",
]
private let segol: Character = "\u{05B6}", patach: Character = "\u{05B7}", chirik: Character = "\u{05B4}"
private let holam: Character = "\u{05B9}", holamHaser: Character = "\u{05BA}"

private func parse(_ word: String) -> [Letter] {
    var letters: [Letter] = []
    for ch in word.unicodeScalars {
        switch ch.value {
        case 0x05D0...0x05EA: letters.append(Letter(base: Character(ch)))
        case 0x05BC: letters[letters.count - 1].dagesh = true
        case 0x05C2: letters[letters.count - 1].sin = true
        case 0x05B0...0x05BB, 0x05C7:
            if !letters.isEmpty { letters[letters.count - 1].vowel = Character(ch) }
        default: break // cantillation, meteg, shin dot, rafe
        }
    }
    return letters
}

private func consonant(_ l: Letter, isLast: Bool) -> String {
    switch l.base {
    case "א", "ע": return ""
    case "ב": return l.dagesh ? "b" : "v"
    case "ג": return "g"
    case "ד": return "d"
    case "ה": return isLast && !l.dagesh && l.vowel == nil ? "" : "h"
    case "ו": return "v"
    case "ז": return "z"
    case "ח": return "kh"
    case "ט", "ת": return "t"
    case "י": return "y"
    case "כ", "ך": return l.dagesh ? "k" : "kh"
    case "ל": return "l"
    case "מ", "ם": return "m"
    case "נ", "ן": return "n"
    case "ס": return "s"
    case "פ", "ף": return l.dagesh ? "p" : "f"
    case "צ", "ץ": return "ts"
    case "ק": return "k"
    case "ר": return "r"
    case "ש": return l.sin ? "s" : "sh"
    default: return ""
    }
}

private func pronounceWord(_ word: String, stressed: Bool) -> String {
    let letters = parse(word)
    guard !letters.isEmpty else { return word }
    let bare = String(letters.map(\.base))
    if bare == "יהוה" { return stressed ? "a-do-NAI" : "a-do-nai" } // read as Adonai, never as written
    if bare == "כל" && letters[0].vowel == "\u{05B8}" { return "kol" }  // qamats qatan

    var syllables: [String] = []
    var cur = "", curHasVowel = false
    var pending = "" // consonants with no vowel of their own: coda of this syllable, unless a vowel letter follows
    var lastVow: String? = nil // the last full vowel heard, so vowel letters and furtive patach know what came before
    var furtive = false

    for (i, l) in letters.enumerated() {
        let isLast = i == letters.count - 1
        var cons = consonant(l, isLast: isLast)
        var vow: String? = l.vowel.flatMap { vowels[$0] ?? hatafs[$0] }
        var isMater = false

        // vav and yod as vowel letters
        if l.base == "ו", l.vowel == holam || l.vowel == holamHaser, !l.dagesh {
            cons = ""; vow = "o"; isMater = true
        } else if l.base == "ו", l.dagesh, l.vowel == nil {
            cons = ""; vow = "u"; isMater = true
        } else if l.base == "י", l.vowel == nil, !l.dagesh, let prev = lastVow {
            cons = prev == "i" ? "" : prev == "e" ? "i" : "y"
        }
        // sheva: spoken at the start of a word, after another sheva, or under a dagesh
        if l.vowel == sheva {
            let afterSheva = i > 0 && letters[i - 1].vowel == sheva
            vow = (!isLast && (i == 0 || afterSheva || l.dagesh)) ? "e" : nil
        }
        // furtive patach: a final guttural with a patach is heard before the consonant
        if isLast, l.vowel == patach, ["ח", "ע"].contains(l.base) || (l.base == "ה" && l.dagesh),
           let prev = lastVow, prev != "a" {
            syllables.append(cur + pending)
            cur = "a" + cons; pending = ""; curHasVowel = true; furtive = true
            continue
        }

        if let vow {
            if isMater, !pending.isEmpty {
                // the waiting consonant is this vowel's onset: sha-LOM, not shal-OM
                if curHasVowel { syllables.append(cur) }
                cur = pending + vow
            } else {
                if curHasVowel { syllables.append(cur + pending); cur = "" } else { cur += pending }
                cur += cons + vow
            }
            pending = ""; curHasVowel = true
            if l.vowel != sheva { lastVow = vow }
        } else {
            pending += cons
        }
    }
    cur += pending
    if !cur.isEmpty { syllables.append(cur) }
    syllables.removeAll(where: \.isEmpty)
    guard stressed, syllables.count > 1 else { return syllables.joined(separator: "-") }

    // stress: last syllable unless one of the shapes that pull it back one
    let full = letters.filter { $0.vowel != nil && $0.vowel != sheva }
    let n = full.count
    let endsClosed = letters.last!.vowel == nil || letters.last!.vowel == sheva
    let segolate = n >= 2 && full[n - 1].vowel == segol && endsClosed && hatafs[full[n - 2].vowel!] == nil
    let ayim = n >= 2 && full[n - 1].base == "י" && full[n - 1].vowel == chirik && full[n - 2].vowel == patach
    // endings that keep the stress off themselves: ־נוּ ־תָּ ־תִּי ־הוּ ־ֶיךָ (checked on letters,
    // since the order of points inside a string varies with normalisation)
    let n2 = letters.count
    let l1 = letters[n2 - 1], l2 = n2 > 1 ? letters[n2 - 2] : l1, l3 = n2 > 2 ? letters[n2 - 3] : l1
    let suffix = n2 > 1 && (
        (l1.base == "ו" && l1.dagesh && (l2.base == "נ" || l2.base == "ה") && l2.vowel == nil) ||
        (l1.base == "ת" && l1.vowel == "\u{05B8}") ||
        (l1.base == "י" && l2.base == "ת" && l2.vowel == chirik) ||
        (l1.base == "ך" && l1.vowel == "\u{05B8}" && l2.base == "י" && l2.vowel == nil && l3.vowel == segol))
    let stressAt = (furtive || segolate || ayim || suffix) ? syllables.count - 2 : syllables.count - 1
    syllables[max(stressAt, 0)] = syllables[max(stressAt, 0)].uppercased()
    return syllables.joined(separator: "-")
}

#if DEBUG
/// Smallest check that fails if a reading rule breaks.
func pronounceSelfCheck() {
    let cases: [(String, String)] = [
        ("דָּבָר", "da-VAR"), ("מֶלֶךְ", "ME-lekh"), ("אֱלֹהִים", "e-lo-HIM"), ("רוּחַ", "RU-akh"),
        ("בְּרֵאשִׁית", "be-re-SHIT"), ("יוֹנָה", "yo-NA"), ("מַיִם", "MA-yim"), ("בַּיִת", "BA-yit"),
        ("הַשָּׁמַיִם", "ha-sha-MA-yim"), ("אֶרֶץ", "E-rets"), ("כָּל־הָאָרֶץ", "kol-ha-A-rets"),
        ("שָׁלוֹם", "sha-LOM"), ("יְהוָה", "a-do-NAI"), ("בָּהּ", "bah"), ("יוֹדֵעַ", "yo-DE-a"),
        ("וַיֹּאמֶר", "va-YO-mer"), ("קָרָאתִי", "ka-RA-ti"), ("לָנוּ", "LA-nu"), ("אֲנִי", "a-NI"),
        ("שָׁמַע", "sha-MA"), ("בֵּין", "bein"), ("אַתָּה", "a-TA"), ("רֹאשׁ", "rosh"), ("הָעִיר", "ha-IR"),
    ]
    for (h, want) in cases {
        assert(pronounce(h) == want, "\(h): got \(pronounce(h)), want \(want)")
    }
}
#endif

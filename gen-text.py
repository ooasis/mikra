#!/usr/bin/env python3
"""Generate Mikra/Texts.json — the reading texts, with per-word glosses and notes.

Hebrew and morphology from OSHB/WLC (CC BY 4.0), glosses from Strong's with
curated overrides, English from the WEB (public domain) remapped to Hebrew
versification. Supersedes gen-jonah.py.

    ./gen-text.py           # write Mikra/Texts.json
    ./gen-text.py --check   # run the self-check only
"""
import json, os, re, sys, urllib.request
import xml.etree.ElementTree as ET
from collections import Counter

NS = "{http://www.bibletechnologies.net/2003/OSIS/namespace}"
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
WLC = "https://raw.githubusercontent.com/openscriptures/morphhb/master/wlc/{}.xml"
WEB = "https://bible-api.com/{}+{}?translation=web"
STRONGS = "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js"

# The texts we ship: display name, Hebrew name, morphhb file, chapters, expected verses.
TEXTS = [
    ("Jonah", "\u05d9\u05d5\u05b9\u05e0\u05b8\u05d4", "Jonah", [1, 2, 3, 4], 48),
    ("Genesis", "\u05d1\u05b0\u05bc\u05e8\u05b5\u05d0\u05e9\u05c1\u05b4\u05d9\u05ea \u05d0", "Gen", [1], 31),
]

# Hebrew and English versification disagree in places. Map a Hebrew (chapter,
# verse) onto the English one that carries the same text.
def remap(book, c, v):
    if book == "Jonah":              # Hebrew 2:1 is English 1:17, shifting the rest of ch.2
        return (1, 17) if (c, v) == (2, 1) else ((2, v - 1) if c == 2 else (c, v))
    return (c, v)


def fetch(url, name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        print(f"  downloading {name}", file=sys.stderr)
        urllib.request.urlretrieve(url, path)
    return path


strongs = json.loads(re.search(
    r"=\s*(\{.*\})\s*;?\s*(module|$)",
    open(fetch(STRONGS, "strongs.js"), encoding="utf-8").read(), re.S).group(1))

CURATED = {
    "1961": "to be, become", "3068": "the LORD (YHWH)", "559": "to say",
    "413": "to, toward", "5921": "on, over, against", "3124": "Jonah",
    "1121": "son", "573": "Amittai", "1697": "word, thing", "6965": "to arise",
    "3212": "to go, walk", "1980": "to go, walk", "5210": "Nineveh",
    "5892": "city", "1419": "great, big", "7121": "to call, cry out",
    "7451": "evil, wickedness", "6440": "face, presence", "8659": "Tarshish",
    "1272": "to flee", "3381": "to go down", "3305": "Joppa",
    "4672": "to find", "591": "ship", "935": "to come, go in",
    "5414": "to give", "7908": "fare, wage", "3220": "sea",
    "2904": "to hurl, throw", "7307": "wind, spirit", "1419 a": "great, big",
    "5591": "storm, tempest", "2803": "to think, reckon", "7665": "to break up",
    "3372": "to fear", "4397": "sailor? messenger", "2199": "to cry out",
    "376": "man, each one", "430": "God, gods", "3627": "vessel, cargo",
    "7043": "to lighten", "3409": "side, recess", "5600": "ship",
    "7901": "to lie down", "7290": "to sleep deeply", "2259": "captain, pilot",
    "7126": "to draw near", "7290 a": "deep sleep", "6246": "to think about",
    "6": "to perish", "7453": "fellow, companion", "5307": "to fall",
    "1486": "lot (casting lots)", "3045": "to know", "4310": "who?",
    "4100": "what?", "4399": "work, occupation", "370": "from where?",
    "776": "land, earth", "5971": "people", "5046": "to tell",
    "3373": "fearing", "8064": "heavens, sky", "6213": "to do, make",
    "3004": "dry land", "3374": "fear", "1419 b": "great",
    "2076": "to sacrifice", "2077": "sacrifice", "5087": "to vow",
    "5088": "vow", "4487": "to appoint, prepare", "1709": "fish",
    "1104": "to swallow", "4578": "belly, inward parts", "3117": "day",
    "3915": "night", "6419": "to pray", "8605": "prayer",
    "6817": "to cry for help", "6031": "affliction? to answer",
    "6030": "to answer", "990": "belly, womb", "7585": "Sheol, the grave",
    "8085": "to hear", "6963": "voice, sound", "7993": "to throw, cast",
    "4688": "deep, depth", "3824": "heart", "5104": "river, current",
    "4867": "breaker, wave", "1530": "wave, billow", "5674": "to pass over",
    "1644": "to drive out", "3254": "to add, do again", "5027": "to look",
    "1964": "temple, palace", "6944": "holiness, holy", "661": "to surround",
    "4325": "water", "5315": "soul, life, self", "8415": "the deep",
    "5475": "reed? council", "5488": "reeds, seaweed", "2280": "to bind, wrap",
    "7218": "head", "7095": "bottom, base", "2022": "mountain",
    "1280": "bar, bolt", "1157": "behind, on behalf of", "5769": "forever",
    "5927": "to go up", "7845": "pit, grave", "2416": "life, alive",
    "5848": "to faint, grow weak", "2142": "to remember", "8199": "to judge",
    "8104": "to keep, watch", "1892": "vapor, idol, vanity", "7723": "vanity, falsehood",
    "2617": "steadfast love", "5800": "to forsake", "8426": "thanksgiving",
    "3444": "salvation, deliverance", "6958": "to vomit", "8145": "second (time)",
    "7150": "proclamation", "1870": "way, road", "4109": "walk, journey",
    "7969": "three", "259": "one", "539": "to believe, trust",
    "6685": "fast (n.)", "3847": "to put on, clothe", "8242": "sackcloth",
    "1571": "also, even", "3678": "throne", "5493": "to turn aside, remove",
    "155": "robe, mantle", "3680": "to cover", "3427": "to sit, dwell",
    "665": "ashes", "2940": "decree? taste", "1697 b": "word",
    "929": "beast, cattle", "1241": "herd, cattle", "6629": "flock, sheep",
    "2963": "to taste? tear", "7462": "to graze, feed", "8354": "to drink",
    "2388": "to be strong; mightily", "7725": "to turn back, return",
    "2555": "violence", "3709": "palm, hand", "5162": "to relent, comfort",
    "2740": "burning anger", "639": "anger, nose", "3808": "not",
    "2940": "decree", "7489": "to be evil, displease", "370": "where?",
    "335": "where?", "6246": "to give a thought to",
    "2734": "to be angry, burn", "3190": "to be good, right",
    "2470": "to be sick? grieve", "4994": "please, now", "3947": "to take",
    "4194": "death", "2896": "good", "3318": "to go out",
    "6924": "east, in front", "5521": "booth, shelter", "6738": "shade, shadow",
    "7200": "to see", "7014": "qiqayon (a plant)", "6738 b": "shade",
    "5337": "to deliver, rescue", "8055": "to rejoice", "8057": "joy, gladness",
    "8438": "worm", "5927 b": "to go up", "7837": "dawn",
    "4283": "next day", "5221": "to strike, attack", "3001": "to wither, dry up",
    "2224": "to rise (sun)", "2775": "sun? scorching", "7307 b": "wind",
    "2759": "scorching, sultry", "5968": "to faint, be feeble", "7592": "to ask",
    "4191": "to die", "5162 b": "to relent", "3966": "very, exceedingly",
    "5750": "still, yet", "705": "forty", "2015": "to overturn, overthrow",
    "120": "man, mankind", "7235": "many, much", "1004": "house",
    "3820": "heart", "227": "then", "834": "which, who",
    "3588": "for, because, that", "5750 b": "yet", "853": "(object marker)",
    "854": "with", "1877": "grass? plant", "3282": "because",
    "8147": "two", "6240": "ten (…teen)", "7239": "ten thousand, myriad",
    "3045 b": "to know", "3225": "right hand", "8040": "left hand",
    "2603": "to be gracious", "7349": "compassionate", "750": "slow (long)",
    "639 b": "anger", "7227": "great, many", "2617 a": "steadfast love",
    "2347": "to pity, spare",
}
PREFIX = {"c": "and", "b": "in", "l": "to", "k": "like", "m": "from", "d": "the",
          "i": "(question)", "s": "which, that"}
# whole-word overrides for fused grammar words, keyed by consonant skeleton
SURFACE = {"בשלמי": "on whose account?", "בשלי": "on my account",
           "שבן": "which overnight (lit. son-of-a-night)"}
SUFFIX = {"1cs": "me/my", "2ms": "you/your", "2fs": "you/your",
          "3ms": "him/his/it", "3fs": "her/its", "1cp": "us/our",
          "2mp": "you/your", "3mp": "them/their", "3fp": "them/their"}
NOTES = [
    (1, 1, "ויהי", "va-y'hi — the vav prefix glues onto the verb and chains the story forward: 'and it was'. Biblical narrative links nearly every sentence with va-/vay-. You'll stop noticing it within a week."),
    (1, 1, "דבר", "d'var = 'word of' — davar squeezed into its construct form. Two nouns back to back mean 'X of Y': d'var-YHWH, 'the word of the LORD'. No word for 'of' needed."),
    (1, 2, "קום", "qum lekh — 'get up, go!' Two bare imperatives, no politeness. Commands are just the verb stripped to its core."),
    (1, 2, "העיר", "ha- = 'the'. The adjective follows its noun and takes ha- again: ha-ir ha-g'dola — literally 'the city, the great'."),
    (1, 3, "לברח", "li-vroach: the prefix l- ('to') + verb makes the infinitive — 'to flee'. Same l- you saw in lemor ('saying')."),
    (1, 4, "הטיל", "hetil — 'hurled'. Watch this verb: the LORD hurls a wind, the sailors hurl cargo, then hurl Jonah. It's the thread stitching chapter 1 together."),
    (1, 5, "אלהיו", "elohav = elohim + -av, 'his god(s)'. Ownership lives in the word ending: -i my, -kha your, -av his, -ah her."),
    (1, 6, "יתעשת", "yit'ashet — 'perhaps the god will spare a thought for us'. The captain uses the vague ha-elohim, 'the deity' — he has no idea whose god is angry."),
    (1, 9, "עברי", "ivri — 'a Hebrew'. This is the word the language is named after. Jonah's whole self-introduction is two words: ivri anokhi."),
    (1, 12, "בשלי", "beshelli — 'on my account'. Jonah admits it: b- (because) + shel (of) + -i (me)."),
    (2, 1, "דג", "dag gadol — 'a big fish'. That's all the Hebrew says. No whale anywhere in this book."),
    (2, 3, "קראתי", "qarati — 'I called'. The -ti ending = 'I did it'. Past-tense endings name the doer: -ti I, -ta you, no ending = he."),
    (3, 3, "שלשת", "sh'loshet yamim — 'a three-day walk'. Numbers come before the noun and pair with its construct form."),
    (3, 4, "ארבעים", "arba'im yom — 'forty day': after numbers above ten the noun often stays singular. od = 'yet/still': 'Yet forty days…'"),
    (3, 8, "שקים", "saqqim — sackcloth, plural of saq. One of a handful of Hebrew words English borrowed almost unchanged: sack."),
    (4, 2, "חנון", "chanun v'rachum — 'gracious and compassionate'. Jonah is quoting God's own self-description from Exodus 34:6 back at him, as a complaint."),
    (4, 6, "קיקיון", "qiqayon — the famous mystery plant. Nobody knows what it was; translators have guessed gourd, ivy, and castor-oil plant for two thousand years."),
    (4, 11, "רבו", "ribbo — 'ten thousand'. 'Twelve myriads' = 120,000 people who don't know their right hand from their left — and also much cattle. The book ends on God's question."),
]

# Genesis 1 adds its own vocabulary; same standard of curation as Jonah's.
CURATED.update({
    "7225": "beginning, first", "1254": "to create", "8414": "formless, waste",
    "922": "emptiness, void", "2822": "darkness", "7549": "expanse, firmament",
    "914": "to divide, separate", "996": "between", "216": "light",
    "215": "to give light", "2233": "seed", "1876": "to sprout",
    "1877": "grass, vegetation", "6212": "plant, herb", "2232": "to sow, seed",
    "6086": "tree, wood", "6529": "fruit", "4327": "kind, species",
    "3974": "light-giver, lamp", "226": "sign", "4150": "appointed time, season",
    "8141": "year", "3556": "star", "4910": "to rule", "4475": "rule, dominion",
    "8317": "to swarm, teem", "8318": "swarming things", "5775": "bird, flying thing",
    "3671": "wing", "1710": "fish (collective)", "6509": "to bear fruit",
    "4390": "to fill, be full", "7431": "creeping things", "7430": "to creep, crawl",
    "6754": "image", "1823": "likeness", "2145": "male", "5347": "female",
    "3533": "to subdue", "3418": "green plant", "402": "food",
    "6153": "evening", "1242": "morning", "8432": "midst", "4725": "place",
    "127": "ground, soil", "2009": "behold, look", "8478": "under, beneath",
    "7992": "third", "7243": "fourth", "2549": "fifth", "8345": "sixth",
})

NOTES = {"Jonah": NOTES, "Genesis": [
    (1, 1, "בראשית", "b'reshit — 'in a beginning'. b- ('in') fused onto reshit ('head, first'). The Bible opens not with a sentence but with a prepositional phrase."),
    (1, 1, "אלהים", "bara elohim — 'created God', i.e. 'God created'. Hebrew puts the verb first; the subject follows it. You'll meet this order in nearly every narrative sentence."),
    (1, 2, "תהו", "tohu va-vohu — 'wild and waste'. A rhyming pair, the kind of doubling Hebrew uses where English would reach for an adjective."),
    (1, 3, "ויאמר", "va-yomer — 'and he said'. The same vay- chain that drives Jonah: va- + verb, one step forward in the story."),
    (1, 3, "יהי", "y'hi or — 'let there be light'. Two words. y'hi is hayah in the jussive: a third-person command or wish."),
    (1, 4, "ויבדל", "va-yavdel bein … u-vein — 'he separated between X and between Y'. Hebrew repeats bein before each item; English says 'between' once."),
    (1, 5, "ויקרא", "va-yiqra … yom — 'he called the light day'. qara + l- means 'to call something by a name'."),
    (1, 5, "אחד", "yom echad — 'day one', not 'first day'. The other days take ordinals (sheni, sh'lishi); day one keeps the cardinal."),
    (1, 26, "נעשה", "na'aseh — 'let us make'. The plural has been argued over for two thousand years: royal plural, divine council, or something else."),
    (1, 27, "בצלמו", "b'tsalmo — 'in his image'. tselem + -o ('his'), the same possessive ending you met on elohav in Jonah 1:5."),
]}


def strip_cant(s):
    # keep niqqud (05B0-05BC, 05C1, 05C2, 05C7), drop cantillation/meteg/rafe
    out = []
    for ch in s:
        o = ord(ch)
        if 0x0591 <= o <= 0x05AF or o in (0x05BD, 0x05BF, 0x05C0, 0x05C3, 0x05C4, 0x05C5):
            continue
        out.append(ch)
    return "".join(out)


def consonants(s):
    return "".join(ch for ch in s if 0x05D0 <= ord(ch) <= 0x05EA)


def short_def(sd):
    sd = re.sub(r"\(.*?\)", "", sd)
    sd = re.sub(r"^(properly|figuratively|literally|specifically|generally),?\s*", "", sd.strip())
    sd = re.split(r"[;]", sd)[0]
    parts = sd.split(",")
    return ",".join(parts[:2]).strip().rstrip(".") or sd.strip()


def gloss_for(lemma, morph):
    lparts = lemma.split("/")
    mparts = morph.split("/") if morph else []
    pieces = []
    for lp in lparts:
        lp = lp.strip()
        if lp in PREFIX:
            pieces.append(PREFIX[lp])
        else:
            base = re.match(r"(\d+)", lp)
            g = CURATED.get(lp) or CURATED.get(base.group(1) if base else "")
            if not g and base:
                e = strongs.get("H" + base.group(1))
                g = short_def(e.get("strongs_def", "")) if e else "?"
            pieces.append(g or "?")
    # pronominal suffix: morph has one more segment starting with S
    if len(mparts) > len(lparts) and mparts[-1].startswith("S"):
        code = mparts[-1][2:] if mparts[-1].startswith("Sp") else mparts[-1][1:]
        sfx = SUFFIX.get(code)
        if sfx:
            pieces.append("+" + sfx)
    return " + ".join(pieces) if len(pieces) > 1 else pieces[0]


def english(book, chapters):
    """WEB text keyed by (chapter, verse), fetched a chapter at a time."""
    text = {}
    for c in chapters:
        path = fetch(WEB.format(book.lower(), c), f"web-{book}-{c}.json")
        for v in json.load(open(path, encoding="utf-8"))["verses"]:
            text[(v["chapter"], v["verse"])] = re.sub(r"\s+", " ", v["text"]).strip()
    return text


def build_book(name, heb, osis, chapters):
    tree = ET.parse(fetch(WLC.format(osis), f"{osis}.xml"))
    web = english(name, chapters)
    verses, unknown, unmatched = [], Counter(), []
    for velem in tree.iter(NS + "verse"):
        _, c, v = velem.get("osisID").split(".")
        c, v = int(c), int(v)
        if c not in chapters:
            continue
        words = []
        for child in velem:
            tag = child.tag.replace(NS, "")
            if tag == "w":
                raw = "".join(child.itertext())
                h = strip_cant(raw).replace("/", "")
                lemma = child.get("lemma", "") or ""
                for lp in lemma.split("/"):
                    lp = lp.strip()
                    if not re.match(r"\d", lp) and lp not in PREFIX:
                        unknown[lp] += 1
                g = SURFACE.get(consonants(h)) or gloss_for(lemma, child.get("morph", "") or "")
                words.append({"h": h, "g": g})
            elif tag == "seg" and child.get("type") == "x-maqqef" and words:
                words[-1]["h"] += "־"
        for (nc, nv, skel, note) in NOTES.get(name, []):
            if (nc, nv) != (c, v):
                continue
            # one note per word, so two notes on a verse can't overwrite each other
            spot = next((w for w in words if skel in consonants(w["h"]) and "n" not in w), None)
            if spot is None:
                unmatched.append((name, nc, nv, skel))
            else:
                spot["n"] = note
        verses.append({"c": c, "v": v, "en": web[remap(name, c, v)], "words": words})
    return {"name": name, "heb": heb, "verses": verses}, unknown, unmatched


def check(books, unknown, unmatched):
    """Smallest set of assertions that fail if the pipeline breaks."""
    assert not unmatched, f"notes that matched no word: {unmatched}"
    assert not unknown, f"lemma prefixes with no gloss: {dict(unknown)}"
    expected = {name: n for name, _, _, _, n in TEXTS}
    for book in books:
        vs = book["verses"]
        assert len(vs) == expected[book["name"]], \
            f"{book['name']}: expected {expected[book['name']]} verses, got {len(vs)}"
        assert len({(x["c"], x["v"]) for x in vs}) == len(vs), f"{book['name']}: duplicate verses"
        assert book["heb"].strip(), f"{book['name']}: no Hebrew name"
        for verse in vs:
            where = f"{book['name']} {verse['c']}:{verse['v']}"
            assert verse["en"].strip(), f"{where} has no English"
            assert verse["words"], f"{where} has no words"
            for w in verse["words"]:
                assert w["h"].strip(), f"{where} has an empty word"
                assert w["g"].strip(), f"{where}: {w['h']} has no gloss"
    assert len({b["name"] for b in books}) == len(books), "duplicate book names"
    total = sum(len(b["verses"]) for b in books)
    words = sum(len(v["words"]) for b in books for v in b["verses"])
    notes = sum(1 for b in books for v in b["verses"] for w in v["words"] if "n" in w)
    print(f"check ok — {len(books)} books, {total} verses, {words} words, {notes} notes")
    # glosses that fell through to raw Strong's are candidates for curation
    # only the literal "?" placeholder counts — a gloss like "what?" is fine
    weak = Counter((w["h"], w["g"]) for b in books for v in b["verses"]
                   for w in v["words"] if "?" in w["g"].split(" + "))
    if weak:
        print("QUESTIONABLE GLOSSES:")
        for (h, g), n in weak.most_common(20):
            print(f"  {n}x {h} -> {g}")


if __name__ == "__main__":
    books, unknown, unmatched = [], Counter(), []
    for name, heb, osis, chapters, _ in TEXTS:
        book, unk, unm = build_book(name, heb, osis, chapters)
        books.append(book)
        unknown.update(unk)
        unmatched += unm
    check(books, unknown, unmatched)
    if "--check" not in sys.argv:
        out = os.path.join(HERE, "Mikra", "Texts.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(books, f, ensure_ascii=False, indent=0)
        print(f"wrote {out}")

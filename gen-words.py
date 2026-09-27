#!/usr/bin/env python3
"""Generate Mikra/Words.json (the 300 commonest content words in the Hebrew Bible)
and Mikra/Decks.json (the curated Pronouns and Numbers decks).

Counts lemmas across all 39 books of OSHB/WLC (CC BY 4.0), keeps content words
only (no particles, no proper nouns, no Aramaic), and pairs each with a curated
gloss. "See also" links come from Strong's own derivation graph, hand-pruned.

    ./gen-words.py           # write Mikra/Words.json
    ./gen-words.py --check   # run the self-check only
"""
import json, os, re, sys, unicodedata, urllib.request
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

NS = "{http://www.bibletechnologies.net/2003/OSIS/namespace}"
HERE = os.path.dirname(os.path.abspath(__file__))
# gen-jonah.py hardcoded a scratchpad path that died with its session; cache next to the script instead.
CACHE = os.path.join(HERE, ".cache")
WLC = "https://raw.githubusercontent.com/openscriptures/morphhb/master/wlc/{}.xml"
STRONGS = "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js"
BOOKS = """1Chr 1Kgs 1Sam 2Chr 2Kgs 2Sam Amos Dan Deut Eccl Esth Exod Ezek Ezra Gen Hab Hag Hos
Isa Jer Job Joel Jonah Josh Judg Lam Lev Mal Mic Nah Neh Num Obad Prov Ps Ruth Song Zech Zeph""".split()

DECK_SIZE = 300
BAND = 100

# Morphology prefixes to exclude. Function words carry the grammar but aren't
# card-shaped (most are one-letter proclitics); proper nouns aren't vocabulary.
FUNC = {"T", "R", "P", "D", "C"}   # particle, preposition, pronoun, adverb, conjunction
PROPER = {"Np", "Ng"}              # proper noun, gentilic

# Curated glosses. Strong's definitions are verbose Victorian prose ("properly,
# the whole; hence, all, any or every..."); a card needs three words. Verbs are
# glossed as infinitives against the 3ms-perfect citation form, the convention
# every Hebrew lexicon uses — explained once in the deck header, not per card.
GLOSS = {
    "3605": "all, every, whole", "559": "to say", "1961": "to be, become",
    "430": "God, gods", "935": "to come, go in", "4428": "king",
    "776": "land, earth", "3117": "day", "376": "man, each one",
    "6440": "face, presence", "5414": "to give, put", "3027": "hand",
    "1697": "word, thing", "7200": "to see", "1": "father",
    "8085": "to hear, obey", "1696": "to speak", "3427": "to sit, dwell",
    "3318": "to go out", "7725": "to return, turn back", "3212": "to go, walk",
    "259": "one", "3947": "to take", "3045": "to know", "5927": "to go up",
    "8141": "year", "8034": "name", "7971": "to send", "4191": "to die",
    "398": "to eat", "5650": "servant, slave", "802": "woman, wife",
    "8147": "two", "5315": "soul, life, self", "3548": "priest",
    "7121": "to call, proclaim", "1870": "way, road", "5375": "to lift, carry",
    "251": "brother", "1323": "daughter", "3967": "hundred", "4325": "water",
    "120": "man, mankind", "2022": "mountain", "5975": "to stand",
    "1980": "to walk, go", "505": "thousand", "5221": "to strike, smite",
    "3205": "to give birth, beget", "6310": "mouth", "6680": "to command",
    "8104": "to keep, guard", "6944": "holiness, a holy thing", "4672": "to find",
    "136": "the Lord", "5769": "forever, ancient time", "5307": "to fall",
    "7969": "three", "4941": "judgement, justice", "8064": "heavens, sky",
    "8269": "chief, official", "8432": "midst, middle", "2719": "sword",
    "3701": "silver, money", "4196": "altar", "4725": "place", "3220": "sea",
    "7651": "seven", "2091": "gold", "3381": "to go down",
    "7307": "wind, spirit, breath", "784": "fire", "1129": "to build",
    "5002": "utterance, declaration", "8179": "gate", "5046": "to tell, declare",
    "1818": "blood", "168": "tent", "2568": "five", "6240": "-teen (in compounds)",
    "5439": "around, surrounding", "6086": "tree, wood", "1288": "to bless",
    "3372": "to fear", "113": "lord, master", "3627": "vessel, article",
    "702": "four", "4421": "war, battle", "5030": "prophet", "6242": "twenty",
    "4940": "family, clan", "5493": "to turn aside, remove", "3899": "bread, food",
    "6256": "time", "3772": "to cut; to make (a covenant)",
    "2388": "to be strong, seize", "5647": "to serve, work", "341": "enemy",
    "1285": "covenant", "2320": "month, new moon", "7126": "to draw near",
    "639": "nose; anger", "6629": "flock, sheep", "68": "stone",
    "1320": "flesh, body", "2421": "to live", "7563": "wicked, guilty",
    "4294": "staff, rod; tribe", "3824": "heart, mind", "7272": "foot",
    "4390": "to fill, be full", "410": "God, mighty one", "1366": "border, territory",
    "2398": "to sin, miss", "5288": "boy, young man, servant",
    "7965": "peace, welfare", "2142": "to remember", "4639": "deed, work",
    "3915": "night", "2428": "strength, army, wealth",
    "3423": "to possess, dispossess", "5771": "iniquity, guilt",
    "2233": "seed, offspring", "3789": "to write", "7130": "inward part, midst",
    "127": "ground, soil", "1245": "to seek", "4150": "appointed time, feast",
    "8451": "instruction, law", "5159": "inheritance", "517": "mother",
    "8354": "to drink", "4264": "camp", "5186": "to stretch out, turn",
    "8337": "six", "1242": "morning", "5337": "to deliver, snatch away",
    "7901": "to lie down", "4397": "messenger, angel", "157": "to love",
    "4503": "offering, gift", "3254": "to add, do again", "3467": "to save, deliver",
    "6662": "righteous", "3615": "to finish, complete", "8199": "to judge",
    "622": "to gather", "727": "ark, chest", "905": "alone, apart; linen",
    "3519": "glory, honour", "3709": "palm, hollow of the hand", "3201": "to be able",
    "8081": "oil", "929": "beast, cattle", "7626": "tribe; rod",
    "7453": "neighbour, friend", "241": "ear", "1540": "to uncover; to go into exile",
    "7650": "to swear an oath", "6": "to perish, be lost", "4687": "commandment",
    "1241": "cattle, herd", "7223": "first, former", "2205": "old; elder",
    "8193": "lip; edge; language", "6235": "ten", "7592": "to ask",
    "7812": "to bow down, worship", "7970": "thirty", "6942": "to be holy, consecrate",
    "995": "to understand, discern", "977": "to choose", "1755": "generation",
    "2026": "to kill, slay", "4399": "work, occupation", "312": "another, other",
    "1875": "to seek, inquire", "6607": "entrance, doorway", "2351": "outside, street",
    "2572": "fifty", "2077": "sacrifice", "5127": "to flee",
    "1368": "mighty man, warrior", "6666": "righteousness", "8055": "to rejoice",
    "4194": "death", "5437": "to go around, surround", "8145": "second",
    "3680": "to cover", "6828": "north", "7230": "abundance, multitude",
    "5060": "to touch, strike", "7665": "to break", "2451": "wisdom",
    "5712": "congregation, assembly", "8130": "to hate", "7843": "to destroy, ruin",
    "5265": "to set out, journey", "5656": "service, work", "7291": "to pursue, chase",
    "2583": "to encamp", "3196": "wine", "3225": "right hand, south",
    "4908": "dwelling, tabernacle", "2450": "wise", "3678": "throne, seat",
    "705": "forty", "6437": "to turn, face", "6153": "evening",
    "2076": "to sacrifice, slaughter", "8121": "sun", "4557": "number, count",
    "6499": "bull, young bull", "7604": "to remain, be left", "6912": "to bury",
    "2346": "wall (of a city)", "7931": "to dwell, settle", "2706": "statute, decree",
    "6908": "to gather, collect", "571": "truth, faithfulness", "6106": "bone; self, very",
    "5066": "to draw near, approach", "7993": "to throw, cast", "2803": "to think, reckon",
    "2534": "wrath, heat", "2677": "half", "6951": "assembly, congregation",
    "3920": "to capture, seize", "216": "light", "982": "to trust",
    "7393": "chariot, chariotry", "6918": "holy", "5104": "river",
    "3477": "upright, straight", "6529": "fruit", "6664": "righteousness, what is right",
    "269": "sister", "6471": "time, occurrence; step", "1060": "firstborn",
    "8441": "abomination", "8210": "to pour out, shed", "4467": "kingdom, dominion",
    "8313": "to burn", "3956": "tongue, language", "3513": "to be heavy, honour",
    "1058": "to weep", "1431": "to be great, grow", "5012": "to prophesy",
    "4054": "pastureland, open land", "954": "to be ashamed", "3034": "to praise, give thanks",
    "8267": "lie, falsehood", "3190": "to be good, do well", "5982": "pillar, column",
    "5045": "the Negev, the south", "3671": "wing; edge, corner", "3847": "to put on, clothe",
    "7676": "sabbath, rest", "6083": "dust, dry earth", "8083": "eight",
    "539": "to believe, trust; be faithful", "7992": "third", "5162": "to comfort; relent",
    "3498": "to remain, be left over", "3532": "lamb", "2708": "statute, ordinance",
    "8548": "continually, regular", "7323": "to run", "1116": "high place",
    "4758": "appearance, sight", "7911": "to forget", "4592": "little, few",
    "7458": "famine, hunger", "7341": "width, breadth",
    "7125": "to meet (usually לִקְרַאת, toward)", "5785": "skin, hide",
    "8334": "to serve, minister", "7637": "seventh", "7646": "to be satisfied",
    "2543": "donkey", "4422": "to escape, deliver", "2891": "to be clean, purify",
    "753": "length", "2015": "to turn, overturn", "8057": "joy, gladness",
    "2889": "clean, pure", "6588": "transgression, rebellion",
    "2181": "to be unfaithful, prostitute oneself", "1847": "knowledge",
    "5797": "strength, might", "2459": "fat, the best part", "3754": "vineyard",
    "5676": "side, region across", "1616": "sojourner, foreigner", "5462": "to shut, close",
    "2220": "arm; strength", "3742": "cherub", "7657": "seventy",
    "8549": "blameless, whole", "4438": "kingdom, royal power",
}

# Strong's derivation is ETYMOLOGICAL, not synchronic: it links words whose
# shared origin is contested, opaque, or plain wrong. These links are dropped
# so "See also" only claims relationships a learner can actually use.
DROP_LINKS = {
    frozenset(("3027", "3709")),   # hand / palm — different roots
    frozenset(("3027", "3034")),   # hand / to praise — opaque
    frozenset(("8034", "8064")),   # name / heavens — not related
    frozenset(("1323", "1129")),   # daughter / to build — contested
    frozenset(("1129", "68")),     # to build / stone — not related
    frozenset(("3627", "3615")),   # vessel / to finish — opaque
    frozenset(("7901", "7931")),   # to lie down / to dwell — different roots
    frozenset(("3680", "3678")),   # to cover / throne — kissē' is a loanword
}

# Letter pairs a beginner actually mixes up, from the confusables already
# warned about on the letter cards in Content.swift.
CONFUSABLE = {frozenset(p) for p in
              [("ד", "ר"), ("ב", "כ"), ("ה", "ח"), ("ם", "ס"), ("ו", "ז"),
               ("ג", "נ"), ("ת", "ח"), ("כ", "פ"), ("ע", "צ")]}


def fetch(url, name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        print(f"  downloading {name}", file=sys.stderr)
        urllib.request.urlretrieve(url, path)
    return path


def consonants(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if "א" <= c <= "ת")


def count_lemmas():
    """Lemma -> (occurrences, dominant morph code), plus the set occurring in Jonah,
    plus (lemma, consonantal surface form) counts for the curated decks."""
    cnt, pos, jonah, forms = Counter(), defaultdict(Counter), set(), Counter()
    for book in BOOKS:
        root = ET.parse(fetch(WLC.format(book), f"{book}.xml")).getroot()
        for w in root.iter(NS + "w"):
            morph = w.get("morph", "") or ""
            if morph.startswith("A"):
                continue  # Aramaic (Daniel, Ezra) — this is a Hebrew deck
            lemmas = (w.get("lemma", "") or "").split("/")
            morphs = morph.lstrip("H").split("/")
            # OSHB writes homograph lemmas as "859 a"; the decks count by surface form, not sense
            tail = re.match(r"^[a-z]?\s*(\d+)", lemmas[-1].strip())
            if tail:
                forms[(tail.group(1), consonants((w.text or "").split("/")[-1]))] += 1
            for i, part in enumerate(lemmas):
                m = re.match(r"^[a-z]?(\d+)([a-z])?$", part.strip())
                if not m:
                    continue  # bare prefix letter, e.g. the "b" of "b/7225"
                num = m.group(1)
                cnt[num] += 1
                pos[num][(morphs[i] if i < len(morphs) else "")[:2]] += 1
                if book == "Jonah":
                    jonah.add(num)
    return cnt, {k: v.most_common(1)[0][0] for k, v in pos.items()}, jonah, forms


# Curated decks: (deck id, title, deck note, cards). A card is one meaning with all its
# forms: (card id, gloss, [(form id, Strong's, pointed form, form label)]). Forms that
# share a Strong's number get their own id so "Learn this" tracks each one.
DECKS = [
    ("pronouns", "Pronouns",
     "The independent pronouns. Hebrew usually folds the subject into the verb, "
     "so these stand alone for emphasis or in sentences without a verb.",
     [("i", "I", [("589", "589", "אֲנִי", "I"), ("595", "595", "אָנֹכִי", "I (longer form)")]),
      ("you", "you", [("859a", "859", "אַתָּה", "m. sg."), ("859c", "859", "אַתְּ", "f. sg."),
                      ("859d", "859", "אַתֶּם", "m. pl."), ("859e", "859", "אַתֵּנָה", "f. pl.")]),
      ("he", "he, she, it", [("1931", "1931", "הוּא", "he, it"), ("1931f", "1931", "הִיא", "she, it")]),
      ("we", "we", [("587", "587", "אֲנַחְנוּ", "we")]),
      ("they", "they", [("1992", "1992", "הֵם", "m."), ("1992b", "1992", "הֵמָּה", "m. (longer form)"),
                        ("2007", "2007", "הֵנָּה", "f.")])]),
    ("numbers", "Numbers",
     "One to ten, each with both genders. Three to ten swap endings: the ־ָה form "
     "counts masculine nouns, the bare form counts feminine nouns.",
     [("1", "one", [("259", "259", "אֶחָד", "m."), ("259f", "259", "אַחַת", "f.")]),
      ("2", "two", [("8147", "8147", "שְׁנַיִם", "m."), ("8147f", "8147", "שְׁתַּיִם", "f.")]),
      ("3", "three", [("7969", "7969", "שְׁלֹשָׁה", "m."), ("7969f", "7969", "שָׁלֹשׁ", "f.")]),
      ("4", "four", [("702", "702", "אַרְבָּעָה", "m."), ("702f", "702", "אַרְבַּע", "f.")]),
      ("5", "five", [("2568", "2568", "חֲמִשָּׁה", "m."), ("2568f", "2568", "חָמֵשׁ", "f.")]),
      ("6", "six", [("8337", "8337", "שִׁשָּׁה", "m."), ("8337f", "8337", "שֵׁשׁ", "f.")]),
      ("7", "seven", [("7651", "7651", "שִׁבְעָה", "m."), ("7651f", "7651", "שֶׁבַע", "f.")]),
      ("8", "eight", [("8083", "8083", "שְׁמֹנָה", "m."), ("8083f", "8083", "שְׁמֹנֶה", "f.")]),
      ("9", "nine", [("8672", "8672", "תִּשְׁעָה", "m."), ("8672f", "8672", "תֵּשַׁע", "f.")]),
      ("10", "ten", [("6235", "6235", "עֲשָׂרָה", "m."), ("6235f", "6235", "עֶשֶׂר", "f.")]),
      ("100", "hundred", [("3967", "3967", "מֵאָה", "hundred"), ("3967d", "3967", "מָאתַיִם", "two hundred"),
                          ("3967p", "3967", "מֵאוֹת", "hundreds")]),
      ("1000", "thousand", [("505", "505", "אֶלֶף", "thousand"), ("505d", "505", "אַלְפַּיִם", "two thousand"),
                            ("505p", "505", "אֲלָפִים", "thousands")])]),
]


def build_decks(forms):
    def form(fid, strongs, h, label):
        return {"s": fid, "h": h, "g": label, "n": forms[(strongs, consonants(h))], "root": [], "conf": []}
    return [{"id": did, "title": title, "note": note,
             "cards": [{"s": cid, "h": fs[0][2], "g": gloss, "n": sum(form(*f)["n"] for f in fs),
                        "root": [], "conf": [], "forms": [form(*f) for f in fs]}
                       for cid, gloss, fs in cards]}
            for did, title, note, cards in DECKS]


def build():
    cnt, pos, jonah, forms = count_lemmas()
    strongs_js = open(fetch(STRONGS, "strongs.js"), encoding="utf-8").read()
    lex = json.loads(re.search(r"=\s*(\{.*\})\s*;?\s*(module|$)", strongs_js, re.S).group(1))

    ranked = [k for k, _ in cnt.most_common()
              if pos[k][:1] not in FUNC and pos[k] not in PROPER]
    deck = ranked[:DECK_SIZE]
    index = {k: i for i, k in enumerate(deck)}

    # Same-root families, from Strong's derivation graph minus the pruned links.
    parent = {k: k for k in deck}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    used_drops = set()
    for k in deck:
        for ref in re.findall(r"H(\d+)", lex.get("H" + k, {}).get("derivation", "")):
            if ref not in index:
                continue
            pair = frozenset((k, ref))
            if pair in DROP_LINKS:
                used_drops.add(pair)
                continue
            if find(k) != find(ref):
                parent[find(k)] = find(ref)
    families = defaultdict(list)
    for k in deck:
        families[find(k)].append(k)
    root_of = {k: sorted((x for x in families[find(k)] if x != k), key=lambda y: index[y])
               for k in deck}

    # Look-alike pairs: same consonant skeleton but for one confusable letter.
    skeleton = {k: consonants(lex["H" + k]["lemma"]) for k in deck}
    conf = defaultdict(list)
    for i, a in enumerate(deck):
        for b in deck[i + 1:]:
            x, y = skeleton[a], skeleton[b]
            if not x or len(x) != len(y):
                continue
            diff = [(p, q) for p, q in zip(x, y) if p != q]
            if len(diff) == 1 and frozenset(diff[0]) in CONFUSABLE:
                conf[a].append(b)
                conf[b].append(a)

    cards = [{"s": k, "h": lex["H" + k]["lemma"], "g": GLOSS[k], "n": cnt[k],
              "j": k in jonah, "root": root_of[k], "conf": sorted(conf[k], key=lambda y: index[y])}
             for k in deck]
    return cards, DROP_LINKS - used_drops, build_decks(forms)


def check_decks(decks):
    for deck in decks:
        ids = [f["s"] for c in deck["cards"] for f in c["forms"]]
        assert len(set(ids)) == len(ids), f"{deck['id']} has duplicate form ids"
        for c in deck["cards"]:
            assert c["forms"] and c["g"].strip(), f"{deck['id']}: {c['s']} is blank"
            for f in c["forms"]:
                assert f["n"] > 0, f"{deck['id']}: {f['h']} never occurs"
                assert f["g"].strip() and f["h"].strip(), f"{deck['id']}: {f['s']} is blank"
    print("decks ok — " + ", ".join(f"{d['title']} {len(d['cards'])}" for d in decks))


def check(cards, stale_drops):
    """Smallest set of assertions that fail if the pipeline breaks."""
    assert len(cards) == DECK_SIZE, f"expected {DECK_SIZE} cards, got {len(cards)}"
    ids = {c["s"] for c in cards}
    assert len(ids) == DECK_SIZE, "duplicate Strong's numbers"
    faces = [c["h"] for c in cards]
    assert len(set(faces)) == DECK_SIZE, \
        f"duplicate Hebrew faces: {[f for f in faces if faces.count(f) > 1]}"
    for c in cards:
        assert c["g"].strip(), f"{c['s']} has no gloss"
        assert c["h"].strip(), f"{c['s']} has no Hebrew"
        assert c["n"] > 0, f"{c['s']} has no occurrences"
        for ref in c["root"] + c["conf"]:
            assert ref in ids, f"{c['s']} points at {ref}, which is not in the deck"
            assert ref != c["s"], f"{c['s']} points at itself"
    counts = [c["n"] for c in cards]
    assert counts == sorted(counts, reverse=True), "deck is not in frequency order"
    assert not stale_drops, \
        "DROP_LINKS entries that matched nothing: " + str([sorted(p) for p in stale_drops])
    missing = set(GLOSS) - ids
    assert not missing, f"GLOSS has {len(missing)} entries not in the deck: {sorted(missing)[:5]}"
    print(f"check ok — {len(cards)} cards, "
          f"{sum(1 for c in cards if c['root'] or c['conf'])} with a 'See also', "
          f"{sum(1 for c in cards if c['j'])} in Jonah, "
          f"bands floor at {cards[BAND-1]['n']}/{cards[2*BAND-1]['n']}/{cards[-1]['n']}")


if __name__ == "__main__":
    cards, stale, decks = build()
    check(cards, stale)
    check_decks(decks)
    if "--check" not in sys.argv:
        for name, data in (("Words.json", cards), ("Decks.json", decks)):
            out = os.path.join(HERE, "Mikra", name)
            with open(out, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
            print(f"wrote {out}")

#!/usr/bin/env python3
"""Generate Mikra/Words.json (the 1000 commonest content words in the Hebrew Bible)
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

DECK_SIZE = 1000
BANDS = [100, 100, 100, 200, 500]  # Words.swift slices the deck the same way

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
    # Words 301–1000.
    "8045": "to destroy, exterminate", "6098": "counsel, advice, plan", "2734": "to burn (with anger)",
    "3206": "child, boy", "7891": "to sing", "8255": "shekel", "2931": "unclean",
    "3925": "to learn; to teach", "8002": "peace offering", "6051": "cloud",
    "7069": "to buy, acquire", "8074": "to be desolate, appalled", "7896": "to put, set",
    "6285": "side, corner, edge", "7350": "far, distant", "6419": "to pray",
    "1167": "owner, master, husband; Baal", "5826": "to help", "4910": "to rule, have dominion",
    "7043": "to be slight; to curse", "2145": "male", "5641": "to hide, conceal",
    "5782": "to awake, rouse", "1964": "palace, temple", "4376": "to sell", "2822": "darkness",
    "214": "treasure, storehouse", "3289": "to advise, counsel", "7794": "ox, bull", "226": "sign",
    "205": "wickedness, trouble", "6041": "poor, afflicted", "4931": "charge, duty, watch",
    "6697": "rock", "7138": "near", "7392": "to ride", "5061": "plague, mark, stroke",
    "1486": "lot (cast)", "3444": "salvation, deliverance", "8605": "prayer",
    "4735": "livestock, cattle", "7198": "bow", "1270": "iron", "5291": "girl, young woman",
    "8641": "contribution, offering", "3240": "to rest; to set down, leave",
    "5324": "to stand, station oneself", "4217": "east, sunrise", "7023": "wall",
    "7998": "plunder, spoil", "4720": "sanctuary", "5795": "goat", "2199": "to cry out",
    "730": "cedar", "3001": "to be dry, dry up", "1892": "breath, vapour; vanity",
    "631": "to bind, imprison", "2781": "reproach, disgrace", "7782": "ram's horn, shofar",
    "990": "belly, womb", "7364": "to wash, bathe", "6381": "to be wonderful, extraordinary",
    "7979": "table", "5775": "birds, fowl", "1389": "hill",
    "8628": "to blow (a horn); to drive (a peg)", "5027": "to look, regard",
    "7378": "to contend, dispute", "5707": "witness", "3684": "fool", "6010": "valley",
    "4886": "to anoint", "2580": "favour, grace", "7495": "to heal", "1293": "blessing",
    "6921": "east; east wind", "270": "to grasp, seize",
    "3603": "round loaf; talent (weight); district", "3802": "shoulder, side",
    "5117": "to rest, settle", "6566": "to spread out", "7093": "end", "6913": "grave, tomb",
    "7611": "remnant, rest", "272": "possession, property", "1272": "to flee",
    "5329": "to oversee; leader (of music)", "1397": "man, strong man",
    "8610": "to seize, grasp, handle", "7925": "to rise early", "3782": "to stumble",
    "801": "offering by fire", "5262": "drink offering; molten image", "2472": "dream",
    "3335": "to form, shape; potter", "4043": "shield", "1869": "to tread, march; to bend (a bow)",
    "8552": "to be complete, finished", "7167": "to tear, rend", "8198": "maidservant",
    "779": "to curse", "5341": "to keep, guard, watch", "1516": "valley",
    "8248": "to give drink, water", "1369": "might, strength", "2282": "feast, festival",
    "7070": "reed, stalk; measuring rod", "1730": "beloved; uncle", "34": "poor, needy",
    "6160": "desert plain, the Arabah", "7379": "dispute, lawsuit", "319": "end, outcome, latter time",
    "7004": "incense", "2555": "violence", "5088": "vow", "433": "God (poetic form)",
    "734": "path, way", "8346": "sixty", "3198": "to rebuke, reprove", "5193": "to plant",
    "6299": "to ransom, redeem", "5157": "to inherit, take possession", "5715": "testimony",
    "2308": "to cease, stop", "5553": "crag, cliff, rock", "8672": "nine", "4392": "full",
    "8416": "praise, song of praise", "7368": "to be far, distant", "7381": "scent, smell, odour",
    "7703": "to devastate, destroy", "7521": "to be pleased with, accept",
    "134": "socket, base, pedestal", "4210": "psalm", "4284": "thought, plan, device",
    "519": "maidservant, female slave", "490": "widow", "2389": "strong",
    "7522": "favour, goodwill, pleasure", "2232": "to sow", "6466": "to do, make, work",
    "7243": "fourth", "1612": "vine", "8127": "tooth; ivory", "3707": "to vex, provoke to anger",
    "6817": "to cry out", "5999": "toil, trouble", "1581": "camel", "8040": "left hand, left side",
    "1692": "to cling, cleave to", "14": "to be willing, consent", "3407": "curtain (of the tabernacle)",
    "1706": "honey", "3373": "fearing, afraid", "6172": "nakedness", "4791": "height, high place",
    "7723": "emptiness, falsehood, vanity", "5560": "fine flour", "2319": "new",
    "4682": "unleavened bread", "4082": "province", "3332": "to pour, cast (metal)",
    "4279": "tomorrow", "5080": "to drive away, banish", "1234": "to split, break open",
    "8597": "beauty, glory", "2865": "to be shattered, dismayed", "314": "last, latter",
    "5703": "forever, perpetuity", "4058": "to measure", "7225": "beginning, first fruits",
    "8582": "to wander, go astray", "3526": "to wash (clothes)", "2372": "to see, have a vision",
    "7175": "board, plank", "6555": "to break through, burst out", "5381": "to reach, overtake",
    "1330": "virgin, young woman", "1104": "to swallow", "4148": "discipline, instruction",
    "2885": "ring, signet ring", "530": "faithfulness, steadfastness",
    "5668": "for the sake of, because of (בַּעֲבוּר)", "6343": "dread, terror", "646": "ephod",
    "5062": "to strike, smite; to be defeated", "4948": "weight", "1698": "plague, pestilence",
    "4026": "tower", "6738": "shadow, shade", "898": "to act treacherously",
    "8504": "blue, violet (wool)", "6453": "Passover", "1347": "majesty, pride",
    "561": "word, saying", "3957": "chamber, room", "2595": "spear",
    "3320": "to take one's stand, present oneself", "8242": "sackcloth", "5545": "to forgive, pardon",
    "5038": "carcass, corpse", "1544": "idols", "4347": "blow, wound, plague",
    "5564": "to lean, support, lay (a hand)", "7617": "to take captive", "1644": "to drive out",
    "4975": "loins, hips", "6823": "to overlay, plate", "7355": "to have compassion",
    "7523": "to murder, kill", "1800": "poor, weak, lowly", "7716": "sheep, lamb; one of a flock",
    "6113": "to restrain, hold back, shut up", "1523": "to rejoice",
    "7503": "to sink, relax; to let go, abandon", "4904": "bed, couch",
    "6293": "to meet, encounter; to entreat", "4960": "feast, banquet", "6967": "height, stature",
    "5237": "foreign, foreigner", "817": "guilt; guilt offering", "970": "young man",
    "7181": "to pay attention, listen", "2549": "fifth", "2671": "arrow", "2167": "to sing, make music",
    "835": "happiness; happy is (אַשְׁרֵי)", "4784": "to be rebellious, defiant",
    "4186": "dwelling, seat", "5057": "leader, ruler, prince", "4818": "chariot",
    "5352": "to be innocent, free of guilt", "7194": "to bind; to conspire",
    "2296": "to gird, put on (a belt)", "7321": "to shout, sound an alarm", "2461": "milk",
    "7667": "breaking, fracture, ruin", "400": "food", "2029": "to conceive, become pregnant",
    "1473": "exile, exiles", "6584": "to strip off; to raid", "3256": "to discipline, chastise",
    "959": "to despise", "2040": "to tear down, overthrow",
    "5331": "endurance, perpetuity; forever (לָנֶצַח)", "3303": "beautiful, handsome",
    "8394": "understanding", "3871": "tablet, board", "215": "to give light, shine",
    "962": "to plunder", "4611": "deed, practice", "7339": "open square, plaza",
    "8393": "produce, yield, harvest", "7068": "jealousy, zeal", "5207": "soothing, pleasing (of an aroma)",
    "8252": "to be quiet, at rest", "3245": "to found, lay a foundation", "914": "to separate, divide",
    "3658": "lyre, harp", "4256": "division (of priests), portion", "5631": "eunuch, court official",
    "4501": "lampstand", "1280": "bar (of a gate), crossbar", "983": "security, safety; securely (לָבֶטַח)",
    "1588": "garden", "5128": "to shake, wander, stagger", "3176": "to wait, hope",
    "582": "man, mankind (poetic)", "3374": "fear, reverence", "2945": "little children, dependents",
    "5422": "to tear down, demolish", "8144": "scarlet, crimson", "2100": "to flow, gush",
    "2723": "ruin, waste place", "3490": "orphan, fatherless", "7264": "to tremble, quake, rage",
    "268": "back, behind, backwards", "553": "to be strong; to strengthen", "6763": "rib; side",
    "6663": "to be righteous, in the right", "6586": "to rebel, transgress", "3985": "to refuse",
    "2550": "to spare, have pity", "693": "to lie in wait, ambush", "2740": "burning anger",
    "238": "to give ear, listen", "7622": "captivity; fortunes (שׁוּב שְׁבוּת, to restore)",
    "4631": "cave", "5203": "to forsake, abandon, leave", "160": "love", "5923": "yoke",
    "374": "ephah (dry measure)", "1589": "to steal", "8047": "desolation, horror",
    "1715": "grain, corn", "6833": "bird, sparrow", "8435": "generations, descendants; account (of origins)",
    "56": "to mourn", "6950": "to assemble, gather", "4899": "anointed one, messiah",
    "4131": "to totter, shake, be moved", "2729": "to tremble, be afraid", "3515": "heavy; severe",
    "8384": "fig, fig tree", "4912": "proverb, parable", "2656": "delight, pleasure, desire",
    "5148": "to lead, guide", "2219": "to scatter, winnow", "1767": "enough, sufficiency",
    "4751": "bitter", "5739": "flock, herd", "926": "to be terrified; to hasten",
    "4820": "deceit, treachery", "8084": "eighty", "6467": "work, deed",
    "998": "understanding, discernment", "4393": "fullness, what fills",
    "3637": "to be humiliated, put to shame", "2132": "olive, olive tree", "2315": "room, inner chamber",
    "2436": "bosom, lap", "4306": "rain", "713": "purple (wool)",
    "1219": "fortified, inaccessible; to gather (grapes)", "8492": "new wine", "4405": "word, speech",
    "6370": "concubine", "7778": "gatekeeper", "1637": "threshing floor", "3556": "star",
    "6239": "riches, wealth", "3557": "to contain, hold; to sustain, provide",
    "1580": "to deal with, repay; to wean", "1364": "high, tall; haughty",
    "7122": "to meet, encounter, befall", "6822": "to watch, keep lookout",
    "4013": "fortress, fortified city", "3950": "to gather, glean", "875": "well",
    "2620": "to take refuge", "4581": "refuge, stronghold", "4603": "to act unfaithfully, trespass",
    "2796": "craftsman, artisan", "7832": "to laugh, play, mock",
    "8643": "shout, blast (of a trumpet), alarm", "4159": "wonder, sign, portent",
    "6231": "to oppress, extort", "8398": "world", "3468": "salvation, safety",
    "3665": "to be humbled, subdued; to subdue", "3368": "precious, costly",
    "6040": "affliction, misery", "7098": "end, extremity, edge", "423": "oath, curse",
    "7561": "to be wicked; to condemn", "3766": "to bow down, kneel", "5254": "to test, try",
    "7186": "hard, harsh, stubborn", "4900": "to draw, drag, prolong",
    "5236": "foreignness; foreigner (בֶּן־נֵכָר)", "2932": "uncleanness", "8415": "the deep, ocean depths",
    "339": "coastland, island", "3816": "people, nation", "4932": "second, double, copy",
    "6189": "uncircumcised", "2377": "vision", "212": "wheel", "4436": "queen", "5695": "calf",
    "1653": "rain, shower", "5358": "to avenge, take vengeance", "816": "to be guilty",
    "2399": "sin, offence", "6883": "leprosy, skin disease", "2236": "to sprinkle, scatter",
    "3618": "bride; daughter-in-law", "8184": "barley", "8668": "salvation, deliverance",
    "860": "she-donkey", "197": "porch, vestibule", "1993": "to roar, murmur, be in uproar",
    "748": "to be long; to prolong", "2623": "faithful, devout; the faithful one",
    "1361": "to be high, exalted; to be proud", "7107": "to be angry, furious",
    "3409": "thigh, loin; side", "1530": "heap (of stones); wave", "6884": "to smelt, refine, test",
    "5678": "fury, overflowing anger", "6845": "to hide, store up", "1416": "band, troop, raiding party",
    "3051": "give! (הַב); to ascribe", "6779": "to sprout, spring up", "2244": "to hide oneself",
    "7045": "curse", "2280": "to bind up, saddle", "3233": "right, right-hand",
    "7440": "ringing cry; shout of joy", "7065": "to be jealous, zealous", "6654": "side",
    "6203": "back of the neck", "3123": "dove", "3830": "clothing, garment",
    "6187": "order, arrangement; valuation", "6212": "herb, grass, plants", "8328": "root",
    "6241": "tenth part, omer (of an ephah)", "4283": "the next day, the morrow", "2474": "window",
    "6486": "visitation, punishment; oversight, charge", "5980": "close beside, alongside (לְעֻמַּת)",
    "6442": "inner", "4219": "basin, bowl", "3243": "to suck; to nurse", "7416": "pomegranate",
    "591": "ship", "3972": "anything; (with a negative) nothing", "5594": "to wail, lament",
    "3582": "to hide, conceal", "3611": "dog", "4676": "standing stone, pillar",
    "759": "citadel, palace", "5645": "thick cloud", "2876": "cook, butcher; bodyguard",
    "4578": "bowels, inward parts, womb", "8426": "thanksgiving; thank offering",
    "4643": "tithe, tenth part", "2898": "goodness, good things", "676": "finger", "2919": "dew",
    "5521": "booth, hut, shelter", "7857": "to overflow, flood, rinse", "5087": "to vow",
    "1406": "roof", "1322": "shame", "8071": "garment, cloak", "2934": "to hide, bury",
    "5175": "serpent, snake", "3341": "to kindle, set on fire", "6099": "mighty, numerous",
    "3213": "to wail, howl", "5003": "to commit adultery", "4327": "kind, species",
    "3629": "kidneys; innermost being", "1497": "to rob, seize, tear away", "3978": "food",
    "7621": "oath", "1926": "splendour, majesty, honour", "2406": "wheat",
    "3411": "far side, rear, recesses", "7562": "wickedness", "6459": "carved image, idol",
    "7493": "to quake, shake", "7257": "to lie down, crouch (of animals)", "8573": "wave offering",
    "3639": "disgrace, humiliation", "1314": "spice, balsam", "6224": "tenth", "2689": "trumpet",
    "4417": "salt", "5081": "noble, willing, generous", "974": "to test, examine",
    "7151": "city, town", "6438": "corner; cornerstone", "3259": "to appoint; to meet by appointment",
    "4296": "bed, couch", "4513": "to withhold, keep back", "8213": "to be low; to bring low, humble",
    "2266": "to join, unite", "5079": "menstrual impurity; impurity", "8300": "survivor, one left",
    "8518": "to hang", "3801": "tunic", "1819": "to be like, resemble; to compare, plan",
    "3577": "lie, falsehood", "6509": "to bear fruit, be fruitful", "6260": "he-goat; leader",
    "3836": "white", "1259": "hail", "2154": "lewdness, wickedness; plan", "8345": "sixth",
    "6413": "escape, remnant, deliverance", "4604": "unfaithfulness, trespass",
    "4487": "to count, number, appoint", "183": "to desire, crave", "8066": "eighth",
    "8003": "whole, complete; at peace", "3474": "to be straight, right, pleasing", "4598": "robe",
    "7399": "property, goods", "2449": "to be wise", "7939": "wages, reward, hire",
    "5488": "reeds, rushes; יַם־סוּף, the Sea of Reeds", "5956": "to be hidden, concealed",
    "6346": "governor", "8251": "detestable thing, detested idol", "7185": "to be hard, difficult; to harden",
    "1310": "to boil, cook; to ripen", "2498": "to pass on, change; to replace", "8181": "hair",
    "1065": "weeping", "5074": "to flee, wander", "7848": "acacia (wood)",
    "8392": "ark (Noah's; Moses' basket)", "2713": "to search out, examine",
    "7854": "adversary; the Accuser, Satan", "2204": "to be old, grow old", "4546": "highway",
    "3727": "cover of the ark, mercy seat", "8052": "report, news, rumour",
    "4161": "going out, exit; source; utterance", "2856": "to seal",
    "1100": "worthlessness; a scoundrel (בֶּן־בְּלִיַּעַל)", "117": "majestic, mighty, noble",
    "4170": "snare, trap", "2820": "to withhold, hold back, spare", "3887": "to scorn, mock; scoffer",
    "5360": "vengeance", "7797": "to rejoice, exult", "5423": "to tear away, pull off, snap",
    "3104": "ram's horn; jubilee (year)", "361": "porch, vestibule", "7605": "rest, remainder, remnant",
    "4046": "plague, blow, slaughter", "2905": "row (of stones, gems)", "1290": "knee",
    "6685": "fast, fasting", "7358": "womb", "6510": "cow, heifer", "4692": "siege; fortification",
    "5833": "help, assistance", "5071": "freewill offering", "6504": "to divide, separate",
    "6923": "to meet, confront; to come before", "3394": "moon", "5404": "eagle, vulture",
    "5787": "blind", "3021": "to toil, grow weary", "6035": "humble, meek, poor",
    # Homographs ("1121 a") were once dropped by the counter; these entered when that was fixed.
    "1121": "son",
    "6213": "to do, make",
    "1004": "house",
    "5971": "people, nation",
    "5892": "city",
    "5869": "eye; spring",
    "7451": "evil, bad",
    "6965": "to rise, stand up",
    "7218": "head, top",
    "3820": "heart, mind",
    "7760": "to put, place",
    "1471": "nation, people",
    "2896": "good",
    "5674": "to pass over, cross",
    "1419": "great, big",
    "6963": "voice, sound",
    "2416": "living, alive; life",
    "6635": "army, host",
    "7227": "many, great",
    "4427": "to reign, be king",
    "7704": "field",
    "6030": "to answer, respond",
    "6485": "to visit, attend to; to muster",
    "2403": "sin; sin offering",
    "5930": "burnt offering",
    "4057": "wilderness, desert",
    "2617": "steadfast love, kindness",
    "520": "cubit",
    "7235": "to be many, multiply",
    "3559": "to be firm, established; to prepare",
    "899": "garment, clothing",
    "5800": "to leave, forsake",
    "352": "ram; leader; pillar",
    "7311": "to be high; to raise",
    "2691": "court, courtyard; village",
    "5612": "book, scroll, letter",
    "3898": "to fight",
    "1984": "to praise",
    "7462": "to shepherd, graze",
    "2930": "to be unclean",
    "5608": "to count; to recount, tell",
    "6605": "to open",
    "2490": "to profane; to begin",
    "5158": "stream, wadi",
    "5483": "horse",
    "5178": "bronze, copper",
    "5387": "leader, chief, prince",
    "3581": "strength, power",
    "6999": "to burn incense",
    "7999": "to repay, make whole; be at peace",
    "6862": "adversary; distress",
    "1350": "to redeem",
    "3722": "to atone, make atonement",
    "7489": "to be evil, do wrong",
    "3499": "rest, remainder",
    "6996": "small, young",
    "1481": "to sojourn, dwell as a foreigner",
    "7097": "end, edge",
    "2491": "slain, pierced",
    "1197": "to burn; to consume",
    "7892": "song",
    "1817": "door",
    "3885": "to lodge, spend the night; to grumble",
    "6924": "east; ancient time",
    "3384": "to throw; to teach",
    "1995": "multitude, crowd, noise",
    "6031": "to afflict, humble",
    "7819": "to slaughter",
    "7133": "offering, sacrifice",
    "738": "lion",
    "2603": "to be gracious, show favour",
    "2114": "strange, foreign",
    "6186": "to arrange, set in order",
    "7161": "horn",
    "3988": "to reject, despise",
    "2654": "to delight in, desire",
    "2470": "to be sick, weak",
    "6869": "distress, trouble",
    "2790": "to plough, engrave; to be silent",
    "7673": "to cease, rest",
    "441": "chief, clan leader; friend",
    "953": "pit, cistern",
    "6327": "to scatter, disperse",
    "2506": "portion, share",
    "4853": "burden; oracle",
    "2505": "to divide, share",
    "6743": "to prosper, succeed",
    "4116": "to hurry, hasten",
    "7919": "to have insight, act wisely",
    "2256": "rope, cord; region",
    "2342": "to writhe, tremble; to dance",
    "3293": "forest",
    "8163": "he-goat; hairy",
    "8077": "desolation",
    "6571": "horseman",
    "4060": "measure, size",
    "5766": "injustice, wrong",
    "1254": "to create",
    "7105": "harvest",
    "5945": "Most High; upper",
    "7442": "to shout for joy",
    "6887": "to bind up; to be hostile",
    "2763": "to devote to destruction; to ban",
    "7114": "to reap; to be short",
    "4609": "step, stair; ascent",
    "5234": "to recognise, acknowledge",
    "6565": "to break, frustrate",
    "6960": "to wait for, hope",
    "5216": "lamp",
    "7628": "captivity, captives",
    "5271": "youth",
    "7356": "compassion; womb",
    "2502": "to draw off; to rescue; to equip",
    "5749": "to testify, warn",
    "657": "end, nothing; only",
    "5355": "innocent, clean",
    "8438": "worm; scarlet",
    "1101": "to mix, mingle",
    "2717": "to be dry, waste",
    "8336": "fine linen; marble",
    "2778": "to reproach, taunt",
    "6677": "neck",
    "2764": "devoted thing; ban",
    "5035": "jar, skin; harp",
    "5130": "to wave, brandish",
    "565": "word, saying",
    "6696": "to besiege; to bind",
    "5643": "hiding place, shelter",
    "4229": "to wipe out, blot out",
    "4135": "to circumcise",
    "6524": "to bud, sprout, flourish",
    "5401": "to kiss",
    "5116": "pasture, dwelling",
    "3563": "cup",
    "5518": "pot; thorn",
    "8615": "hope; cord",
    "2859": "to become a son-in-law; father-in-law",
    "5592": "threshold; basin",
    "6643": "beauty, glory; gazelle",
    "5774": "to fly",
    "3715": "young lion",
    "5090": "to drive, lead",
    "2563": "clay, mire; heap",
    "1826": "to be silent, still",
    "2492": "to dream",
    "2513": "plot of land, portion",
    "7110": "wrath, anger",
    "4541": "molten image",
    "6601": "to entice, deceive; to be simple",
    "2530": "to desire, covet",
    "8433": "rebuke, correction",
    "7287": "to rule, have dominion",
    "7136": "to happen, befall",
    "2254": "to take a pledge; to ruin",
    "6341": "snare, trap; plate",
    "5591": "storm, tempest",
    "3867": "to join; to borrow, lend",
    "5713": "testimony",
    "8577": "sea monster, serpent",
    "4888": "anointing",
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
    frozenset(("376", "1100")),    # man / worthlessness — "often used with", not derived
    frozenset(("802", "1100")),    # woman / worthlessness — same
    frozenset(("120", "582")),     # mankind / man — Strong's contrasts them, not derives
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
    full = defaultdict(Counter)  # lemma -> full morph codes, for gender/number/stem
    plain = defaultdict(Counter)  # (lemma, consonants of the bare word) -> morph codes, for the number of the dictionary form
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
                parts = (w.text or "").split("/")
                forms[(tail.group(1), consonants(parts[-1]))] += 1
                if len(parts) > 1:  # also as written with its prefixes, so כַּאֲשֶׁר can be a card
                    forms[(tail.group(1), consonants("".join(parts)))] += 1
                i = len(lemmas) - 1  # the word proper: after any prefixes, before any suffix
                if i < len(parts) and i < len(morphs):
                    plain[(tail.group(1), consonants(parts[i]))][morphs[i]] += 1
            for i, part in enumerate(lemmas):
                # OSHB writes homographs as "1121 a"; the deck is keyed by Strong's number, so the letter is dropped
                m = re.match(r"^[a-z]?\s*(\d+)\s*([a-z])?$", part.strip())
                if not m:
                    continue  # bare prefix letter, e.g. the "b" of "b/7225"
                num = m.group(1)
                cnt[num] += 1
                pos[num][(morphs[i] if i < len(morphs) else "")[:2]] += 1
                full[num][morphs[i] if i < len(morphs) else ""] += 1
                if book == "Jonah":
                    jonah.add(num)
    return cnt, {k: v.most_common(1)[0][0] for k, v in pos.items()}, jonah, forms, full, plain


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
    ("small", "Small words",
     "The glue of a sentence: prepositions, particles, adverbs, and question words. "
     "Too short for the frequency deck, too common to skip.",
     [("on", "on, over, against", [("5921", "5921", "עַל", "on, over, against")]),
      ("to", "to, toward", [("413", "413", "אֶל", "to, toward")]),
      ("from", "from, out of", [("4480", "4480", "מִן", "from, out of")]),
      ("until", "until, as far as", [("5704", "5704", "עַד", "until, as far as")]),
      ("with", "with", [("5973", "5973", "עִם", "with")]),
      ("after", "after, behind", [("310", "310", "אַחַר", "after, behind")]),
      ("under", "under, instead of", [("8478", "8478", "תַּחַת", "under, instead of")]),
      ("between", "between", [("996", "996", "בֵּין", "between")]),
      ("for-sake", "for the sake of, so that", [("4616", "4616", "לְמַעַן", "for the sake of, so that")]),
      ("obj", "(object marker)", [("853", "853", "אֵת", "marks the object")]),
      ("which", "which, who, that", [("834", "834", "אֲשֶׁר", "which, who, that"),
                                       ("834k", "834", "כַּאֲשֶׁר", "as, when, just as")]),
      ("not", "not", [("3808", "3808", "לֹא", "not (facts)"), ("408", "408", "אַל", "do not (commands)")]),
      ("is", "there is", [("3426", "3426", "יֵשׁ", "there is")]),
      ("isnt", "there is not", [("369", "369", "אֵין", "there is not")]),
      ("behold", "behold, look", [("2009", "2009", "הִנֵּה", "behold, look"), ("2005", "2005", "הֵן", "behold (shorter)")]),
      ("so", "so, thus", [("3651", "3651", "כֵּן", "so, thus"), ("3541", "3541", "כֹּה", "thus, here")]),
      ("also", "also, even", [("1571", "1571", "גַּם", "also, even")]),
      ("only", "only", [("7535", "7535", "רַק", "only"), ("389", "389", "אַךְ", "only, surely")]),
      ("please", "please, now", [("4994", "4994", "נָא", "please, now")]),
      ("because", "because, that, when", [("3588", "3588", "כִּי", "because, that, when")]),
      ("if", "if", [("518", "518", "אִם", "if")]),
      ("or", "or", [("176", "176", "אוֹ", "or")]),
      ("lest", "lest", [("6435", "6435", "פֶּן", "lest")]),
      ("perhaps", "perhaps", [("194", "194", "אוּלַי", "perhaps")]),
      ("there", "there", [("8033", "8033", "שָׁם", "there")]),
      ("here", "here", [("6311", "6311", "פֹּה", "here")]),
      ("still", "still, again", [("5750", "5750", "עוֹד", "still, again")]),
      ("now", "now", [("6258", "6258", "עַתָּה", "now")]),
      ("then", "then", [("227", "227", "אָז", "then")]),
      ("very", "very", [("3966", "3966", "מְאֹד", "very")]),
      ("this", "this, these", [("2088", "2088", "זֶה", "this (m.)"), ("2063", "2063", "זֹאת", "this (f.)"),
                               ("428", "428", "אֵלֶּה", "these")]),
      ("what", "what?", [("4100", "4100", "מָה", "what?")]),
      ("who", "who?", [("4310", "4310", "מִי", "who?")]),
      ("where", "where?", [("346", "346", "אַיֵּה", "where?")]),
      ("how", "how?", [("349", "349", "אֵיךְ", "how?")]),
      ("when", "when?", [("4970", "4970", "מָתַי", "when?")])]),
]


# Part of speech from the dominant OSHB morph code: its first letter is the class,
# the second refines adjectives into numbers.
def part_of_speech(code):
    if code[:1] == "A" and code[1:2] in ("c", "o"):
        return "number"
    return {"N": "noun", "V": "verb", "A": "adjective", "P": "pronoun", "D": "adverb",
            "R": "preposition", "C": "conjunction", "T": "particle"}.get(code[:1])


# Gender and number for nouns and adjectives, the stem for verbs, each the commonest over the
# lemma's occurrences (OSHB codes: Ncmsa = noun common masculine singular absolute; Vqp3ms = qal).
GENDER = {"m": "masculine", "f": "feminine", "b": "masculine or feminine", "c": "common gender"}
NUMBER = {"s": "singular", "p": "plural", "d": "dual"}
STEM = {"q": "qal", "N": "niphal", "p": "piel", "P": "pual", "h": "hiphil", "H": "hophal", "t": "hitpael"}


def features(codes, own):
    """`codes`: morphs of every occurrence of the lemma; `own`: of the occurrences spelled like the
    card's form, so בֵּן is singular although בָּנִים is commoner, and אֱלֹהִים is plural."""
    def commonest(picks):
        c = Counter(p for p in picks if p)
        return c.most_common(1)[0][0] if c else None
    cls = commonest(m[:1] for m in codes.elements())
    if cls in ("N", "A"):
        words = [m for m in codes.elements() if m[:1] == cls and len(m) >= 4]
        mine = [m for m in own.elements() if m[:1] == cls and len(m) >= 4] or words
        g, n = commonest(GENDER.get(m[2]) for m in words), commonest(NUMBER.get(m[3]) for m in mine)
        return " ".join(x for x in (g, n) if x) or None
    if cls == "V":
        return commonest(STEM.get(m[1:2]) for m in codes.elements() if m[:1] == "V")
    return None


def build_decks(forms, pos, full, plain):
    def form(fid, strongs, h, label):
        return {"s": fid, "h": h, "g": label, "n": forms[(strongs, consonants(h))], "root": [], "conf": []}
    return [{"id": did, "title": title, "note": note,
             "cards": [{"s": cid, "h": fs[0][2], "g": gloss, "n": sum(form(*f)["n"] for f in fs),
                        "p": part_of_speech(pos.get(fs[0][1], "")), "f": features(full.get(fs[0][1], Counter()), plain.get((fs[0][1], consonants(fs[0][2])), Counter())),
                        "root": [], "conf": [], "forms": [form(*f) for f in fs]}
                       for cid, gloss, fs in cards]}
            for did, title, note, cards in DECKS]


def build():
    cnt, pos, jonah, forms, full, plain = count_lemmas()
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

    cards = [{"s": k, "h": lex["H" + k]["lemma"], "g": GLOSS[k], "n": cnt[k], "p": part_of_speech(pos[k]),
              "f": features(full[k], plain.get((k, consonants(lex["H" + k]["lemma"])), Counter())),
              "j": k in jonah, "root": root_of[k], "conf": sorted(conf[k], key=lambda y: index[y])}
             for k in deck]
    return cards, DROP_LINKS - used_drops, build_decks(forms, pos, full, plain)


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
    faces = [(c["h"], c["g"]) for c in cards]  # homographs (רִיב verb/noun) share a face, never a gloss
    assert len(set(faces)) == DECK_SIZE, \
        f"duplicate cards: {[f for f in faces if faces.count(f) > 1]}"
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
          f"bands floor at {'/'.join(str(cards[sum(BANDS[:i+1])-1]['n']) for i in range(len(BANDS)))}")


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

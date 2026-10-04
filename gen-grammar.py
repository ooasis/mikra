#!/usr/bin/env python3
"""Generate Mikra/Grammar.json: the grammar lessons behind the dashboard's Grammar section.

Lessons are authored here, not in the JSON, so a cited verse can be checked
against Texts.json: every example with a `ref` must occur in that verse.

    ./gen-grammar.py           # write Mikra/Grammar.json
    ./gen-grammar.py --check   # validate only
"""
import glob
import json, os, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))

# Group ids match `grammarGroups` in Grammar.swift.
SCRIPT, ATTACH, NOUNS, VERBS, SENTENCES = "script", "attach", "nouns", "verbs", "sentences"


def ex(h, g, ref=None):
    return {"h": h, "g": g, **({"ref": ref} if ref else {})}


def table(title, columns, rows):
    """A small grid under the lesson text; row labels go in the first column."""
    return {"title": title, "columns": columns, "rows": rows}


LESSONS = [
    # ————— A. Reading the script —————
    {"group": SCRIPT, "id": "syllables", "title": "Syllables and stress",
     "why": "Knowing where a syllable ends tells you how to say a sheva and where to put the stress.",
     "body": [
         "A syllable starts with a consonant. It is open if it ends in a vowel (בָּ). It is closed "
         "if it ends in a consonant (בַּת). Give each vowel the consonant before it. A consonant "
         "with no vowel closes the syllable before it.",
         "Most words stress the last syllable: דָּבָר is da-VAR. Two kinds of words stress the "
         "syllable before the last: words with two segols (מֶלֶךְ, ME-lekh) and words ending in "
         "-ayim (מַיִם, MA-yim).",
         "The reader hides the accent marks. So say the last syllable louder, unless the word "
         "has one of those two shapes.",
     ],
     "tables": [
         table("Where the stress falls", ["", "Stress", "Example"],
               [["Most words", "last syllable", "דָּבָר\nda-VAR"],
                ["Two segols", "before last", "מֶלֶךְ\nME-lekh"],
                ["Ends in -ayim", "before last", "מַיִם\nMA-yim"]]),
     ],
     "examples": [
         ex("דָּבָר", "da-VAR — word"),
         ex("מֶלֶךְ", "ME-lekh — king"),
         ex("יוֹנָה", "yo-NA — Jonah", "Jonah 1:1"),
         ex("אֱלֹהִים", "e-lo-HIM — God", "Genesis 1:1"),
         ex("הַשָּׁמַיִם", "ha-sha-MA-yim — the heavens", "Genesis 1:1"),
         ex("מַיִם", "MA-yim — water", "Jonah 2:6"),
     ]},
    {"group": SCRIPT, "id": "sheva", "title": "Sheva: silent or spoken",
     "why": "The same two dots are sometimes a short e and sometimes nothing at all.",
     "body": [
         "Sheva (ְ) is a very short e when it starts a syllable. That happens at the start of a "
         "word, after another sheva, and under a letter with a dagesh.",
         "Sheva is silent when it closes a syllable. That happens in the middle of a word after "
         "a short vowel, and always at the end of a word.",
         "Israeli readers often skip even the spoken sheva, so בְּרֵאשִׁית comes out as bre-SHIT. "
         "That is fine. Just never add a vowel where the sheva is silent.",
     ],
     "tables": [
         table("Spoken or silent", ["", "Sheva is", "Example"],
               [["Start of a word", "spoken", "בְּרֵאשִׁית\nbe-re-SHIT"],
                ["After a short vowel", "silent", "לִבְרֹחַ\nliv-RO-akh"],
                ["End of a word", "silent", "לֵךְ\nlekh"],
                ["Second of two shevas", "spoken", "יִשְׁמְעוּ\nyish-me-U"],
                ["Under a dagesh", "spoken", "דִּבְּרוּ\ndib-be-RU"]]),
     ],
     "examples": [
         ex("בְּרֵאשִׁית", "be-re-SHIT — in the beginning; spoken", "Genesis 1:1"),
         ex("לִבְרֹחַ", "liv-RO-akh — to flee; silent", "Jonah 1:3"),
         ex("לֵךְ", "lekh — go!; silent at the end", "Jonah 1:2"),
         ex("תַּרְשִׁישָׁה", "tar-SHI-sha — to Tarshish; silent", "Jonah 1:3"),
         ex("דְּבַר־", "de-VAR — word of; spoken", "Jonah 1:1"),
         ex("יִשְׁמַע", "yish-MA — he hears; silent"),
     ]},
    {"group": SCRIPT, "id": "dagesh", "title": "Dagesh: the dot inside a letter",
     "why": "One dot does two different jobs, and only one of them changes the sound.",
     "body": [
         "In בּ כּ פּ the dot makes a hard sound: b, k, p. Without the dot they are v, kh, f. "
         "The dot appears at the start of a word and after a closed syllable.",
         "In any other letter the dot doubles the letter. The syllable before it closes on that "
         "letter: הַיָּם is hay-YAM. You will see this most after the article הַ and after מִן.",
         "Two look-alikes: וּ with a dot in the middle is the vowel u. The dot above שׁ or שׂ is "
         "the shin/sin mark, not a dagesh.",
     ],
     "tables": [
         table("What the dot does", ["", "Effect", "Example"],
               [["In בּ כּ פּ", "hard sound", "בָּרָא\nba-RA"],
                ["In other letters", "doubles it", "הַיָּם\nhay-YAM"],
                ["In vav (וּ)", "the vowel u", "קוּם\nkum"],
                ["Above shin", "sh or s", "אִישׁ\nish"]]),
     ],
     "examples": [
         ex("בָּרָא", "ba-RA — he created; hard b", "Genesis 1:1"),
         ex("הַיָּם", "hay-YAM — the sea; doubled yod", "Jonah 1:5"),
         ex("הַגְּדוֹלָה", "hag-ge-do-LA — the great; doubled gimel", "Jonah 1:2"),
         ex("כָּל־", "kol — all; hard k", "Jonah 2:4"),
         ex("וּשְׁלֹשָׁה", "u-shlo-SHA — and three; the vowel u", "Jonah 2:1"),
         ex("הָאִישׁ", "ha-ISH — the man; shin mark", "Psalms 1:1"),
     ]},
    {"group": SCRIPT, "id": "vowel-letters", "title": "Vav and yod as vowels",
     "why": "Three of the letters you learned also spell vowels, and then they are not consonants.",
     "body": [
         "Vav with a dot above (וֹ) is o. Vav with a dot inside (וּ) is u. Yod after a chirik "
         "(ִי) is a long i. Yod after a tsere or segol (ֵי) is e or ei.",
         "When a vav or yod has its own vowel, it is a consonant again: וְ is ve, יָם is yam.",
         "A he at the end of a word is silent, and you hear the vowel before it: יוֹנָה ends in "
         "-a. A final he with a dot inside (הּ) is a real h and is pronounced.",
     ],
     "tables": [
         table("Vowel letters", ["Letter", "Sound", "Example"],
               [["וֹ", "o", "יוֹנָה"], ["וּ", "u", "קוּם"], ["ִי", "i", "אֱלֹהִים"],
                ["ֵי", "e, ei", "בֵּין"], ["ָה at the end", "a", "יוֹנָה"], ["הּ at the end", "h", "בָּהּ"]]),
     ],
     "examples": [
         ex("יוֹנָה", "yo-NA — the vav is o", "Jonah 1:1"),
         ex("קוּם", "kum — the vav is u", "Jonah 1:2"),
         ex("נִינְוֵה", "nin-VE — the vav is a consonant here", "Jonah 1:2"),
         ex("אֱלֹהִים", "e-lo-HIM — the yod is a long i", "Genesis 1:1"),
         ex("בֵּין", "ben — between", "Genesis 1:4"),
         ex("בָּהּ", "bah — in her; the dotted he is pronounced", "Jonah 1:3"),
     ]},
    {"group": SCRIPT, "id": "qamats-o", "title": "The qamats that sounds o",
     "why": "Two vowels look the same; one is a and one is o.",
     "body": [
         "Qamats (ָ) is normally a. In a closed syllable with no stress it is a short o. The "
         "big case is כָּל 'all', kol, especially with a maqqef: כָּל־הָאָרֶץ.",
         "A hataf-qamats (ֳ) under a guttural is always o: בָּאֳנִיָּה ba-o-ni-YA.",
         "When in doubt, say a. The o-reading is rare, and כָּל covers most of what you will meet.",
     ],
     "tables": [
         table("Qamats: a or o", ["", "Sound", "Example"],
               [["Usual", "a", "דָּבָר\nda-VAR"],
                ["Closed, unstressed", "o", "כָּל־\nkol"],
                ["Hataf-qamats ֳ", "o", "בָּאֳנִיָּה\nba-o-ni-YA"]]),
     ],
     "examples": [
         ex("כָּל־", "kol — all", "Jonah 2:4"),
         ex("קָדְשֶׁךָ", "kod-SHE-kha — your holy (temple)", "Jonah 2:5"),
         ex("בָּאֳנִיָּה", "ba-o-ni-YA — in the ship", "Jonah 1:5"),
         ex("חָכְמָה", "khokh-MA — wisdom"),
         ex("דָּבָר", "da-VAR — word; a normal qamats"),
     ]},
    {"group": SCRIPT, "id": "gutturals", "title": "Gutturals: the letters that bend the rules",
     "why": "א ה ח ע (and ר) refuse to double and prefer a-vowels. That explains many odd forms.",
     "body": [
         "The gutturals cannot take a dagesh. Where doubling should happen, the vowel before "
         "them often gets longer instead: הָאָרֶץ has a qamats under the article, not a patach.",
         "They like a-vowels. Instead of a plain sheva they take a hataf vowel: ֲ ֱ ֳ. Say it as a "
         "very short a, e, or o: אֱלֹהִים e-lo-HIM.",
         "Furtive patach: when a word ends in ח or ע after a long vowel, a small a slips in "
         "before it. רוּחַ is RU-akh, not ru-KHA.",
     ],
     "tables": [
         table("Three guttural habits", ["", "What happens", "Example"],
               [["No dagesh", "vowel before gets long", "הָאָרֶץ"],
                ["No plain sheva", "hataf vowel instead", "אֱלֹהִים"],
                ["Final ח or ע", "furtive patach", "רוּחַ\nRU-akh"]]),
     ],
     "examples": [
         ex("הָאָרֶץ", "ha-A-rets — the land", "Genesis 1:1"),
         ex("הָעִיר", "ha-IR — the city", "Jonah 1:2"),
         ex("אֱלֹהִים", "e-lo-HIM — hataf segol", "Genesis 1:1"),
         ex("אֲנִי", "a-NI — I; hataf patach", "Jonah 1:9"),
         ex("רוּחַ", "RU-akh — wind, spirit", "Genesis 1:2"),
         ex("לִבְרֹחַ", "liv-RO-akh — to flee", "Jonah 1:3"),
         ex("יוֹדֵעַ", "yo-DE-a — knowing", "Jonah 3:9"),
     ]},
    {"group": SCRIPT, "id": "maqqef-accents", "title": "Maqqef and the accent marks",
     "why": "The little hyphen and the marks above and below the letters tell you how to phrase a verse.",
     "body": [
         "Maqqef (־) joins two words into one. Say them as one word, with the stress on the "
         "last part: אֶת־הָאָרֶץ. The first word loses its stress, and כָּל becomes kol.",
         "A printed Bible has accent marks (te'amim) above and below the letters. They show "
         "the stressed syllable and split the verse into phrases. The reader hides them so the "
         "vowels stay easy to read.",
         "Two marks are worth knowing. Sof pasuq (׃) ends a verse. Atnach (֑) splits it in the "
         "middle. Pause at both.",
     ],
     "tables": [
         table("Marks to know", ["Mark", "Name", "Meaning"],
               [["־", "maqqef", "join the two words"],
                ["׃", "sof pasuq", "end of verse"],
                ["֑", "atnach", "pause mid-verse"]]),
     ],
     "examples": [
         ex("אֵת הַשָּׁמַיִם", "et ha-sha-MA-yim — the heavens", "Genesis 1:1"),
         ex("דְּבַר־יְהוָה", "de-var-adonai — the word of the LORD; one unit", "Jonah 1:1"),
         ex("בֶן־אֲמִתַּי", "ven-amit-TAI — son of Amittai", "Jonah 1:1"),
         ex("כָּל־הָאָרֶץ", "kol-ha-A-rets — all the earth", "Genesis 1:29"),
         ex("מִי־יוֹדֵעַ", "mi-yo-DE-a — who knows?", "Jonah 3:9"),
     ]},
    {"group": SCRIPT, "id": "divine-name", "title": "The name יְהוָה",
     "why": "The most frequent word in the reader is never said the way it is written.",
     "body": [
         "יְהוָה is God's personal name. Jewish tradition does not say it aloud. Readers say "
         "אֲדֹנָי, adonai, 'my Lord'. The vowels printed on the name come from that word, as a "
         "reminder. English Bibles print it as LORD in capitals.",
         "When אֲדֹנָי already stands next to it, the name is read as אֱלֹהִים, elohim, and its "
         "printed vowels change to match.",
         "This is one case of a general habit: what is written (ketiv) and what is read (qere) "
         "can differ. The app's voice reads what is said, not what is written.",
     ],
     "tables": [
         table("Written and said", ["Written", "Said", "English"],
               [["יְהוָה", "adonai", "the LORD"],
                ["אֲדֹנָי יְהוִה", "adonai elohim", "the Lord GOD"],
                ["אֱלֹהִים", "elohim", "God"]]),
     ],
     "examples": [
         ex("יְהוָה", "adonai — the LORD", "Jonah 1:1"),
         ex("יְהוָה רֹעִי", "adonai ro-I — the LORD is my shepherd", "Psalms 23:1"),
         ex("אֲדֹנָי", "adonai — my Lord; the word actually spoken"),
         ex("אֱלֹהִים", "e-lo-HIM — God", "Genesis 1:1"),
         ex("יְהוָה־אֱלֹהִים", "adonai elohim — the LORD God", "Jonah 4:6"),
     ]},

    # ————— B. Little words that attach —————
    {"group": ATTACH, "id": "article", "title": "The article הַ",
     "why": "Hebrew glues 'the' to the front of the word and doubles the letter after it.",
     "body": [
         "'The' is הַ stuck to the front of the word, with a dagesh in the next letter: מֶלֶךְ "
         "'king', הַמֶּלֶךְ 'the king'.",
         "A guttural (א ה ח ע ר) cannot double. Before א ע ר the article becomes הָ: הָאָרֶץ, "
         "הָעִיר. Before ה ח it may stay הַ or become הֶ: הֶהָרִים.",
         "There is no word for 'a': אִישׁ is 'a man' or 'man'. Names never take the article. An "
         "adjective after a definite noun takes the article too: הָעִיר הַגְּדוֹלָה 'the great city'.",
     ],
     "tables": [
         table("Shape of the article", ["Before", "Article", "Example"],
               [["most letters", "הַ + dagesh", "הַיָּם"],
                ["א ע ר", "הָ", "הָאָרֶץ"],
                ["ה ח", "הַ or הֶ", "הֶהָרִים"]]),
     ],
     "examples": [
         ex("הַיָּם", "the sea", "Jonah 1:5"),
         ex("הַדָּג", "the fish", "Jonah 2:1"),
         ex("הָאָרֶץ", "the land, the earth", "Genesis 1:1"),
         ex("הָעִיר הַגְּדוֹלָה", "the great city", "Jonah 1:2"),
         ex("הָאִישׁ", "the man", "Psalms 1:1"),
         ex("הֶהָרִים", "the mountains", "Psalms 121:1"),
         ex("הַשָּׁמַיִם", "the heavens", "Genesis 1:1"),
     ]},
    {"group": ATTACH, "id": "conjunction", "title": "The conjunction וְ",
     "why": "Almost every verse starts with it, and it changes shape with its neighbours.",
     "body": [
         "'And' is a vav stuck to the front of a word: וְ. It also means 'but', 'then', 'so'. "
         "Hebrew joins clauses with it far more than English does.",
         "Before ב מ פ, or before a letter with a sheva, it becomes the vowel וּ: וּבֵין 'and "
         "between'. Before a hataf vowel it copies that vowel: וַאֲנִי 'and I'.",
         "וַ with a patach and a doubled next letter (וַיֹּאמֶר) is the storytelling 'and then'. "
         "That form has its own lesson under Verbs.",
     ],
     "tables": [
         table("Shape of 'and'", ["Before", "Shape", "Example"],
               [["most letters", "וְ", "וְלֹא"],
                ["ב מ פ, or a sheva", "וּ", "וּבֵין"],
                ["a hataf vowel", "copies it", "וַאֲנִי"],
                ["a past-tense verb", "וַ + dagesh", "וַיֹּאמֶר"]]),
     ],
     "examples": [
         ex("וְאֵת הָאָרֶץ", "and the earth", "Genesis 1:1"),
         ex("וְהָאָרֶץ", "and the earth", "Genesis 1:2"),
         ex("וּבֵין", "and between", "Genesis 1:4"),
         ex("וּשְׁלֹשָׁה", "and three", "Jonah 2:1"),
         ex("וַאֲנִי", "and I, but I", "Jonah 2:5"),
         ex("וְלֹא", "and not", "Jonah 1:6"),
         ex("וַיְהִי", "and it was; storytelling form", "Jonah 1:1"),
     ]},
    {"group": ATTACH, "id": "prepositions", "title": "The prefixes בְּ לְ כְּ",
     "why": "'In', 'to', and 'like' are single letters glued to the word, and they swallow the article.",
     "body": [
         "בְּ 'in, with', לְ 'to, for', כְּ 'like, as' stick to the front of a word: לְיוֹנָה 'to "
         "Jonah'.",
         "Before a sheva they take a chirik: לִבְרֹחַ 'to flee'. Before a hataf vowel they copy "
         "it: בֵּאלֹהִים 'in God'.",
         "With the article, the ה disappears. The prefix takes its vowel and its dagesh: בְּ + "
         "הַיָּם = בַּיָּם 'in the sea'. So בַּ or לָ plus a doubled letter means 'in the', 'to the'.",
     ],
     "tables": [
         table("The three prefixes", ["Prefix", "Meaning", "Example"],
               [["בְּ", "in, with, by", "בְּרֵאשִׁית"],
                ["לְ", "to, for", "לְיוֹנָה"],
                ["כְּ", "like, as", "כַּאֲשֶׁר"]]),
         table("With the article", ["Parts", "Result", "Meaning"],
               [["בְּ + הַיָּם", "בַּיָּם", "in the sea"],
                ["לְ + הָעִיר", "לָעִיר", "to the city"],
                ["כְּ + הַמֶּלֶךְ", "כַּמֶּלֶךְ", "like the king"]]),
     ],
     "examples": [
         ex("לִבְרֹחַ", "to flee", "Jonah 1:3"),
         ex("לְיוֹנָה", "to Jonah, for Jonah", "Jonah 4:6"),
         ex("בֵּאלֹהִים", "in God", "Jonah 3:5"),
         ex("בְּרֵאשִׁית", "in (the) beginning", "Genesis 1:1"),
         ex("בַּיָּם", "in the sea; בְּ + הַ", "Jonah 1:4"),
         ex("לָעִיר", "to the city; לְ + הָ", "Jonah 4:5"),
         ex("כַּאֲשֶׁר", "as, just as", "Jonah 1:14"),
     ]},
    {"group": ATTACH, "id": "min", "title": "מִן 'from' and the dagesh it leaves",
     "why": "'From' usually loses its nun, and a doubled letter is the only trace.",
     "body": [
         "מִן means 'from, out of'. Before the article it stands alone: מִן־הָעִיר. Stuck to a "
         "word it drops the nun and doubles the next letter: מִבֶּטֶן 'from the belly'.",
         "A guttural cannot double, so before one it becomes מֵ: מֵעַל 'from upon'.",
         "The same word means 'than', because Hebrew says 'good from' for 'better than': טוֹב "
         "מוֹתִי מֵחַיָּי 'my death is better than my life'.",
     ],
     "tables": [
         table("Shape of 'from'", ["Before", "Shape", "Example"],
               [["the article", "מִן־", "מִן־הָעִיר"],
                ["most letters", "מִ + dagesh", "מִבֶּטֶן"],
                ["a guttural", "מֵ", "מֵעַל"],
                ["a comparison", "'than'", "מֵחַיָּי"]]),
     ],
     "examples": [
         ex("מִלִּפְנֵי", "from before (the LORD)", "Jonah 1:3"),
         ex("מִבֶּטֶן", "from the belly of", "Jonah 2:3"),
         ex("מִצָּרָה", "out of distress", "Jonah 2:3"),
         ex("מִן־הָעִיר", "from the city", "Jonah 4:5"),
         ex("מֵעַל", "from upon, from over", "Jonah 4:6"),
         ex("מֵחַיָּי", "than my life", "Jonah 4:3"),
         ex("מִכִּסְאוֹ", "from his throne", "Jonah 3:6"),
     ]},
    {"group": ATTACH, "id": "object-marker", "title": "The object marker אֵת",
     "why": "A small word with no translation tells you who is doing what to whom.",
     "body": [
         "אֵת (or אֶת־ with a maqqef) comes before a definite direct object. That is the thing "
         "the verb is done to, when it has the article, is a name, or has a suffix: בָּרָא "
         "אֱלֹהִים אֵת הַשָּׁמַיִם 'God created the heavens'.",
         "It has no meaning and is never translated. It is the surest sign that the next word "
         "is the object, not the subject.",
         "There is another אֵת that means 'with'. They look the same alone. With suffixes they "
         "differ: אֹתִי 'me', אִתִּי 'with me'.",
     ],
     "tables": [
         table("Two words spelled אֵת", ["", "Object marker", "'With'"],
               [["me / with me", "אֹתִי", "אִתִּי"],
                ["him / with him", "אֹתוֹ", "אִתּוֹ"],
                ["them / with them", "אֹתָם", "אִתָּם"]]),
     ],
     "examples": [
         ex("אֵת הַשָּׁמַיִם", "the heavens (object)", "Genesis 1:1"),
         ex("אֶת־הָאוֹר", "the light (object)", "Genesis 1:4"),
         ex("אֶת־יוֹנָה", "Jonah (object)", "Jonah 2:1"),
         ex("אֶת־נַפְשִׁי", "my life (object)", "Jonah 4:3"),
         ex("בָּרָא אֹתוֹ", "he created him", "Genesis 1:27"),
     ]},
    {"group": ATTACH, "id": "noun-suffixes", "title": "Pronoun suffixes on nouns",
     "why": "'My', 'your', 'his' are endings, not separate words.",
     "body": [
         "Possession is an ending on the noun: דְּבָרִי 'my word', דְּבָרוֹ 'his word'.",
         "A plural noun puts a yod before the ending: דְּבָרַי 'my words', דְּבָרָיו 'his words'.",
         "The noun's own vowels often shift when an ending is added. Read the consonants and "
         "the ending.",
     ],
     "tables": [
         table("On a singular noun: דָּבָר 'word'", ["", "Ending", "Example"],
               [["my", "־ִי", "דְּבָרִי"], ["your (m.)", "־ְךָ", "דְּבָרְךָ"], ["your (f.)", "־ֵךְ", "דְּבָרֵךְ"],
                ["his", "־וֹ", "דְּבָרוֹ"], ["her", "־ָהּ", "דְּבָרָהּ"], ["our", "־ֵנוּ", "דְּבָרֵנוּ"],
                ["your (pl.)", "־ְכֶם", "דְּבַרְכֶם"], ["their", "־ָם", "דְּבָרָם"]]),
         table("On a plural noun: דְּבָרִים 'words'", ["", "Ending", "Example"],
               [["my", "־ַי", "דְּבָרַי"], ["your (m.)", "־ֶיךָ", "דְּבָרֶיךָ"], ["his", "־ָיו", "דְּבָרָיו"],
                ["her", "־ֶיהָ", "דְּבָרֶיהָ"], ["our", "־ֵינוּ", "דְּבָרֵינוּ"], ["their", "־ֵיהֶם", "דִּבְרֵיהֶם"]]),
     ],
     "examples": [
         ex("נַפְשִׁי", "my soul, my life", "Jonah 2:8"),
         ex("רֹעִי", "my shepherd", "Psalms 23:1"),
         ex("אַרְצֶךָ", "your land", "Jonah 1:8"),
         ex("קָדְשֶׁךָ", "your holiness", "Jonah 2:5"),
         ex("אֱלֹהָיו", "his God", "Jonah 1:5"),
         ex("רֹאשׁוֹ", "his head", "Jonah 4:6"),
         ex("רָעָתָם", "their evil", "Jonah 1:2"),
         ex("עֵינֶיךָ", "your eyes; plural noun", "Jonah 2:5"),
         ex("מַעֲשֵׂיהֶם", "their deeds; plural noun", "Jonah 3:10"),
     ]},
    {"group": ATTACH, "id": "prep-suffixes", "title": "Pronoun suffixes on prepositions",
     "why": "'To me', 'with him', 'upon them' are single words.",
     "body": [
         "The same endings attach to prepositions: לִי 'to me', לוֹ 'to him', בּוֹ 'in him'.",
         "אֶל 'to' and עַל 'on' add a yod first, like plural nouns: אֵלַי 'to me', אֵלָיו 'to him', "
         "עָלַי 'on me'.",
         "מִן doubles up: מִמֶּנִּי 'from me', מִמֶּנּוּ 'from him'. עִם 'with' doubles the mem: עִמִּי, "
         "עִמּוֹ.",
     ],
     "tables": [
         table("Endings on three prepositions", ["", "לְ to", "בְּ in", "אֶל to"],
               [["me", "לִי", "בִּי", "אֵלַי"], ["you (m.)", "לְךָ", "בְּךָ", "אֵלֶיךָ"],
                ["you (f.)", "לָךְ", "בָּךְ", "אֵלַיִךְ"], ["him", "לוֹ", "בּוֹ", "אֵלָיו"],
                ["her", "לָהּ", "בָּהּ", "אֵלֶיהָ"], ["us", "לָנוּ", "בָּנוּ", "אֵלֵינוּ"],
                ["you (pl.)", "לָכֶם", "בָּכֶם", "אֲלֵיכֶם"], ["them", "לָהֶם", "בָּהֶם", "אֲלֵיהֶם"]]),
     ],
     "examples": [
         ex("לִי", "to me", "Jonah 2:3"),
         ex("לְּךָ", "to you", "Jonah 1:6"),
         ex("לוֹ", "to him", "Jonah 1:6"),
         ex("לָנוּ", "to us", "Jonah 1:6"),
         ex("לָהֶם", "to them", "Jonah 1:10"),
         ex("בָּהּ", "in her, in it", "Jonah 1:3"),
         ex("אֵלָיו", "to him", "Jonah 1:6"),
         ex("אֲלֵיהֶם", "to them", "Jonah 1:9"),
         ex("עָלַי", "upon me", "Jonah 2:4"),
         ex("מִמֶּנִּי", "from me", "Jonah 4:3"),
     ]},
    {"group": ATTACH, "id": "directional-he", "title": "Directional ה: 'toward'",
     "why": "An unstressed ־ָה on the end of a place means 'to' it.",
     "body": [
         "Add ־ָה to a place and it means 'toward that place': תַּרְשִׁישָׁה 'to Tarshish'.",
         "This ending is not stressed: tar-SHI-sha. The feminine ending ־ָה is stressed. In "
         "pointed text that is the only visible difference, so let the sense guide you.",
     ],
     "tables": [
         table("Place and 'toward'", ["Place", "Toward it", "Meaning"],
               [["תַּרְשִׁישׁ", "תַּרְשִׁישָׁה", "to Tarshish"],
                ["מִצְרַיִם", "מִצְרַיְמָה", "to Egypt"],
                ["יָם", "יָמָּה", "seaward, west"],
                ["אֶרֶץ", "אַרְצָה", "to the ground"],
                ["הַבַּיִת", "הַבַּיְתָה", "homeward"]]),
     ],
     "examples": [
         ex("תַּרְשִׁישָׁה", "to Tarshish", "Jonah 1:3"),
         ex("תַרְשִׁישׁ", "Tarshish; the bare name", "Jonah 1:3"),
         ex("מִצְרַיְמָה", "to Egypt"),
         ex("יָמָּה", "seaward, westward"),
         ex("אַרְצָה", "to the ground"),
         ex("הַבַּיְתָה", "homeward"),
     ]},
    {"group": ATTACH, "id": "questions", "title": "Asking questions",
     "why": "A question can hide in a single letter at the start of a word.",
     "body": [
         "The prefix הֲ turns a statement into a yes/no question: הֲטוֹב 'is it good?' There is "
         "no question mark. The הֲ has a hataf patach and no dagesh after it. That is how it "
         "differs from the article הַ.",
         "מַה־ before a word often means 'what a...!' or 'how...!': מַה־לְּךָ 'what's with you?'",
     ],
     "tables": [
         table("Question words", ["Word", "Meaning", "Example"],
               [["מִי", "who?", "מִי־יוֹדֵעַ"], ["מָה, מַה־", "what?", "מַה־לְּךָ"],
                ["לָמָּה", "why?", ""], ["אֵיךְ", "how?", ""], ["אַיֵּה", "where?", ""],
                ["מֵאַיִן", "from where?", "וּמֵאַיִן תָּבוֹא"], ["מָתַי", "when?", ""],
                ["הֲ", "yes or no?", "הַהֵיטֵב"]]),
     ],
     "examples": [
         ex("מַה־לְּךָ", "what is it to you?", "Jonah 1:6"),
         ex("מַה־זֹּאת עָשִׂיתָ", "what is this you have done?", "Jonah 1:10"),
         ex("מִי־יוֹדֵעַ", "who knows?", "Jonah 3:9"),
         ex("וּמֵאַיִן תָּבוֹא", "and from where do you come?", "Jonah 1:8"),
         ex("הַהֵיטֵב חָרָה לָךְ", "is it right that you are angry?", "Jonah 4:4"),
         ex("הֲלוֹא־זֶה דְבָרִי", "was this not my word?", "Jonah 4:2"),
         ex("לָמָּה", "why?"),
     ]},

    # ————— C. Nouns, adjectives, pronouns —————
    {"group": NOUNS, "id": "gender-number", "title": "Gender and number endings",
     "why": "Four endings tell you whether a noun is feminine, plural, or a natural pair.",
     "body": [
         "Every noun is masculine or feminine. Most feminine nouns end in ־ָה or ־ת. A noun with "
         "no ending is usually masculine. Some bare nouns are feminine anyway: אֶרֶץ, עִיר, נֶפֶשׁ, "
         "רוּחַ.",
         "The masculine plural ends in ־ִים. The feminine plural ends in ־וֹת. The endings are not "
         "a sure guide: לַיְלָה 'night' is masculine but takes ־וֹת.",
         "The dual ־ַיִם is for pairs: עֵינַיִם 'eyes', יָדַיִם 'hands'. A few words just have it: "
         "מַיִם 'water', שָׁמַיִם 'heavens'.",
     ],
     "tables": [
         table("Noun endings", ["", "Singular", "Plural"],
               [["Masculine", "no ending\nדָּבָר", "־ִים\nדְּבָרִים"],
                ["Feminine", "־ָה or ־ת\nאֳנִיָּה", "־וֹת\nאֳנִיּוֹת"],
                ["Pairs (dual)", "", "־ַיִם\nעֵינַיִם"]]),
         table("One adjective, four forms: גָּדוֹל 'big'", ["", "Singular", "Plural"],
               [["Masculine", "גָּדוֹל", "גְּדוֹלִים"],
                ["Feminine", "גְּדוֹלָה", "גְּדוֹלוֹת"]]),
     ],
     "examples": [
         ex("אָנִיָּה", "a ship; feminine ־ָה", "Jonah 1:3"),
         ex("הַמַּלָּחִים", "the sailors; masculine plural", "Jonah 1:5"),
         ex("יָמִים", "days; masculine plural", "Jonah 2:1"),
         ex("לֵילוֹת", "nights; ־וֹת plural", "Jonah 2:1"),
         ex("גוֹרָלוֹת", "lots; ־וֹת plural", "Jonah 1:7"),
         ex("מַיִם", "water; dual shape", "Jonah 2:6"),
         ex("הַשָּׁמַיִם", "the heavens; dual shape", "Genesis 1:1"),
         ex("עֵינַי", "my eyes; from the dual עֵינַיִם", "Psalms 121:1"),
     ]},
    {"group": NOUNS, "id": "construct", "title": "Construct chains: 'the word of the LORD'",
     "why": "Hebrew says 'of' by putting one noun right before the next, and the first noun changes shape.",
     "body": [
         "To say 'X of Y', put X right before Y with nothing between: דְּבַר־יְהוָה 'the word of "
         "the LORD'. X is in the construct form, Y in the normal form.",
         "The construct form is usually shorter or lighter. The plural ־ִים becomes ־ֵי, and the "
         "feminine ־ָה becomes ־ַת. A maqqef often joins the pair.",
         "Only the last noun can take the article, and it makes the whole chain definite: מֶלֶךְ "
         "נִינְוֵה 'the king of Nineveh'.",
     ],
     "tables": [
         table("How the first noun changes", ["Normal", "Construct", "Meaning"],
               [["דָּבָר", "דְּבַר־", "word of"], ["בֵּן", "בֶּן־", "son of"],
                ["אֲנָשִׁים", "אַנְשֵׁי", "men of"], ["יָמִים", "יְמֵי", "days of"],
                ["עֵצָה", "עֲצַת", "counsel of"]]),
     ],
     "examples": [
         ex("דְּבַר־יְהוָה", "the word of the LORD", "Jonah 1:1"),
         ex("בֶן־אֲמִתַּי", "son of Amittai", "Jonah 1:1"),
         ex("אַנְשֵׁי נִינְוֵה", "the men of Nineveh", "Jonah 3:5"),
         ex("מֶלֶך נִינְוֵה", "the king of Nineveh", "Jonah 3:6"),
         ex("יַרְכְּתֵי הַסְּפִינָה", "the far corners of the ship", "Jonah 1:5"),
         ex("בַּעֲצַת רְשָׁעִים", "in the counsel of the wicked", "Psalms 1:1"),
         ex("פְּנֵי תְהוֹם", "the face of the deep", "Genesis 1:2"),
         ex("יְמֵי חַיָּי", "the days of my life", "Psalms 23:6"),
     ]},
    {"group": NOUNS, "id": "adjectives", "title": "Adjectives",
     "why": "An adjective follows its noun and copies its gender, number, and article.",
     "body": [
         "An adjective comes after its noun and agrees with it: דָּג גָּדוֹל 'a big fish', עִיר "
         "גְּדוֹלָה 'a big city'. If the noun has the article, the adjective takes it too.",
         "An adjective without the article after a definite noun makes a statement: הָעִיר "
         "גְּדוֹלָה 'the city is big'.",
         "'This' behaves like an adjective and comes last: הַסַּעַר הַגָּדוֹל הַזֶּה 'this great storm'.",
     ],
     "tables": [
         table("Describing or stating", ["Hebrew", "Meaning", "Pattern"],
               [["עִיר גְּדוֹלָה", "a big city", "noun + adj."],
                ["הָעִיר הַגְּדוֹלָה", "the big city", "both with הַ"],
                ["הָעִיר גְּדוֹלָה", "the city is big", "only the noun with הַ"]]),
     ],
     "examples": [
         ex("דָּג גָּדוֹל", "a big fish", "Jonah 2:1"),
         ex("הָעִיר הַגְּדוֹלָה", "the great city", "Jonah 1:2"),
         ex("רוּחַ־גְּדוֹלָה", "a great wind; רוּחַ is feminine", "Jonah 1:4"),
         ex("יִרְאָה גְדוֹלָה", "a great fear", "Jonah 1:10"),
         ex("הַסַּעַר הַגָּדוֹל הַזֶּה", "this great storm", "Jonah 1:12"),
         ex("הַמְּאֹרֹת הַגְּדֹלִים", "the great lights; plural", "Genesis 1:16"),
         ex("כִּי־טוֹב", "that it was good", "Genesis 1:4"),
     ]},
    {"group": NOUNS, "id": "demonstratives", "title": "This and that",
     "why": "'This' has a masculine and a feminine form, and 'that' is just 'he' with the article.",
     "body": [
         "'This' is זֶה (masculine), זֹאת (feminine), אֵלֶּה 'these'. After a definite noun it "
         "takes the article, like an adjective: הָאִישׁ הַזֶּה 'this man'.",
         "Alone, it is a pronoun: זֶה דְבָרִי 'this was my word', מַה־זֹּאת 'what is this?'",
         "'That' is the pronoun 'he' or 'she' with the article: הָאִישׁ הַהוּא 'that man', בַּיּוֹם "
         "הַהוּא 'on that day'.",
     ],
     "tables": [
         table("This and that", ["", "Masculine", "Feminine", "Plural"],
               [["this", "זֶה", "זֹאת", "אֵלֶּה"],
                ["that", "הַהוּא", "הַהִיא", "הָהֵם"]]),
     ],
     "examples": [
         ex("הָרָעָה הַזֹּאת", "this evil; feminine", "Jonah 1:7"),
         ex("הַזֶּה", "this; masculine", "Jonah 1:12"),
         ex("הָאִישׁ הַזֶּה", "this man", "Jonah 1:14"),
         ex("מַה־זֹּאת", "what is this?", "Jonah 1:10"),
         ex("זֶה דְבָרִי", "this was my word", "Jonah 4:2"),
         ex("אֵלֶּה", "these"),
         ex("בַּיּוֹם הַהוּא", "on that day"),
     ]},
    {"group": NOUNS, "id": "pronoun-copula", "title": "Pronouns as 'is'",
     "why": "Hebrew has no present-tense 'is', so a pronoun often does that job.",
     "body": [
         "The verb already says who acts. So a separate pronoun (אֲנִי, הוּא and the rest, in "
         "the Pronouns deck) adds emphasis: וַאֲנִי אָמַרְתִּי 'and I, I said'.",
         "In a sentence with no verb, the pronoun is the link: עִבְרִי אָנֹכִי 'a Hebrew (am) I'.",
         "הוּא can sit between two nouns as a plain 'is': יְהוָה הוּא אֱלֹהִים 'the LORD, he (is) "
         "God'. Read הוּא there as 'is'.",
     ],
     "tables": [
         table("Three jobs of a pronoun", ["Job", "Example", "Meaning"],
               [["emphasis", "וַאֲנִי אָמַרְתִּי", "and I, I said"],
                ["'am, are'", "עִבְרִי אָנֹכִי", "I am a Hebrew"],
                ["'is'", "יְהוָה הוּא אֱלֹהִים", "the LORD is God"]]),
     ],
     "examples": [
         ex("עִבְרִי אָנֹכִי", "I am a Hebrew", "Jonah 1:9"),
         ex("אֲנִי יָרֵא", "I fear", "Jonah 1:9"),
         ex("אַתָּה אֵל־חַנּוּן", "you are a gracious God", "Jonah 4:2"),
         ex("יְהוָה הוּא אֱלֹהִים", "the LORD, he is God", "Psalms 100:3"),
         ex("הוּא בֹרֵחַ", "he was fleeing", "Jonah 1:10"),
         ex("וַאֲנִי אָמַרְתִּי", "and I, I said", "Jonah 2:5"),
     ]},
    {"group": NOUNS, "id": "verbless", "title": "Sentences without a verb",
     "why": "Many short sentences have no verb at all. Add 'is' yourself.",
     "body": [
         "'The LORD is my shepherd' is two words in Hebrew: יְהוָה רֹעִי. Subject, then what is "
         "said about it, with no 'is'. The tense comes from the story around it.",
         "For emphasis the second part comes first: עִבְרִי אָנֹכִי 'a Hebrew am I'.",
     ],
     "tables": [
         table("What can follow the subject", ["Kind", "Example", "Meaning"],
               [["a noun", "יְהוָה רֹעִי", "the LORD is my shepherd"],
                ["an adjective", "טוֹב יְהוָה", "the LORD is good"],
                ["a phrase", "מַה־לְּךָ", "what is it to you?"],
                ["a participle", "הַיָּם הוֹלֵךְ", "the sea is going"]]),
     ],
     "examples": [
         ex("יְהוָה רֹעִי", "the LORD is my shepherd", "Psalms 23:1"),
         ex("מַה־לְּךָ", "what is it to you?", "Jonah 1:6"),
         ex("הַיָּם הוֹלֵךְ וְסֹעֵר", "the sea was getting stormier", "Jonah 1:11"),
         ex("טוֹב מוֹתִי מֵחַיָּי", "my death is better than my life", "Jonah 4:3"),
         ex("כִּי־טוֹב יְהֹוָה", "for the LORD is good", "Psalms 100:5"),
         ex("עֶזְרִי מֵעִם יְהוָה", "my help is from the LORD", "Psalms 121:2"),
     ]},
    {"group": NOUNS, "id": "comparison", "title": "Comparison with מִן",
     "why": "There is no word for 'than' or '-er'. 'From' does both jobs.",
     "body": [
         "Put the adjective first, then מִן before the thing compared. טוֹב מוֹתִי מֵחַיָּי is "
         "'good my death from my life', which means 'my death is better than my life'.",
         "There is no special form for 'the biggest'. Use the article ('the big one') or a "
         "construct: קֹדֶשׁ הַקֳּדָשִׁים 'the holy of holies', the holiest place.",
     ],
     "tables": [
         table("'From' as 'than'", ["Hebrew", "Word for word", "Meaning"],
               [["טוֹב מִן", "good from", "better than"],
                ["גָּדוֹל מִמֶּנִּי", "big from me", "bigger than me"],
                ["קָשֶׁה מִמְּךָ", "hard from you", "too hard for you"],
                ["קֹדֶשׁ הַקֳּדָשִׁים", "holy of holies", "the holiest"]]),
     ],
     "examples": [
         ex("טוֹב מוֹתִי מֵחַיָּי", "my death is better than my life", "Jonah 4:3"),
         ex("מִגְּדוֹלָם וְעַד־קְטַנָּם", "from the greatest to the least of them", "Jonah 3:5"),
         ex("גָּדוֹל מִמֶּנִּי", "bigger than me"),
         ex("טוֹב מִזָּהָב", "better than gold"),
         ex("קֹדֶשׁ הַקֳּדָשִׁים", "the holy of holies"),
     ]},
    {"group": NOUNS, "id": "numbers-usage", "title": "Counting with numbers",
     "why": "The number forms are in the Numbers deck. This is how they sit next to a noun.",
     "body": [
         "'One' follows its noun like an adjective: יוֹם אֶחָד 'one day'. 'Two' and up usually "
         "come before the noun: שְׁלֹשָׁה יָמִים 'three days'. From twenty up, the noun stays "
         "singular: אַרְבָּעִים יוֹם 'forty days'.",
         "Three to ten look backwards. The form ending in ־ָה goes with masculine nouns. The bare "
         "form goes with feminine nouns.",
         "Ordinals (first, second) are separate words. They follow the noun: יוֹם שֵׁנִי 'a second "
         "day'.",
     ],
     "tables": [
         table("With a masculine and a feminine noun", ["", "יוֹם 'day' (m.)", "עִיר 'city' (f.)"],
               [["one", "יוֹם אֶחָד", "עִיר אַחַת"],
                ["two", "שְׁנֵי יָמִים", "שְׁתֵּי עָרִים"],
                ["three", "שְׁלֹשָׁה יָמִים", "שָׁלֹשׁ עָרִים"]]),
         table("Ordinals", ["", "Masculine", "Feminine"],
               [["first", "רִאשׁוֹן", "רִאשׁוֹנָה"], ["second", "שֵׁנִי", "שֵׁנִית"],
                ["third", "שְׁלִישִׁי", "שְׁלִישִׁית"], ["fourth", "רְבִיעִי", "רְבִיעִית"],
                ["fifth", "חֲמִישִׁי", "חֲמִישִׁית"], ["sixth", "שִׁשִּׁי", "שִׁשִּׁית"],
                ["seventh", "שְׁבִיעִי", "שְׁבִיעִית"]]),
     ],
     "examples": [
         ex("יוֹם אֶחָד", "one day", "Genesis 1:5"),
         ex("שְׁלֹשָׁה יָמִים", "three days", "Jonah 2:1"),
         ex("שְׁלֹשֶׁת יָמִים", "three days; construct form", "Jonah 3:3"),
         ex("אַרְבָּעִים יוֹם", "forty days; singular noun", "Jonah 3:4"),
         ex("שְׁנֵי הַמְּאֹרֹת", "the two lights", "Genesis 1:16"),
         ex("יוֹם שֵׁנִי", "a second day", "Genesis 1:8"),
         ex("שֵׁנִית", "a second time", "Jonah 3:1"),
     ]},

    # ————— D. Verbs —————
    {"group": VERBS, "id": "root", "title": "The three-letter root",
     "why": "Every verb form grows from three consonants. Find them and you know the word.",
     "body": [
         "A Hebrew verb is three consonants, the root, plus vowels and add-ons for tense and "
         "person. ק-ו-ם is 'rise': קוּם 'rise!', וַיָּקָם 'and he rose'.",
         "A dictionary lists a verb by its simplest form: 'he did'. אָמַר 'he said' is glossed "
         "'to say'. The word deck uses that form too.",
         "To find the root, strip what is glued on: the וַ prefix, the י/ת/א/נ at the front, "
         "the endings ־תִּי, ־תָּ, ־וּ, and any suffix. The three letters left are the root.",
     ],
     "tables": [
         table("One root, many forms", ["Root", "Meaning", "Forms"],
               [["ק־ו־ם", "rise", "קוּם · וַיָּקָם"],
                ["י־ר־ד", "go down", "יָרַד · וַיֵּרֶד"],
                ["י־ד־ע", "know", "יָדְעוּ · יוֹדֵעַ"],
                ["ב־ר־ח", "flee", "לִבְרֹחַ · בֹרֵחַ"]]),
     ],
     "examples": [
         ex("קוּם", "rise! root ק-ו-ם", "Jonah 1:2"),
         ex("וַיָּקָם", "and he rose", "Jonah 1:3"),
         ex("יָרַד", "he went down; root י-ר-ד", "Jonah 1:5"),
         ex("וַיֵּרֶד", "and he went down", "Jonah 1:3"),
         ex("יָדְעוּ", "they knew; root י-ד-ע", "Jonah 1:10"),
         ex("יוֹדֵעַ", "knowing", "Jonah 1:12"),
         ex("יָדַעְתִּי", "I knew", "Jonah 4:2"),
         ex("לִבְרֹחַ", "to flee; root ב-ר-ח", "Jonah 1:3"),
         ex("בֹרֵחַ", "fleeing", "Jonah 1:10"),
     ]},
    {"group": VERBS, "id": "perfect", "title": "The perfect: 'he did'",
     "why": "Endings on the back of the verb say who did it. The action is finished.",
     "body": [
         "The perfect (the suffix form) is for a finished action, usually past in English: "
         "יָרַד 'he went down', בָּרָא 'he created'.",
         "The person is an ending. 'He' has none. The others are in the table.",
         "A subject word is optional. קָרָאתִי already says 'I called'.",
     ],
     "tables": [
         table("Perfect of שָׁמַע 'hear'", ["", "Ending", "Form"],
               [["he", "none", "שָׁמַע"], ["she", "־ָה", "שָׁמְעָה"], ["you (m.)", "־תָּ", "שָׁמַעְתָּ"],
                ["you (f.)", "־תְּ", "שָׁמַעַתְּ"], ["I", "־תִּי", "שָׁמַעְתִּי"], ["they", "־וּ", "שָׁמְעוּ"],
                ["you (pl.)", "־תֶּם", "שְׁמַעְתֶּם"], ["we", "־נוּ", "שָׁמַעְנוּ"]]),
     ],
     "examples": [
         ex("בָּרָא", "he created", "Genesis 1:1"),
         ex("יָרַד", "he went down", "Jonah 1:5"),
         ex("הָיְתָה", "she was, it was", "Genesis 1:2"),
         ex("שָׁמַעְתָּ", "you heard", "Jonah 2:3"),
         ex("עָשִׂיתָ", "you did", "Jonah 1:10"),
         ex("קָרָאתִי", "I called", "Jonah 2:3"),
         ex("אָמַרְתִּי", "I said", "Jonah 2:5"),
         ex("יָדְעוּ", "they knew", "Jonah 1:10"),
         ex("שָׁבוּ", "they turned back", "Jonah 3:10"),
     ]},
    {"group": VERBS, "id": "imperfect", "title": "The imperfect: 'he will do'",
     "why": "A letter on the front of the verb says who. The action is not finished.",
     "body": [
         "The imperfect (the prefix form) is for action not yet done: future, habit, or 'would' "
         "and 'may'. יָשׁוּב 'he will return'.",
         "The person is a letter at the front: י, ת, א, or נ. Plurals add ־וּ at the end.",
         "In poetry the imperfect is often just present: לֹא אִירָא 'I do not fear'. The same "
         "shape with וַ in front is the past-tense story form, the next lesson.",
     ],
     "tables": [
         table("Imperfect of שָׁמַע 'hear'", ["", "Prefix", "Form"],
               [["he", "יִ", "יִשְׁמַע"], ["she, you (m.)", "תִּ", "תִּשְׁמַע"], ["you (f.)", "תִּ ... ִי", "תִּשְׁמְעִי"],
                ["I", "אֶ", "אֶשְׁמַע"], ["they", "יִ ... וּ", "יִשְׁמְעוּ"], ["you (pl.)", "תִּ ... וּ", "תִּשְׁמְעוּ"],
                ["we", "נִ", "נִשְׁמַע"]]),
     ],
     "examples": [
         ex("יָשׁוּב", "he will turn back", "Jonah 3:9"),
         ex("יִהְיֶה", "it will be", "Genesis 1:29"),
         ex("תָּבוֹא", "you come", "Jonah 1:8"),
         ex("אֵלֵךְ", "I walk", "Psalms 23:4"),
         ex("לֹא אֶחְסָר", "I shall not lack", "Psalms 23:1"),
         ex("לֹא־אִירָא", "I will not fear", "Psalms 23:4"),
         ex("נַעֲשֶׂה", "we shall do", "Jonah 1:11"),
         ex("יָבֹא", "it will come", "Psalms 121:1"),
     ]},
    {"group": VERBS, "id": "wayyiqtol", "title": "וַיֹּאמֶר: the storytelling form",
     "why": "Bible stories run on this one shape: 'and then he ...', over and over.",
     "body": [
         "Take an imperfect, put וַ in front, and double the prefix letter: יֹאמַר 'he will say' "
         "becomes וַיֹּאמֶר 'and he said'. It looks like a future but it is past. It carries every "
         "next step of a story.",
         "Spot it by וַ plus a dagesh in the letter after it. Before א the vowel gets long "
         "instead: וָאֹמַר 'and I said'.",
         "וַיְהִי 'and it came to pass' opens a scene. וַיֹּאמֶר introduces speech. Genesis 1 and "
         "Jonah are chains of these forms.",
     ],
     "tables": [
         table("Imperfect and story form", ["Imperfect", "Story form", "Meaning"],
               [["יֹאמַר", "וַיֹּאמֶר", "and he said"],
                ["יָקוּם", "וַיָּקָם", "and he rose"],
                ["יֵרֵד", "וַיֵּרֶד", "and he went down"],
                ["יִהְיֶה", "וַיְהִי", "and it was"],
                ["יִרְאֶה", "וַיַּרְא", "and he saw"]]),
     ],
     "examples": [
         ex("וַיְהִי", "and it was, and it came to pass", "Jonah 1:1"),
         ex("וַיָּקָם", "and he rose", "Jonah 1:3"),
         ex("וַיֵּרֶד", "and he went down", "Jonah 1:3"),
         ex("וַיִּמְצָא", "and he found", "Jonah 1:3"),
         ex("וַיִּתֵּן", "and he gave", "Jonah 1:3"),
         ex("וַיֹּאמֶר", "and he said", "Jonah 1:6"),
         ex("וַיַּרְא", "and he saw", "Genesis 1:4"),
         ex("וַיַּבְדֵּל", "and he separated", "Genesis 1:4"),
         ex("וַיִּקְרָא", "and he called", "Genesis 1:5"),
     ]},
    {"group": VERBS, "id": "commands", "title": "Commands and wishes",
     "why": "Jonah's story opens with two bare commands. Prayers are full of gentle ones.",
     "body": [
         "The imperative is the imperfect with its front letter cut off: קוּם 'rise!', לֵךְ 'go!'. "
         "Plural adds ־וּ: לְכוּ 'go (all of you)!'. A נָא after it softens it: הַגִּידָה־נָּא 'please "
         "tell'.",
         "For 'let him', 'let it', the plain imperfect does the job: יְהִי אוֹר 'let there be light'.",
         "For 'let us', 'let me', the imperfect adds ־ָה: וְנַפִּילָה 'and let us cast'. A negative "
         "command is אַל plus the imperfect: אַל־תִּתֵּן 'do not put'.",
     ],
     "tables": [
         table("Commands and wishes", ["Form", "Meaning", "Example"],
               [["imperative", "do!", "קוּם"],
                ["plural ־וּ", "do! (all of you)", "לְכוּ"],
                ["+ נָא", "please do", "הַגִּידָה־נָּא"],
                ["imperfect", "let him, let it", "יְהִי אוֹר"],
                ["imperfect + ־ָה", "let us, let me", "נַפִּילָה"],
                ["אַל + imperfect", "do not", "אַל־תִּתֵּן"]]),
     ],
     "examples": [
         ex("קוּם לֵךְ", "rise, go!", "Jonah 1:2"),
         ex("קְרָא", "call!", "Jonah 1:6"),
         ex("לְכוּ", "go! (plural)", "Jonah 1:7"),
         ex("הַגִּידָה־נָּא", "please tell", "Jonah 1:8"),
         ex("יְהִי אוֹר", "let there be light", "Genesis 1:3"),
         ex("וְנַפִּילָה", "and let us cast", "Jonah 1:7"),
         ex("וְנֵדְעָה", "and let us know", "Jonah 1:7"),
         ex("אַל־נָא נֹאבְדָה", "please let us not perish", "Jonah 1:14"),
         ex("וְאַל־תִּתֵּן", "and do not put", "Jonah 1:14"),
     ]},
    {"group": VERBS, "id": "infinitive", "title": "The infinitive: 'to flee'",
     "why": "לְ plus a short verb form is 'to do', and לֵאמֹר is how the Bible says 'saying'.",
     "body": [
         "The infinitive is the verb's noun form. Most often it has לְ: לִבְרֹחַ 'to flee', לָבוֹא "
         "'to come'. It gives a purpose: וַיָּקָם יוֹנָה לִבְרֹחַ 'Jonah rose to flee'.",
         "With בְּ or כְּ it means 'when' or 'as': בַּעֲלוֹת הַשַּׁחַר 'when the dawn rose'.",
         "לֵאמֹר, 'to say', is the Bible's open quote mark. It follows a verb of speaking and "
         "introduces the words.",
     ],
     "tables": [
         table("Infinitive with a prefix", ["Prefix", "Meaning", "Example"],
               [["לְ", "to, in order to", "לִבְרֹחַ"],
                ["בְּ", "when", "בַּעֲלוֹת"],
                ["כְּ", "as, when", "כִּזְרֹחַ"],
                ["לֵאמֹר", "saying:", "לֵאמֹר"]]),
     ],
     "examples": [
         ex("לִבְרֹחַ", "to flee", "Jonah 1:3"),
         ex("לָבוֹא", "to come, to go", "Jonah 1:3"),
         ex("לִבְלֹעַ", "to swallow", "Jonah 2:1"),
         ex("לִהְיוֹת", "to be", "Jonah 4:6"),
         ex("לְהַצִּיל", "to save", "Jonah 4:6"),
         ex("לֵאמֹר", "saying; opens a quote", "Jonah 1:1"),
         ex("בַּעֲלוֹת הַשַּׁחַר", "when the dawn rose", "Jonah 4:7"),
         ex("כִּזְרֹחַ הַשֶּׁמֶשׁ", "as the sun rose", "Jonah 4:8"),
     ]},
    {"group": VERBS, "id": "participle", "title": "Participles: 'the one who ...'",
     "why": "A verb shaped like a noun. It describes, names a doer, or says what is happening now.",
     "body": [
         "The active participle has the vowels o-e: יֹשֵׁב 'sitting, one who dwells', שֹׁמֵר "
         "'keeping, keeper'. It agrees like an adjective.",
         "As a verb it means 'is doing': הַיָּם הוֹלֵךְ 'the sea is going'. As a noun it names the "
         "doer: שׁוֹמֵר יִשְׂרָאֵל 'the keeper of Israel'. With a suffix: רֹעִי 'my shepherd'.",
         "The passive participle has the vowels a-u: שָׁתוּל 'planted', בָּרוּךְ 'blessed'.",
     ],
     "tables": [
         table("Participle of שָׁמַר 'keep'", ["", "Vowels", "Form"],
               [["active", "o-e", "שֹׁמֵר"], ["active, feminine", "־ֶת", "שֹׁמֶרֶת"],
                ["active, plural", "־ִים", "שֹׁמְרִים"], ["passive", "a-u", "שָׁמוּר"]]),
     ],
     "examples": [
         ex("יֹשֵׁב", "dwelling; one who dwells", "Psalms 91:1"),
         ex("יוֹדֵעַ", "knowing", "Jonah 3:9"),
         ex("בֹרֵחַ", "fleeing", "Jonah 1:10"),
         ex("הוֹלֵךְ וְסֹעֵר", "going and storming", "Jonah 1:11"),
         ex("שׁוֹמֵר יִשְׂרָאֵל", "the keeper of Israel", "Psalms 121:4"),
         ex("רֹעִי", "my shepherd", "Psalms 23:1"),
         ex("מְרַחֶפֶת", "hovering; feminine", "Genesis 1:2"),
         ex("שָׁתוּל", "planted; passive", "Psalms 1:3"),
         ex("חָבוּשׁ", "bound; passive", "Jonah 2:6"),
     ]},
    {"group": VERBS, "id": "stems", "title": "The stems: Niphal, Piel, Hiphil, Hitpael",
     "why": "The same root can be simple, passive, intense, or causing. A few letters tell which.",
     "body": [
         "Most verbs you meet are Qal, the simple stem. The other stems reshape the root with a "
         "prefix or a doubled middle letter. You only need to recognise them.",
         "Niphal is passive: 'was done'. Piel is intense or makes something happen. Hiphil is "
         "causing: 'make someone do'. Hitpael is reflexive: 'do to oneself'.",
     ],
     "tables": [
         table("How to spot each stem", ["Stem", "Look for", "Example"],
               [["Qal (simple)", "nothing added", "שָׁמַר\nhe kept"],
                ["Niphal (passive)", "נִ in front", "נִרְדָּם\nfast asleep"],
                ["Piel (intense)", "dagesh in the middle", "דִּבֶּר\nhe spoke"],
                ["Hiphil (causing)", "הִ in front, or לְהַ", "הִגִּיד\nhe told"],
                ["Hitpael (to oneself)", "הִתְ in front", "הִתְפַּלֵּל\nhe prayed"]]),
     ],
     "examples": [
         ex("נִרְדָּם", "fast asleep; Niphal", "Jonah 1:6"),
         ex("נִגְרַשְׁתִּי", "I was driven out; Niphal", "Jonah 2:5"),
         ex("וַיִּנָּחֶם", "and he relented; Niphal", "Jonah 3:10"),
         ex("וַיְמַן", "and he appointed; Piel", "Jonah 2:1"),
         ex("דִּבֶּר", "he spoke; Piel", "Jonah 3:10"),
         ex("הִגִּיד", "he told; Hiphil", "Jonah 1:10"),
         ex("הֵטִיל", "he hurled; Hiphil", "Jonah 1:4"),
         ex("וַיַּבְדֵּל", "and he separated; Hiphil", "Genesis 1:4"),
         ex("לְהַצִּיל", "to save; Hiphil", "Jonah 4:6"),
         ex("וַיִּתְפַּלֵּל", "and he prayed; Hitpael", "Jonah 2:2"),
     ]},
    {"group": VERBS, "id": "weak-roots", "title": "Weak roots: why וַיְהִי comes from הָיָה",
     "why": "Some root letters drop or melt, so the form you see is shorter than the root.",
     "body": [
         "Roots ending in ה (הָיָה 'be', רָאָה 'see') lose the ה in many forms: וַיְהִי, וַיַּרְא.",
         "Hollow roots have a vowel letter in the middle (קוּם 'rise', שׁוּב 'return'). It shows "
         "in some forms and vanishes in others: וַיָּקָם, יָשׁוּב.",
         "Roots starting with נ turn it into a dagesh: נָתַן 'give' becomes וַיִּתֵּן. Roots starting "
         "with י turn it into a vowel: יָרַד 'go down' becomes וַיֵּרֶד.",
     ],
     "tables": [
         table("Four weak patterns", ["", "Root", "Story form"],
               [["ends in ה: ה drops", "הָיָה", "וַיְהִי"],
                ["hollow: middle vanishes", "קוּם", "וַיָּקָם"],
                ["starts with נ: נ → dagesh", "נָתַן", "וַיִּתֵּן"],
                ["starts with י: י → vowel", "יָרַד", "וַיֵּרֶד"]]),
     ],
     "examples": [
         ex("וַיְהִי", "and it was; from הָיָה", "Jonah 1:1"),
         ex("וַיַּרְא", "and he saw; from רָאָה", "Genesis 1:4"),
         ex("וַיַּעַל", "and it went up; from עָלָה", "Jonah 4:6"),
         ex("וַיָּקָם", "and he rose; from קוּם", "Jonah 1:3"),
         ex("יָשׁוּב", "he will return; from שׁוּב", "Jonah 3:9"),
         ex("וַיֵּלֶךְ", "and he went; from הָלַךְ", "Jonah 3:3"),
         ex("וַיִּתֵּן", "and he gave; from נָתַן", "Jonah 1:3"),
         ex("וַיִּפֹּל", "and it fell; from נָפַל", "Jonah 1:7"),
         ex("וַיֵּרֶד", "and he went down; from יָרַד", "Jonah 1:3"),
         ex("וַיֵּשֶׁב", "and he sat; from יָשַׁב", "Jonah 3:6"),
     ]},
    {"group": VERBS, "id": "object-suffixes", "title": "Object suffixes on verbs",
     "why": "'He answered me' is one word. The 'me' hangs on the end of the verb.",
     "body": [
         "A pronoun object can attach to the verb: וַיַּעֲנֵנִי 'and he answered me', גִדַּלְתּוֹ "
         "'you grew it'. The endings are the ones from nouns, with ־נִי for 'me'.",
         "The other way is the object marker with a suffix as its own word: אֹתוֹ 'him'. Both "
         "are common and mean the same.",
     ],
     "tables": [
         table("Object endings", ["", "Ending", "Example"],
               [["me", "־נִי", "וַיַּעֲנֵנִי"], ["you", "־ךָ", "יִשְׁמָרְךָ"], ["him", "־וֹ, ־הוּ", "גִדַּלְתּוֹ"],
                ["her", "־ָהּ", "שְׁמָרָהּ"], ["us", "־נוּ", "עָשָׂנוּ"], ["them", "־ָם", "בָּרָא אֹתָם"]]),
     ],
     "examples": [
         ex("וַיַּעֲנֵנִי", "and he answered me", "Jonah 2:3"),
         ex("יְסֹבְבֵנִי", "it surrounded me", "Jonah 2:4"),
         ex("אֲפָפוּנִי", "they closed around me", "Jonah 2:6"),
         ex("שָׂאוּנִי", "lift me up", "Jonah 1:12"),
         ex("וַיְטִלֻהוּ", "and they hurled him", "Jonah 1:15"),
         ex("יַנְחֵנִי", "he leads me", "Psalms 23:3"),
         ex("גִדַּלְתּוֹ", "you grew it", "Jonah 4:10"),
         ex("עָשָׂנוּ", "he made us", "Psalms 100:3"),
         ex("בָּרָא אֹתוֹ", "he created him; separate word", "Genesis 1:27"),
     ]},
    {"group": VERBS, "id": "negation", "title": "Not: לֹא and אַל",
     "why": "Two words for 'not'. The choice tells you whether it is a fact or a wish.",
     "body": [
         "לֹא is for facts: לֹא הָלַךְ 'he did not walk', לֹא אִירָא 'I will not fear'. It also makes "
         "lasting rules, as in the Ten Commandments.",
         "אַל is for wishes and commands, with the imperfect: אַל־תִּתֵּן 'do not put'.",
         "אֵין is 'there is not': אֵין מַיִם 'there is no water'. Its opposite is יֵשׁ, in the next "
         "lesson.",
     ],
     "tables": [
         table("Three ways to say 'not'", ["Word", "Use", "Example"],
               [["לֹא", "facts", "לֹא הָלַךְ"],
                ["אַל", "commands, wishes", "אַל־תִּתֵּן"],
                ["אֵין", "there is not", "אֵין מַיִם"]]),
     ],
     "examples": [
         ex("לֹא הָלַךְ", "he did not walk", "Psalms 1:1"),
         ex("לֹא־אִירָא", "I will not fear", "Psalms 23:4"),
         ex("וְלֹא נֹאבֵד", "and we will not perish", "Jonah 1:6"),
         ex("לֹא־כֵן", "not so", "Psalms 1:4"),
         ex("וְאַל־תִּתֵּן", "and do not put", "Jonah 1:14"),
         ex("אַל־יָנוּם", "may he not slumber", "Psalms 121:3"),
         ex("אַל־יִרְעוּ", "let them not graze", "Jonah 3:7"),
         ex("אֵין מַיִם", "there is no water"),
     ]},
    {"group": VERBS, "id": "hinneh-yesh", "title": "הִנֵּה, יֵשׁ, אֵין",
     "why": "'Look!', 'there is', and 'there is not' do much of the work that verbs do in English.",
     "body": [
         "הִנֵּה 'behold, look' points at something: הִנֵּה נָתַתִּי לָכֶם 'look, I have given you'. "
         "With a suffix it means 'here I am': הִנְנִי.",
         "יֵשׁ 'there is' says something exists: יֶשׁ־בָּהּ 'there is in it'. With לְ it means "
         "'have': יֵשׁ לִי 'I have'.",
         "אֵין is its opposite: אֵין מֶלֶךְ 'there is no king', אֵין לָנוּ 'we have not'.",
     ],
     "tables": [
         table("Three little words", ["Word", "Meaning", "With לְ"],
               [["הִנֵּה", "look!, behold", "הִנְנִי  here I am"],
                ["יֵשׁ", "there is", "יֵשׁ לִי  I have"],
                ["אֵין", "there is not", "אֵין לִי  I have not"]]),
     ],
     "examples": [
         ex("הִנֵּה נָתַתִּי לָכֶם", "look, I have given you", "Genesis 1:29"),
         ex("וְהִנֵּה־טוֹב מְאֹד", "and behold, very good", "Genesis 1:31"),
         ex("הִנֵּה לֹא־יָנוּם", "behold, he does not slumber", "Psalms 121:4"),
         ex("יֶשׁ־בָּהּ", "there is in it", "Jonah 4:11"),
         ex("הִנְנִי", "here I am"),
         ex("יֵשׁ לִי", "I have"),
         ex("אֵין לָנוּ", "we have not"),
     ]},

    # ————— E. Sentences and texts —————
    {"group": SENTENCES, "id": "word-order", "title": "Word order: verb first",
     "why": "The verb usually comes first, then the subject, then the object. Anything else is emphasis.",
     "body": [
         "A story sentence runs verb, subject, object: בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם 'created God "
         "the heavens'. Read the verb, then look for who did it.",
         "When the subject comes first, the story pauses: for background, contrast, or a new "
         "scene. וְיוֹנָה יָרַד 'but Jonah had gone down' steps away from the sailors to tell you "
         "where Jonah was.",
         "Poetry and verbless sentences are freer. Whatever comes first is stressed: עִבְרִי "
         "אָנֹכִי 'a Hebrew am I'.",
     ],
     "tables": [
         table("What the order tells you", ["First word", "Signal", "Example"],
               [["verb", "the story moves on", "וַיָּקָם יוֹנָה"],
                ["subject", "background, contrast", "וְיוֹנָה יָרַד"],
                ["something else", "emphasis", "עִבְרִי אָנֹכִי"]]),
     ],
     "examples": [
         ex("בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם", "God created the heavens", "Genesis 1:1"),
         ex("וַיָּקָם יוֹנָה", "and Jonah rose", "Jonah 1:3"),
         ex("וַיִּתְפַּלֵּל יוֹנָה אֶל־יְהוָה", "and Jonah prayed to the LORD", "Jonah 2:2"),
         ex("וַיְמַן יְהוָה דָּג גָּדוֹל", "and the LORD appointed a big fish", "Jonah 2:1"),
         ex("וְיוֹנָה יָרַד", "but Jonah had gone down; subject first", "Jonah 1:5"),
         ex("וְהָאָרֶץ הָיְתָה", "now the earth was; subject first", "Genesis 1:2"),
     ]},
    {"group": SENTENCES, "id": "asher-ki", "title": "אֲשֶׁר and כִּי: joining clauses",
     "why": "Two small words do the work of 'who', 'which', 'that', 'because', and 'when'.",
     "body": [
         "אֲשֶׁר is 'who, which, that'. It never changes: הָאִישׁ אֲשֶׁר לֹא הָלַךְ 'the man who did not "
         "walk'. Often a pronoun inside the clause points back: אֲשֶׁר יֶשׁ־בָּהּ 'which there is in "
         "it', that is, 'in which there is'.",
         "כִּי is 'that' after seeing and knowing, 'because', 'when', or 'indeed'. Let the context "
         "choose.",
     ],
     "tables": [
         table("Joining words", ["Word", "Meaning", "Example"],
               [["אֲשֶׁר", "who, which, that", "אֲשֶׁר בָּאֳנִיָּה"],
                ["כִּי", "that", "וַיַּרְא כִּי־טוֹב"],
                ["כִּי", "because", "כִּי יָדְעוּ"],
                ["כַּאֲשֶׁר", "as, when", "כַּאֲשֶׁר חָפַצְתָּ"],
                ["כִּי אִם", "but rather", "כִּי אִם"]]),
     ],
     "examples": [
         ex("הָאִישׁ אֲשֶׁר לֹא הָלַךְ", "the man who did not walk", "Psalms 1:1"),
         ex("אֲשֶׁר בָּאֳנִיָּה", "which were in the ship", "Jonah 1:5"),
         ex("אֲשֶׁר יֶשׁ־בָּהּ", "in which there is", "Jonah 4:11"),
         ex("כִּי־טוֹב", "that it was good", "Genesis 1:4"),
         ex("כִּי יָדְעוּ הָאֲנָשִׁים", "because the men knew", "Jonah 1:10"),
         ex("כִּי הִגִּיד לָהֶם", "because he had told them", "Jonah 1:10"),
         ex("כַּאֲשֶׁר חָפַצְתָּ", "as you pleased", "Jonah 1:14"),
         ex("כִּי אִם", "but rather", "Psalms 1:2"),
     ]},
    {"group": SENTENCES, "id": "parallelism", "title": "Parallelism: reading a psalm",
     "why": "Hebrew poetry rhymes ideas, not sounds. The second line answers the first.",
     "body": [
         "A line of poetry has two halves. They say the same thing twice, say opposite things, "
         "or the second half finishes the first. Psalm 1:6 sets 'the LORD knows the way of the "
         "righteous' against 'the way of the wicked perishes'.",
         "This is your best help with hard words. If the first half is clear, the second means "
         "the same or the opposite.",
         "Jonah's prayer in chapter 2 is a psalm too. Expect a story in chapters 1, 3, and 4, "
         "and poetry in chapter 2.",
     ],
     "tables": [
         table("Three kinds of pairs", ["Kind", "Second half does", "Where"],
               [["same", "says it again", "Jonah 2:3"],
                ["opposite", "contrasts", "Psalm 1:6"],
                ["answer", "completes it", "Psalm 121:1-2"]]),
     ],
     "examples": [
         ex("לֹא הָלַךְ", "he did not walk; the first of three matching lines", "Psalms 1:1"),
         ex("לֹא עָמָד", "he did not stand; the second", "Psalms 1:1"),
         ex("לֹא יָשָׁב", "he did not sit; the third", "Psalms 1:1"),
         ex("יוֹדֵעַ יְהוָה דֶּרֶךְ צַדִּיקִים", "the LORD knows the way of the righteous", "Psalms 1:6"),
         ex("וְדֶרֶךְ רְשָׁעִים תֹּאבֵד", "but the way of the wicked perishes; the contrast", "Psalms 1:6"),
         ex("מֵאַיִן יָבֹא עֶזְרִי", "from where will my help come?", "Psalms 121:1"),
         ex("עֶזְרִי מֵעִם יְהוָה", "my help is from the LORD; the answer", "Psalms 121:2"),
         ex("קָרָאתִי מִצָּרָה לִי", "I called out of my distress", "Jonah 2:3"),
         ex("מִבֶּטֶן שְׁאוֹל שִׁוַּעְתִּי", "from the belly of Sheol I cried; the echo", "Jonah 2:3"),
     ]},
]


def consonants(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if "א" <= c <= "ת")


def check(lessons):
    """Every cited example really occurs in its verse, ids are unique, nothing is blank."""
    books = {}
    for p in glob.glob(os.path.join(HERE, "Mikra", "Texts", "*.json")):
        b = json.load(open(p, encoding="utf-8"))
        books[b["name"]] = {(v["c"], v["v"]): v for v in b["verses"]}
    ids = [l["id"] for l in lessons]
    assert len(set(ids)) == len(ids), "duplicate lesson ids"
    cited = 0
    for l in lessons:
        assert l["group"] in {SCRIPT, ATTACH, NOUNS, VERBS, SENTENCES}, f"{l['id']}: bad group"
        assert l["title"] and l["why"] and l["body"] and l["examples"], f"{l['id']} is incomplete"
        for t in l.get("tables", []):
            assert t["columns"] and all(len(r) == len(t["columns"]) for r in t["rows"]), \
                f"{l['id']}: table '{t['title']}' has ragged rows"
        for e in l["examples"]:
            assert e["h"].strip() and e["g"].strip(), f"{l['id']}: blank example"
            if "ref" not in e:
                continue
            book, cv = e["ref"].rsplit(" ", 1)
            c, v = map(int, cv.split(":"))
            verse = books[book][(c, v)]
            text = consonants("".join(w["h"] for w in verse["words"]))
            assert consonants(e["h"]) in text, f"{l['id']}: {e['h']} is not in {e['ref']}"
            cited += 1
    print(f"grammar ok — {len(lessons)} lessons, {cited} examples cited from the texts")


if __name__ == "__main__":
    check(LESSONS)
    if "--check" not in sys.argv:
        out = os.path.join(HERE, "Mikra", "Grammar.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(LESSONS, f, ensure_ascii=False, separators=(",", ":"))
        print(f"wrote {out}")

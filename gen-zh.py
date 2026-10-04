#!/usr/bin/env python3
"""Check Mikra/Zh.json — the Chinese meanings, keyed by the English string they translate.

The app looks each English gloss, note, and lesson string up in Zh.json at
display time, so the generated JSON files stay English-only. Verse lines are
the exception: gen-text.py fetches the Union Version into Texts.json directly.

    ./gen-zh.py            # report strings that have no Chinese yet
    ./gen-zh.py --missing  # print them as a JSON object to fill in
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HEBREW = re.compile("[א-ת]")


def load(name):
    return json.load(open(os.path.join(HERE, "Mikra", name), encoding="utf-8"))


def needed():
    """Every English string the app can show in Chinese, in a stable order."""
    keys = []
    for w in load("Words.json"):
        keys += [w["g"], w.get("p"), w.get("f")]
    for deck in load("Decks.json"):
        for card in deck["cards"]:
            keys += [card["g"], card.get("p"), card.get("f")]
            keys += [f["g"] for f in card.get("forms", [])]
    for entry in load("Texts.json"):  # the book index; the verses sit in Texts/<file>.json
        if not entry["notes"]:
            continue  # the whole Tanakh is readable, but only the course chapters get Chinese glosses
        verses = load(f"Texts/{entry['file']}.json")["verses"]
        course = {v["c"] for v in verses if any("n" in w for w in v["words"])}
        for verse in verses:
            if verse["c"] not in course:
                continue
            for w in verse["words"]:
                keys += w["g"].split(" + ")  # "and + to be" is translated a piece at a time
                if "n" in w:
                    keys.append(w["n"])
    for lesson in load("Grammar.json"):
        keys += [lesson["title"], lesson["why"]] + lesson["body"]
        for table in lesson.get("tables") or []:
            keys.append(table["title"])
            keys += [c for c in table["columns"] if c]
            keys += [c for row in table["rows"] for c in row if not HEBREW.search(c)]
        keys += [e["g"].split(" — ", 1)[-1] for e in lesson["examples"]]  # after the reading
    seen = set()
    return [k for k in keys if k and not (k in seen or seen.add(k))]


if __name__ == "__main__":
    zh = load("Zh.json")
    keys = needed()
    missing = [k for k in keys if k not in zh]
    if "--missing" in sys.argv:
        json.dump({k: "" for k in missing}, sys.stdout, ensure_ascii=False, indent=1)
    else:
        print(f"{len(keys)} strings, {len(missing)} without Chinese, {len(set(zh) - set(keys))} unused")
        for k in missing[:20]:
            print("  " + k[:80])
    sys.exit(1 if missing else 0)

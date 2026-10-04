#!/usr/bin/env python3
"""Generate Mikra/Phrases.json: everyday Modern Hebrew phrases ("good morning", "how much
is it?") in the shape of a book of verses, one chapter per situation, so the reader,
the word taps and the progress tints work on them unchanged.

    ./gen-phrases.py           # write the JSON
    ./gen-phrases.py --check   # self-check only
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
NIQQUD = re.compile("[ְ-ׇּׁׂ]")

# (English set name, Chinese, tile glyph, phrases); a phrase is (words, English, Chinese) and a
# word is "hebrew=gloss". Masculine forms unless marked; "(m)" / "(f)" is who is spoken to or speaking.
SETS = [
    ("Greetings", "问候", "שָׁלוֹם", [
        ("שָׁלוֹם=peace; hello, goodbye", "Hello", "你好"),
        ("בּוֹקֶר=morning טוֹב=good", "Good morning", "早上好"),
        ("עֶרֶב=evening טוֹב=good", "Good evening", "晚上好"),
        ("לַיְלָה=night טוֹב=good", "Good night", "晚安"),
        ("מַה=what שְּׁלוֹמְךָ=your well-being (to a man)", "How are you? (to a man)", "你好吗？（对男性）"),
        ("מַה=what שְּׁלוֹמֵךְ=your well-being (to a woman)", "How are you? (to a woman)", "你好吗？（对女性）"),
        ("טוֹב=good, fine תּוֹדָה=thanks", "Fine, thanks", "很好，谢谢"),
        ("מַה=what נִשְׁמָע=is heard", "What's new?", "最近怎么样？"),
        ("לְהִתְרָאוֹת=to see each other; see you", "See you", "再见"),
        ("שַׁבָּת=Sabbath שָׁלוֹם=peace", "Shabbat shalom", "安息日平安"),
    ]),
    ("Politeness", "礼貌用语", "תּוֹדָה", [
        ("תּוֹדָה=thanks רַבָּה=much, great (f)", "Thank you very much", "非常感谢"),
        ("בְּבַקָּשָׁה=please; you're welcome", "Please / You're welcome", "请；不客气"),
        ("סְלִיחָה=forgiveness; sorry, excuse me", "Sorry / Excuse me", "对不起；打扰一下"),
        ("אֵין=there is no בְּעָיָה=problem", "No problem", "没问题"),
        ("בְּתֵאָבוֹן=with appetite", "Enjoy your meal", "祝好胃口"),
        ("לְחַיִּים=to life", "Cheers", "干杯"),
        ("מַזָּל=luck, fortune טוֹב=good", "Congratulations", "恭喜"),
        ("בְּהַצְלָחָה=with success", "Good luck", "祝成功"),
        ("כָּל=all הַכָּבוֹד=the honour", "Well done", "真棒"),
        ("כֵּן=yes", "Yes", "是"),
        ("לֹא=no, not", "No", "不"),
    ]),
    ("Getting acquainted", "初次见面", "נָעִים", [
        ("מַה=what שִּׁמְךָ=your name (to a man)", "What's your name? (to a man)", "你叫什么名字？（对男性）"),
        ("מַה=what שְּׁמֵךְ=your name (to a woman)", "What's your name? (to a woman)", "你叫什么名字？（对女性）"),
        ("קוֹרְאִים=they call לִי=to me דָּוִד=David", "My name is David", "我叫大卫"),
        ("נָעִים=pleasant מְאֹד=very", "Nice to meet you", "很高兴认识你"),
        ("מֵאַיִן=from where אַתָּה=you (m)", "Where are you from? (to a man)", "你从哪里来？（对男性）"),
        ("אֲנִי=I מִסִּין=from China", "I'm from China", "我来自中国"),
        ("אֲנִי=I לוֹמֵד=learning (m) עִבְרִית=Hebrew", "I'm learning Hebrew (m)", "我在学希伯来语（男）"),
        ("אַתָּה=you (m) מְדַבֵּר=speaking (m) אַנְגְּלִית=English", "Do you speak English? (to a man)", "你会说英语吗？（对男性）"),
        ("אֲנִי=I לֹא=not מֵבִין=understanding (m)", "I don't understand (m)", "我不明白（男）"),
        ("עוֹד=again, more פַּעַם=time, occasion בְּבַקָּשָׁה=please", "Once more, please", "请再说一遍"),
        ("לְאַט=slowly בְּבַקָּשָׁה=please", "Slowly, please", "请慢一点"),
    ]),
    ("Weather", "天气", "גֶּשֶׁם", [
        ("מַה=what מֶּזֶג=temperament; weather (with אֲוִיר) הָאֲוִיר=the air הַיּוֹם=today", "What's the weather today?", "今天天气怎么样？"),
        ("חַם=hot הַיּוֹם=today", "It's hot today", "今天很热"),
        ("קַר=cold בַּחוּץ=outside", "It's cold outside", "外面很冷"),
        ("יוֹרֵד=coming down (m) גֶּשֶׁם=rain", "It's raining", "下雨了"),
        ("הַשֶּׁמֶשׁ=the sun זוֹרַחַת=shining (f)", "The sun is shining", "阳光灿烂"),
        ("יֵשׁ=there is רוּחַ=wind חֲזָקָה=strong (f)", "There's a strong wind", "风很大"),
        ("יוֹם=day יָפֶה=beautiful הַיּוֹם=today", "It's a beautiful day today", "今天天气很好"),
        ("מָחָר=tomorrow יִהְיֶה=will be קַר=cold", "Tomorrow will be cold", "明天会冷"),
        ("יֵשׁ=there is שֶׁלֶג=snow בָּהָר=on the mountain", "There's snow on the mountain", "山上有雪"),
    ]),
    ("Food and drink", "饮食", "אֹכֶל", [
        ("אֲנִי=I רָעֵב=hungry (m)", "I'm hungry (m)", "我饿了（男）"),
        ("אֲנִי=I צָמֵא=thirsty (m)", "I'm thirsty (m)", "我渴了（男）"),
        ("מַיִם=water בְּבַקָּשָׁה=please", "Water, please", "请给我水"),
        ("אֶפְשָׁר=is it possible אֶת=(object marker) הַתַּפְרִיט=the menu", "Can I have the menu?", "可以给我菜单吗？"),
        ("קָפֶה=coffee בְּלִי=without סֻכָּר=sugar", "Coffee without sugar", "咖啡不加糖"),
        ("זֶה=this טָעִים=tasty מְאֹד=very", "This is very tasty", "这很好吃"),
        ("אֲנִי=I לֹא=not אוֹכֵל=eating (m) בָּשָׂר=meat", "I don't eat meat (m)", "我不吃肉（男）"),
        ("כַּמָּה=how much זֶה=this עוֹלֶה=costs", "How much does it cost?", "这个多少钱？"),
        ("הַחֶשְׁבּוֹן=the bill בְּבַקָּשָׁה=please", "The bill, please", "请结账"),
        ("לֶחֶם=bread וְחֶמְאָה=and butter", "Bread and butter", "面包和黄油"),
    ]),
    ("Getting around", "问路", "אֵיפֹה", [
        ("אֵיפֹה=where הַשֵּׁרוּתִים=the restroom", "Where is the restroom?", "洗手间在哪里？"),
        ("אֵיפֹה=where הַתַּחֲנָה=the station, stop", "Where is the station?", "车站在哪里？"),
        ("יָמִינָה=to the right", "To the right", "向右"),
        ("שְׂמֹאלָה=to the left", "To the left", "向左"),
        ("יָשָׁר=straight", "Straight ahead", "直走"),
        ("זֶה=this רָחוֹק=far", "Is it far?", "远吗？"),
        ("זֶה=this קָרוֹב=near", "It's close", "很近"),
        ("אֲנִי=I הוֹלֵךְ=going (m) הַבַּיְתָה=homeward", "I'm going home (m)", "我回家（男）"),
        ("כַּמָּה=how much זְמַן=time זֶה=this לוֹקֵחַ=takes", "How long does it take?", "需要多长时间？"),
        ("עֲצֹר=stop! (to a man) כָּאן=here בְּבַקָּשָׁה=please", "Stop here, please", "请在这里停"),
    ]),
    ("Time", "时间", "שָׁעָה", [
        ("מַה=what הַשָּׁעָה=the hour", "What time is it?", "现在几点？"),
        ("הַשָּׁעָה=the hour שָׁלוֹשׁ=three", "It's three o'clock", "现在三点"),
        ("אֵיזֶה=which יוֹם=day הַיּוֹם=today", "What day is it today?", "今天星期几？"),
        ("הַיּוֹם=today יוֹם=day רִאשׁוֹן=first", "Today is Sunday", "今天是星期日"),
        ("מָחָר=tomorrow", "Tomorrow", "明天"),
        ("אֶתְמוֹל=yesterday", "Yesterday", "昨天"),
        ("אֲנִי=I מְאֻחָר=late (m)", "I'm late (m)", "我迟到了（男）"),
        ("עוֹד=more מְעַט=a little", "In a little while", "马上"),
        ("נִפָּגֵשׁ=we will meet בַּבֹּקֶר=in the morning", "Let's meet in the morning", "我们早上见"),
        ("בְּשָׁבוּעַ=in the week הַבָּא=the coming (m)", "Next week", "下周"),
    ]),
    ("Feelings", "心情", "לֵב", [
        ("אֲנִי=I עָיֵף=tired (m)", "I'm tired (m)", "我累了（男）"),
        ("אֲנִי=I שָׂמֵחַ=happy (m)", "I'm happy (m)", "我很高兴（男）"),
        ("אֲנִי=I לֹא=not מַרְגִּישׁ=feeling (m) טוֹב=good", "I don't feel well (m)", "我不舒服（男）"),
        ("הַכֹּל=everything בְּסֵדֶר=in order; okay", "Everything is fine", "一切都好"),
        ("אֲנִי=I אוֹהֵב=loving (m) אוֹתָךְ=you (f, object)", "I love you (man to woman)", "我爱你（男对女）"),
        ("אֲנִי=I צָרִיךְ=need (m) לָלֶכֶת=to go", "I have to go (m)", "我得走了（男）"),
        ("בּוֹא=come! (to a man) הֵנָּה=here, hither", "Come here (to a man)", "过来（对男性）"),
        ("רֶגַע=moment בְּבַקָּשָׁה=please", "One moment, please", "请稍等"),
        ("אַל=don't תִּדְאַג=you will worry (m)", "Don't worry (to a man)", "别担心（对男性）"),
        ("אֲנִי=I מִתְגַּעְגֵּעַ=longing (m) אֵלֶיךָ=to you (m)", "I miss you (man to man)", "我想你（男对男）"),
    ]),
]


def build():
    sets, verses = [], []
    for c, (name, zh, heb, phrases) in enumerate(SETS, 1):
        sets.append({"c": c, "name": name, "zh": zh, "heb": heb})
        for v, (words, en, pzh) in enumerate(phrases, 1):
            # a gloss may hold spaces; a new word starts at a space before "hebrew="
            ws = [dict(zip(("h", "g"), w.split("=", 1))) for w in re.split(r" (?=[\u05D0-\u05EA][^ ]*=)", words)]
            verses.append({"c": c, "v": v, "en": en, "zh": pzh, "words": ws})
    return {"name": "Daily phrases", "heb": "עִבְרִית", "sets": sets, "verses": verses}


def check(data):
    for verse in data["verses"]:
        for w in verse["words"]:
            assert w["h"] and w["g"], verse
            assert NIQQUD.search(w["h"]), f"unpointed: {w['h']} in {verse['en']}"
    refs = [(v["c"], v["v"]) for v in data["verses"]]
    assert len(refs) == len(set(refs))
    assert {s["c"] for s in data["sets"]} == {v["c"] for v in data["verses"]}


if __name__ == "__main__":
    data = build()
    check(data)
    if "--check" not in sys.argv:
        with open(os.path.join(HERE, "Mikra", "Phrases.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"{len(data['sets'])} sets, {len(data['verses'])} phrases")

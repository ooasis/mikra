import SwiftUI

/// Practice now: one short run that mixes words (your sets first, then the core band) with a verse.
/// Each item is a flip card: tap to see the back, swipe to move on or back; the last page ends the run.
struct PracticeView: View {
    @EnvironmentObject var store: Store

    private enum Item: Identifiable {
        case word(WordCard), verse(Verse)
        var id: String {
            switch self {
            case .word(let w): return "w" + w.id
            case .verse(let v): return "v" + v.id
            }
        }
    }

    @State private var items: [Item] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var reading: Verse?


    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(ui("Practice", "练习")).font(.title2.weight(.medium))
                Spacer()
                if !items.isEmpty {
                    Text("\(min(index + 1, items.count)) / \(items.count)").font(.caption).foregroundStyle(Theme.neutral500)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ProgressLine(fraction: items.isEmpty ? 0 : Double(index) / Double(items.count))
                .padding(.horizontal)
                .padding(.top, 10)

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    card(item, showBack: revealed && i == index)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cardSurface(lit: revealed && i == index)
                        .contentShape(.rect)
                        .onTapGesture { flip() }
                        .padding(16)
                        .environment(\.layoutDirection, .leftToRight) // content stays LTR
                        .tag(i)
                }
                finished
                    .environment(\.layoutDirection, .leftToRight)
                    .tag(items.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
        }
        .background(Theme.ground)
        .onAppear { if items.isEmpty { items = Self.build(store) } }
        .onChange(of: index) { Speech.stop(); revealed = false }
        .onDisappear { Speech.stop() }
        .fullScreenCover(item: $reading) { v in VerseView(verse: v, mode: .passive) }
    }

    private static func build(_ store: Store) -> [Item] {
        let mine = store.sets.flatMap(\.ids).compactMap { wordCardByID[$0] }.shuffled()
        let core = Array(wordDeck.prefix(100)).shuffled()
        var seen = Set<String>()
        let words = (mine + core).filter { seen.insert($0.id).inserted }.prefix(9)
        var out = words.map(Item.word)
        if let verse = store.waveVerse ?? store.todaysVerse ?? store.ritualVerses.first {
            out.insert(.verse(verse), at: min(4, out.count))
        }
        return out
    }

    @ViewBuilder
    private func card(_ item: Item, showBack: Bool) -> some View {
        switch item {
        case .word(let w):
            VStack(spacing: 10) {
                Text(pointed(w.h)).font(.system(size: 96)).minimumScaleFactor(0.5).lineLimit(1)
                if showBack {
                    Text(tr(w.g)).font(.title2.weight(.medium)).multilineTextAlignment(.center)
                    Text(pronounce(w.h)).font(.callout).foregroundStyle(Theme.neutral500)
                    if w.p != nil || w.f != nil {
                        Text([w.p, w.f].compactMap { $0 }.map(tr).joined(separator: " · "))
                            .font(.caption).foregroundStyle(Theme.neutral500)
                    }
                } else {
                    tapHint
                }
            }
            .padding(24)
        case .verse(let v):
            VStack(alignment: .leading, spacing: 14) {
                Text(ui("VERSE", "经文") + " · " + tr(v.book) + " \(v.c):\(v.v)")
                    .font(.caption2).tracking(1).foregroundStyle(Theme.accent)
                VerseFlow {
                    ForEach(Array(v.words.enumerated()), id: \.offset) { _, word in
                        Text(pointed(word.h)).font(.system(size: 32))
                    }
                }
                if showBack {
                    Text(v.text).font(.body).foregroundStyle(Theme.neutral400)
                    Button { reading = v } label: {
                        Label(ui("Read this verse", "打开经文"), systemImage: "arrow.right")
                    }
                    .buttonStyle(OutlineButtonStyle())
                } else {
                    tapHint.frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    private var tapHint: some View {
        Label(ui("Tap to flip · swipe for next", "点按翻面 · 横滑换卡"), systemImage: "hand.tap")
            .font(.footnote).foregroundStyle(Theme.neutral500).padding(.top, 12)
    }

    private var finished: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("כָּל הַכָּבוֹד").font(.system(size: 44))
            Text(ui("That's the run.", "这一轮完成了。")).font(.title3.weight(.medium))
            Button(ui("Another round", "再来一轮")) {
                items = Self.build(store); index = 0; revealed = false
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    /// Turning the card over reads it; turning it back is silent.
    private func flip() {
        if !revealed, index < items.count {
            switch items[index] {
            case .word(let w): Speech.say(words: w.units.map(\.h))
            case .verse(let v): Speech.say(verse: v, pace: store.pace)
            }
        }
        withAnimation(.easeOut(duration: 0.15)) { revealed.toggle() }
    }
}

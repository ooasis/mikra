import SwiftUI

/// A deck of pointed words as flip cards: Hebrew on the front, tap to turn it over, swipe for
/// the next. Got it marks a card known; the listening test skips known cards. Serves the
/// frequency bands, the curated decks, and a lesson's examples.
struct WordDeckView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let note: String?
    /// Set when the deck is a custom set, so a card can be dropped from it in one tap.
    let setID: String?
    private let cards: [WordCard]
    /// Indices into `cards`, shuffled once when the deck opens and then left alone.
    @State private var order: [Int]
    @State private var index = 0
    @State private var revealed = false
    @State private var namingSet = false
    @State private var newSetName = ""
    /// Listening test: the deck pages along with the spoken word until the last one or a stop.
    @State private var listening = false
    @State private var paused = false
    @State private var playing = 0 // page the test is on, so a swipe elsewhere can be told apart
    @State private var run: Task<Void, Never>?
    @AppStorage("listenGap") private var listenGap = 2.0

    init(title: String, note: String? = nil, cards: [WordCard], shuffle: Bool = true, start: Int = 0,
         revealed: Bool = false, setID: String? = nil) {
        self.title = title
        self.note = note
        self.setID = setID
        self.cards = cards
        _order = State(initialValue: shuffle ? Array(cards.indices).shuffled() : Array(cards.indices))
        _index = State(initialValue: start)
        _revealed = State(initialValue: revealed)
    }

    init(band: WordBand) {
        // The 3ms-perfect convention, explained once when you open a band rather than on 99 cards.
        self.init(title: band.title,
                  note: "Verbs are listed the way every Hebrew dictionary lists them — "
                      + "as \u{201C}he did\u{201D}, glossed \u{201C}to do\u{201D}.",
                  cards: Self.cards(for: band))
    }

    static func cards(for band: WordBand) -> [WordCard] {
        Array(wordDeck[band.start ..< band.start + band.count])
    }

    private var card: WordCard { cards[order[index]] }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $index) {
                ForEach(Array(order.enumerated()), id: \.offset) { i, word in
                    page(cards[word], showBack: revealed && i == index)
                        .environment(\.layoutDirection, .leftToRight) // content stays LTR
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
        }
        .background(Theme.ground)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { actionBar }
        .onChange(of: index) {
            revealed = false
            if listening, index != playing { stopListening() } // you paged: you drive now
        }
        .onDisappear { stopListening() }
        .alert(ui("New set", "新词集"), isPresented: $namingSet) {
            TextField(nextSetName(taken: store.sets.map(\.name)), text: $newSetName)
            Button(ui("Create", "创建")) { store.createSet(named: newSetName, with: card.id) }
            Button(ui("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(ui("Name the set this word starts.", "给这个词开启的新词集起个名字。"))
        }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-reveal") { revealed = true } } // UI smoke-test hook
        #endif
    }

    /// Nothing speaks on its own — a word is only pronounced when you ask for it.
    private func reveal() {
        withAnimation(.easeOut(duration: 0.15)) { revealed = true }
        if !listening { say() } // mid-test, revealing shows the gloss without cutting the run
    }

    private func flip() {
        if revealed { withAnimation(.easeOut(duration: 0.15)) { revealed = false } } else { reveal() }
    }

    private func say() {
        stopListening()
        Speech.say(words: card.units.map(\.h))
    }

    /// One word, a pause, the next — a task the buttons cancel, so stop never waits on the synth.
    private func listen(from start: Int = 0) {
        listening = true
        paused = false
        run = Task { @MainActor in
            for i in start ..< order.count where !store.known.contains(cards[order[i]].id) { // Got it: skipped
                playing = i
                withAnimation { index = i }
                await Speech.say(word: cards[order[i]].units.map(\.h).joined(separator: " "))
                try? await Task.sleep(for: .seconds(listenGap))
                if Task.isCancelled { return }
            }
            listening = false
        }
    }

    private func pauseListening() {
        run?.cancel()
        Speech.stop()
        paused = true
    }

    private func stopListening() {
        guard listening else { return }
        run?.cancel()
        listening = false
        paused = false
        Speech.stop()
    }

    /// Tap to read the whole set aloud with a pause after each word; tap again to pause,
    /// and again to resume. Hold for the pause length and Stop.
    private var listenButton: some View {
        Menu {
            if listening { Button(ui("Stop", "停止"), systemImage: "stop.fill", role: .destructive) { stopListening() } }
            Picker(ui("Pause between words", "词与词之间停顿"), selection: $listenGap) {
                Text(ui("Normal · 2 s", "普通 · 2 秒")).tag(2.0)
                Text(ui("Think · 4 s", "思考 · 4 秒")).tag(4.0)
                Text(ui("Long · 7 s", "长 · 7 秒")).tag(7.0)
            }
        } label: {
            Image(systemName: !listening ? "headphones" : paused ? "play.fill" : "pause.fill")
                .iconChrome(listening ? Theme.accent : Theme.text)
        } primaryAction: {
            if !listening { listen() } else if paused { listen(from: playing) } else { pauseListening() }
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.weight(.medium))
                Spacer()
                Text("\(index + 1) / \(order.count)" + (card.n > 0 ? " · \(card.n)×" : ""))
                    .font(.caption)
                    .foregroundStyle(Theme.neutral500)
            }
            ProgressLine(fraction: Double(index + 1) / Double(max(order.count, 1)))
            if index == 0, let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Theme.neutral500)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    /// The card: a surface that lights its edge when turned over.
    private func page(_ word: WordCard, showBack: Bool) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let forms = word.forms, forms.count > 1 { // one form reads like any plain word
                    // one meaning, every form: the labels (m., f., pl.) are the back of the card
                    VStack(spacing: 10) {
                        ForEach(forms) { f in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(pointed(f.h)).font(.system(size: 56)).minimumScaleFactor(0.5).lineLimit(1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tr(f.g)).font(.subheadline).foregroundStyle(Theme.neutral400)
                                    Text(pronounce(f.h)).font(.caption).foregroundStyle(Theme.neutral500)
                                }
                                .opacity(showBack ? 1 : 0)
                            }
                        }
                    }
                    .padding(.top, 24)
                } else {
                    Text(pointed(word.h))
                        .font(.system(size: 96))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.top, 40)
                }

                if showBack {
                    Text(tr(word.g))
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                    if (word.forms?.count ?? 0) < 2 {
                        Text(pronounce(word.h))
                            .font(.callout)
                            .foregroundStyle(Theme.neutral500)
                    }
                    if word.p != nil || word.f != nil { // "noun · feminine plural", "verb · qal"
                        Text([word.p, word.f].compactMap { $0 }.map(tr).joined(separator: " · "))
                            .font(.caption).foregroundStyle(Theme.neutral500)
                    }

                    if !word.root.isEmpty || !word.conf.isEmpty {
                        seeAlso(word).padding(.top, 8)
                    }
                } else {
                    Label(ui("Tap to flip", "点按翻面"), systemImage: "hand.tap")
                        .font(.footnote)
                        .foregroundStyle(Theme.neutral500)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .cardSurface(lit: showBack)
        .contentShape(.rect)
        .onTapGesture { flip() }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func seeAlso(_ word: WordCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ui("See also", "另见")).font(.caption.weight(.medium)).foregroundStyle(Theme.neutral400)
            ForEach(word.root, id: \.self) { link($0, ui("same root", "同根")) }
            ForEach(word.conf, id: \.self) { link($0, ui("don’t confuse", "别混淆")) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A sibling is read aloud in place: the card you are on stays the card you are on.
    private func link(_ strongs: String, _ why: String) -> some View {
        let w = wordDeck[wordIndexByStrongs[strongs] ?? 0]
        return Button {
            stopListening()
            Speech.say(words: [w.h])
        } label: {
            HStack(spacing: 8) {
                Text(pointed(w.h)).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr(w.g)).font(.subheadline)
                    Text(pronounce(w.h)).font(.caption).foregroundStyle(Theme.neutral500)
                    Text(why).font(.caption2).foregroundStyle(Theme.neutral500)
                }
                Spacer()
                Image(systemName: "speaker.wave.2").font(.caption).foregroundStyle(Theme.neutral500)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider))
        }
        .buttonStyle(.plain)
    }

    /// Drops the card from the set and from this deck; the last card closes the deck.
    private func removeButton(_ setID: String) -> some View {
        Button {
            store.toggle(card.id, in: setID)
            order.remove(at: index)
            guard !order.isEmpty else { return dismiss() }
            index = min(index, order.count - 1)
            revealed = false
        } label: {
            Image(systemName: "bookmark.slash")
        }
        .buttonStyle(IconButtonStyle(tint: Theme.accent300))
    }

    /// Tick a set to put the word in it, tick again to take it out; the last item starts a new set.
    private var setMenu: some View {
        let inSets = store.sets.filter { $0.ids.contains(card.id) }
        return Menu {
            ForEach(store.sets) { set in
                Button {
                    store.toggle(card.id, in: set.id)
                } label: {
                    Label(set.name, systemImage: set.ids.contains(card.id) ? "checkmark" : "")
                }
            }
            if !store.sets.isEmpty { Divider() }
            Button {
                newSetName = ""
                namingSet = true
            } label: {
                Label(ui("New set…", "新词集…"), systemImage: "plus")
            }
        } label: {
            Image(systemName: inSets.isEmpty ? "bookmark" : "bookmark.fill")
                .iconChrome(inSets.isEmpty ? Theme.text : Theme.accent)
        }
        .buttonStyle(.plain)
    }

    /// Thumb-reachable: the tools on the left, Got it on the right.
    private var actionBar: some View {
        let known = store.known.contains(card.id)
        return HStack(spacing: 8) {
            Button { say() } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(ui("Play", "朗读"))

            if let setID {
                listenButton
                removeButton(setID)
            } else if !card.s.isEmpty { // a lesson phrase has no card to collect
                setMenu
            }

            Spacer()

            if !card.s.isEmpty {
                Button { store.toggleKnown(card.id) } label: {
                    Image(systemName: known ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .buttonStyle(IconButtonStyle(tint: known ? Theme.accent : Theme.text))
                .accessibilityLabel(ui("Got it", "记住了"))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.bg)
    }
}

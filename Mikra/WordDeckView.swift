import SwiftUI

/// A deck of pointed words: one per page, tap to reveal the gloss. Serves the
/// frequency bands, the curated decks, and a lesson's examples.
struct WordDeckView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let note: String?
    /// Set when the deck is a custom set, so a card can be dropped from it in one tap.
    let setID: String?
    private let cards: [WordCard]
    /// Indices into `cards`, shuffled once when the deck opens and then left alone,
    /// so paging back and forth keeps the same order until you close it.
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
                ForEach(Array(order.enumerated()), id: \.element) { i, word in
                    page(cards[word], showBack: revealed && i == index)
                        .environment(\.layoutDirection, .leftToRight) // content stays LTR
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
        }
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { actionBar }
        .onChange(of: index) {
            revealed = false
            if listening, index != playing { stopListening() } // you paged: you drive now
        }
        .onDisappear { stopListening() }
        .alert("New set", isPresented: $namingSet) {
            TextField(nextSetName(taken: store.sets.map(\.name)), text: $newSetName)
            Button("Create") { store.createSet(named: newSetName, with: card.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name the set this word starts.")
        }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-reveal") { revealed = true } } // UI smoke-test hook
        #endif
    }

    /// Nothing speaks on its own — a word is only pronounced when you ask for it.
    private func reveal() {
        revealed = true
        if !listening { say() } // mid-test, revealing shows the gloss without cutting the run
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
            for i in start ..< order.count {
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
            if listening { Button("Stop", systemImage: "stop.fill", role: .destructive) { stopListening() } }
            Picker("Pause between words", selection: $listenGap) {
                Text("Normal · 2 s").tag(2.0)
                Text("Think · 4 s").tag(4.0)
                Text("Long · 7 s").tag(7.0)
            }
        } label: {
            Image(systemName: !listening ? "headphones" : paused ? "play.fill" : "pause.fill")
                .font(.headline)
                .foregroundStyle(listening ? Color.orange : Color.primary)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground), in: Capsule())
        } primaryAction: {
            if !listening { listen() } else if paused { listen(from: playing) } else { pauseListening() }
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(index + 1) of \(order.count)" + (card.n > 0 ? " · \(card.n)×" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if index == 0, let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private func page(_ word: WordCard, showBack: Bool) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let forms = word.forms, forms.count > 1 { // one form reads like any plain word
                    // one meaning, every form: the labels (m., f., pl.) are the back of the card
                    VStack(spacing: 10) {
                        ForEach(forms) { f in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(pointed(f.h)).font(.system(size: 60)).minimumScaleFactor(0.5).lineLimit(1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tr(f.g)).font(.subheadline).foregroundStyle(.secondary)
                                    Text(pronounce(f.h)).font(.caption).foregroundStyle(.tertiary)
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
                        .padding(.top, 32)
                }

                if showBack {
                    Text(tr(word.g))
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                    if (word.forms?.count ?? 0) < 2 {
                        Text(pronounce(word.h))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if let p = word.p {
                        Text(tr(p)).font(.caption).foregroundStyle(.tertiary)
                    }

                    if !word.root.isEmpty || !word.conf.isEmpty {
                        seeAlso(word).padding(.top, 8)
                    }
                } else {
                    Text("Tap to reveal")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .contentShape(.rect)
            .onTapGesture { reveal() }
        }
    }

    private func seeAlso(_ word: WordCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("See also").font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(word.root, id: \.self) { link($0, "same root") }
            ForEach(word.conf, id: \.self) { link($0, "don’t confuse") }
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
                    Text(pronounce(w.h)).font(.caption).foregroundStyle(.secondary)
                    Text(why).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "speaker.wave.2").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
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
                .font(.headline)
                .foregroundStyle(.red)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
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
                Label("New set…", systemImage: "plus")
            }
        } label: {
            Image(systemName: inSets.isEmpty ? "bookmark" : "bookmark.fill")
                .font(.headline)
                .foregroundStyle(inSets.isEmpty ? Color.primary : Color.orange)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Thumb-reachable, like the flash cards' replay bar — the card sits too high to tap one-handed.
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                say()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)

            if let setID {
                listenButton
                removeButton(setID)
            } else if !card.s.isEmpty { // a lesson phrase has no card to collect
                setMenu
            }

            if revealed {
                Spacer()
            } else {
                Button {
                    reveal()
                } label: {
                    Text("Reveal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

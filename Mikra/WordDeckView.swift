import SwiftUI

/// A deck of pointed words: one per page, tap to reveal the gloss. Serves the
/// frequency bands, the curated decks, and a lesson's examples.
/// Browse-only — nothing is scheduled unless you tap "Learn this".
struct WordDeckView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let note: String?
    /// Set when the deck is a custom set, so a card can be dropped from it in one tap.
    let setID: String?
    /// "See also" links can pull a sibling in from the frequency deck, so this grows.
    @State private var cards: [WordCard]
    /// Indices into `cards`, shuffled once when the deck opens and then left alone,
    /// so paging back and forth keeps the same order until you close it.
    @State private var order: [Int]
    @State private var index = 0
    @State private var revealed = false
    @State private var namingSet = false
    @State private var newSetName = ""

    init(title: String, note: String? = nil, cards: [WordCard], shuffle: Bool = true, start: Int = 0,
         revealed: Bool = false, setID: String? = nil) {
        self.title = title
        self.note = note
        self.setID = setID
        _cards = State(initialValue: cards)
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
        .onChange(of: index) { revealed = false }
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
        say()
    }

    private func say() { Speech.say(words: card.units.map(\.h)) }

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
                if let forms = word.forms {
                    // one meaning, every form: the labels (m., f., pl.) are the back of the card
                    VStack(spacing: 10) {
                        ForEach(forms) { f in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(pointed(f.h)).font(.system(size: 60)).minimumScaleFactor(0.5).lineLimit(1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(f.g).font(.subheadline).foregroundStyle(.secondary)
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
                    Text(word.g)
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                    if word.forms == nil {
                        Text(pronounce(word.h))
                            .font(.callout)
                            .foregroundStyle(.secondary)
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

    /// Siblings usually live in another band — jumping is how you follow a root family.
    private func link(_ strongs: String, _ why: String) -> some View {
        Button {
            guard let source = wordIndexByStrongs[strongs] else { return }
            // a sibling usually lives in another band; append it rather than
            // reshuffling, so everything you already paged through keeps its place
            if !cards.contains(where: { $0.s == strongs }) {
                cards.append(wordDeck[source])
                order.append(cards.count - 1)
            }
            withAnimation {
                index = order.firstIndex { cards[$0].s == strongs } ?? index
                revealed = true // the gloss was on the link you just tapped
            }
        } label: {
            HStack(spacing: 8) {
                Text(pointed(wordDeck[wordIndexByStrongs[strongs] ?? 0].h)).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 1) {
                    Text(wordDeck[wordIndexByStrongs[strongs] ?? 0].g).font(.subheadline)
                    Text(why).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
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
                removeButton(setID)
            } else if !card.s.isEmpty { // a lesson phrase has no card to collect
                setMenu
            }

            if revealed, card.s.isEmpty {
                // a lesson example is a phrase, not a dictionary word — nothing to enrol
                Spacer()
            } else if revealed {
                let enrolled = card.units.allSatisfy { store.tapped.contains($0.id) }
                Button {
                    card.units.forEach { store.enroll($0.id) }
                } label: {
                    Label(enrolled ? "Learning" : "Learn this",
                          systemImage: enrolled ? "checkmark" : "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(enrolled ? Color.green : Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(enrolled)
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

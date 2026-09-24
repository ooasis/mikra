import SwiftUI

/// The frequency deck: one pointed word per page, tap to reveal the gloss.
/// Browse-only — nothing is scheduled unless you tap "Learn this".
struct WordDeckView: View {
    @EnvironmentObject var store: Store
    @State var index: Int
    @State private var revealed = false

    private var card: WordCard { wordDeck[index] }
    private var band: WordBand {
        wordBands.last { index >= $0.start } ?? wordBands[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $index) {
                ForEach(Array(wordDeck.enumerated()), id: \.element.s) { i, word in
                    page(word, showBack: revealed && i == index)
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
    }

    /// Nothing speaks on its own — a word is only pronounced when you ask for it.
    private func reveal() {
        revealed = true
        Speech.say(card.h)
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Text(band.title).font(.headline)
                Spacer()
                Text("#\(index + 1) of \(wordDeck.count) · \(card.n)×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // The 3ms-perfect convention, explained once when you open a deck rather than on 99 cards.
            if index == band.start {
                Text("Verbs are listed the way every Hebrew dictionary lists them — "
                     + "as \u{201C}he did\u{201D}, glossed \u{201C}to do\u{201D}.")
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
                Text(word.h)
                    .font(.system(size: 64))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.top, 32)

                if showBack {
                    Text(word.g)
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)

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
            guard let target = wordIndexByStrongs[strongs] else { return }
            withAnimation {
                index = target
                revealed = true // the gloss was on the link you just tapped
            }
        } label: {
            HStack(spacing: 8) {
                Text(wordDeck[wordIndexByStrongs[strongs] ?? 0].h).font(.title3)
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

    /// Thumb-reachable, like the flash cards' replay bar — the card sits too high to tap one-handed.
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                Speech.say(card.h)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)

            if revealed {
                let enrolled = store.tapped.contains(card.id)
                Button {
                    store.enroll(card.id)
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

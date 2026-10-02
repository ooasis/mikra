import SwiftUI

// The dashboard's sub-screens: each lists one kind of knowledge and opens its leaf view.

/// The letter or vowel tiles; a tile opens the flash cards.
struct LetterGridView: View {
    let kind: Kind
    @State private var selected: LetterGroup?

    private var groups: [LetterGroup] { kind == .vowel ? vowelGroups : letterGroups }
    private var allGroups: [LetterGroup] { letterGroups + vowelGroups }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: kind == .vowel ? 4 : 3),
                      spacing: 10) {
                ForEach(groups) { group in
                    Button {
                        selected = group
                    } label: {
                        VStack(spacing: 2) {
                            Text(group.cards.map(\.displayGlyph).joined(separator: " "))
                                .font(.system(size: kind == .vowel ? 48 : 30))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(group.cards.map(\.name).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(group.cards.map { $0.sound.components(separatedBy: " (")[0] }
                                    .joined(separator: " · "))
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .environment(\.layoutDirection, .rightToLeft) // rows flow right-to-left, like Hebrew
        }
        .navigationTitle(kind == .vowel ? "Vowels" : "Letters")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { group in
            FlashCardView(groups: allGroups, index: allGroups.firstIndex { $0.id == group.id } ?? 0)
        }
        #if DEBUG
        .onAppear { // UI smoke-test hook
            guard kind == .vowel, ProcessInfo.processInfo.arguments.contains("-openVowel") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selected = vowelGroups[0] }
        }
        #endif
    }
}

let vowelGroups: [LetterGroup] = curriculum.filter { $0.kind == .vowel }
    .map { LetterGroup(id: $0.id, cards: [$0]) }

/// A curated deck (Pronouns, Numbers) as tiles, like the alphabet; a tile opens the deck at that word.
struct DeckGridView: View {
    let deck: Deck
    @State private var start: Start?

    struct Start: Identifiable { let i: Int; var id: Int { i } }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(Array(deck.cards.enumerated()), id: \.element.id) { i, card in
                    Button {
                        start = Start(i: i)
                    } label: {
                        VStack(spacing: 2) {
                            Text(pointed(card.h))
                                .font(.system(size: 40))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(tr(card.g))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            // the other forms, like a letter tile's dagesh/final variants
                            Text(pointed(card.units.dropFirst().map(\.h).joined(separator: " · ")))
                                .font(.system(size: 18))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .environment(\.layoutDirection, .rightToLeft) // rows flow right-to-left, like Hebrew
            Text(deck.note)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $start) { s in
            WordDeckView(title: deck.title, cards: deck.cards, shuffle: false, start: s.i)
        }
        #if DEBUG
        .onAppear { // UI smoke-test hook
            let args = ProcessInfo.processInfo.arguments
            guard args.contains("-openDeck"), !args.contains("-grid") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start = Start(i: 2) }
        }
        #endif
    }
}

/// A custom set as a list: a row opens the deck at that word, the shuffle button opens it
/// reshuffled; swipe to prune, and the menu renames or deletes.
struct WordSetView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let setID: String
    @State private var start: DeckGridView.Start? // -1 opens the deck shuffled
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false

    private var wordSet: WordSet? { store.sets.first { $0.id == setID } }
    private var cards: [WordCard] { wordSet?.ids.compactMap { wordCardByID[$0] } ?? [] }

    var body: some View {
        List {
            if cards.isEmpty {
                Text("No words yet — tap the bookmark on any word card to add one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                Button {
                    start = DeckGridView.Start(i: i)
                } label: {
                    HStack {
                        Text(tr(card.g)).foregroundStyle(.secondary)
                        Spacer()
                        Text(pointed(card.h)).font(.system(size: 40))
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { cards[$0].id }.forEach { store.toggle($0, in: setID) }
            }
        }
        .navigationTitle(wordSet?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                start = DeckGridView.Start(i: -1)
            } label: {
                Image(systemName: "shuffle")
            }
            .disabled(cards.isEmpty)
            Menu {
                Button {
                    newName = wordSet?.name ?? ""
                    renaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete set", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .alert("Rename set", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") { store.renameSet(setID, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this set? The words stay in their decks.",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete set", role: .destructive) {
                store.deleteSet(setID)
                dismiss()
            }
        }
        .sheet(item: $start) { s in
            WordDeckView(title: wordSet?.name ?? "", cards: cards, shuffle: s.i < 0, start: max(s.i, 0), setID: setID)
        }
    }
}

/// The frequency deck's bands; a band opens its deck.
struct BandsView: View {
    @State private var openBand: WordBand?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(wordBands) { band in
                    Button {
                        openBand = band
                    } label: {
                        VStack(spacing: 3) {
                            Text(pointed(wordDeck[band.start].h))
                                .font(.system(size: 38))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(band.title).font(.caption2.bold())
                            Text("\(band.floor)+ times")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Commonest in the Bible")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openBand) { band in
            WordDeckView(band: band)
        }
        #if DEBUG
        .onAppear { // UI smoke-test hook
            guard ProcessInfo.processInfo.arguments.contains("-openWords") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { openBand = wordBands[0] }
        }
        #endif
    }
}

/// One grammar group's lessons.
struct LessonListView: View {
    let group: GrammarGroup

    var body: some View {
        List(lessons(in: group)) { lesson in
            NavigationLink(value: Route.lesson(lesson.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr(lesson.title))
                    Text(tr(lesson.why)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A lesson page: the rule, then its examples, each spoken on tap; Practice opens them as a deck.
struct LessonView: View {
    let lesson: Lesson
    @State private var practising = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(pointed(ltr(tr(lesson.why))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(lesson.body, id: \.self) { paragraph in
                    Text(pointed(ltr(tr(paragraph))))
                }
                ForEach(lesson.tables ?? [], id: \.self) { table in
                    lessonTable(table)
                }
                Text("Examples").font(.headline).padding(.top, 8)
                ForEach(lesson.examples, id: \.self) { e in
                    Button {
                        Speech.say(e.h)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(pointed(e.h))
                                .font(.system(size: 38))
                                .frame(minWidth: 130, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ltr(tr(e.g))).font(.subheadline)
                                if let ref = e.ref {
                                    Text(ref).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "speaker.wave.2")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(tr(lesson.title))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                practising = true
            } label: {
                Text("Practice")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .sheet(isPresented: $practising) {
            WordDeckView(title: tr(lesson.title), cards: lesson.examples.map(\.card), shuffle: false)
        }
    }

    /// A paragraph that opens with a Hebrew word would otherwise lay out right-to-left
    /// and scramble the English around it; a leading left-to-right mark pins the direction.
    private func ltr(_ text: String) -> String { "\u{200E}" + text }

    private func lessonTable(_ table: LessonTable) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(table.title)).font(.subheadline.bold())
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    ForEach(table.columns, id: \.self) { col in
                        Text(tr(col)).font(.caption.bold()).foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(table.rows, id: \.self) { row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { i, cell in
                            if cell.unicodeScalars.contains(where: { (0x05D0...0x05EA).contains($0.value) }) {
                                Text(pointed(ltr(cell))).font(.system(size: 28)).lineSpacing(2)
                            } else {
                                Text(tr(cell)).font(.subheadline)
                                    .foregroundStyle(i == 0 ? .secondary : .primary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 4)
    }
}

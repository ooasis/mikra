import SwiftUI

// The dashboard's sub-screens: each lists one kind of knowledge and opens its leaf view.

/// The letter or vowel tiles, coloured by drill progress; a tile opens the flash cards.
struct LetterGridView: View {
    @EnvironmentObject var store: Store
    let kind: Kind
    @State private var selected: LetterGroup?

    private var groups: [LetterGroup] { kind == .vowel ? vowelGroups : letterGroups }
    private var allGroups: [LetterGroup] { letterGroups + vowelGroups }
    private var cards: [Card] { curriculum.filter { $0.kind == kind } }

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
                        .background(tileColor(group), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .environment(\.layoutDirection, .rightToLeft) // rows flow right-to-left, like Hebrew
        }
        .navigationTitle("\(kind == .vowel ? "Vowels" : "Letters") — \(learned)/\(cards.count)")
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

    private var learned: Int {
        cards.filter { (store.states[$0.id]?.intervalDays ?? 0) >= 1 }.count
    }

    private func tileColor(_ group: LetterGroup) -> Color {
        let states = group.cards.map { store.states[$0.id] }
        if states.allSatisfy({ ($0?.intervalDays ?? 0) >= 1 }) { return .green.opacity(0.2) }
        if states.contains(where: { $0 != nil }) { return .blue.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }
}

let vowelGroups: [LetterGroup] = curriculum.filter { $0.kind == .vowel }
    .map { LetterGroup(id: $0.id, cards: [$0]) }

/// A curated deck (Pronouns, Numbers) as tiles, like the alphabet; a tile opens the deck at that word.
struct DeckGridView: View {
    @EnvironmentObject var store: Store
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
                            Text(card.h)
                                .font(.system(size: 30))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(card.g)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            // the other forms, like a letter tile's dagesh/final variants
                            Text(card.units.dropFirst().map(\.h).joined(separator: " · "))
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(card.units.allSatisfy { store.tapped.contains($0.id) }
                                        ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
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
            guard ProcessInfo.processInfo.arguments.contains("-openDeck") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start = Start(i: 2) }
        }
        #endif
    }
}

/// The frequency deck's bands; a band opens its deck.
struct BandsView: View {
    @EnvironmentObject var store: Store
    @State private var openBand: WordBand?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(wordBands) { band in
                    Button {
                        openBand = band
                    } label: {
                        VStack(spacing: 3) {
                            Text(wordDeck[band.start].h)
                                .font(.system(size: 28))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(band.title).font(.caption2.bold())
                            Text("\(band.floor)+ times")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(learningIn(band)) learning")
                                .font(.caption2).foregroundStyle(.tertiary)
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

    private func learningIn(_ band: WordBand) -> Int {
        wordDeck[band.start ..< band.start + band.count]
            .filter { store.tapped.contains($0.id) }.count
    }
}

/// One grammar group's lessons.
struct LessonListView: View {
    let group: GrammarGroup

    var body: some View {
        List(lessons(in: group)) { lesson in
            NavigationLink(value: Route.lesson(lesson.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                    Text(lesson.why).font(.caption).foregroundStyle(.secondary)
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
                Text(ltr(lesson.why))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(lesson.body, id: \.self) { paragraph in
                    Text(ltr(paragraph))
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
                            Text(e.h)
                                .font(.system(size: 26))
                                .frame(minWidth: 96, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ltr(e.g)).font(.subheadline)
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
        .navigationTitle(lesson.title)
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
            WordDeckView(title: lesson.title, cards: lesson.examples.map(\.card), shuffle: false)
        }
    }

    /// A paragraph that opens with a Hebrew word would otherwise lay out right-to-left
    /// and scramble the English around it; a leading left-to-right mark pins the direction.
    private func ltr(_ text: String) -> String { "\u{200E}" + text }

    private func lessonTable(_ table: LessonTable) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(table.title).font(.subheadline.bold())
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    ForEach(table.columns, id: \.self) { col in
                        Text(col).font(.caption.bold()).foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(table.rows, id: \.self) { row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { i, cell in
                            if cell.unicodeScalars.contains(where: { (0x05D0...0x05EA).contains($0.value) }) {
                                Text(ltr(cell)).font(.system(size: 20)).lineSpacing(2)
                            } else {
                                Text(cell).font(.subheadline)
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

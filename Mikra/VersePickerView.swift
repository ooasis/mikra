import SwiftUI

/// Pick any verse from a book; the verse opens in the reader over this screen.
struct VersePickerView: View {
    @EnvironmentObject var store: Store
    let book: String
    @State private var open: Pick?

    struct Pick: Identifiable {
        let verse: Verse
        let mode: VerseMode
        var id: String { verse.id }
    }

    private var verses: [Verse] { Mikra.book(named: book).verses }
    /// The verses by chapter, in order; one grid per chapter.
    private var chapters: [(c: Int, verses: [Verse])] {
        Dictionary(grouping: verses, by: \.c).sorted { $0.key < $1.key }.map { (c: $0.key, verses: $0.value) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if chapters.count > 10 { // chapter links above the verses; tap one to jump to its section
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                            ForEach(chapters, id: \.c) { chapter in
                                Button("\(chapter.c)") { proxy.scrollTo(chapter.c, anchor: .top) }
                                    .font(.caption2.monospacedDigit())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    ForEach(chapters, id: \.c) { chapter in
                        if chapters.count > 1 {
                            Text("Chapter \(chapter.c)").font(.subheadline.bold()).padding(.top, 10)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                                  spacing: 6) {
                            ForEach(chapter.verses) { verse in
                                Button {
                                    open = Pick(verse: verse, mode: .passive)
                                } label: {
                                    Text("\(verse.c):\(verse.v)")
                                        .font(.caption.monospacedDigit())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(tint(verse), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .id(chapter.c)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear { store.openedBook(book) }
        .padding(.top, 2)
        .navigationTitle(Mikra.book(named: book).heb)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $open) { p in
            VerseView(verse: p.verse, mode: p.mode)
        }
        #if DEBUG
        .onAppear { // UI smoke-test hooks: -openVerse / -openWave open the book's first verse
            let args = ProcessInfo.processInfo.arguments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if args.contains("-openVerse") {
                    open = Pick(verse: verses[0], mode: .passive)
                } else if args.contains("-openWave") {
                    open = Pick(verse: verses[0], mode: .wave)
                }
            }
        }
        #endif
    }

    private func tint(_ verse: Verse) -> Color {
        let p = store.verses[verse.id]
        if p?.wave != nil { return .green.opacity(0.35) }
        if p?.passive != nil { return .blue.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }
}

/// The everyday-phrase sets, one row each, like the book list.
struct PhraseListView: View {
    var body: some View {
        List(phraseSets) { set in
            NavigationLink(value: Route.phrases(set.c)) {
                HStack {
                    Text(set.title)
                    Spacer()
                    Text(pointed(set.heb)).font(.title3)
                }
            }
        }
        .navigationTitle(book(named: phraseBook).heb)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The phrases of one everyday set, one row each; a row opens the phrase in the reader,
/// which then pages through the set.
struct PhraseSetView: View {
    @EnvironmentObject var store: Store
    let set: PhraseSet
    @State private var open: Verse?

    var body: some View {
        List(set.verses) { verse in
            Button { open = verse } label: {
                HStack {
                    Text(verse.text).font(.subheadline).foregroundStyle(Theme.neutral400)
                    Spacer()
                    Text(pointed(verse.hebrew)).font(.title2).multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(store.verses[verse.id] != nil ? Color.blue.opacity(0.12) : nil)
        }
        .listStyle(.plain)
        .navigationTitle(set.heb)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $open) { v in
            VerseView(verse: v, mode: .passive)
        }
    }
}

/// Every book of the Tanakh by part; the home screen shows only the course books.
struct BookListView: View {
    var body: some View {
        List {
            ForEach(["Torah", "Prophets", "Writings"], id: \.self) { part in
                Section(part) {
                    ForEach(books.filter { $0.part == part }) { b in
                        NavigationLink(value: Route.book(b.name)) {
                            HStack {
                                Text(b.name)
                                Spacer()
                                Text(pointed(b.heb)).font(.title3)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("תנ״ך")
        .navigationBarTitleDisplayMode(.inline)
    }
}

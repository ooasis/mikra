import SwiftUI

/// Where a dashboard tile leads. Ids rather than values keep routes trivially Hashable.
enum Route: Hashable {
    case letters, vowels, bands
    case deck(String)
    case set(String)
    case book(String)
    case group(String)
    case lesson(String)
    case settings, scan
}

/// The dashboard: three sections of tiles, each leading to one piece of knowledge.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var pick: WordCard?
    @FocusState private var focused: Bool

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("מִקְרָא").font(.largeTitle.bold())
                        Spacer()
                        NavigationLink(value: Route.settings) {
                            Image(systemName: "gearshape").font(.title3).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    TextField(Zh.on ? "搜索词义（中文或英文）" : "Search words in English or 中文", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .overlay(alignment: .trailing) {
                            if !query.isEmpty {
                                Button { query = ""; focused = false } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .padding(.trailing, 6)
                            }
                        }
                        .focused($focused)
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        results
                    } else {
                        section("Words") {
                            NavigationLink(value: Route.letters) { tile("א", "Alphabet") }
                            NavigationLink(value: Route.vowels) { tile("בָּ", "Vowels") }
                            ForEach(decks) { d in
                                NavigationLink(value: Route.deck(d.id)) { tile(d.cards[0].h, d.title) }
                            }
                            NavigationLink(value: Route.bands) { tile("דָּבָר", "Common words") }
                            NavigationLink(value: Route.scan) { tile("📷", "Scan notes") }
                            ForEach(store.sets) { set in
                                // your own sets follow the built-in decks: tap for the word list,
                                // which starts the flash cards from a word or shuffled
                                NavigationLink(value: Route.set(set.id)) {
                                    tile(set.ids.first.flatMap { wordCardByID[$0]?.h } ?? "＋", set.name,
                                         custom: true)
                                }
                            }
                        }
                        section("Verses") {
                            ForEach(books) { b in
                                NavigationLink(value: Route.book(b.name)) { tile(b.heb, b.name) }
                            }
                        }
                        section("Grammar") {
                            ForEach(grammarGroups) { g in
                                NavigationLink(value: Route.group(g.id)) { tile(g.glyph, g.title) }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .toolbar(.hidden, for: .navigationBar) // the Hebrew title above is the header
            .sheet(item: $pick) { w in
                WordDeckView(title: tr(w.g), cards: [w], shuffle: false, revealed: true)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .letters: LetterGridView(kind: .letter)
                case .vowels: LetterGridView(kind: .vowel)
                case .bands: BandsView()
                case .deck(let id): DeckGridView(deck: deck(id))
                case .set(let id): WordSetView(setID: id)
                case .book(let name): VersePickerView(book: name)
                case .group(let id): LessonListView(group: grammarGroups.first { $0.id == id }!)
                case .lesson(let id): LessonView(lesson: lessonsByID[id]!)
                case .settings: SettingsView()
                case .scan: ScanView()
                }
            }
        }
        #if DEBUG
        .onAppear { // UI smoke-test hooks push the sub-screen; the sub-screen opens its leaf
            let args = ProcessInfo.processInfo.arguments
            if let q = args.first(where: { $0.hasPrefix("-search=") }) { query = String(q.dropFirst(8)) }
            // delay: navigating during the first onAppear races the cold launch and silently no-ops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let bookName = args.contains("-genesis") ? "Genesis" : books[0].name
                if args.contains("-openHit") {
                    pick = searchWords(query).first
                } else if args.contains("-openPicker") || args.contains("-openVerse") || args.contains("-openWave") {
                    path.append(Route.book(bookName))
                } else if args.contains("-openWords") {
                    path.append(Route.bands)
                } else if args.contains("-openVowel") {
                    path.append(Route.vowels)
                } else if args.contains("-openDeck") {
                    path.append(Route.deck(decks[0].id))
                } else if args.contains("-openSet"), let set = store.sets.first {
                    path.append(Route.set(set.id))
                } else if args.contains(where: { $0.hasPrefix("-scan") }) {
                    path.append(Route.scan)
                } else if args.contains("-openSettings") {
                    path.append(Route.settings)
                } else if args.contains("-openLesson") {
                    path.append(Route.lesson(args.contains("-stems") ? "stems" : "prep-suffixes"))
                }
            }
        }
        #endif
    }

    /// One dictionary line per hit; tapping opens the card with the gloss already shown.
    private var results: some View {
        let hits = searchWords(query)
        return VStack(spacing: 0) {
            if hits.isEmpty {
                Text("No words match").foregroundStyle(.secondary).padding()
            }
            ForEach(hits) { w in
                Button { pick = w } label: {
                    HStack {
                        Text(tr(w.g)).foregroundStyle(.secondary)
                        Spacer()
                        Text(pointed(w.h)).font(.system(size: 48))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading)
            }
        }
    }

    private func section<Tiles: View>(_ title: String, @ViewBuilder tiles: () -> Tiles) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 10, content: tiles)
                .buttonStyle(.plain) // links and buttons alike: no accent tint on the tiles
                .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }

    /// A custom set's tile takes a faint warm tint, so your own sets read apart from the built-in ones.
    private func tile(_ glyph: String, _ label: String, custom: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(pointed(glyph))
                .font(.system(size: 40))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(custom ? Color.orange.opacity(0.08) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }
}

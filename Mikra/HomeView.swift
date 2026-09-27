import SwiftUI

/// Where a dashboard tile leads. Ids rather than values keep routes trivially Hashable.
enum Route: Hashable {
    case letters, vowels, bands
    case deck(String)
    case book(String)
    case group(String)
    case lesson(String)
    case settings
}

/// The dashboard: three sections of tiles, each leading to one piece of knowledge.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var path = NavigationPath()

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
                    .padding(.bottom, 16)

                    section("Words") {
                        NavigationLink(value: Route.letters) { tile("א", "Alphabet") }
                        NavigationLink(value: Route.vowels) { tile("בָּ", "Vowels") }
                        ForEach(decks) { d in
                            NavigationLink(value: Route.deck(d.id)) { tile(d.cards[0].h, d.title) }
                        }
                        NavigationLink(value: Route.bands) { tile("דָּבָר", "Common words") }
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
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar) // the Hebrew title above is the header
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .letters: LetterGridView(kind: .letter)
                case .vowels: LetterGridView(kind: .vowel)
                case .bands: BandsView()
                case .deck(let id): DeckGridView(deck: deck(id))
                case .book(let name): VersePickerView(book: name)
                case .group(let id): LessonListView(group: grammarGroups.first { $0.id == id }!)
                case .lesson(let id): LessonView(lesson: lessonsByID[id]!)
                case .settings: SettingsView()
                }
            }
        }
        #if DEBUG
        .onAppear { // UI smoke-test hooks push the sub-screen; the sub-screen opens its leaf
            let args = ProcessInfo.processInfo.arguments
            // delay: navigating during the first onAppear races the cold launch and silently no-ops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let bookName = args.contains("-genesis") ? "Genesis" : books[0].name
                if args.contains("-openPicker") || args.contains("-openVerse") || args.contains("-openWave") {
                    path.append(Route.book(bookName))
                } else if args.contains("-openWords") {
                    path.append(Route.bands)
                } else if args.contains("-openVowel") {
                    path.append(Route.vowels)
                } else if args.contains("-openDeck") {
                    path.append(Route.deck(decks[0].id))
                } else if args.contains("-openSettings") {
                    path.append(Route.settings)
                } else if args.contains("-openLesson") {
                    path.append(Route.lesson(args.contains("-stems") ? "stems" : "prep-suffixes"))
                }
            }
        }
        #endif
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

    private func tile(_ glyph: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(glyph)
                .font(.system(size: 30))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

import SwiftUI

/// Where a dashboard tile leads. Ids rather than values keep routes trivially Hashable.
enum Route: Hashable {
    case letters, vowels, bands
    case deck(String)
    case set(String)
    case books
    case book(String)
    case phraseSets, phrases(Int)
    case group(String)
    case lesson(String)
    case settings, scan
    case practice
}

/// The dashboard: Practice now, then three sections of tiles, each leading to one piece of knowledge.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var pick: WordCard?
    @FocusState private var focused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("מִקְרָא").font(.system(size: 36, weight: .medium))
                        Spacer()
                        NavigationLink(value: Route.settings) {
                            Image(systemName: "gearshape").font(.body)
                                .foregroundStyle(Theme.neutral400)
                                .frame(width: 36, height: 36)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider))
                        }
                        .accessibilityLabel(ui("Settings", "设置"))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    searchField
                        .padding(.horizontal)
                        .padding(.bottom, 14)

                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        results
                    } else {
                        practiceButton
                            .padding(.horizontal)
                            .padding(.bottom, 18)

                        section(ui("Words", "词汇")) {
                            // the one tile that is a tool rather than a thing to learn: outlined, no fill
                            NavigationLink(value: Route.scan) { tile(nil, ui("Scan notes", "扫描笔记"), icon: "camera") }
                            NavigationLink(value: Route.letters) { tile("א", ui("Alphabet", "字母")) }
                            NavigationLink(value: Route.vowels) { tile("בָּ", ui("Vowels", "元音")) }
                            ForEach(decks) { d in
                                NavigationLink(value: Route.deck(d.id)) { tile(d.cards[0].h, tr(d.title)) }
                            }
                            NavigationLink(value: Route.bands) { tile("דָּבָר", ui("Common words", "常用词")) }
                            // your own sets sit with the built-in decks, set apart by a tinted surface
                            ForEach(store.sets) { set in
                                NavigationLink(value: Route.set(set.id)) {
                                    tile(set.ids.first.flatMap { wordCardByID[$0]?.h } ?? "＋", set.name,
                                         mine: "bookmark.fill")
                                }
                            }
                        }
                        section(ui("Verses", "经文")) {
                            NavigationLink(value: Route.books) { tile("תנ״ך", ui("Old Testament", "旧约")) }
                            NavigationLink(value: Route.phraseSets) { tile("עִבְרִית", tr(phraseBook)) }
                            ForEach(store.recentBooks.map { book(named: $0) }) { b in // recently opened: comes and goes
                                NavigationLink(value: Route.book(b.name)) { tile(b.heb, tr(b.name), mine: "clock") }
                            }
                        }
                        section(ui("Grammar", "语法")) {
                            ForEach(grammarGroups) { g in
                                NavigationLink(value: Route.group(g.id)) { tile(g.glyph, tr(g.title)) }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar) // the Hebrew title above is the header
            .sheet(item: $pick) { w in
                WordDeckView(title: tr(w.g), cards: [w], shuffle: false, revealed: true)
            }
            .navigationDestination(for: Route.self) { route in
                destination(route)
                    .crumbs(trail(route), home: { path = NavigationPath() })
                    .toolbarBackground(Theme.bg, for: .navigationBar)
            }
        }
        #if DEBUG
        .onAppear { // UI smoke-test hooks push the sub-screen; the sub-screen opens its leaf
            let args = ProcessInfo.processInfo.arguments
            if let q = args.first(where: { $0.hasPrefix("-search=") }) { query = String(q.dropFirst(8)) }
            // delay: navigating during the first onAppear races the cold launch and silently no-ops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let bookName = args.first { $0.hasPrefix("-book=") }.map { String($0.dropFirst(6)) }
                    ?? (args.contains("-genesis") ? "Genesis" : "Jonah")
                if args.contains("-openHit") {
                    pick = searchWords(query).first
                } else if args.contains("-openPicker") || args.contains("-openVerse") || args.contains("-openWave") {
                    path.append(Route.book(bookName))
                } else if args.contains("-openPhrases") {
                    path.append(Route.phraseSets)
                    path.append(Route.phrases(phraseSets[0].c))
                } else if args.contains("-openBooks") {
                    path.append(Route.books)
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
                } else if args.contains("-openPractice") {
                    path.append(Route.practice)
                } else if args.contains("-openLesson") {
                    path.append(Route.lesson(args.contains("-stems") ? "stems" : "prep-suffixes"))
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .letters: LetterGridView(kind: .letter)
        case .vowels: LetterGridView(kind: .vowel)
        case .bands: BandsView()
        case .deck(let id): DeckGridView(deck: deck(id))
        case .set(let id): WordSetView(setID: id)
        case .books: BookListView()
        case .book(let name): VersePickerView(book: name)
        case .phraseSets: PhraseListView()
        case .phrases(let c): PhraseSetView(set: phraseSets.first { $0.c == c }!)
        case .group(let id): LessonListView(group: grammarGroups.first { $0.id == id }!)
        case .lesson(let id): LessonView(lesson: lessonsByID[id]!)
        case .settings: SettingsView()
        case .scan: ScanView()
        case .practice: PracticeView()
        }
    }

    /// The breadcrumb after מִקְרָא: the dashboard section, then where you are.
    private func trail(_ route: Route) -> [String] {
        let words = ui("Words", "词汇"), verses = ui("Verses", "经文"), grammar = ui("Grammar", "语法")
        switch route {
        case .letters: return [words, ui("Alphabet", "字母")]
        case .vowels: return [words, ui("Vowels", "元音")]
        case .bands: return [words, ui("Common words", "常用词")]
        case .deck(let id): return [words, tr(deck(id).title)]
        case .set(let id): return [words, store.sets.first { $0.id == id }?.name ?? ""]
        case .scan: return [words, ui("Scan notes", "扫描笔记")]
        case .books: return [verses, ui("Old Testament", "旧约")]
        case .phraseSets: return [verses, tr(phraseBook)]
        case .book(let name): return [verses, tr(name)]
        case .phrases(let c): return [verses, tr(phraseBook), phraseSets.first { $0.c == c }?.title ?? ""]
        case .group(let id): return [grammar, tr(grammarGroups.first { $0.id == id }?.title ?? "")]
        case .lesson(let id):
            let lesson = lessonsByID[id]
            let group = grammarGroups.first { $0.id == lesson?.group }
            return [grammar, tr(group?.title ?? ""), tr(lesson?.title ?? "")]
        case .settings: return [ui("Settings", "设置")]
        case .practice: return [ui("Practice", "练习")]
        }
    }

    /// One way in: a short run that mixes words and a verse.
    private var practiceButton: some View {
        Button { path.append(Route.practice) } label: {
            HStack(spacing: 8) {
                Image(systemName: "play").font(.subheadline)
                Text(ui("Practice now", "开始练习"))
                Spacer()
                Text(ui("Words and verses, mixed", "词汇与经文混合")).font(.caption).foregroundStyle(Theme.accent300)
                Image(systemName: "arrow.right").font(.caption)
            }
            .padding(.horizontal, 14)
        }
        .buttonStyle(OutlineButtonStyle())
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.subheadline).foregroundStyle(Theme.neutral500)
            TextField(Zh.on ? "搜索词义（中文或英文）" : "Search words in English or 中文", text: $query)
                .autocorrectionDisabled()
                .focused($focused)
            if !query.isEmpty {
                Button { query = ""; focused = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.neutral500)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius)
            .strokeBorder(focused ? Theme.accent : Theme.divider))
    }

    /// One dictionary line per hit; tapping opens the card with the gloss already shown.
    private var results: some View {
        let hits = searchWords(query)
        return VStack(spacing: 0) {
            if hits.isEmpty {
                Text(ui("No words match", "没有匹配的词")).foregroundStyle(Theme.neutral500).padding()
            }
            ForEach(hits) { w in
                Button { pick = w } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr(w.g)).font(.subheadline).foregroundStyle(Theme.neutral400)
                            Text(pronounce(w.h)).font(.caption2).foregroundStyle(Theme.neutral500)
                        }
                        Spacer()
                        Text(pointed(w.h)).font(.system(size: 40))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                FadingRule()
            }
        }
    }

    private func section<Tiles: View>(_ title: String, @ViewBuilder tiles: () -> Tiles) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium)).padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 8, content: tiles)
                .buttonStyle(.plain) // links and buttons alike: no accent tint on the tiles
                .padding(.horizontal)
        }
        .padding(.bottom, 18)
    }

    /// Things that come and go — your sets, recently opened books — sit on a faintly accent-tinted
    /// surface with a corner mark (`mine`). An `icon` tile is an action, drawn as an outline with no fill.
    private func tile(_ glyph: String?, _ label: String, mine: String? = nil, icon: String? = nil) -> some View {
        VStack(spacing: 4) {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: 28)).foregroundStyle(Theme.accent)
                } else if let glyph {
                    Text(pointed(glyph)).font(.system(size: 34)).minimumScaleFactor(0.5).lineLimit(1)
                }
            }
            .frame(height: 40)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(mine != nil ? Theme.accent300 : Theme.neutral400)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.horizontal, 4)
        .background(icon != nil ? .clear : mine != nil ? Theme.accent900 : Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            if icon != nil { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider) }
        }
        .overlay(alignment: .topTrailing) {
            if let mine {
                Image(systemName: mine).font(.system(size: 9)).foregroundStyle(Theme.accent).padding(6)
            }
        }
    }
}

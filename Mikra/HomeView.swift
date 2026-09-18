import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var showSession = false
    @State private var selected: LetterGroup?
    @State private var openVerse: VersePresentation?

    struct VersePresentation: Identifiable {
        let verse: JonahVerse
        let mode: VerseMode
        var id: String { verse.id }
    }

    private let letters = curriculum.filter { $0.kind == .letter }
    private let vowels = curriculum.filter { $0.kind == .vowel }
    private var vowelGroups: [LetterGroup] { vowels.map { LetterGroup(id: $0.id, cards: [$0]) } }
    private var allGroups: [LetterGroup] { letterGroups + vowelGroups }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("אָלֶף־בֵּית").font(.title)
                Spacer()
                Text("\(store.dueCards.count) due · \(store.streak)🔥")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            ScrollView {
                jonahSection
                section("Letters — \(learnedIn(letters))/\(letters.count)",
                        letterGroups, columns: 3)
                section("Vowels — \(learnedIn(vowels))/\(vowels.count)",
                        vowelGroups, columns: 4)
            }

            Button {
                showSession = true
            } label: {
                Text(store.dueCards.isEmpty ? "Learn" : "Review")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding()
            // two fullScreenCovers on one view don't both fire; keep this one here
            .fullScreenCover(isPresented: $showSession) {
                SessionView()
            }
        }
        .fullScreenCover(item: $openVerse) { p in
            VerseView(verse: p.verse, mode: p.mode)
        }
        .sheet(item: $selected) { group in
            if let i = allGroups.firstIndex(where: { $0.id == group.id }) {
                FlashCardView(groups: allGroups, index: i)
            } else {
                FlashCardView(groups: [group], index: 0) // ad-hoc group (DEBUG hook)
            }
        }
        #if DEBUG
        .onAppear { // UI smoke-test hooks: -openVerse / -openWave
            let args = ProcessInfo.processInfo.arguments
            // delay: presenting during the first onAppear races the cold launch and silently no-ops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if args.contains("-openVerse") {
                    openVerse = VersePresentation(verse: jonahVerses[0], mode: .passive)
                } else if args.contains("-openWave") {
                    openVerse = VersePresentation(verse: jonahVerses[0], mode: .wave)
                } else if args.contains("-openVowel") {
                    selected = LetterGroup(id: "qamats",
                                           cards: ["qamats", "cholam", "kubuts", "segol"].compactMap { cardsByID[$0] })
                }
            }
        }
        #endif
    }

    // — Jonah (Assimil waves) —

    private var jonahSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("יוֹנָה — Jonah").font(.headline)
                Spacer()
                Text("\(store.verses.values.filter { $0.passive != nil }.count)/48")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12), spacing: 4) {
                ForEach(Array(jonahVerses.enumerated()), id: \.element.id) { i, verse in
                    let p = store.verses[verse.id]
                    Button {
                        openVerse = VersePresentation(verse: verse, mode: .passive)
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(verseColor(p, isNext: i == store.verseIndex))
                            .frame(height: 18)
                            .overlay {
                                if i == store.verseIndex {
                                    RoundedRectangle(cornerRadius: 4).strokeBorder(.blue, lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(p?.passive == nil && i != store.verseIndex)
                }
            }

            HStack(spacing: 8) {
                if let today = store.todaysVerse, !store.verseDoneToday {
                    jonahButton("▶ Today: \(today.ref)", .blue) {
                        openVerse = VersePresentation(verse: today, mode: .passive)
                    }
                } else if store.todaysVerse != nil {
                    Text("✓ Verse done today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                if let wave = store.waveVerse {
                    jonahButton("🌊 Wave: \(wave.ref)", .teal) {
                        openVerse = VersePresentation(verse: wave, mode: .wave)
                    }
                }
                if !store.recentVerses.isEmpty {
                    Button {
                        Speech.say(store.recentVerses.map(\.hebrew).joined(separator: ". "))
                    } label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func verseColor(_ p: VerseProgress?, isNext: Bool) -> Color {
        if p?.wave != nil { return .green.opacity(0.6) }
        if p?.passive != nil { return .blue.opacity(0.45) }
        return Color(.secondarySystemBackground)
    }

    private func jonahButton(_ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(color)
        }
    }

    private func learnedIn(_ cards: [Card]) -> Int {
        cards.filter { (store.states[$0.id]?.intervalDays ?? 0) >= 1 }.count
    }

    private func tileColor(_ group: LetterGroup) -> Color {
        let states = group.cards.map { store.states[$0.id] }
        if states.allSatisfy({ ($0?.intervalDays ?? 0) >= 1 }) { return .green.opacity(0.2) }
        if states.contains(where: { $0 != nil }) { return .blue.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }

    private func section(_ title: String, _ groups: [LetterGroup], columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 10) {
                ForEach(groups) { group in
                    Button {
                        selected = group
                    } label: {
                        VStack(spacing: 2) {
                            Text(group.cards.map(\.displayGlyph).joined(separator: " "))
                                .font(.system(size: group.cards[0].kind == .vowel ? 48 : 30))
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
            .environment(\.layoutDirection, .rightToLeft) // rows flow right-to-left, like Hebrew
        }
        .padding(.bottom, 12)
    }
}

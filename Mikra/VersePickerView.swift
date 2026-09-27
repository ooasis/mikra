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

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                          spacing: 6) {
                    ForEach(verses) { verse in
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
                .padding(.horizontal)
            }
        }
        .padding(.top, 12)
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

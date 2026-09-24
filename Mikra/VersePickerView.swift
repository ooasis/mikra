import SwiftUI

/// Pick any verse from any book, outside the daily ritual. Reading one here
/// doesn't spend your verse for the day — only the ritual's own next verse does.
struct VersePickerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var pickedBook: String
    let onPick: (Verse) -> Void

    init(book: String, onPick: @escaping (Verse) -> Void) {
        _pickedBook = State(initialValue: book)
        self.onPick = onPick
    }

    private var verses: [Verse] { book(named: pickedBook).verses }

    var body: some View {
        VStack(spacing: 12) {
            if books.count > 1 {
                Picker("Book", selection: $pickedBook) {
                    ForEach(books) { Text($0.name).tag($0.name) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                          spacing: 6) {
                    ForEach(verses) { verse in
                        Button {
                            onPick(verse)
                            dismiss()
                        } label: {
                            Text(label(for: verse))
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

            if pickedBook != store.currentBook {
                Button("Follow \(pickedBook) daily") {
                    store.setCurrentBook(pickedBook)
                }
                .font(.subheadline)
                .padding(.bottom, 8)
            } else {
                Text("Today’s verse comes from \(pickedBook)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.top, 20)
        .presentationDragIndicator(.visible)
    }

    /// Chapter:verse, or just the verse number in a one-chapter text.
    private func label(for verse: Verse) -> String {
        Set(verses.map(\.c)).count > 1 ? "\(verse.c):\(verse.v)" : "\(verse.v)"
    }

    private func tint(_ verse: Verse) -> Color {
        let p = store.verses[verse.id]
        if p?.wave != nil { return .green.opacity(0.35) }
        if p?.passive != nil { return .blue.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }
}

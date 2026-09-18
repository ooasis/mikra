import SwiftUI

/// A vowel drawn by hand: dotted placeholder circle + the niqqud mark drawn
/// as plain shapes, as large as the circle (in text the mark stays tiny).
struct VowelGlyph: View {
    let card: Card
    let size: CGFloat // circle diameter ≈ mark height

    var body: some View {
        let u = size * 0.24 // dot diameter / bar thickness
        VStack(spacing: size * 0.22) {
            if card.id == "cholam" { mark(u) }
            Circle()
                .stroke(style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round,
                                           dash: [0.1, size * 0.18]))
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
            if card.id != "cholam" { mark(u) }
        }
    }

    @ViewBuilder
    private func mark(_ u: CGFloat) -> some View {
        switch card.id {
        case "patach":
            bar(u)
        case "qamats":
            VStack(spacing: 0) {
                bar(u)
                Rectangle().frame(width: u * 0.6, height: u * 1.4)
            }
        case "tsere":
            HStack(spacing: u * 0.7) { dot(u); dot(u) }
        case "segol":
            VStack(spacing: u * 0.3) {
                HStack(spacing: u * 0.9) { dot(u); dot(u) }
                dot(u)
            }
        case "chirik", "cholam":
            dot(u)
        case "kubuts":
            HStack(spacing: u * 0.45) { dot(u); dot(u); dot(u) }
                .rotationEffect(.degrees(45))
                .frame(width: u * 2.9, height: u * 2.9) // rotation exceeds row bounds
        case "sheva":
            VStack(spacing: u * 0.55) { dot(u); dot(u) }
        default:
            EmptyView()
        }
    }

    private func dot(_ u: CGFloat) -> some View {
        Circle().frame(width: u, height: u)
    }
    private func bar(_ u: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: u * 0.15).frame(width: u * 2.6, height: u * 0.55)
    }
}

struct FlashCardView: View {
    let cards: [Card] // one letter's variants (or a single vowel/word card)
    @Environment(\.dismiss) private var dismiss
    @State private var playing: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done") { dismiss() }
                Spacer()
            }
            .padding()

            ScrollView {
                HStack(spacing: 16) {
                    ForEach(cards) { card in
                        Button {
                            Speech.say(card.speechText)
                        } label: {
                            VStack(spacing: 6) {
                                if card.kind == .vowel {
                                    VowelGlyph(card: card, size: 60)
                                } else {
                                    Text(card.hebrew)
                                        .font(.system(size: cards.count > 2 ? 64 : 80))
                                }
                                Text(card.name).font(.headline)
                                Text(card.sound).font(.subheadline).foregroundStyle(.secondary)
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.blue)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .environment(\.layoutDirection, .rightToLeft)

                ForEach(cards.filter { $0.note != nil }) { card in
                    Text(card.note!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 6)
                }

                ForEach(cards) { card in
                    let practice = combos(for: card)
                    if !practice.isEmpty {
                        Text(cards.count > 1 ? "Practice: \(card.name) with vowels" : "Practice with vowels")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding([.horizontal, .top])

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(practice) { combo in
                                Button {
                                    playing = combo.id
                                    Speech.say(combo.hebrew)
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(combo.hebrew).font(.system(size: 34))
                                        Text(combo.caption).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        playing == combo.id ? Color.blue.opacity(0.25) : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                }
            }
        }
        .onAppear { if let first = cards.first { Speech.say(first.speechText) } }
    }
}

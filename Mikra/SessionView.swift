import SwiftUI

struct SessionView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Card] = []
    @State private var revealed = false
    @State private var done = 0
    @State private var history: [Card] = []
    @State private var browse: Int? = nil // index into history; nil = live card

    private var card: Card? { browse.map { history[$0] } ?? queue.first }
    private var isRevealed: Bool { browse != nil || revealed }

    var body: some View {
        VStack {
            HStack {
                Button("Done") { dismiss() }
                Spacer()
                Button {
                    browse = (browse ?? history.count) - 1
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled((browse ?? history.count) == 0)
                Button {
                    let next = browse! + 1
                    browse = next == history.count ? nil : next
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(browse == nil)
                .padding(.horizontal, 8)
                Spacer()
                Text("\(queue.count) left").foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            if let card {
                if card.kind == .vowel {
                    VowelGlyph(card: card, size: 85)
                } else {
                    Text(card.hebrew)
                        .font(.system(size: 120))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal)
                }

                if isRevealed {
                    VStack(spacing: 8) {
                        Text(card.name).font(.title).bold()
                        if !card.sound.isEmpty {
                            Text(card.sound).font(.title3).foregroundStyle(.secondary)
                        }
                        if let note = card.note {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Button {
                            Speech.say(card.speechText)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill").font(.title2)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 24)
                } else {
                    Text(card.prompt)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            } else {
                VStack(spacing: 12) {
                    Text("🎉").font(.system(size: 60))
                    Text("Session done — \(done) cards").font(.title2)
                }
            }

            Spacer()

            if browse != nil {
                Text("Reviewing an earlier card")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding()
            } else if let card {
                if revealed {
                    HStack(spacing: 12) {
                        gradeButton("Again", .red) { finish(card, .again) }
                        gradeButton("Good", .blue) { finish(card, .good) }
                        gradeButton("Easy", .green) { finish(card, .easy) }
                    }
                    .padding()
                } else {
                    Button {
                        revealed = true
                        Speech.say(card.speechText)
                    } label: {
                        Text("Reveal")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
            } else {
                Button("Close") { dismiss() }.padding()
            }
        }
        .onAppear {
            queue = store.dueCards + store.newCards(limit: 5)
        }
    }

    private func finish(_ card: Card, _ grade: Grade) {
        store.grade(card, grade)
        queue.removeFirst()
        if grade == .again { queue.append(card) } // recycle within session
        history.append(card)
        done += 1
        revealed = false
    }

    private func gradeButton(_ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(color)
        }
    }
}

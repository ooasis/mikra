import SwiftUI

enum VerseMode { case passive, wave }

struct VerseView: View {
    let verse: JonahVerse
    let mode: VerseMode
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case listen, read, check }
    @State private var stage: Stage
    @State private var tappedWord: JonahWord?

    init(verse: JonahVerse, mode: VerseMode) {
        self.verse = verse
        self.mode = mode
        _stage = State(initialValue: mode == .passive ? .listen : .read)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Text(verse.ref).font(.headline)
                Spacer()
                Button {
                    Speech.say(verse.hebrew)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .opacity(stage == .listen && mode == .passive ? 0 : 1)
            }
            .padding()

            ScrollView {
                switch stage {
                case .listen:
                    listenStage
                case .read, .check:
                    readStage
                }
            }

            footer
        }
        .sheet(item: $tappedWord) { word in
            WordSheet(word: word)
                .presentationDetents([.height(300)])
        }
        .onAppear {
            if mode == .passive { Speech.say(verse.hebrew) }
        }
    }

    private var listenStage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 80)
            Button {
                Speech.say(verse.hebrew)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 70))
            }
            Text("Ear first: just listen.\nReplay until the sounds feel familiar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var readStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            if mode == .wave && stage == .read {
                Text("Second wave — read it aloud, no help.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            VerseFlow {
                ForEach(Array(verse.words.enumerated()), id: \.offset) { _, word in
                    Button {
                        tappedWord = word
                        store.tapWord(word)
                        Speech.say(word.h)
                    } label: {
                        Text(word.h)
                            .font(.system(size: 32))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 2)
                            .overlay(alignment: .bottom) {
                                if word.n != nil {
                                    Circle().fill(.orange).frame(width: 5, height: 5).offset(y: 4)
                                } else if store.tapped.contains(jonahCardID(word)) {
                                    Circle().fill(.blue.opacity(0.5)).frame(width: 4, height: 4).offset(y: 4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            if stage == .check {
                Text(verse.en)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else if mode == .passive {
                Text("Tap any word you don't know — it joins your drills.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var footer: some View {
        VStack {
            switch (mode, stage) {
            case (.passive, .listen):
                bigButton("Show the text") { stage = .read }
            case (.passive, .read):
                bigButton("I read it aloud — check meaning") { stage = .check }
            case (.passive, .check):
                bigButton("Done ✓") {
                    store.completePassive(verse)
                    dismiss()
                }
            case (.wave, .read):
                bigButton("Check") {
                    stage = .check
                    Speech.say(verse.hebrew)
                }
            case (.wave, .check):
                HStack(spacing: 12) {
                    Button {
                        dismiss() // stays in the wave queue
                    } label: {
                        Text("Struggled")
                            .frame(maxWidth: .infinity).padding()
                            .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.red)
                    }
                    Button {
                        store.completeWave(verse)
                        dismiss()
                    } label: {
                        Text("Owned it ✓")
                            .frame(maxWidth: .infinity).padding()
                            .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            case (.wave, .listen):
                EmptyView() // unreachable
            }
        }
    }

    private func bigButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding()
    }
}

extension JonahWord: Identifiable {
    var id: String { h }
}

private struct WordSheet: View {
    let word: JonahWord

    var body: some View {
        VStack(spacing: 12) {
            Text(word.h).font(.system(size: 64))
            Text(word.g).font(.title3).multilineTextAlignment(.center)
            if let n = word.n {
                Text(n)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button {
                Speech.say(word.h)
            } label: {
                Image(systemName: "speaker.wave.2.fill").font(.title2)
            }
        }
        .padding()
    }
}

/// Wrapping layout that flows right-to-left, like Hebrew text.
struct VerseFlow: Layout {
    let spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        return CGSize(width: width, height: arrange(subviews, in: width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, in: bounds.width)
        for (i, p) in arrangement.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.maxX - p.x, y: bounds.minY + p.y),
                              anchor: .topTrailing, proposal: .unspecified)
        }
    }

    // x is each word's trailing-edge offset from the right margin
    private func arrange(_ subviews: Subviews, in width: CGFloat) -> (points: [CGPoint], height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (points, y + rowHeight)
    }
}

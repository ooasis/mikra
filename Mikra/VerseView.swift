import SwiftUI

enum VerseMode { case passive, wave }

/// One verse per page; swipe to move through the book.
struct VerseView: View {
    let verse: Verse
    let mode: VerseMode
    @State private var index: Int

    init(verse: Verse, mode: VerseMode) {
        self.verse = verse
        self.mode = mode
        _index = State(initialValue: book(named: verse.book).verses
            .firstIndex { $0.id == verse.id } ?? 0)
    }

    private var verses: [Verse] { book(named: verse.book).verses }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(verses.enumerated()), id: \.element.id) { i, v in
                VersePage(verse: v, mode: mode)
                    .environment(\.layoutDirection, .leftToRight) // content stays LTR
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
        // audio belongs to the pager: a page's own onAppear would fire for the
        // neighbours TabView builds off-screen, and they'd all start talking
        .onAppear { if mode == .passive { Speech.say(verse: verse, pace: Speech.pace) } }
        .onChange(of: index) { Speech.stop() }
    }
}

private struct VersePage: View {
    let verse: Verse
    let mode: VerseMode
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = SpeechMonitor.shared
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case listen, read, check }
    @State private var stage: Stage
    /// Which word's sheet is open. By index, since a verse can repeat a word.
    private struct WordPick: Identifiable { let index: Int; var id: Int { index } }
    @State private var picked: WordPick?

    init(verse: Verse, mode: VerseMode) {
        self.verse = verse
        self.mode = mode
        _stage = State(initialValue: mode == .passive ? .listen : .read)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-showText") { _stage = State(initialValue: .read) } // screenshot hook
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Text(verse.ref).font(.headline)
                Spacer()
                // no speaker here: on the text page the pace buttons do the speaking
                Color.clear.frame(width: 44, height: 1)
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
        .sheet(item: $picked) { pick in
            WordSheet(words: verse.words, index: pick.index)
                .presentationDetents([.height(320)])
        }
    }

    private var listenStage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 80)
            Button {
                // ear first is always full speed — slow practice belongs with the text
                Speech.say(verse: verse, pace: store.pace)
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

    /// Each button plays the verse at its own pace — tapping the current one replays,
    /// which is why these are buttons rather than a Picker.
    private var paceControls: some View {
        HStack(spacing: 8) {
            ForEach(Pace.allCases) { pace in
                let isCurrent = store.pace == pace
                Button {
                    store.setPace(pace)
                    Speech.say(verse: verse, pace: pace)
                } label: {
                    Text(pace.label)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(isCurrent ? Color.blue : Color(.secondarySystemBackground),
                                    in: Capsule())
                        .foregroundStyle(isCurrent ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
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
                ForEach(Array(verse.words.enumerated()), id: \.offset) { i, word in
                    Button {
                        picked = WordPick(index: i)
                        store.tapWord(word)
                        Speech.say(word.h)
                    } label: {
                        Text(word.h)
                            .font(.system(size: 32))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 3)
                            .background(monitor.spokenWord == i ? Color.yellow.opacity(0.45) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .animation(.easeOut(duration: 0.12), value: monitor.spokenWord == i)
                            .overlay(alignment: .bottom) {
                                if word.n != nil {
                                    Circle().fill(.orange).frame(width: 5, height: 5).offset(y: 4)
                                } else if store.tapped.contains(verseWordCardID(word)) {
                                    Circle().fill(.blue.opacity(0.5)).frame(width: 4, height: 4).offset(y: 4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            paceControls

            if stage == .check {
                Text(verse.en)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else if mode == .passive {
                Text(store.pace.wordByWord
                     ? "Tap any word you don't know — it joins your drills.\nPlay follows along, one word at a time."
                     : "Tap any word you don't know — it joins your drills.")
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
                    Speech.say(verse: verse, pace: store.pace)
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

/// One word at a time; swipe to walk through the verse.
private struct WordSheet: View {
    let words: [VerseWord]
    @State var index: Int

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                page(word, position: i)
                    .environment(\.layoutDirection, .leftToRight) // content stays LTR
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
    }

    private func page(_ word: VerseWord, position: Int) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("\(position + 1) / \(words.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(word.h).font(.system(size: 64)).minimumScaleFactor(0.5).lineLimit(1)
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
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding(.top, 12)
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

import SwiftUI

enum VerseMode { case passive, wave }

/// What sits under each word of a verse: nothing, its meaning, or how to say it.
enum VerseHelp: String, CaseIterable, Identifiable {
    case none, meaning, reading
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return ui("None", "无")
        case .meaning: return ui("Meaning", "含义")
        case .reading: return ui("Reading", "读音")
        }
    }
}

/// One verse per page; swipe to move through the chapter.
struct VerseView: View {
    let verse: Verse
    let mode: VerseMode
    @State private var index: Int

    init(verse: Verse, mode: VerseMode) {
        self.verse = verse
        self.mode = mode
        _index = State(initialValue: Self.chapter(of: verse).firstIndex { $0.id == verse.id } ?? 0)
    }

    /// The pages: the verse's chapter. A page TabView builds every page up front, and Psalms has 2,527 verses.
    private var verses: [Verse] { Self.chapter(of: verse) }
    private static func chapter(of verse: Verse) -> [Verse] {
        book(named: verse.book).verses.filter { $0.c == verse.c }
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(verses.enumerated()), id: \.element.id) { i, v in
                VersePage(verse: v, mode: mode, chapter: verses, position: i,
                          jump: { j in index = j }) // a tap on the strip cuts straight to the verse, no slide
                    .environment(\.layoutDirection, .leftToRight) // content stays LTR
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .rightToLeft) // pages advance right-to-left, like Hebrew
        .background(Theme.ground)
        .onChange(of: index) { Speech.stop(); Recorder.shared.stop() }
        .onDisappear { Recorder.shared.stop() }
    }
}

/// Tap a word to hear it; the bar at the bottom holds what changes often (help, play, recording,
/// Done); the gear at the top holds what doesn't (text size, pace, saving the verse's words).
private struct VersePage: View {
    let verse: Verse
    let mode: VerseMode
    let chapter: [Verse]
    let position: Int
    let jump: (Int) -> Void
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = SpeechMonitor.shared
    @ObservedObject private var recorder = Recorder.shared
    @Environment(\.dismiss) private var dismiss

    /// Passive reading shows text and translation at once; the wave hides the translation until Check.
    private enum Stage { case read, check }
    @State private var stage: Stage
    /// Which word's sheet is open. By index, since a verse can repeat a word.
    private struct WordPick: Identifiable { let index: Int; var id: Int { index } }
    @State private var picked: WordPick?
    /// Hebrew text size: 1 is the 40pt default; the sheet offers Normal, Large, X-large.
    @AppStorage("verseScale") private var scale = 1.0
    @State private var showSettings = false
    @State private var pickWords = false

    init(verse: Verse, mode: VerseMode, chapter: [Verse], position: Int, jump: @escaping (Int) -> Void) {
        self.verse = verse
        self.mode = mode
        self.chapter = chapter
        self.position = position
        self.jump = jump
        _stage = State(initialValue: mode == .passive ? .check : .read)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            rail
            ScrollView { readStage }
            if mode == .wave { footer } // the wave's Check / Owned it flow stays in view
        }
        .safeAreaInset(edge: .bottom) { bar }
        #if DEBUG
        .onAppear { // -tapPlay: play at 1.5 s, pause at 4 s, resume at 6 s
            guard position == 0 else { return }
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tapPlay") {
                for t in [1.5, 4, 6] { DispatchQueue.main.asyncAfter(deadline: .now() + t) { playTapped() } }
            }
            if args.contains("-verseSettings") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showSettings = true } }
            if args.contains("-verseWords") { // the picker lives inside the settings sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showSettings = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { pickWords = true }
            }
            if args.contains("-tapHelp") { // set Meaning here, then jump to the next verse: does it follow?
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { store.setVerseHelp(.meaning); scale = 1.5 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { jump(1) }
            }
        }
        #endif
        .sheet(item: $picked) { pick in
            WordSheet(words: verse.words, index: pick.index)
                .presentationDetents([.height(340)])
                .presentationBackground(Theme.surface)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ui("Close", "关闭"))
            CrumbLine(trail: [tr(verse.book), "\(verse.c):\(verse.v)"])
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.subheadline)
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ui("Verse settings", "经文设置"))
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .sheet(isPresented: $showSettings) {
            settings
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.surface)
        }
    }

    // — Verse settings: the gear sheet —

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            group(ui("Text size", "字号")) {
                Picker("", selection: $scale) {
                    Text(ui("Normal", "标准")).tag(1.0)
                    Text(ui("Large", "大")).tag(1.25)
                    Text(ui("X-large", "特大")).tag(1.5)
                }
                .pickerStyle(.segmented)
            }
            group(ui("Reading pace", "朗读速度")) {
                Picker("", selection: Binding(get: { store.pace }, set: { store.setPace($0) })) {
                    ForEach(Pace.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            group(ui("Words of this verse", "本节的词")) {
                let found = Set(verse.words.compactMap { cardForHebrew($0.h)?.id }).count
                Button { pickWords = true } label: {
                    Label(ui("Add words to a set · \(found) found", "加入词集 · 找到 \(found) 个"), systemImage: "bookmark")
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(found == 0)
            }
        }
        .padding()
        .padding(.top, 8)
        .sheet(isPresented: $pickWords) { // the scan result page: tick the words, pick or create the set
            NavigationStack { ScanView(text: verse.hebrew, setName: setName) }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.neutral400)
            content()
        }
    }

    /// The name a new set takes for this verse's words: one per chapter, like "Jonah-1".
    private var setName: String { "\(tr(verse.book))-\(verse.c)" }

    /// One number per verse of the chapter, right to left; the current one lit, read ones tinted.
    private var rail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(chapter.enumerated()), id: \.element.id) { i, v in
                        Button { jump(i) } label: {
                            Text("\(v.v)")
                                .font(.system(size: 14, weight: i == position ? .semibold : .regular).monospacedDigit())
                                .foregroundStyle(tick(i, v))
                                .frame(minWidth: 26, minHeight: 32)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear { proxy.scrollTo(position, anchor: .center) }
        }
        .padding(.bottom, 8)
    }

    private func tick(_ i: Int, _ v: Verse) -> Color {
        if i == position { return Theme.accent }
        return store.verses[v.id]?.passive != nil ? Theme.accent700 : Theme.neutral700
    }

    private var readStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode == .wave && stage == .read {
                Text(ui("Second wave — read it aloud, no help.", "第二遍：不看提示，大声读出来。"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.neutral400)
            }
            VStack(alignment: .leading, spacing: 12) {
                VerseFlow {
                    ForEach(Array(verse.words.enumerated()), id: \.offset) { i, word in
                        Button {
                            picked = WordPick(index: i)
                            Speech.say(word.h)
                        } label: {
                            VStack(spacing: 2) {
                                Text(pointed(word.h))
                                    .font(.system(size: 40 * scale))
                                    .foregroundStyle(Theme.text)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 3)
                                    .background(monitor.spokenWord == i ? Theme.accent800 : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .animation(.easeOut(duration: 0.12), value: monitor.spokenWord == i)
                                    .overlay(alignment: .bottom) {
                                        if word.n != nil { // a micro-note waits in the word sheet
                                            Circle().fill(Theme.accent).frame(width: 4, height: 4).offset(y: 4)
                                        }
                                    }
                                if let help = help(for: word) {
                                    Text(help)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.neutral400)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(maxWidth: 90 * scale)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .cardSurface()

            if stage == .check {
                Text(verse.text)
                    .font(.title3)
                    .foregroundStyle(Theme.neutral400)
                    .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func help(for word: VerseWord) -> String? {
        switch store.verseHelp {
        case .none: return nil
        case .meaning: return tr(word.g)
        case .reading: return pronounce(word.h)
        }
    }

    // — The floating bar: one row of icons, no chrome; a lit icon is an option that is on —

    private var bar: some View {
        let hasTake = Recorder.hasTake(for: verse)
        let busy = recorder.isRecording || !hasTake
        return HStack(spacing: 0) {
            tool(helpIcon, on: store.verseHelp != .none, label: store.verseHelp.label) {
                let all = VerseHelp.allCases // None → Meaning → Reading → None
                store.setVerseHelp(all[(all.firstIndex(of: store.verseHelp)! + 1) % all.count])
            }
            playTool
            tool(recorder.isRecording ? "stop.fill" : "mic", on: recorder.isRecording,
                 label: recorder.isRecording ? ui("Stop", "停止") : ui("Record me", "录我")) {
                recorder.isRecording ? recorder.stop() : recorder.record(verse)
            }
            tool(recorder.isPlaying ? "stop.fill" : "person.wave.2", on: recorder.isPlaying,
                 label: recorder.isPlaying ? ui("Stop", "停止") : ui("Play me", "播放我")) {
                recorder.isPlaying ? recorder.stop() : recorder.play(verse)
            }
            .disabled(busy).opacity(busy ? 0.35 : 1)
            ShareLink(item: Recorder.url(for: verse)) { Image(systemName: "square.and.arrow.up").toolChrome() }
                .buttonStyle(.plain)
                .disabled(busy).opacity(busy ? 0.35 : 1)
            if mode == .passive { // a toggle: the reader stays open either way
                let done = store.verses[verse.id]?.passive != nil
                tool(done ? "checkmark.circle.fill" : "checkmark.circle", on: done, label: ui("Done", "读完了")) {
                    done ? store.clearPassive(verse) : store.completePassive(verse)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.bg)
    }

    /// One tap starts, pauses or resumes the reading; a swipe to another verse stops it.
    private var playTool: some View {
        let busy = monitor.playing && !monitor.paused
        return Button(action: playTapped) {
            Image(systemName: busy ? "pause.fill" : "play.fill").toolChrome(monitor.playing ? Theme.accent : Theme.neutral400)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(busy ? ui("Pause", "暂停") : ui("Read the verse", "朗读整节"))
    }

    private func playTapped() {
        if !monitor.playing { Speech.say(verse: verse, pace: store.pace) }
        else if monitor.paused { Speech.resume() }
        else { Speech.pause() }
    }

    private var helpIcon: String {
        switch store.verseHelp {
        case .none: return "character.book.closed"
        case .meaning: return "character.book.closed.fill"
        case .reading: return "textformat.abc"
        }
    }

    /// One icon that fills its share of the row; `on` lights it with the accent.
    private func tool(_ icon: String, on: Bool = false, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).toolChrome(on ? Theme.accent : Theme.neutral400) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    // — The second wave keeps its own footer —

    private var footer: some View {
        Group {
            switch stage {
            case .read:
                Button(ui("Check", "核对")) {
                    stage = .check
                    Speech.say(verse: verse, pace: store.pace)
                }
                .buttonStyle(OutlineButtonStyle())
            case .check:
                HStack(spacing: 8) {
                    Button(ui("Struggled", "还不熟")) { dismiss() } // stays in the wave queue
                        .buttonStyle(OutlineButtonStyle(prominent: false))
                    Button {
                        store.completeWave(verse)
                        dismiss()
                    } label: {
                        Label(ui("Owned it", "掌握了"), systemImage: "checkmark")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
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
            VStack(spacing: 10) {
                Text("\(position + 1) / \(words.count)")
                    .font(.caption2)
                    .foregroundStyle(Theme.neutral500)
                Text(pointed(word.h)).font(.system(size: 84)).minimumScaleFactor(0.5).lineLimit(1)
                Text(pronounce(word.h)).font(.subheadline).foregroundStyle(Theme.neutral500)
                Text(tr(word.g)).font(.title2.weight(.medium)).multilineTextAlignment(.center)
                if let n = word.n {
                    Text(tr(n))
                        .font(.subheadline)
                        .foregroundStyle(Theme.neutral400)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                }
                Button {
                    Speech.say(word.h)
                } label: {
                    Label(ui("Hear it", "再听"), systemImage: "speaker.wave.2")
                }
                .buttonStyle(OutlineButtonStyle())
                .padding(.horizontal, 60)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding(.top, 12)
    }
}

private extension View {
    func toolChrome(_ tint: Color = Theme.neutral400) -> some View {
        self.font(.title3)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
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
                              anchor: .topTrailing, proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }

    // x is each word's trailing-edge offset from the right margin
    private func arrange(_ subviews: Subviews, in width: CGFloat) -> (points: [CGPoint], height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            // propose the row width, so a caption that wraps is measured as tall as it is drawn
            let size = sv.sizeThatFits(ProposedViewSize(width: width, height: nil))
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

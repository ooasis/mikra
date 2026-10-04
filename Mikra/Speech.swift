import AVFoundation

/// How a verse is read aloud. Slow paces speak one word at a time, with a gap
/// between words — the point is to hear where each word ends, not just slower sound.
enum Pace: String, CaseIterable, Identifiable {
    case normal, slow, slower

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var wordByWord: Bool { self != .normal }

    /// Multiplier on the system's default speech rate.
    var rate: Float {
        switch self {
        case .normal: return 0.5
        case .slow:   return 0.45
        case .slower: return 0.4
        }
    }

    /// Silence after each word. Zero for normal, which speaks the verse in one breath.
    var gap: TimeInterval {
        switch self {
        case .normal: return 0
        case .slow:   return 0.4
        case .slower: return 0.9
        }
    }
}

/// Publishes which word is currently being spoken, so the reader can follow along,
/// and tells whoever is waiting on an utterance when it has ended, however it ended.
final class SpeechMonitor: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechMonitor()

    @Published private(set) var spokenWord: Int?
    /// A reading is under way (`playing`), and whether it is held (`paused`).
    @Published private(set) var playing = false
    @Published private(set) var paused = false

    /// The utterance being waited on. Keyed by identity: a stale didCancel from an
    /// earlier utterance must not wake the waiter of the next one.
    fileprivate var waiting: (utterance: AVSpeechUtterance, resume: () -> Void)?

    /// Always deferred: called from a view's onAppear, and mutating an observed
    /// @Published during a view update can blank the presentation.
    fileprivate func highlight(_ value: Int?) {
        DispatchQueue.main.async {
            if self.spokenWord != value { self.spokenWord = value }
        }
    }

    fileprivate func set(playing p: Bool, paused h: Bool) {
        DispatchQueue.main.async {
            if self.playing != p { self.playing = p }
            if self.paused != h { self.paused = h }
        }
    }

    private func ended(_ utterance: AVSpeechUtterance) {
        guard let w = waiting, w.utterance === utterance else { return }
        waiting = nil
        w.resume()
    }

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        #if DEBUG
        started += 1
        #endif
    }

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        ended(utterance)
        #if DEBUG
        onFinish?()
        #endif
    }

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        ended(utterance)
    }

    #if DEBUG
    var started = 0
    var onFinish: (() -> Void)?
    #endif
}

enum Speech {
    private static let synth: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = SpeechMonitor.shared
        return s
    }()

    /// The global reading speed, set from Settings (and the reader's pace buttons) via the Store.
    static var pace: Pace = .normal

    /// The word-by-word reading in progress. The pauses between words are this task's
    /// sleeps, never the synthesizer's postUtteranceDelay: stopping the synthesizer
    /// inside that delay silently kills every utterance after it until the app restarts.
    private static var reading: Task<Void, Never>?
    private static var paused = false

    static func say(_ text: String, pace: Pace = Speech.pace) {
        speak([text], pace: pace)
    }

    /// Word by word, in order, with the pace's gap after each.
    static func say(words: [String], pace: Pace = Speech.pace) {
        speak(words, pace: pace)
    }

    /// What gets spoken for a verse: one breath at normal pace, one word at a time otherwise.
    static func chunks(for verse: Verse, pace: Pace) -> [String] {
        pace.wordByWord ? verse.words.map(\.h) : [verse.hebrew]
    }

    /// Reads a verse the way the current pace asks for.
    static func say(verse: Verse, pace: Pace) {
        speak(chunks(for: verse, pace: pace), pace: pace)
    }

    static func stop() {
        reading?.cancel()
        reading = nil
        paused = false
        SpeechMonitor.shared.highlight(nil)
        SpeechMonitor.shared.set(playing: false, paused: false)
        synth.stopSpeaking(at: .immediate)
    }

    /// Holds the reading where it is: mid-word the synth pauses, mid-gap the loop waits.
    static func pause() {
        guard reading != nil, !paused else { return }
        paused = true
        synth.pauseSpeaking(at: .word)
        SpeechMonitor.shared.set(playing: true, paused: true)
    }

    static func resume() {
        guard paused else { return }
        paused = false
        synth.continueSpeaking()
        SpeechMonitor.shared.set(playing: true, paused: false)
    }

    /// Speaks one word and returns once it has been heard — or cut off by a stop.
    static func say(word: String) async {
        stop()
        await speakOne(word, pace: pace)
    }

    private static func speak(_ chunks: [String], pace: Pace) {
        stop()
        #if DEBUG
        // simulator TTS can hang view presentation; UI smoke tests pass -muteTTS
        if ProcessInfo.processInfo.arguments.contains("-muteTTS") { return }
        #endif
        let wordByWord = pace.wordByWord && chunks.count > 1
        SpeechMonitor.shared.set(playing: true, paused: false)
        reading = Task { @MainActor in
            for (i, chunk) in chunks.enumerated() {
                if wordByWord { SpeechMonitor.shared.highlight(i) }
                await speakOne(chunk, pace: pace)
                if wordByWord { try? await Task.sleep(for: .seconds(pace.gap)) }
                while paused, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(100)) }
                if Task.isCancelled { return }
            }
            reading = nil
            SpeechMonitor.shared.highlight(nil)
            SpeechMonitor.shared.set(playing: false, paused: false)
        }
    }

    /// One utterance, awaited until the delegate says it ended. Not `isSpeaking`: that reads
    /// false for a moment after `speak`, which made every reading look finished at once.
    private static func speakOne(_ text: String, pace: Pace) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-muteTTS") { return } // nothing to wait for
        #endif
        let u = utterance(text, pace: pace)
        await withCheckedContinuation { c in
            SpeechMonitor.shared.waiting = (u, { c.resume() })
            synth.speak(u)
        }
    }

    /// The best Hebrew voice on the device. iOS has one personality (Carmit) in several
    /// qualities; the enhanced and premium ones are downloads in Settings > Accessibility >
    /// Spoken Content > Voices > Hebrew, and are used here as soon as they are present.
    static let voice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "he-IL" }
            .max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "he-IL")

    private static func utterance(_ text: String, pace: Pace) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * pace.rate
        return u
    }
}

#if DEBUG
/// Smallest check that fails if slow mode stops being word-by-word.
func speechSelfCheck() {
    let verse = books[0].verses[0]
    assert(Speech.chunks(for: verse, pace: .normal) == [verse.hebrew], "normal reads the verse whole")
    for pace in [Pace.slow, .slower] {
        assert(Speech.chunks(for: verse, pace: pace) == verse.words.map(\.h),
               "\(pace.rawValue) reads one word at a time")
        assert(pace.gap > 0, "\(pace.rawValue) leaves a gap between words")
        assert(pace.rate < Pace.normal.rate, "\(pace.rawValue) is slower than normal")
        assert(pace.wordByWord, "\(pace.rawValue) is a word-by-word pace")
    }
    assert(!Pace.normal.wordByWord, "normal is not word-by-word")
    assert(Pace.slower.rate < Pace.slow.rate && Pace.slower.gap > Pace.slow.gap, "slower is slower than slow")
}
#endif

#if DEBUG
/// Launch with -wedgeTest (on a device, with the console attached): reads word by word, stops
/// inside the first gap, then tries to speak again and prints whether anything starts.
extension Speech {
    static func wedgeTest() {
        let m = SpeechMonitor.shared
        print("wedgeTest: speaking slower, word by word")
        m.onFinish = {
            m.onFinish = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("wedgeTest: stop inside the gap; isSpeaking=\(synth.isSpeaking)")
                stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("wedgeTest: after stop isSpeaking=\(synth.isSpeaking); speaking again")
                    m.started = 0
                    say("בְּרֵאשִׁית בָּרָא אֱלֹהִים")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        print("wedgeTest: RESULT started=\(m.started) isSpeaking=\(synth.isSpeaking)")
                    }
                }
            }
        }
        say(words: ["אָב", "אָב", "אָב", "אָב"], pace: .slower)
    }

    /// Launch with -rateSamples: Genesis 1:1 in one breath at a few rates, each announced in English.
    static func rateSamples(_ rates: [Float] = [0.8, 0.7, 0.6, 0.5]) {
        let verse = books[0].verses[0]
        Task { @MainActor in
            for (i, rate) in rates.enumerated() {
                let label = AVSpeechUtterance(string: "Sample \(i + 1)")
                label.voice = AVSpeechSynthesisVoice(language: "en-US")
                synth.speak(label)
                await withCheckedContinuation { c in SpeechMonitor.shared.waiting = (label, { c.resume() }) }
                try? await Task.sleep(for: .seconds(0.5))
                let u = AVSpeechUtterance(string: verse.hebrew)
                u.voice = voice
                u.rate = AVSpeechUtteranceDefaultSpeechRate * rate
                synth.speak(u)
                await withCheckedContinuation { c in SpeechMonitor.shared.waiting = (u, { c.resume() }) }
                try? await Task.sleep(for: .seconds(1.2))
            }
        }
    }
}
#endif

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
        case .normal: return 0.8
        case .slow:   return 0.6
        case .slower: return 0.45
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

/// Publishes which word is currently being spoken, so the reader can follow along.
/// Only tracks word-by-word playback; at normal pace the verse is one utterance
/// and there is nothing to highlight.
final class SpeechMonitor: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechMonitor()

    @Published private(set) var spokenWord: Int?

    private var indices: [ObjectIdentifier: Int] = [:]
    private var lastIndex: Int?

    fileprivate func track(_ utterances: [AVSpeechUtterance], wordByWord: Bool) {
        indices = [:]
        lastIndex = nil
        publish(nil)
        guard wordByWord else { return }
        for (i, u) in utterances.enumerated() { indices[ObjectIdentifier(u)] = i }
        lastIndex = utterances.count - 1
    }

    /// Always deferred: `track` is called from a view's onAppear, and mutating an
    /// observed @Published during a view update can blank the presentation.
    private func publish(_ value: Int?) {
        DispatchQueue.main.async {
            if self.spokenWord != value { self.spokenWord = value }
        }
    }

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        publish(indices[ObjectIdentifier(utterance)])
    }

    /// Clear only after the final word, so the highlight doesn't flicker off between words.
    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if indices[ObjectIdentifier(utterance)] == lastIndex { publish(nil) }
    }

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        publish(nil)
    }
}

enum Speech {
    private static let synth: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = SpeechMonitor.shared
        return s
    }()

    /// The global reading speed, set from Settings (and the reader's pace buttons) via the Store.
    static var pace: Pace = .normal

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
        synth.stopSpeaking(at: .immediate)
    }

    private static func speak(_ chunks: [String], pace: Pace) {
        #if DEBUG
        // simulator TTS can hang view presentation; UI smoke tests pass -muteTTS
        if ProcessInfo.processInfo.arguments.contains("-muteTTS") {
            SpeechMonitor.shared.track([], wordByWord: false) // don't strand a highlight
            return
        }
        #endif
        synth.stopSpeaking(at: .immediate)
        let utterances = chunks.map { chunk -> AVSpeechUtterance in
            let u = AVSpeechUtterance(string: chunk)
            u.voice = AVSpeechSynthesisVoice(language: "he-IL")
            u.rate = AVSpeechUtteranceDefaultSpeechRate * pace.rate
            u.postUtteranceDelay = pace.gap
            return u
        }
        SpeechMonitor.shared.track(utterances, wordByWord: pace.wordByWord && chunks.count > 1)
        utterances.forEach(synth.speak)
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

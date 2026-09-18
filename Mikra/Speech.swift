import AVFoundation

enum Speech {
    private static let synth = AVSpeechSynthesizer()

    static func say(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "he-IL")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        synth.speak(u)
    }
}

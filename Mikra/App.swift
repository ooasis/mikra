import AVFoundation
import SwiftUI

@main
struct MikraApp: App {
    @StateObject private var store = Store()

    init() {
        #if DEBUG
        storeSelfCheck()
        speechSelfCheck()
        textsSelfCheck()
        wordDeckSelfCheck()
        grammarSelfCheck()
        pronounceSelfCheck()
        zhSelfCheck()
        if ProcessInfo.processInfo.arguments.contains("-wedgeTest") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Speech.wedgeTest() }
        }
        if ProcessInfo.processInfo.arguments.contains("-listVoices") {
            for v in AVSpeechSynthesisVoice.speechVoices() where v.language.hasPrefix("he") {
                print("voice: \(v.name) \(v.identifier) quality=\(v.quality.rawValue) gender=\(v.gender.rawValue)")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-rateSamples") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Speech.rateSamples() }
        }
        assert(decks.map(\.id) == ["pronouns", "numbers", "small"], "Decks.json should bundle Pronouns, Numbers, Small words")
        assert(book(named: "Jonah").verses.count == 48, "Texts should bundle 48 Jonah verses")
        assert(book(named: "Genesis").verses.count == 1533, "Texts should bundle all of Genesis")
        assert(book(named: "Psalms").verses.count == 2527, "Texts should bundle all 150 psalms")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .tint(Theme.accent) // Nocturne: links, toggles and pickers take the accent
                .preferredColorScheme(store.appearance.scheme)
        }
    }
}

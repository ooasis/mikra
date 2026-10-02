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
        assert(decks.map(\.id) == ["pronouns", "numbers", "small"], "Decks.json should bundle Pronouns, Numbers, Small words")
        assert(book(named: "Jonah").verses.count == 48, "Texts.json should bundle 48 Jonah verses")
        assert(book(named: "Genesis").verses.count == 31, "Texts.json should bundle Genesis 1")
        assert(book(named: "Psalms").verses.count == 41, "Texts.json should bundle 5 psalms")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.scheme)
        }
    }
}

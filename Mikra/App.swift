import SwiftUI

@main
struct MikraApp: App {
    @StateObject private var store = Store()

    init() {
        #if DEBUG
        srsSelfCheck()
        assert(jonahVerses.count == 48, "Jonah.json should bundle 48 verses")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}

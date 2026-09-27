import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// nil follows the device.
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Global preferences, kept in the Store's save file alongside progress.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: Binding(get: { store.appearance },
                                                        set: { store.setAppearance($0) })) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker("Reading speed", selection: Binding(get: { store.pace },
                                                           set: { store.setPace($0) })) {
                    ForEach(Pace.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Button("Hear a sample") { Speech.say(words: ["בְּרֵאשִׁית", "בָּרָא", "אֱלֹהִים"]) }
            } header: {
                Text("Reading speed")
            } footer: {
                Text("Slow and Slower read a verse one word at a time, with a pause after each.")
            }
            Section {
                Button("Reset all progress", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { store.resetAll() }
        } message: {
            Text("Deletes all drill history, verse progress, and your streak. This cannot be undone.")
        }
    }
}

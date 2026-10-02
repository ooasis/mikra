import SwiftUI
import PhotosUI
import Vision
import VisionKit

/// Scan handwritten or printed notes: the Hebrew words Mikra already knows become a new set.
/// Words it does not know are listed greyed out — nothing is made up from OCR.
struct ScanView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var camera = false
    @State private var working = false
    @State private var hits: [ScanHit]?
    @State private var chosen: Set<String> = []
    @State private var target = "" // id of the set to add to; "" means a new set

    private var targetSet: WordSet? { store.sets.first { $0.id == target } }

    var body: some View {
        List {
            if let hits {
                let known = hits.filter { $0.card != nil }
                let unknown = hits.filter { $0.card == nil }
                if hits.isEmpty { Text("No text found. Try a sharper, closer photo.").foregroundStyle(.secondary) }
                if !store.sets.isEmpty && !known.isEmpty {
                    Picker("Add to", selection: $target) {
                        Text("New set").tag("")
                        ForEach(store.sets) { Text($0.name).tag($0.id) }
                    }
                }
                ForEach(known) { hit in
                    let card = hit.card!
                    let present = targetSet?.ids.contains(card.id) == true
                    Toggle(isOn: Binding(
                        get: { chosen.contains(card.id) },
                        set: { if $0 { chosen.insert(card.id) } else { chosen.remove(card.id) } }
                    )) {
                        HStack {
                            Text(present ? "already in set" : tr(card.g)).foregroundStyle(.secondary)
                            Spacer()
                            Text(pointed(card.h)).font(.system(size: 32))
                        }
                        .opacity(present ? 0.4 : 1)
                    }
                    .disabled(present)
                }
                if !unknown.isEmpty { // what was read but not matched, so a bad scan shows itself
                    Section("Not in Mikra's words") {
                        Text(unknown.map(\.token).joined(separator: "  ")).foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Button { camera = true } label: { Label("Take photo", systemImage: "camera") }
                        .disabled(!VNDocumentCameraViewController.isSupported)
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo", systemImage: "photo") }
                    Button { show(matchWords(in: UIPasteboard.general.string ?? "")) } label: {
                        Label("Paste copied text", systemImage: "doc.on.clipboard")
                    }
                } footer: {
                    Text("Photograph a word list in English, 中文 or Hebrew, or paste copied text. Each word Mikra knows becomes a card in a new set.")
                }
            }
        }
        .onChange(of: target) { // what the set already holds is not offered again
            chosen = Set((hits ?? []).compactMap(\.card?.id)).subtracting(targetSet?.ids ?? [])
        }
        .navigationTitle("Scan notes")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if working { ProgressView("Reading…") } }
        .toolbar {
            if hits != nil {
                Button(targetSet == nil ? "Create set (\(chosen.count))" : "Add (\(chosen.count))") {
                    let setID = targetSet?.id ?? store.createSet(named: "").id
                    chosen.sorted { a, b in // keep the order they appear on the page
                        (hits!.firstIndex { $0.card?.id == a } ?? 0) < (hits!.firstIndex { $0.card?.id == b } ?? 0)
                    }.forEach { store.toggle($0, in: setID) }
                    dismiss()
                }
                .disabled(chosen.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $camera) { DocumentCamera { read($0) }.ignoresSafeArea() }
        .onChange(of: photo) {
            guard let photo else { return }
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    read([img])
                }
            }
        }
        #if DEBUG
        .onAppear { // -scan=<png path>: OCR a file instead of the camera, for simulator tests
            let args = ProcessInfo.processInfo.arguments
            if let a = args.first(where: { $0.hasPrefix("-scan=") }), let img = UIImage(contentsOfFile: String(a.dropFirst(6))) {
                read([img])
            } else if let a = args.first(where: { $0.hasPrefix("-scanText=") }) {
                if let n = args.first(where: { $0.hasPrefix("-toSet=") }),
                   let set = store.sets.first(where: { $0.name == String(n.dropFirst(7)) }) { target = set.id }
                show(matchWords(in: String(a.dropFirst(10))))
            }
        }
        #endif
    }

    private func read(_ images: [UIImage]) {
        working = true
        Task {
            let text = await Task.detached { // OCR takes seconds: off the main thread
                var text = ""
                for img in images { text += " " + (await recognizeText(img)) }
                return text
            }.value
            show(matchWords(in: text))
        }
    }

    private func show(_ found: [ScanHit]) {
        hits = found
        chosen = Set(found.compactMap(\.card?.id)).subtracting(targetSet?.ids ?? [])
        working = false
    }
}

struct ScanHit: Identifiable {
    let token: String
    let card: WordCard?
    var id: String { token + (card?.id ?? "") }
}

/// Live Text first — the engine behind text selection in Photos, which the user has seen
/// read Hebrew — then the Vision OCR request, which may not have a Hebrew model.
func recognizeText(_ image: UIImage) async -> String {
    if ImageAnalyzer.isSupported,
       let analysis = try? await ImageAnalyzer().analyze(image, configuration: .init([.text])),
       !analysis.transcript.isEmpty {
        #if DEBUG
        print("Live Text languages \(ImageAnalyzer.supportedTextRecognitionLanguages) → \(analysis.transcript)")
        #endif
        return analysis.transcript
    }
    guard let cg = image.cgImage else { return "" }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.automaticallyDetectsLanguage = true
    let supported = (try? req.supportedRecognitionLanguages()) ?? []
    // Hebrew has no Vision model as of iOS 26; English and Chinese glosses are the reliable route
    req.recognitionLanguages = ["zh-Hans", "en-US"] + supported.filter { $0.hasPrefix("he") }
    try? VNImageRequestHandler(cgImage: cg).perform([req])
    let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    #if DEBUG
    print("OCR languages \(supported) → \(lines)")
    #endif
    return lines.joined(separator: " ")
}

/// Every word of the text that names a card: Hebrew by its consonants, English or Chinese
/// by gloss. Vision reads English and Chinese well, so a glossary in either finds its Hebrew.
func matchWords(in text: String) -> [ScanHit] {
    var seen: Set<String> = []
    var hits: [ScanHit] = []
    func add(_ token: String, _ card: WordCard?) {
        let key = card?.id ?? (skeleton(token).isEmpty ? token : skeleton(token)) // pointed variants are one
        if seen.insert(key).inserted { hits.append(ScanHit(token: token, card: card)) }
    }
    for phrase in text.components(separatedBy: CharacterSet(charactersIn: ",;:/()\n\r\t•·、，；：（）0123456789")) {
        let p = phrase.trimmingCharacters(in: .whitespaces).lowercased()
        guard !p.isEmpty else { continue }
        if let card = cardByGloss[p] { add(p, card); continue } // "to say", "all, every" as written
        for word in p.split(separator: " ").map(String.init) {
            let key = skeleton(word)
            if key.count > 1 { add(word, wordCardBySkeleton[key]) } // one-letter bits are OCR noise
            else if word.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
                // a space-separated chunk is one phrase; only when it is not a gloss itself
                // are longer glosses looked for inside it — single characters would match anywhere
                if let card = cardByGloss[word] { add(word, card) } else {
                    let inside = cardByGloss.filter { $0.key.count > 1 && word.contains($0.key) }
                    inside.forEach { add($0.key, $0.value) }
                    if inside.isEmpty { add(word, nil) }
                }
            } else if word.count > 1 { add(word, cardByGloss[word]) }
        }
    }
    return hits
}

/// Every gloss term, English (lowercased, with and without "to ") and Chinese, by card.
let cardByGloss: [String: WordCard] = {
    var d: [String: WordCard] = [:]
    for card in wordDeck + decks.flatMap(\.cards) {
        var terms = [card.g.lowercased()]
        terms += card.g.lowercased().components(separatedBy: ", ")
        terms += terms.compactMap { $0.hasPrefix("to ") ? String($0.dropFirst(3)) : nil }
        if let zh = Zh.strings[card.g] { terms += [zh] + zh.components(separatedBy: "、") }
        for t in terms where d[t] == nil { d[t] = card }
    }
    return d
}()

/// Consonants only — the stable part of a Hebrew word across pointed, unpointed, and scanned forms.
func skeleton(_ hebrew: String) -> String {
    String(String.UnicodeScalarView(hebrew.unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) }))
}

/// Every form of every card, by consonants; the first (most frequent) card wins a homograph.
let wordCardBySkeleton: [String: WordCard] = {
    var d: [String: WordCard] = [:]
    for card in wordDeck + decks.flatMap(\.cards) {
        for unit in card.units where d[skeleton(unit.h)] == nil { d[skeleton(unit.h)] = card }
    }
    return d
}()

/// The system document scanner: finds the page, straightens it, hands back the pages.
struct DocumentCamera: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCamera
        init(_ parent: DocumentCamera) { self.parent = parent }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.dismiss()
            parent.done((0 ..< scan.pageCount).map(scan.imageOfPage))
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { parent.dismiss() }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) { parent.dismiss() }
    }
}

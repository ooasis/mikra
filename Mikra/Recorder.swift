import AVFoundation

/// Records the reader saying a verse and plays it back. One take per verse,
/// kept in Caches; a new take overwrites the last.
final class Recorder: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    static let shared = Recorder()

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    static func url(for verse: Verse) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("take-\(verse.id).m4a")
    }

    static func hasTake(for verse: Verse) -> Bool {
        FileManager.default.fileExists(atPath: url(for: verse).path)
    }

    func record(_ verse: Verse) {
        stop()
        Speech.stop()
        AVAudioSession.sharedInstance().requestRecordPermission { [self] ok in
            guard ok else { return }
            DispatchQueue.main.async { [self] in
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try? session.setActive(true)
                recorder = try? AVAudioRecorder(url: Self.url(for: verse), settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                ])
                recorder?.delegate = self
                isRecording = recorder?.record() ?? false
            }
        }
    }

    func play(_ verse: Verse) {
        stop()
        Speech.stop()
        player = try? AVAudioPlayer(contentsOf: Self.url(for: verse))
        player?.delegate = self
        isPlaying = player?.play() ?? false
    }

    func stop() {
        recorder?.stop(); recorder = nil; isRecording = false
        player?.stop(); player = nil; isPlaying = false
    }

    func audioRecorderDidFinishRecording(_ r: AVAudioRecorder, successfully flag: Bool) { isRecording = false }
    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) { isPlaying = false }
}

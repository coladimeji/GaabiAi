import Foundation
import AVFoundation
import Speech

@MainActor
class VoiceManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordings: [Recording] = []
    @Published var permissionGranted = false
    
    private var audioRecorder: AVAudioRecorder?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = status == .authorized
            }
        }
    }
    
    func startRecording() {
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let url = audioRecorder?.url {
            let recording = Recording(
                id: UUID(),
                fileURL: url,
                createdAt: Date()
            )
            recordings.append(recording)
            transcribeAudio(url: url) { [weak self] transcription in
                if let transcription = transcription {
                    DispatchQueue.main.async {
                        if let index = self?.recordings.firstIndex(where: { $0.fileURL == url }) {
                            self?.recordings[index].transcription = transcription
                        }
                    }
                }
            }
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            do {
                try FileManager.default.removeItem(at: recording.fileURL)
                recordings.remove(at: index)
            } catch {
                print("Error deleting recording: \(error)")
            }
        }
    }
    
    private func transcribeAudio(url: URL, completion: @escaping (String?) -> Void) {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            completion(nil)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { result, error in
            guard error == nil else {
                completion(nil)
                return
            }
            
            if let result = result {
                completion(result.bestTranscription.formattedString)
            }
        }
    }
}

// MARK: - Supporting Types
struct Recording: Identifiable {
    let id: UUID
    let fileURL: URL
    let createdAt: Date
    var transcription: String?
    
    var duration: TimeInterval {
        if let audio = try? AVAudioFile(forReading: fileURL) {
            return Double(audio.length) / audio.processingFormat.sampleRate
        }
        return 0
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 
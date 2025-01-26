import Foundation
import AVFoundation
import Speech

struct VoiceNote: Identifiable, Codable {
    let id: UUID
    var title: String
    var recordingDate: Date
    var duration: TimeInterval
    var transcription: String?
    var tags: Set<String>
    var category: VoiceNoteCategory
    var location: CLLocationCoordinate2D?
    var fileURL: URL
    var isProcessed: Bool
    var associatedTasks: [UUID]?
    
    enum VoiceNoteCategory: String, Codable {
        case memo, meeting, reminder, idea, task
    }
}

actor VoiceRecordingManager {
    private var audioEngine: AVAudioEngine?
    private var audioSession: AVAudioSession
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recordingURL: URL?
    private var isRecording = false
    
    init() {
        audioSession = AVAudioSession.sharedInstance()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func startRecording() async throws -> URL {
        guard !isRecording else { throw RecordingError.alreadyRecording }
        
        try await setupAudioSession()
        let fileURL = try createAudioFile()
        try await setupAudioEngine(outputURL: fileURL)
        
        isRecording = true
        recordingURL = fileURL
        return fileURL
    }
    
    func stopRecording() async throws -> VoiceNote {
        guard isRecording else { throw RecordingError.notRecording }
        
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        
        try await audioSession.setActive(false)
        isRecording = false
        
        guard let url = recordingURL else {
            throw RecordingError.noRecordingURL
        }
        
        return VoiceNote(
            id: UUID(),
            title: "Voice Note \(Date())",
            recordingDate: Date(),
            duration: try await getAudioDuration(url: url),
            transcription: nil,
            tags: [],
            category: .memo,
            location: nil,
            fileURL: url,
            isProcessed: false
        )
    }
    
    func transcribeAudio(for note: VoiceNote) async throws -> String {
        let recognizer = SFSpeechRecognizer()
        guard recognizer?.isAvailable == true else {
            throw RecordingError.speechRecognitionUnavailable
        }
        
        let request = SFSpeechURLRecognitionRequest(url: note.fileURL)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else {
                    continuation.resume(throwing: RecordingError.transcriptionFailed)
                }
            }
        }
    }
    
    private func setupAudioSession() async throws {
        try await audioSession.setCategory(.playAndRecord, mode: .default)
        try await audioSession.setActive(true)
    }
    
    private func createAudioFile() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let audioFile = try AVAudioFile(forWriting: audioFilename, settings: settings)
        return audioFilename
    }
    
    private func setupAudioEngine(outputURL: URL) async throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecordingError.audioEngineSetupFailed
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        return try await asset.load(.duration).seconds
    }
}

enum RecordingError: Error {
    case alreadyRecording
    case notRecording
    case noRecordingURL
    case audioEngineSetupFailed
    case speechRecognitionUnavailable
    case transcriptionFailed
    
    var localizedDescription: String {
        switch self {
        case .alreadyRecording:
            return "Already recording a voice note"
        case .notRecording:
            return "No active recording to stop"
        case .noRecordingURL:
            return "Recording URL not found"
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        }
    }
} 
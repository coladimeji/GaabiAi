import Foundation
import AVFoundation
import Speech

class VoiceManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine,
              let recognitionRequest = recognitionRequest else {
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        do {
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if error != nil {
                    self.stopRecording()
                }
            }
            
            isRecording = true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        // Save recording URL if needed
        // recordingURL = savedFileURL
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition authorization denied")
                case .restricted:
                    print("Speech recognition restricted on this device")
                case .notDetermined:
                    print("Speech recognition not yet authorized")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
    }
} 
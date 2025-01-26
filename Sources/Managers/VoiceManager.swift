import Foundation
import AVFoundation
import Speech

class VoiceManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioRecorder: AVAudioRecorder?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var recordingURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingError: Error?
    
    private var timer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
        requestPermissions()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                default:
                    print("Speech recognition authorization denied")
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Recording permission granted")
                } else {
                    print("Recording permission denied")
                }
            }
        }
    }
    
    func startRecording() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let audioFilename = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            recordingURL = audioFilename
            isRecording = true
            recordingDuration = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
            
            startTranscribing()
        } catch {
            recordingError = error
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        stopTranscribing()
    }
    
    private func startTranscribing() {
        guard let recognizer = speechRecognizer,
              recognizer.isAvailable else { return }
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            
            if error != nil {
                self.stopTranscribing()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func stopTranscribing() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}

extension VoiceManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording failed"])
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            recordingError = error
        }
    }
} 
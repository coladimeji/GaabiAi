import Foundation
import AVFoundation
import Speech

class VoiceNoteViewModel: NSObject, ObservableObject {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var transcriptionStatus: TranscriptionStatus = .idle
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let aiService: AIService
    private let weatherService: WeatherService
    private let trafficService: TrafficService
    
    enum TranscriptionStatus {
        case idle
        case transcribing
        case analyzing
        case finished
        case error(String)
    }
    
    init(
        aiService: AIService,
        weatherService: WeatherService,
        trafficService: TrafficService
    ) {
        self.aiService = aiService
        self.weatherService = weatherService
        self.trafficService = trafficService
        super.init()
        loadVoiceNotes()
        setupAudioSession()
        requestPermissions()
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordingTime += 1
            }
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        if let url = audioRecorder?.url {
            processVoiceNote(url: url)
        }
    }
    
    private func processVoiceNote(url: URL) {
        transcriptionStatus = .transcribing
        
        transcribeAudio(url: url) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transcript):
                self.transcriptionStatus = .analyzing
                
                Task {
                    do {
                        let analysis = try await self.aiService.analyzeTranscript(transcript)
                        let voiceNote = VoiceNote(
                            title: analysis.summary ?? "New Voice Note",
                            audioURL: url,
                            transcript: transcript,
                            duration: self.recordingTime,
                            aiAnalysis: analysis
                        )
                        
                        if let date = self.extractDate(from: transcript) {
                            await self.enrichWithContextualData(voiceNote: voiceNote, for: date)
                        }
                        
                        DispatchQueue.main.async {
                            self.voiceNotes.append(voiceNote)
                            self.saveVoiceNotes()
                            self.transcriptionStatus = .finished
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.transcriptionStatus = .error(error.localizedDescription)
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.transcriptionStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func transcribeAudio(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        
        speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let result = result {
                completion(.success(result.bestTranscription.formattedString))
            }
        }
    }
    
    private func enrichWithContextualData(voiceNote: VoiceNote, for date: Date) async {
        var updatedAnalysis = voiceNote.aiAnalysis ?? AIAnalysis(
            actionItems: [],
            sentiment: .neutral,
            keywords: [],
            categories: [],
            suggestedTasks: []
        )
        
        // Add weather context
        if let weather = await weatherService.getForecast(for: date) {
            updatedAnalysis.weatherContext = weather
        }
        
        // Add traffic context
        if let traffic = await trafficService.getTrafficInfo(for: date) {
            updatedAnalysis.trafficContext = traffic
        }
        
        var updatedNote = voiceNote
        updatedNote.aiAnalysis = updatedAnalysis
        
        DispatchQueue.main.async {
            if let index = self.voiceNotes.firstIndex(where: { $0.id == voiceNote.id }) {
                self.voiceNotes[index] = updatedNote
                self.saveVoiceNotes()
            }
        }
    }
    
    private func extractDate(from transcript: String) -> Date? {
        // Use natural language processing to extract date
        // This is a simplified example
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: transcript, options: [], range: NSRange(location: 0, length: transcript.utf16.count))
        return matches?.first?.date
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadVoiceNotes() {
        if let data = UserDefaults.standard.data(forKey: "voiceNotes"),
           let decodedNotes = try? JSONDecoder().decode([VoiceNote].self, from: data) {
            voiceNotes = decodedNotes
        }
    }
    
    private func saveVoiceNotes() {
        if let encoded = try? JSONEncoder().encode(voiceNotes) {
            UserDefaults.standard.set(encoded, forKey: "voiceNotes")
        }
    }
}

extension VoiceNoteViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            transcriptionStatus = .error("Recording failed")
        }
    }
} 
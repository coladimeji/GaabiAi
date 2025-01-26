import Foundation
import Speech
import Vapor

enum VoiceCommandType {
    case createTask
    case completeTask
    case createHabit
    case setReminder
    case searchNotes
    case unknown
}

struct VoiceCommand {
    let type: VoiceCommandType
    let parameters: [String: Any]
}

final class VoiceRecognitionService {
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private let taskRepository: TaskRepository
    private let habitRepository: HabitRepository
    private let voiceNoteRepository: VoiceNoteRepository
    
    init(taskRepository: TaskRepository, habitRepository: HabitRepository, voiceNoteRepository: VoiceNoteRepository) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.audioEngine = AVAudioEngine()
        self.taskRepository = taskRepository
        self.habitRepository = habitRepository
        self.voiceNoteRepository = voiceNoteRepository
    }
    
    // Start voice recognition session
    func startRecognition() async throws -> AsyncStream<String> {
        try await requestAuthorization()
        
        return AsyncStream { continuation in
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try? audioEngine.start()
            
            speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    continuation.yield(result.bestTranscription.formattedString)
                }
                if error != nil || result?.isFinal == true {
                    continuation.finish()
                }
            }
        }
    }
    
    // Stop voice recognition
    func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // Parse voice command from transcription
    func parseCommand(_ transcription: String) -> VoiceCommand {
        let lowercased = transcription.lowercased()
        
        // Create task command
        if lowercased.hasPrefix("create task") {
            let taskDescription = String(transcription.dropFirst(11).trimmingCharacters(in: .whitespaces))
            return VoiceCommand(type: .createTask, parameters: ["description": taskDescription])
        }
        
        // Complete task command
        if lowercased.hasPrefix("complete task") {
            let taskDescription = String(transcription.dropFirst(13).trimmingCharacters(in: .whitespaces))
            return VoiceCommand(type: .completeTask, parameters: ["description": taskDescription])
        }
        
        // Create habit command
        if lowercased.hasPrefix("create habit") {
            let habitDescription = String(transcription.dropFirst(12).trimmingCharacters(in: .whitespaces))
            return VoiceCommand(type: .createHabit, parameters: ["description": habitDescription])
        }
        
        // Set reminder command
        if lowercased.hasPrefix("set reminder") {
            let reminderText = String(transcription.dropFirst(12).trimmingCharacters(in: .whitespaces))
            return VoiceCommand(type: .setReminder, parameters: ["text": reminderText])
        }
        
        // Search notes command
        if lowercased.hasPrefix("search notes") {
            let searchQuery = String(transcription.dropFirst(12).trimmingCharacters(in: .whitespaces))
            return VoiceCommand(type: .searchNotes, parameters: ["query": searchQuery])
        }
        
        return VoiceCommand(type: .unknown, parameters: [:])
    }
    
    // Execute voice command
    func executeCommand(_ command: VoiceCommand, for userId: String) async throws {
        switch command.type {
        case .createTask:
            if let description = command.parameters["description"] as? String {
                let task = Task(
                    id: UUID().uuidString,
                    userId: userId,
                    description: description,
                    isCompleted: false,
                    createdAt: Date()
                )
                try await taskRepository.create(task)
            }
            
        case .completeTask:
            if let description = command.parameters["description"] as? String {
                if let task = try await taskRepository.findOne(where: ["userId": userId, "description": description]) {
                    try await taskRepository.markAsComplete(task.id, userId: userId)
                }
            }
            
        case .createHabit:
            if let description = command.parameters["description"] as? String {
                let habit = Habit(
                    id: UUID().uuidString,
                    userId: userId,
                    description: description,
                    frequency: "daily",
                    createdAt: Date()
                )
                try await habitRepository.create(habit)
            }
            
        case .setReminder:
            if let text = command.parameters["text"] as? String {
                // Parse reminder text for date/time and create reminder
                // This would require natural language date parsing
            }
            
        case .searchNotes:
            if let query = command.parameters["query"] as? String {
                _ = try await voiceNoteRepository.searchTranscriptions(userId: userId, query: query)
            }
            
        case .unknown:
            throw Abort(.badRequest, reason: "Unknown voice command")
        }
    }
    
    private func requestAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized else {
            throw Abort(.forbidden, reason: "Speech recognition not authorized")
        }
    }
} 
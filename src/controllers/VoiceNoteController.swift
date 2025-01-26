import Foundation
import Vapor
import MongoDBVapor

struct VoiceNoteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let voiceNotes = routes.grouped("api", "voice-notes")
            .grouped(UserAuthMiddleware())
        
        voiceNotes.get(use: getAllVoiceNotes)
        voiceNotes.post(use: createVoiceNote)
        voiceNotes.get(":noteId", use: getVoiceNote)
        voiceNotes.put(":noteId", use: updateVoiceNote)
        voiceNotes.delete(":noteId", use: deleteVoiceNote)
        voiceNotes.get("analytics", use: getVoiceNoteAnalytics)
        voiceNotes.post(":noteId", "process", use: processVoiceNote)
    }
    
    // MARK: - Route Handlers
    
    func getAllVoiceNotes(req: Request) async throws -> [VoiceNoteResponse] {
        let user = try req.auth.require(User.self)
        let notes = try await VoiceNote.query(on: req.db)
            .filter(\.$userId == user._id!)
            .sort(\.$createdAt, .descending)
            .all()
        
        return try notes.map { try VoiceNoteResponse(note: $0) }
    }
    
    func createVoiceNote(req: Request) async throws -> VoiceNoteResponse {
        let user = try req.auth.require(User.self)
        let createRequest = try req.content.decode(CreateVoiceNoteRequest.self)
        
        let note = VoiceNote(
            userId: user._id!,
            title: createRequest.title,
            transcription: createRequest.transcription,
            audioFileURL: createRequest.audioFileURL,
            duration: createRequest.duration,
            tags: createRequest.tags ?? [],
            category: createRequest.category
        )
        
        try await note.save(on: req.db)
        return try VoiceNoteResponse(note: note)
    }
    
    func getVoiceNote(req: Request) async throws -> VoiceNoteResponse {
        let user = try req.auth.require(User.self)
        guard let noteId = try? BSONObjectID(string: req.parameters.get("noteId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid note ID")
        }
        
        guard let note = try await VoiceNote.query(on: req.db)
            .filter(\.$_id == noteId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        return try VoiceNoteResponse(note: note)
    }
    
    func updateVoiceNote(req: Request) async throws -> VoiceNoteResponse {
        let user = try req.auth.require(User.self)
        guard let noteId = try? BSONObjectID(string: req.parameters.get("noteId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid note ID")
        }
        
        guard let note = try await VoiceNote.query(on: req.db)
            .filter(\.$_id == noteId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        let updateRequest = try req.content.decode(UpdateVoiceNoteRequest.self)
        
        note.title = updateRequest.title ?? note.title
        note.transcription = updateRequest.transcription ?? note.transcription
        note.tags = updateRequest.tags ?? note.tags
        note.category = updateRequest.category ?? note.category
        note.actionItems = updateRequest.actionItems ?? note.actionItems
        note.updatedAt = Date()
        
        try await note.save(on: req.db)
        return try VoiceNoteResponse(note: note)
    }
    
    func deleteVoiceNote(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        guard let noteId = try? BSONObjectID(string: req.parameters.get("noteId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid note ID")
        }
        
        guard let note = try await VoiceNote.query(on: req.db)
            .filter(\.$_id == noteId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Delete associated audio file if exists
        if let audioFileURL = note.audioFileURL {
            // Implement file deletion logic here
        }
        
        try await note.delete(on: req.db)
        return .noContent
    }
    
    func processVoiceNote(req: Request) async throws -> VoiceNoteResponse {
        let user = try req.auth.require(User.self)
        guard let noteId = try? BSONObjectID(string: req.parameters.get("noteId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid note ID")
        }
        
        guard let note = try await VoiceNote.query(on: req.db)
            .filter(\.$_id == noteId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Process transcription with AI to extract action items
        let actionItems = try await processTranscription(note.transcription)
        note.actionItems = actionItems
        note.updatedAt = Date()
        
        try await note.save(on: req.db)
        return try VoiceNoteResponse(note: note)
    }
    
    func getVoiceNoteAnalytics(req: Request) async throws -> VoiceNoteAnalytics {
        let user = try req.auth.require(User.self)
        let notes = try await VoiceNote.query(on: req.db)
            .filter(\.$userId == user._id!)
            .all()
        
        var notesByCategory: [VoiceNoteCategory: Int] = [:]
        var mostUsedTags: [String: Int] = [:]
        var totalDuration: TimeInterval = 0
        var completedActionItems = 0
        var totalActionItems = 0
        
        for note in notes {
            notesByCategory[note.category, default: 0] += 1
            totalDuration += note.duration
            
            for tag in note.tags {
                mostUsedTags[tag, default: 0] += 1
            }
            
            for item in note.actionItems {
                totalActionItems += 1
                if item.isCompleted {
                    completedActionItems += 1
                }
            }
        }
        
        let actionItemCompletion = totalActionItems == 0 ? 0 : Double(completedActionItems) / Double(totalActionItems)
        let averageDuration = notes.isEmpty ? 0 : totalDuration / Double(notes.count)
        
        return VoiceNoteAnalytics(
            totalNotes: notes.count,
            totalDuration: totalDuration,
            notesByCategory: notesByCategory,
            averageDuration: averageDuration,
            mostUsedTags: mostUsedTags,
            actionItemCompletion: actionItemCompletion
        )
    }
    
    // MARK: - Helper Methods
    
    private func processTranscription(_ transcription: String) async throws -> [ActionItem] {
        // Implement AI processing logic here
        // This should analyze the transcription and extract action items
        return []
    }
}

// MARK: - Request DTOs

struct CreateVoiceNoteRequest: Content {
    let title: String
    let transcription: String
    let audioFileURL: String?
    let duration: TimeInterval
    let tags: [String]?
    let category: VoiceNoteCategory
}

struct UpdateVoiceNoteRequest: Content {
    let title: String?
    let transcription: String?
    let tags: [String]?
    let category: VoiceNoteCategory?
    let actionItems: [ActionItem]?
}

// MARK: - Response DTOs

struct VoiceNoteResponse: Content {
    let id: String
    let title: String
    let transcription: String
    let audioFileURL: String?
    let duration: TimeInterval
    let tags: [String]
    let category: VoiceNoteCategory
    let actionItems: [ActionItem]
    let createdAt: Date
    let updatedAt: Date
    
    init(note: VoiceNote) throws {
        self.id = note._id?.hex ?? ""
        self.title = note.title
        self.transcription = note.transcription
        self.audioFileURL = note.audioFileURL
        self.duration = note.duration
        self.tags = note.tags
        self.category = note.category
        self.actionItems = note.actionItems
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
    }
} 
import Foundation
import MongoDBVapor
import Vapor

final class VoiceNote: Content {
    var _id: BSONObjectID?
    var userId: BSONObjectID
    var title: String
    var transcription: String
    var audioFileURL: String?
    var duration: TimeInterval
    var tags: [String]
    var category: VoiceNoteCategory
    var actionItems: [ActionItem]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: BSONObjectID? = nil,
         userId: BSONObjectID,
         title: String,
         transcription: String,
         audioFileURL: String? = nil,
         duration: TimeInterval = 0,
         tags: [String] = [],
         category: VoiceNoteCategory = .note,
         actionItems: [ActionItem] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self._id = id
        self.userId = userId
        self.title = title
        self.transcription = transcription
        self.audioFileURL = audioFileURL
        self.duration = duration
        self.tags = tags
        self.category = category
        self.actionItems = actionItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum VoiceNoteCategory: String, Content, CaseIterable {
    case note
    case reminder
    case task
    case idea
    case meeting
    case custom
}

struct ActionItem: Content {
    var text: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: TaskPriority?
    
    init(text: String,
         isCompleted: Bool = false,
         dueDate: Date? = nil,
         priority: TaskPriority? = nil) {
        self.text = text
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
    }
}

// Voice Note Analytics
struct VoiceNoteAnalytics: Content {
    var totalNotes: Int
    var totalDuration: TimeInterval
    var notesByCategory: [VoiceNoteCategory: Int]
    var averageDuration: TimeInterval
    var mostUsedTags: [String: Int]
    var actionItemCompletion: Double
    
    init(totalNotes: Int = 0,
         totalDuration: TimeInterval = 0,
         notesByCategory: [VoiceNoteCategory: Int] = [:],
         averageDuration: TimeInterval = 0,
         mostUsedTags: [String: Int] = [:],
         actionItemCompletion: Double = 0) {
        self.totalNotes = totalNotes
        self.totalDuration = totalDuration
        self.notesByCategory = notesByCategory
        self.averageDuration = averageDuration
        self.mostUsedTags = mostUsedTags
        self.actionItemCompletion = actionItemCompletion
    }
} 
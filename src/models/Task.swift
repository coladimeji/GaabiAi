import Foundation
import MongoDBVapor
import Vapor

final class Task: Content {
    var _id: BSONObjectID?
    var userId: BSONObjectID
    var title: String
    var description: String?
    var dueDate: Date
    var priority: TaskPriority
    var status: TaskStatus
    var tags: [String]
    var location: Location?
    var reminderTime: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: BSONObjectID? = nil,
         userId: BSONObjectID,
         title: String,
         description: String? = nil,
         dueDate: Date,
         priority: TaskPriority = .medium,
         status: TaskStatus = .pending,
         tags: [String] = [],
         location: Location? = nil,
         reminderTime: Date? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self._id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.tags = tags
        self.location = location
        self.reminderTime = reminderTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum TaskPriority: String, Content {
    case low
    case medium
    case high
    case urgent
}

enum TaskStatus: String, Content {
    case pending
    case inProgress
    case completed
    case cancelled
    case delayed
}

// Task Analytics
struct TaskAnalytics: Content {
    var completionRate: Double
    var averageCompletionTime: TimeInterval
    var tasksByPriority: [TaskPriority: Int]
    var tasksByStatus: [TaskStatus: Int]
    var tasksByTag: [String: Int]
    
    init(completionRate: Double = 0,
         averageCompletionTime: TimeInterval = 0,
         tasksByPriority: [TaskPriority: Int] = [:],
         tasksByStatus: [TaskStatus: Int] = [:],
         tasksByTag: [String: Int] = [:]) {
        self.completionRate = completionRate
        self.averageCompletionTime = averageCompletionTime
        self.tasksByPriority = tasksByPriority
        self.tasksByStatus = tasksByStatus
        self.tasksByTag = tasksByTag
    }
} 
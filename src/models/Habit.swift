import Foundation
import MongoDBVapor
import Vapor

final class Habit: Content {
    var _id: BSONObjectID?
    var userId: BSONObjectID
    var title: String
    var description: String?
    var frequency: HabitFrequency
    var targetDays: Set<Weekday>
    var timeOfDay: Date?
    var streak: Int
    var totalCompletions: Int
    var lastCompletedDate: Date?
    var startDate: Date
    var createdAt: Date
    var updatedAt: Date
    
    init(id: BSONObjectID? = nil,
         userId: BSONObjectID,
         title: String,
         description: String? = nil,
         frequency: HabitFrequency = .daily,
         targetDays: Set<Weekday> = Set(Weekday.allCases),
         timeOfDay: Date? = nil,
         streak: Int = 0,
         totalCompletions: Int = 0,
         lastCompletedDate: Date? = nil,
         startDate: Date = Date(),
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self._id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.frequency = frequency
        self.targetDays = targetDays
        self.timeOfDay = timeOfDay
        self.streak = streak
        self.totalCompletions = totalCompletions
        self.lastCompletedDate = lastCompletedDate
        self.startDate = startDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum HabitFrequency: String, Content, CaseIterable {
    case daily
    case weekly
    case monthly
    case custom
}

enum Weekday: Int, Content, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

// Habit Analytics
struct HabitAnalytics: Content {
    var completionRate: Double
    var currentStreak: Int
    var bestStreak: Int
    var totalCompletions: Int
    var completionsByDay: [Weekday: Int]
    var monthlyProgress: [String: Double] // YYYY-MM: completion rate
    
    init(completionRate: Double = 0,
         currentStreak: Int = 0,
         bestStreak: Int = 0,
         totalCompletions: Int = 0,
         completionsByDay: [Weekday: Int] = [:],
         monthlyProgress: [String: Double] = [:]) {
        self.completionRate = completionRate
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.totalCompletions = totalCompletions
        self.completionsByDay = completionsByDay
        self.monthlyProgress = monthlyProgress
    }
} 
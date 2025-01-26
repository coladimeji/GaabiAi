import Foundation
import Vapor
import MongoDBVapor

struct HabitController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let habits = routes.grouped("api", "habits")
            .grouped(UserAuthMiddleware())
        
        habits.get(use: getAllHabits)
        habits.post(use: createHabit)
        habits.get(":habitId", use: getHabit)
        habits.put(":habitId", use: updateHabit)
        habits.delete(":habitId", use: deleteHabit)
        habits.post(":habitId", "complete", use: markHabitComplete)
        habits.get("analytics", use: getHabitAnalytics)
    }
    
    // MARK: - Route Handlers
    
    func getAllHabits(req: Request) async throws -> [HabitResponse] {
        let user = try req.auth.require(User.self)
        let habits = try await Habit.query(on: req.db)
            .filter(\.$userId == user._id!)
            .sort(\.$startDate, .descending)
            .all()
        
        return try habits.map { try HabitResponse(habit: $0) }
    }
    
    func createHabit(req: Request) async throws -> HabitResponse {
        let user = try req.auth.require(User.self)
        let createRequest = try req.content.decode(CreateHabitRequest.self)
        
        let habit = Habit(
            userId: user._id!,
            title: createRequest.title,
            description: createRequest.description,
            frequency: createRequest.frequency,
            targetDays: createRequest.targetDays ?? Set(Weekday.allCases),
            timeOfDay: createRequest.timeOfDay
        )
        
        try await habit.save(on: req.db)
        return try HabitResponse(habit: habit)
    }
    
    func getHabit(req: Request) async throws -> HabitResponse {
        let user = try req.auth.require(User.self)
        guard let habitId = try? BSONObjectID(string: req.parameters.get("habitId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid habit ID")
        }
        
        guard let habit = try await Habit.query(on: req.db)
            .filter(\.$_id == habitId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        return try HabitResponse(habit: habit)
    }
    
    func updateHabit(req: Request) async throws -> HabitResponse {
        let user = try req.auth.require(User.self)
        guard let habitId = try? BSONObjectID(string: req.parameters.get("habitId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid habit ID")
        }
        
        guard let habit = try await Habit.query(on: req.db)
            .filter(\.$_id == habitId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        let updateRequest = try req.content.decode(UpdateHabitRequest.self)
        
        habit.title = updateRequest.title ?? habit.title
        habit.description = updateRequest.description ?? habit.description
        habit.frequency = updateRequest.frequency ?? habit.frequency
        habit.targetDays = updateRequest.targetDays ?? habit.targetDays
        habit.timeOfDay = updateRequest.timeOfDay ?? habit.timeOfDay
        habit.updatedAt = Date()
        
        try await habit.save(on: req.db)
        return try HabitResponse(habit: habit)
    }
    
    func deleteHabit(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        guard let habitId = try? BSONObjectID(string: req.parameters.get("habitId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid habit ID")
        }
        
        guard let habit = try await Habit.query(on: req.db)
            .filter(\.$_id == habitId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        try await habit.delete(on: req.db)
        return .noContent
    }
    
    func markHabitComplete(req: Request) async throws -> HabitResponse {
        let user = try req.auth.require(User.self)
        guard let habitId = try? BSONObjectID(string: req.parameters.get("habitId") ?? "") else {
            throw Abort(.badRequest, reason: "Invalid habit ID")
        }
        
        guard let habit = try await Habit.query(on: req.db)
            .filter(\.$_id == habitId)
            .filter(\.$userId == user._id!)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Update streak and completion data
        let today = Date()
        if let lastCompleted = habit.lastCompletedDate {
            let calendar = Calendar.current
            let daysBetween = calendar.numberOfDaysBetween(lastCompleted, and: today)
            
            if daysBetween <= 1 {
                habit.streak += 1
            } else {
                habit.streak = 1
            }
        } else {
            habit.streak = 1
        }
        
        habit.lastCompletedDate = today
        habit.totalCompletions += 1
        habit.updatedAt = today
        
        try await habit.save(on: req.db)
        return try HabitResponse(habit: habit)
    }
    
    func getHabitAnalytics(req: Request) async throws -> HabitAnalytics {
        let user = try req.auth.require(User.self)
        let habits = try await Habit.query(on: req.db)
            .filter(\.$userId == user._id!)
            .all()
        
        var completionsByDay: [Weekday: Int] = [:]
        var monthlyProgress: [String: Double] = [:]
        var bestStreak = 0
        var currentStreak = 0
        var totalCompletions = 0
        
        for habit in habits {
            bestStreak = max(bestStreak, habit.streak)
            currentStreak += habit.streak
            totalCompletions += habit.totalCompletions
            
            // Calculate completions by day
            if let lastCompleted = habit.lastCompletedDate {
                let weekday = Calendar.current.component(.weekday, from: lastCompleted)
                if let day = Weekday(rawValue: weekday) {
                    completionsByDay[day, default: 0] += 1
                }
            }
            
            // Calculate monthly progress
            if let lastCompleted = habit.lastCompletedDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM"
                let monthKey = dateFormatter.string(from: lastCompleted)
                monthlyProgress[monthKey, default: 0] += 1
            }
        }
        
        let completionRate = habits.isEmpty ? 0 : Double(totalCompletions) / Double(habits.count)
        
        return HabitAnalytics(
            completionRate: completionRate,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCompletions: totalCompletions,
            completionsByDay: completionsByDay,
            monthlyProgress: monthlyProgress
        )
    }
}

// MARK: - Request DTOs

struct CreateHabitRequest: Content {
    let title: String
    let description: String?
    let frequency: HabitFrequency
    let targetDays: Set<Weekday>?
    let timeOfDay: Date?
}

struct UpdateHabitRequest: Content {
    let title: String?
    let description: String?
    let frequency: HabitFrequency?
    let targetDays: Set<Weekday>?
    let timeOfDay: Date?
}

// MARK: - Response DTOs

struct HabitResponse: Content {
    let id: String
    let title: String
    let description: String?
    let frequency: HabitFrequency
    let targetDays: Set<Weekday>
    let timeOfDay: Date?
    let streak: Int
    let totalCompletions: Int
    let lastCompletedDate: Date?
    let startDate: Date
    let createdAt: Date
    let updatedAt: Date
    
    init(habit: Habit) throws {
        self.id = habit._id?.hex ?? ""
        self.title = habit.title
        self.description = habit.description
        self.frequency = habit.frequency
        self.targetDays = habit.targetDays
        self.timeOfDay = habit.timeOfDay
        self.streak = habit.streak
        self.totalCompletions = habit.totalCompletions
        self.lastCompletedDate = habit.lastCompletedDate
        self.startDate = habit.startDate
        self.createdAt = habit.createdAt
        self.updatedAt = habit.updatedAt
    }
}

// MARK: - Helper Extensions

extension Calendar {
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from)
        let toDate = startOfDay(for: to)
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate)
        
        return numberOfDays.day ?? 0
    }
} 
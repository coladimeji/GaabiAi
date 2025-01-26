import Foundation
import MongoDBVapor
import Vapor

struct UserWeights: Codable {
    let userId: String
    var hourlyWeights: [Int: Double]
    var dayWeights: [Int: Double]
    var categoryWeights: [String: Double]
    var taskSuccessRates: [String: Double]
    var categorySuccessRates: [String: Double]
    var timeToCompleteAverages: [String: TimeInterval]
    var lastUpdated: Date
    
    // Exponential moving average parameters
    var emaAlpha: Double = 0.2 // Controls how much weight is given to recent data
    
    init(userId: String) {
        self.userId = userId
        self.hourlyWeights = [:]
        self.dayWeights = [:]
        self.categoryWeights = [:]
        self.taskSuccessRates = [:]
        self.categorySuccessRates = [:]
        self.timeToCompleteAverages = [:]
        self.lastUpdated = Date()
        
        // Initialize with default values
        for hour in 0...23 {
            hourlyWeights[hour] = 1.0
        }
        for day in 1...7 {
            dayWeights[day] = 1.0
        }
    }
}

final class MLWeightStore {
    private let database: MongoDatabase
    private let collection: MongoCollection<UserWeights>
    private var cachedWeights: [String: UserWeights] = [:]
    
    init(database: MongoDatabase) {
        self.database = database
        self.collection = database.collection("ml_weights", withType: UserWeights.self)
    }
    
    // Get weights for a user, creating if not exists
    func getWeights(for userId: String) async throws -> UserWeights {
        if let cached = cachedWeights[userId] {
            return cached
        }
        
        if let existing = try await collection.findOne(["userId": userId]) {
            cachedWeights[userId] = existing
            return existing
        }
        
        let newWeights = UserWeights(userId: userId)
        try await collection.insertOne(newWeights)
        cachedWeights[userId] = newWeights
        return newWeights
    }
    
    // Update weights using exponential moving average
    func updateWeights(for userId: String, updates: (inout UserWeights) -> Void) async throws {
        var weights = try await getWeights(for: userId)
        updates(&weights)
        weights.lastUpdated = Date()
        
        try await collection.replaceOne(
            where: ["userId": userId],
            replacement: weights,
            upsert: true
        )
        
        cachedWeights[userId] = weights
    }
    
    // Update success rate for a task
    func updateTaskSuccessRate(userId: String, taskId: String, success: Bool) async throws {
        try await updateWeights(for: userId) { weights in
            let currentRate = weights.taskSuccessRates[taskId] ?? 0.5
            let alpha = weights.emaAlpha
            weights.taskSuccessRates[taskId] = (alpha * (success ? 1.0 : 0.0)) + ((1 - alpha) * currentRate)
        }
    }
    
    // Update category success rate
    func updateCategorySuccessRate(userId: String, category: String, success: Bool) async throws {
        try await updateWeights(for: userId) { weights in
            let currentRate = weights.categorySuccessRates[category] ?? 0.5
            let alpha = weights.emaAlpha
            weights.categorySuccessRates[category] = (alpha * (success ? 1.0 : 0.0)) + ((1 - alpha) * currentRate)
        }
    }
    
    // Update time to complete average for a category
    func updateTimeToComplete(userId: String, category: String, timeInterval: TimeInterval) async throws {
        try await updateWeights(for: userId) { weights in
            let currentAvg = weights.timeToCompleteAverages[category] ?? timeInterval
            let alpha = weights.emaAlpha
            weights.timeToCompleteAverages[category] = (alpha * timeInterval) + ((1 - alpha) * currentAvg)
        }
    }
    
    // Get success prediction for a task
    func predictTaskSuccess(userId: String, task: Task) async throws -> Double {
        let weights = try await getWeights(for: userId)
        
        var prediction = 0.5 // Default prediction
        
        // Consider task-specific success rate
        if let taskRate = weights.taskSuccessRates[task.id] {
            prediction = prediction * 0.3 + taskRate * 0.7
        }
        
        // Consider category success rate
        if let category = task.category, let categoryRate = weights.categorySuccessRates[category] {
            prediction = prediction * 0.5 + categoryRate * 0.5
        }
        
        return prediction
    }
    
    // Get estimated time to complete
    func estimateTimeToComplete(userId: String, task: Task) async throws -> TimeInterval? {
        let weights = try await getWeights(for: userId)
        return task.category.flatMap { weights.timeToCompleteAverages[$0] }
    }
    
    // Clear cache for a user
    func clearCache(for userId: String) {
        cachedWeights.removeValue(forKey: userId)
    }
} 
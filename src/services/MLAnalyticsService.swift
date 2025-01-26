import Foundation
import MongoDBVapor
import Vapor

struct MLPerformanceMetrics: Codable {
    let timestamp: Date
    let userId: String
    let taskId: String
    let predictedScore: Double
    let actualSuccess: Bool
    let predictedTimeToComplete: TimeInterval?
    let actualTimeToComplete: TimeInterval?
    let category: String?
}

struct UserSimilarity: Codable {
    let userId1: String
    let userId2: String
    let similarityScore: Double
    let lastUpdated: Date
    
    static let collectionName = "user_similarities"
}

final class MLAnalyticsService {
    private let database: MongoDatabase
    private let metricsCollection: MongoCollection<MLPerformanceMetrics>
    private let similaritiesCollection: MongoCollection<UserSimilarity>
    private let weightStore: MLWeightStore
    private let taskRepository: TaskRepository
    private let userRepository: UserRepository
    
    init(database: MongoDatabase, weightStore: MLWeightStore, taskRepository: TaskRepository, userRepository: UserRepository) {
        self.database = database
        self.metricsCollection = database.collection("ml_performance_metrics", withType: MLPerformanceMetrics.self)
        self.similaritiesCollection = database.collection(UserSimilarity.collectionName, withType: UserSimilarity.self)
        self.weightStore = weightStore
        self.taskRepository = taskRepository
        self.userRepository = userRepository
    }
    
    // Record prediction performance
    func recordPredictionPerformance(
        userId: String,
        taskId: String,
        predictedScore: Double,
        actualSuccess: Bool,
        predictedTime: TimeInterval?,
        actualTime: TimeInterval?,
        category: String?
    ) async throws {
        let metrics = MLPerformanceMetrics(
            timestamp: Date(),
            userId: userId,
            taskId: taskId,
            predictedScore: predictedScore,
            actualSuccess: actualSuccess,
            predictedTimeToComplete: predictedTime,
            actualTimeToComplete: actualTime,
            category: category
        )
        
        try await metricsCollection.insertOne(metrics)
    }
    
    // Get performance metrics for a user
    func getPerformanceMetrics(for userId: String, timeRange: TimeInterval = 7 * 24 * 3600) async throws -> [String: Any] {
        let startDate = Date().addingTimeInterval(-timeRange)
        
        let metrics = try await metricsCollection.find([
            "userId": userId,
            "timestamp": ["$gte": startDate]
        ]).toArray()
        
        var result: [String: Any] = [:]
        
        // Calculate prediction accuracy
        let totalPredictions = Double(metrics.count)
        if totalPredictions > 0 {
            let correctPredictions = Double(metrics.filter { metrics in
                let wasCorrect = (metrics.predictedScore >= 0.7 && metrics.actualSuccess) ||
                                (metrics.predictedScore < 0.7 && !metrics.actualSuccess)
                return wasCorrect
            }.count)
            
            result["predictionAccuracy"] = correctPredictions / totalPredictions
        }
        
        // Calculate time estimation accuracy
        let timeEstimates = metrics.compactMap { metrics -> Double? in
            guard let predicted = metrics.predictedTimeToComplete,
                  let actual = metrics.actualTimeToComplete else {
                return nil
            }
            return abs(predicted - actual) / actual // Relative error
        }
        
        if !timeEstimates.isEmpty {
            result["timeEstimationError"] = timeEstimates.reduce(0.0, +) / Double(timeEstimates.count)
        }
        
        // Category-specific metrics
        var categoryMetrics: [String: [String: Double]] = [:]
        for metric in metrics {
            guard let category = metric.category else { continue }
            
            var categoryData = categoryMetrics[category] ?? [
                "totalTasks": 0,
                "successfulTasks": 0,
                "averageScore": 0
            ]
            
            categoryData["totalTasks"]! += 1
            if metric.actualSuccess {
                categoryData["successfulTasks"]! += 1
            }
            categoryData["averageScore"]! += metric.predictedScore
            
            categoryMetrics[category] = categoryData
        }
        
        // Calculate averages for categories
        for (category, data) in categoryMetrics {
            let total = data["totalTasks"]!
            categoryMetrics[category]?["successRate"] = data["successfulTasks"]! / total
            categoryMetrics[category]?["averageScore"] = data["averageScore"]! / total
        }
        
        result["categoryMetrics"] = categoryMetrics
        
        return result
    }
    
    // Update user similarities
    func updateUserSimilarities(for userId: String) async throws {
        let userWeights = try await weightStore.getWeights(for: userId)
        
        // Get all users
        let allUsers = try await userRepository.findAll()
        var similarities: [UserSimilarity] = []
        
        for otherUser in allUsers where otherUser.id != userId {
            guard let otherUserId = otherUser.id else { continue }
            let otherWeights = try await weightStore.getWeights(for: otherUserId)
            
            // Calculate similarity based on various factors
            var similarityScore = 0.0
            
            // Compare hourly patterns
            let hourlyCorrelation = calculateCorrelation(
                dict1: userWeights.hourlyWeights,
                dict2: otherWeights.hourlyWeights
            )
            
            // Compare daily patterns
            let dailyCorrelation = calculateCorrelation(
                dict1: userWeights.dayWeights,
                dict2: otherWeights.dayWeights
            )
            
            // Compare category preferences
            let categoryCorrelation = calculateCorrelation(
                dict1: userWeights.categoryWeights,
                dict2: otherWeights.categoryWeights
            )
            
            // Weighted average of correlations
            similarityScore = (hourlyCorrelation * 0.4 + dailyCorrelation * 0.3 + categoryCorrelation * 0.3)
            
            let similarity = UserSimilarity(
                userId1: userId,
                userId2: otherUserId,
                similarityScore: similarityScore,
                lastUpdated: Date()
            )
            similarities.append(similarity)
        }
        
        // Store similarities
        if !similarities.isEmpty {
            try await similaritiesCollection.deleteMany(["userId1": userId])
            try await similaritiesCollection.insertMany(similarities)
        }
    }
    
    // Get collaborative recommendations
    func getCollaborativeRecommendations(for userId: String) async throws -> [String: Any] {
        // Get similar users
        let similarUsers = try await similaritiesCollection
            .find(["userId1": userId])
            .sort(["similarityScore": -1])
            .limit(5)
            .toArray()
        
        var recommendations: [String: Any] = [:]
        var categoryRecommendations: [String: Double] = [:]
        var timeRecommendations: [String: TimeInterval] = [:]
        
        // Get weights for similar users
        for similar in similarUsers {
            let similarWeights = try await weightStore.getWeights(for: similar.userId2)
            let similarity = similar.similarityScore
            
            // Blend category success rates
            for (category, rate) in similarWeights.categorySuccessRates {
                let currentRate = categoryRecommendations[category] ?? 0.0
                categoryRecommendations[category] = currentRate + (rate * similarity)
            }
            
            // Blend time estimates
            for (category, time) in similarWeights.timeToCompleteAverages {
                let currentTime = timeRecommendations[category] ?? 0.0
                timeRecommendations[category] = currentTime + (time * similarity)
            }
        }
        
        // Normalize recommendations
        let totalSimilarity = similarUsers.reduce(0.0) { $0 + $1.similarityScore }
        if totalSimilarity > 0 {
            for category in categoryRecommendations.keys {
                categoryRecommendations[category] = categoryRecommendations[category]! / totalSimilarity
            }
            for category in timeRecommendations.keys {
                timeRecommendations[category] = timeRecommendations[category]! / totalSimilarity
            }
        }
        
        recommendations["categoryRecommendations"] = categoryRecommendations
        recommendations["timeRecommendations"] = timeRecommendations
        recommendations["similarUsers"] = similarUsers.map { [
            "userId": $0.userId2,
            "similarity": $0.similarityScore
        ] }
        
        return recommendations
    }
    
    // Helper function to calculate correlation between two dictionaries
    private func calculateCorrelation<T: Hashable>(dict1: [T: Double], dict2: [T: Double]) -> Double {
        let keys = Set(dict1.keys).union(Set(dict2.keys))
        guard !keys.isEmpty else { return 0 }
        
        var sum1 = 0.0, sum2 = 0.0
        var sumSq1 = 0.0, sumSq2 = 0.0
        var sumCoproduct = 0.0
        let n = Double(keys.count)
        
        for key in keys {
            let val1 = dict1[key] ?? 1.0 // Default to neutral value if missing
            let val2 = dict2[key] ?? 1.0
            
            sum1 += val1
            sum2 += val2
            sumSq1 += val1 * val1
            sumSq2 += val2 * val2
            sumCoproduct += val1 * val2
        }
        
        let numerator = sumCoproduct - (sum1 * sum2 / n)
        let denominator = sqrt((sumSq1 - (sum1 * sum1) / n) * (sumSq2 - (sum2 * sum2) / n))
        
        return denominator > 0 ? numerator / denominator : 0
    }
} 
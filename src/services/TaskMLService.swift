import Foundation
import MongoDBVapor
import Vapor

struct TaskCompletionData {
    let taskId: String
    let userId: String
    let completedAt: Date
    let originalPriority: Double
    let timeToComplete: TimeInterval
    let wasCompleteOnTime: Bool
    let dayOfWeek: Int
    let hourOfDay: Int
    let category: String
}

final class TaskMLService {
    private let taskRepository: TaskRepository
    private let weightStore: MLWeightStore
    private let analyticsService: MLAnalyticsService
    private let experimentService: MLExperimentService
    private static let defaultLearningRate: Double = 0.1
    
    init(taskRepository: TaskRepository, weightStore: MLWeightStore, analyticsService: MLAnalyticsService, experimentService: MLExperimentService) {
        self.taskRepository = taskRepository
        self.weightStore = weightStore
        self.analyticsService = analyticsService
        self.experimentService = experimentService
    }
    
    // Record task completion for learning
    func recordTaskCompletion(_ task: Task, completedAt: Date) async throws {
        guard let userId = task.userId else { return }
        
        let calendar = Calendar.current
        let hourOfDay = calendar.component(.hour, from: completedAt)
        let dayOfWeek = calendar.component(.weekday, from: completedAt)
        
        // Get experiment parameters
        let experimentParams = try await experimentService.getExperimentParameters(userId: userId)
        let learningRate = experimentParams["learningRate"] ?? TaskMLService.defaultLearningRate
        
        // Update weights based on completion time
        try await weightStore.updateWeights(for: userId) { weights in
            // Update hourly weight
            let currentHourWeight = weights.hourlyWeights[hourOfDay] ?? 1.0
            weights.hourlyWeights[hourOfDay] = max(0.1, min(2.0, currentHourWeight + learningRate))
            
            // Update daily weight
            let currentDayWeight = weights.dayWeights[dayOfWeek] ?? 1.0
            weights.dayWeights[dayOfWeek] = max(0.1, min(2.0, currentDayWeight + learningRate))
            
            // Update category weight if available
            if let category = task.category {
                let currentCategoryWeight = weights.categoryWeights[category] ?? 1.0
                weights.categoryWeights[category] = max(0.1, min(2.0, currentCategoryWeight + learningRate))
            }
        }
        
        // Update success rates
        try await weightStore.updateTaskSuccessRate(userId: userId, taskId: task.id, success: true)
        if let category = task.category {
            try await weightStore.updateCategorySuccessRate(userId: userId, category: category, success: true)
        }
        
        // Record performance metrics
        if let createdAt = task.createdAt {
            let timeToComplete = completedAt.timeIntervalSince(createdAt)
            let predictedTime = try await weightStore.estimateTimeToComplete(userId: userId, task: task)
            let predictedScore = try await weightStore.predictTaskSuccess(userId: userId, task: task)
            
            try await analyticsService.recordPredictionPerformance(
                userId: userId,
                taskId: task.id,
                predictedScore: predictedScore,
                actualSuccess: true,
                predictedTime: predictedTime,
                actualTime: timeToComplete,
                category: task.category
            )
            
            if let category = task.category {
                try await weightStore.updateTimeToComplete(userId: userId, category: category, timeInterval: timeToComplete)
            }
        }
        
        // Update user similarities
        try await analyticsService.updateUserSimilarities(for: userId)
        
        // Check for anomalies
        try await experimentService.detectAnomalies(userId: userId)
    }
    
    // Record task failure or incompletion
    func recordTaskFailure(_ task: Task) async throws {
        guard let userId = task.userId else { return }
        
        let now = Date()
        let calendar = Calendar.current
        let hourOfDay = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        
        // Get experiment parameters
        let experimentParams = try await experimentService.getExperimentParameters(userId: userId)
        let learningRate = experimentParams["learningRate"] ?? TaskMLService.defaultLearningRate
        
        // Update weights based on failure
        try await weightStore.updateWeights(for: userId) { weights in
            // Update hourly weight
            let currentHourWeight = weights.hourlyWeights[hourOfDay] ?? 1.0
            weights.hourlyWeights[hourOfDay] = max(0.1, min(2.0, currentHourWeight - learningRate))
            
            // Update daily weight
            let currentDayWeight = weights.dayWeights[dayOfWeek] ?? 1.0
            weights.dayWeights[dayOfWeek] = max(0.1, min(2.0, currentDayWeight - learningRate))
            
            // Update category weight if available
            if let category = task.category {
                let currentCategoryWeight = weights.categoryWeights[category] ?? 1.0
                weights.categoryWeights[category] = max(0.1, min(2.0, currentCategoryWeight - learningRate))
            }
        }
        
        // Update success rates and record performance
        try await weightStore.updateTaskSuccessRate(userId: userId, taskId: task.id, success: false)
        let predictedScore = try await weightStore.predictTaskSuccess(userId: userId, task: task)
        
        try await analyticsService.recordPredictionPerformance(
            userId: userId,
            taskId: task.id,
            predictedScore: predictedScore,
            actualSuccess: false,
            predictedTime: nil,
            actualTime: nil,
            category: task.category
        )
        
        if let category = task.category {
            try await weightStore.updateCategorySuccessRate(userId: userId, category: category, success: false)
        }
        
        // Update user similarities
        try await analyticsService.updateUserSimilarities(for: userId)
        
        // Check for anomalies
        try await experimentService.detectAnomalies(userId: userId)
    }
    
    // Get ML-adjusted score multiplier for a task
    func getScoreMultiplier(task: Task, currentTime: Date) async throws -> Double {
        guard let userId = task.userId else { return 1.0 }
        
        let weights = try await weightStore.getWeights(for: userId)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let day = calendar.component(.weekday, from: currentTime)
        
        var multiplier = 1.0
        
        // Apply hourly weight
        multiplier *= weights.hourlyWeights[hour] ?? 1.0
        
        // Apply daily weight
        multiplier *= weights.dayWeights[day] ?? 1.0
        
        // Apply category weight if available
        if let category = task.category {
            multiplier *= weights.categoryWeights[category] ?? 1.0
        }
        
        // Apply success prediction
        let successPrediction = try await weightStore.predictTaskSuccess(userId: userId, task: task)
        multiplier *= (0.5 + successPrediction) // Scale prediction to 0.5-1.5 range
        
        // Apply collaborative filtering insights
        if let category = task.category {
            let recommendations = try await analyticsService.getCollaborativeRecommendations(for: userId)
            if let categoryRecommendations = recommendations["categoryRecommendations"] as? [String: Double],
               let categoryScore = categoryRecommendations[category] {
                multiplier *= (0.7 + (categoryScore * 0.3)) // Blend with collaborative insights
            }
        }
        
        return multiplier
    }
    
    // Get insights about learned patterns
    func getLearningInsights(for userId: String) async throws -> [String: Any] {
        var insights = try await weightStore.getWeights(for: userId)
        
        // Add performance metrics
        let performanceMetrics = try await analyticsService.getPerformanceMetrics(for: userId)
        var result: [String: Any] = performanceMetrics
        
        // Find best hours
        let bestHours = insights.hourlyWeights.sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key):00" }
        result["bestHours"] = bestHours
        
        // Find best days
        let bestDays = insights.dayWeights.sorted { $0.value > $1.value }
            .prefix(3)
            .map { calendar.weekdaySymbols[$0.key - 1] }
        result["bestDays"] = bestDays
        
        // Find most productive categories
        let bestCategories = insights.categoryWeights.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        result["bestCategories"] = bestCategories
        
        // Add collaborative insights
        let collaborativeInsights = try await analyticsService.getCollaborativeRecommendations(for: userId)
        result["collaborativeInsights"] = collaborativeInsights
        
        return result
    }
    
    // Get estimated time to complete for a task
    func getEstimatedTimeToComplete(task: Task) async throws -> TimeInterval? {
        guard let userId = task.userId else { return nil }
        
        // Get personal estimate
        let personalEstimate = try await weightStore.estimateTimeToComplete(userId: userId, task: task)
        
        // Get collaborative estimate
        if let category = task.category {
            let recommendations = try await analyticsService.getCollaborativeRecommendations(for: userId)
            if let timeRecommendations = recommendations["timeRecommendations"] as? [String: TimeInterval],
               let collaborativeEstimate = timeRecommendations[category] {
                
                // Blend estimates (70% personal, 30% collaborative)
                if let personal = personalEstimate {
                    return (personal * 0.7) + (collaborativeEstimate * 0.3)
                }
                return collaborativeEstimate
            }
        }
        
        return personalEstimate
    }
} 
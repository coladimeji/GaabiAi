import Foundation
import MongoDBVapor
import Vapor

struct TaskPriorityScore {
    let taskId: String
    let score: Double
    let factors: [String: Double]
}

final class TaskPrioritizationService {
    private let taskRepository: TaskRepository
    private let habitRepository: HabitRepository
    private let mlService: TaskMLService
    
    init(taskRepository: TaskRepository, habitRepository: HabitRepository, mlService: TaskMLService) {
        self.taskRepository = taskRepository
        self.habitRepository = habitRepository
        self.mlService = mlService
    }
    
    // Main prioritization method
    func prioritizeTasks(for userId: String) async throws -> [TaskPriorityScore] {
        let tasks = try await taskRepository.findIncomplete(for: userId)
        let habits = try await habitRepository.findByUser(userId: userId)
        let now = Date()
        
        var priorityScores: [TaskPriorityScore] = []
        
        for task in tasks {
            let score = try await calculatePriorityScore(
                task: task,
                habits: habits,
                currentTime: now
            )
            priorityScores.append(score)
        }
        
        // Sort by score in descending order
        return priorityScores.sorted { $0.score > $1.score }
    }
    
    // Calculate priority score for a single task
    private func calculatePriorityScore(task: Task, habits: [Habit], currentTime: Date) async throws -> TaskPriorityScore {
        var factors: [String: Double] = [:]
        
        // Due date factor (higher score for closer due dates)
        let dueDateFactor = calculateDueDateFactor(dueDate: task.dueDate, currentTime: currentTime)
        factors["dueDate"] = dueDateFactor
        
        // Habit alignment factor (tasks that align with user habits get higher priority)
        let habitFactor = calculateHabitAlignmentFactor(task: task, habits: habits)
        factors["habitAlignment"] = habitFactor
        
        // Time of day factor (based on typical completion patterns)
        let timeOfDayFactor = calculateTimeOfDayFactor(currentTime: currentTime)
        factors["timeOfDay"] = timeOfDayFactor
        
        // Complexity factor (more complex tasks get higher priority earlier in the day)
        let complexityFactor = calculateComplexityFactor(task: task, currentTime: currentTime)
        factors["complexity"] = complexityFactor
        
        // Calculate base score with weighted factors
        let baseScore = (dueDateFactor * 0.4) +      // Due date is most important
                       (habitFactor * 0.3) +         // Habit alignment is second
                       (timeOfDayFactor * 0.2) +     // Time of day is third
                       (complexityFactor * 0.1)      // Complexity is fourth
        
        // Apply ML-based adjustments
        let mlMultiplier = mlService.getScoreMultiplier(task: task, currentTime: currentTime)
        factors["mlAdjustment"] = mlMultiplier
        
        let finalScore = baseScore * mlMultiplier
        
        return TaskPriorityScore(
            taskId: task.id,
            score: finalScore,
            factors: factors
        )
    }
    
    // Calculate due date factor (0-1, higher for closer due dates)
    private func calculateDueDateFactor(dueDate: Date?, currentTime: Date) -> Double {
        guard let dueDate = dueDate else { return 0.5 } // Default priority for tasks without due date
        
        let timeInterval = dueDate.timeIntervalSince(currentTime)
        let daysUntilDue = timeInterval / (24 * 60 * 60)
        
        if daysUntilDue < 0 { // Overdue tasks get highest priority
            return 1.0
        } else if daysUntilDue == 0 { // Due today
            return 0.9
        } else if daysUntilDue <= 1 { // Due tomorrow
            return 0.8
        } else if daysUntilDue <= 3 { // Due within 3 days
            return 0.7
        } else if daysUntilDue <= 7 { // Due within a week
            return 0.6
        } else { // Due later
            return max(0.1, 1.0 - (daysUntilDue / 30.0)) // Gradually decrease priority
        }
    }
    
    // Calculate habit alignment factor (0-1, higher for tasks that align with habits)
    private func calculateHabitAlignmentFactor(task: Task, habits: [Habit]) -> Double {
        // Check if task category matches any habit categories
        let matchingHabits = habits.filter { habit in
            return task.category == habit.category
        }
        
        if matchingHabits.isEmpty {
            return 0.5 // Neutral priority for tasks without habit alignment
        }
        
        // Calculate average frequency of matching habits
        let frequencyScores = matchingHabits.map { habit -> Double in
            switch habit.frequency {
            case "daily": return 1.0
            case "weekly": return 0.8
            case "monthly": return 0.6
            default: return 0.5
            }
        }
        
        return frequencyScores.reduce(0.0, +) / Double(frequencyScores.count)
    }
    
    // Calculate time of day factor (0-1, based on optimal task completion times)
    private func calculateTimeOfDayFactor(currentTime: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        // Assume peak productivity hours are 9 AM - 11 AM and 2 PM - 4 PM
        switch hour {
        case 9...11: return 1.0  // Morning peak
        case 14...16: return 0.9 // Afternoon peak
        case 8, 12, 13, 17: return 0.8 // Shoulder hours
        case 7, 18: return 0.7 // Early morning/evening
        case 19...22: return 0.6 // Evening
        default: return 0.3 // Late night/early morning
        }
    }
    
    // Calculate complexity factor (0-1, higher for complex tasks during peak hours)
    private func calculateComplexityFactor(task: Task, currentTime: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        // Estimate task complexity based on description length and subtasks
        let descriptionComplexity = task.description?.count ?? 0
        let hasSubtasks = task.subtasks?.isEmpty == false
        
        var complexityScore = 0.5 // Default medium complexity
        
        if descriptionComplexity > 500 || hasSubtasks {
            complexityScore = 0.8 // High complexity
        } else if descriptionComplexity > 200 {
            complexityScore = 0.6 // Medium-high complexity
        }
        
        // Adjust complexity score based on time of day
        // Complex tasks get higher priority during peak hours
        if (9...11).contains(hour) || (14...16).contains(hour) {
            return complexityScore
        } else {
            return complexityScore * 0.7 // Reduce priority of complex tasks outside peak hours
        }
    }
    
    // Get recommended task order
    func getRecommendedTaskOrder(for userId: String) async throws -> [Task] {
        let priorityScores = try await prioritizeTasks(for: userId)
        var orderedTasks: [Task] = []
        
        for score in priorityScores {
            if let task = try await taskRepository.find(by: score.taskId) {
                orderedTasks.append(task)
            }
        }
        
        return orderedTasks
    }
    
    // Record task completion for ML learning
    func recordTaskCompletion(_ task: Task) async throws {
        try await mlService.recordTaskCompletion(task, completedAt: Date())
    }
    
    // Record task failure for ML learning
    func recordTaskFailure(_ task: Task) async throws {
        try await mlService.recordTaskFailure(task)
    }
    
    // Get task insights with ML data
    func getTaskInsights(for userId: String) async throws -> [String: Any] {
        let priorityScores = try await prioritizeTasks(for: userId)
        
        var insights: [String: Any] = [:]
        
        // Calculate average scores for different factors
        var avgDueDateFactor = 0.0
        var avgHabitFactor = 0.0
        var avgTimeOfDayFactor = 0.0
        var avgComplexityFactor = 0.0
        var avgMlAdjustment = 0.0
        
        for score in priorityScores {
            avgDueDateFactor += score.factors["dueDate"] ?? 0
            avgHabitFactor += score.factors["habitAlignment"] ?? 0
            avgTimeOfDayFactor += score.factors["timeOfDay"] ?? 0
            avgComplexityFactor += score.factors["complexity"] ?? 0
            avgMlAdjustment += score.factors["mlAdjustment"] ?? 0
        }
        
        let count = Double(priorityScores.count)
        if count > 0 {
            insights["averageFactors"] = [
                "dueDate": avgDueDateFactor / count,
                "habitAlignment": avgHabitFactor / count,
                "timeOfDay": avgTimeOfDayFactor / count,
                "complexity": avgComplexityFactor / count,
                "mlAdjustment": avgMlAdjustment / count
            ]
        }
        
        // Add high priority tasks
        insights["highPriorityTasks"] = priorityScores.prefix(3).map { $0.taskId }
        
        // Add ML-based insights
        insights["learningInsights"] = mlService.getLearningInsights()
        
        return insights
    }
} 
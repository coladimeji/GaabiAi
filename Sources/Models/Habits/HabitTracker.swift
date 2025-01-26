import Foundation
import CoreLocation

actor HabitTracker {
    private var habits: [UUID: Habit] = [:]
    private let habitStorage: HabitStorage
    private let notificationManager: NotificationManager
    private let locationManager: LocationManager
    private let weatherClient: OpenWeatherClient
    
    init(
        habitStorage: HabitStorage,
        notificationManager: NotificationManager,
        locationManager: LocationManager,
        weatherClient: OpenWeatherClient
    ) {
        self.habitStorage = habitStorage
        self.notificationManager = notificationManager
        self.locationManager = locationManager
        self.weatherClient = weatherClient
    }
    
    func createHabit(_ habit: Habit) async throws {
        habits[habit.id] = habit
        try await habitStorage.save(habit)
        await scheduleReminders(for: habit)
    }
    
    func completeHabit(_ habitId: UUID, date: Date = Date()) async throws {
        guard var habit = habits[habitId] else {
            throw HabitError.habitNotFound
        }
        
        // Record completion
        habit.completedDates.append(date)
        
        // Update streak
        if habit.isStreak(from: habit.lastCompletionDate, to: date) {
            habit.currentStreak += 1
            habit.bestStreak = max(habit.currentStreak, habit.bestStreak)
        } else {
            habit.currentStreak = 1
        }
        
        habit.lastCompletionDate = date
        
        // Update analytics
        if let location = await locationManager.getCurrentLocation() {
            habit.analytics.completionLocations.append(location)
        }
        
        if habit.weatherDependent {
            if let location = await locationManager.getCurrentLocation() {
                let weather = try await weatherClient.getCurrentWeather(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                habit.analytics.weatherConditions.append(weather.current)
            }
        }
        
        // Save changes
        habits[habitId] = habit
        try await habitStorage.save(habit)
        
        // Update linked tasks if any
        if let linkedTasks = habit.linkedTasks {
            for taskId in linkedTasks {
                // Update task status
                // This would be handled by your task management system
            }
        }
    }
    
    func getHabitAnalytics(_ habitId: UUID) async throws -> HabitAnalytics {
        guard let habit = habits[habitId] else {
            throw HabitError.habitNotFound
        }
        
        return HabitAnalytics(
            totalCompletions: habit.completedDates.count,
            currentStreak: habit.currentStreak,
            bestStreak: habit.bestStreak,
            completionRate: calculateCompletionRate(habit),
            commonCompletionTimes: findCommonCompletionTimes(habit),
            commonLocations: findCommonLocations(habit),
            weatherPatterns: analyzeWeatherPatterns(habit)
        )
    }
    
    func suggestOptimalTime(_ habitId: UUID) async throws -> [DateComponents] {
        guard let habit = habits[habitId] else {
            throw HabitError.habitNotFound
        }
        
        var suggestions: [DateComponents] = []
        
        // Analyze completion patterns
        let commonTimes = findCommonCompletionTimes(habit)
        suggestions.append(contentsOf: commonTimes)
        
        // Consider weather if applicable
        if habit.weatherDependent {
            let weatherPatterns = analyzeWeatherPatterns(habit)
            // Adjust suggestions based on weather patterns
        }
        
        // Consider location patterns
        let locationPatterns = findCommonLocations(habit)
        // Adjust suggestions based on location patterns
        
        return suggestions
    }
    
    private func scheduleReminders(for habit: Habit) async {
        guard let reminderTime = habit.reminderTime else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time for your habit: \(habit.title)"
        content.body = habit.description
        content.sound = .default
        
        var components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "habit-\(habit.id)",
            content: content,
            trigger: trigger
        )
        
        try? await notificationManager.add(request)
    }
    
    private func calculateCompletionRate(_ habit: Habit) -> Double {
        guard let startDate = habit.startDate else { return 0 }
        
        let calendar = Calendar.current
        let totalDays = calendar.numberOfDaysBetween(startDate, and: Date())
        let completions = habit.completedDates.count
        
        return Double(completions) / Double(totalDays)
    }
    
    private func findCommonCompletionTimes(_ habit: Habit) -> [DateComponents] {
        let times = habit.completedDates.map { date in
            Calendar.current.dateComponents([.hour, .minute], from: date)
        }
        
        // Group by hour and minute to find patterns
        var timeFrequency: [DateComponents: Int] = [:]
        times.forEach { components in
            timeFrequency[components, default: 0] += 1
        }
        
        // Sort by frequency and return top times
        return Array(timeFrequency.sorted { $0.value > $1.value }.prefix(3)).map { $0.key }
    }
    
    private func findCommonLocations(_ habit: Habit) -> [CLLocation] {
        let locations = habit.analytics.completionLocations
        
        // Group nearby locations
        var locationClusters: [[CLLocation]] = []
        for location in locations {
            if let cluster = locationClusters.first(where: { cluster in
                cluster.contains { $0.distance(from: location) < 100 } // 100m radius
            }) {
                cluster.append(location)
            } else {
                locationClusters.append([location])
            }
        }
        
        // Return center of most common clusters
        return locationClusters
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { cluster in
                let avgLat = cluster.map { $0.coordinate.latitude }.reduce(0, +) / Double(cluster.count)
                let avgLon = cluster.map { $0.coordinate.longitude }.reduce(0, +) / Double(cluster.count)
                return CLLocation(latitude: avgLat, longitude: avgLon)
            }
    }
    
    private func analyzeWeatherPatterns(_ habit: Habit) -> [WeatherPattern] {
        let conditions = habit.analytics.weatherConditions
        
        // Group by weather condition
        var patterns: [String: WeatherPattern] = [:]
        conditions.forEach { condition in
            let key = condition.main
            if var pattern = patterns[key] {
                pattern.count += 1
                patterns[key] = pattern
            } else {
                patterns[key] = WeatherPattern(condition: key, count: 1)
            }
        }
        
        return Array(patterns.values.sorted { $0.count > $1.count })
    }
}

struct Habit: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var frequency: HabitFrequency
    var startDate: Date?
    var completedDates: [Date]
    var currentStreak: Int
    var bestStreak: Int
    var reminderTime: Date?
    var linkedTasks: [UUID]?
    var weatherDependent: Bool
    var lastCompletionDate: Date?
    var analytics: HabitAnalyticsData
    
    func isStreak(from: Date?, to: Date) -> Bool {
        guard let lastDate = from else { return true }
        
        let calendar = Calendar.current
        let days = calendar.numberOfDaysBetween(lastDate, and: to)
        
        switch frequency {
        case .daily:
            return days <= 1
        case .weekly:
            return days <= 7
        case .monthly:
            return calendar.isDate(lastDate, equalTo: to, toGranularity: .month)
        case .custom(let interval):
            return days <= interval
        }
    }
}

struct HabitAnalyticsData: Codable {
    var completionLocations: [CLLocation]
    var weatherConditions: [CurrentWeather]
    var averageCompletionTime: TimeInterval?
}

struct HabitAnalytics {
    let totalCompletions: Int
    let currentStreak: Int
    let bestStreak: Int
    let completionRate: Double
    let commonCompletionTimes: [DateComponents]
    let commonLocations: [CLLocation]
    let weatherPatterns: [WeatherPattern]
}

struct WeatherPattern {
    let condition: String
    var count: Int
}

enum HabitError: Error {
    case habitNotFound
    case invalidFrequency
    case invalidDate
    
    var localizedDescription: String {
        switch self {
        case .habitNotFound:
            return "Habit not found"
        case .invalidFrequency:
            return "Invalid habit frequency"
        case .invalidDate:
            return "Invalid date"
        }
    }
}

extension Calendar {
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from)
        let toDate = startOfDay(for: to)
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate)
        
        return numberOfDays.day ?? 0
    }
} 
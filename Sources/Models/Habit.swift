import Foundation

struct Habit: Identifiable, Codable {
    var id: UUID
    var name: String
    var category: Category
    var frequency: Frequency
    var targetType: TargetType
    var targetValue: Double
    var reminder: Date?
    var notes: String?
    var progress: [Progress]
    var streak: Int
    var customCategory: String?
    
    enum Category: String, Codable {
        case health
        case fitness
        case productivity
        case mindfulness
        case learning
        case custom
    }
    
    enum Frequency: String, Codable {
        case daily
        case weekly
        case monthly
        
        var daysToComplete: Int {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .monthly: return 30
            }
        }
    }
    
    enum TargetType: String, Codable {
        case completion
        case duration
        case count
        case distance
        
        var defaultUnit: String {
            switch self {
            case .completion: return "times"
            case .duration: return "minutes"
            case .count: return "times"
            case .distance: return "km"
            }
        }
    }
    
    struct Progress: Codable {
        var date: Date
        var value: Double
        var notes: String?
        
        init(date: Date = Date(), value: Double, notes: String? = nil) {
            self.date = date
            self.value = value
            self.notes = notes
        }
    }
    
    init(id: UUID = UUID(),
         name: String,
         category: Category,
         frequency: Frequency = .daily,
         targetType: TargetType = .completion,
         targetValue: Double = 1,
         reminder: Date? = nil,
         notes: String? = nil,
         progress: [Progress] = [],
         streak: Int = 0,
         customCategory: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.frequency = frequency
        self.targetType = targetType
        self.targetValue = targetValue
        self.reminder = reminder
        self.notes = notes
        self.progress = progress
        self.streak = streak
        self.customCategory = customCategory
    }
    
    func progressForDate(_ date: Date) -> Double {
        let calendar = Calendar.current
        let progressForDate = progress.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return progressForDate.reduce(0) { $0 + $1.value }
    }
    
    func isCompleted(for date: Date) -> Bool {
        progressForDate(date) >= targetValue
    }
    
    func currentStreak(as of: Date = Date()) -> Int {
        var currentDate = as of
        var streakCount = 0
        let calendar = Calendar.current
        
        while isCompleted(for: currentDate) {
            streakCount += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        
        return streakCount
    }
}

enum HabitCategory: String, Codable, CaseIterable {
    case fitness
    case health
    case productivity
    case mindfulness
    case learning
    case custom(String)
    
    var description: String {
        switch self {
        case .custom(let name): return name
        default: return rawValue.capitalized
        }
    }
}

enum HabitFrequency: Codable {
    case daily(times: Int)
    case weekly(days: Set<WeekDay>, times: Int)
    case monthly(days: Set<Int>)
    case custom(interval: Int, unit: Calendar.Component)
}

enum WeekDay: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

struct HabitTarget: Codable {
    var type: TargetType
    var value: Double
    var unit: String
}

enum TargetType: String, Codable {
    case completion
    case duration
    case distance
    case quantity
    case weight
}

struct HabitReminder: Codable {
    var time: Date
    var days: Set<WeekDay>
    var message: String?
    var isEnabled: Bool
} 
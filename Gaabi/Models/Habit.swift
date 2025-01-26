import Foundation

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var frequency: Frequency
    var reminder: Date?
    var notes: String
    var completionHistory: [Completion]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(),
         title: String,
         frequency: Frequency = .daily,
         reminder: Date? = nil,
         notes: String = "",
         completionHistory: [Completion] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.frequency = frequency
        self.reminder = reminder
        self.notes = notes
        self.completionHistory = completionHistory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .daily: return "Every day"
            case .weekly: return "Every week"
            case .monthly: return "Every month"
            }
        }
    }
    
    struct Completion: Identifiable, Codable, Equatable {
        let id: UUID
        let date: Date
        
        init(id: UUID = UUID(), date: Date = Date()) {
            self.id = id
            self.date = date
        }
    }
    
    var isCompletedToday: Bool {
        completionHistory.contains { Calendar.current.isDateInToday($0.date) }
    }
    
    func isCompletedForTimeframe(_ timeframe: HabitListView.Timeframe) -> Bool {
        switch timeframe {
        case .day:
            return isCompletedToday
        case .week:
            return completionHistory.contains { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        case .month:
            return completionHistory.contains { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        }
    }
    
    var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        let today = Date()
        
        // Sort completions by date in descending order
        let sortedCompletions = completionHistory.sorted { $0.date > $1.date }
        
        // If no completions or last completion is not today/yesterday, return 0
        guard let lastCompletion = sortedCompletions.first,
              calendar.isDateInToday(lastCompletion.date) ||
                calendar.isDateInYesterday(lastCompletion.date) else {
            return 0
        }
        
        var currentDate = today
        
        while true {
            if completionHistory.contains(where: { calendar.isDate($0.date, inSameDayAs: currentDate) }) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    var bestStreak: Int {
        var bestStreak = 0
        var currentStreak = 0
        let calendar = Calendar.current
        
        // Sort completions by date
        let sortedCompletions = completionHistory.sorted { $0.date < $1.date }
        
        // Calculate streaks
        var lastDate: Date?
        for completion in sortedCompletions {
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: completion.date).day ?? 0
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    bestStreak = max(bestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = completion.date
        }
        
        // Check final streak
        bestStreak = max(bestStreak, currentStreak)
        
        return bestStreak
    }
    
    mutating func toggleCompletion() {
        if isCompletedToday {
            completionHistory.removeAll { Calendar.current.isDateInToday($0.date) }
        } else {
            completionHistory.append(Completion())
        }
        updatedAt = Date()
    }
    
    mutating func update(title: String? = nil,
                        frequency: Frequency? = nil,
                        reminder: Date? = nil,
                        notes: String? = nil) {
        if let title = title { self.title = title }
        if let frequency = frequency { self.frequency = frequency }
        if let reminder = reminder { self.reminder = reminder }
        if let notes = notes { self.notes = notes }
        updatedAt = Date()
    }
} 
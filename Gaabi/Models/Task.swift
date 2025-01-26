import Foundation

struct Task: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var dueDate: Date?
    var hasReminder: Bool
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), 
         title: String, 
         notes: String = "", 
         isCompleted: Bool = false, 
         dueDate: Date? = nil, 
         hasReminder: Bool = false, 
         reminderDate: Date? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.hasReminder = hasReminder
        self.reminderDate = reminderDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Task Extensions
extension Task {
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }
    
    mutating func toggleCompletion() {
        isCompleted.toggle()
        updatedAt = Date()
    }
    
    mutating func update(title: String? = nil,
                        notes: String? = nil,
                        isCompleted: Bool? = nil,
                        dueDate: Date? = nil,
                        hasReminder: Bool? = nil,
                        reminderDate: Date? = nil) {
        if let title = title { self.title = title }
        if let notes = notes { self.notes = notes }
        if let isCompleted = isCompleted { self.isCompleted = isCompleted }
        if let dueDate = dueDate { self.dueDate = dueDate }
        if let hasReminder = hasReminder { self.hasReminder = hasReminder }
        if let reminderDate = reminderDate { self.reminderDate = reminderDate }
        self.updatedAt = Date()
    }
} 
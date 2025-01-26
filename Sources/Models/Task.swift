import Foundation

struct Task: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var date: Date
    var isCompleted: Bool
    var hasReminder: Bool
    var reminderTime: Date?
    var weatherAlert: Bool
    var trafficAlert: Bool
    var alternativeRoutes: Bool
    var recurrence: RecurrenceType
    var voiceNoteURL: URL?
    
    enum RecurrenceType: String, Codable {
        case none
        case daily
        case weekly
        case monthly
        case yearly
    }
    
    init(id: UUID = UUID(),
         title: String,
         description: String = "",
         date: Date = Date(),
         isCompleted: Bool = false,
         hasReminder: Bool = false,
         reminderTime: Date? = nil,
         weatherAlert: Bool = false,
         trafficAlert: Bool = false,
         alternativeRoutes: Bool = false,
         recurrence: RecurrenceType = .none,
         voiceNoteURL: URL? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.date = date
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
        self.reminderTime = reminderTime
        self.weatherAlert = weatherAlert
        self.trafficAlert = trafficAlert
        self.alternativeRoutes = alternativeRoutes
        self.recurrence = recurrence
        self.voiceNoteURL = voiceNoteURL
    }
}

enum TaskRecurrence: String, Codable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
    case custom(interval: Int, unit: Calendar.Component)
} 
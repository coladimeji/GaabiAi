import Foundation

struct VoiceNote: Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var fileURL: URL
    var transcription: String?
    var analysis: Analysis?
    var tags: [String]
    var linkedItems: [LinkedItem]
    
    struct Analysis: Codable {
        var summary: String
        var keywords: [String]
        var actionItems: [String]
        var sentiment: Sentiment
        var weatherContext: String?
        var trafficContext: String?
        
        enum Sentiment: String, Codable {
            case positive
            case neutral
            case negative
        }
    }
    
    struct LinkedItem: Codable {
        var id: String
        var type: ItemType
        var title: String
        
        enum ItemType: String, Codable {
            case task
            case habit
            case device
        }
    }
    
    init(id: UUID = UUID(),
         title: String,
         date: Date = Date(),
         duration: TimeInterval = 0,
         fileURL: URL,
         transcription: String? = nil,
         analysis: Analysis? = nil,
         tags: [String] = [],
         linkedItems: [LinkedItem] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.fileURL = fileURL
        self.transcription = transcription
        self.analysis = analysis
        self.tags = tags
        self.linkedItems = linkedItems
    }
}

struct AIAnalysis: Codable {
    var summary: String?
    var actionItems: [String]
    var sentiment: Sentiment
    var keywords: Set<String>
    var categories: Set<String>
    var suggestedTasks: [Task]
    var weatherContext: WeatherContext?
    var trafficContext: TrafficContext?
}

enum Sentiment: String, Codable {
    case positive
    case neutral
    case negative
}

struct LinkedItems: Codable {
    var tasks: [UUID]
    var habits: [UUID]
    var smartDevices: [UUID]
    var schedules: [UUID]
    
    init(
        tasks: [UUID] = [],
        habits: [UUID] = [],
        smartDevices: [UUID] = [],
        schedules: [UUID] = []
    ) {
        self.tasks = tasks
        self.habits = habits
        self.smartDevices = smartDevices
        self.schedules = schedules
    }
}

struct WeatherContext: Codable {
    var temperature: Double
    var condition: String
    var forecast: String?
}

struct TrafficContext: Codable {
    var currentConditions: String
    var alternativeRoutes: [Route]
    var estimatedDuration: TimeInterval
}

struct Route: Codable {
    var name: String
    var duration: TimeInterval
    var distance: Double
    var trafficLevel: TrafficLevel
}

enum TrafficLevel: String, Codable {
    case light
    case moderate
    case heavy
    case severe
} 
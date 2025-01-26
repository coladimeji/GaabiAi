import Foundation
import CoreLocation

struct SmartTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: Date
    var priority: TaskPriority
    var status: TaskStatus
    var category: TaskCategory
    var location: TaskLocation?
    var weatherDependent: Bool
    var routeInfo: RouteInfo?
    var linkedDevices: [IoTDevice]
    var habitData: HabitData?
    var completionTime: TimeInterval?
    var tags: Set<String>
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        dueDate: Date,
        priority: TaskPriority = .medium,
        status: TaskStatus = .pending,
        category: TaskCategory = .general,
        location: TaskLocation? = nil,
        weatherDependent: Bool = false,
        routeInfo: RouteInfo? = nil,
        linkedDevices: [IoTDevice] = [],
        habitData: HabitData? = nil,
        completionTime: TimeInterval? = nil,
        tags: Set<String> = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.category = category
        self.location = location
        self.weatherDependent = weatherDependent
        self.routeInfo = routeInfo
        self.linkedDevices = linkedDevices
        self.habitData = habitData
        self.completionTime = completionTime
        self.tags = tags
    }
}

enum TaskPriority: String, Codable {
    case low, medium, high, urgent
    
    var score: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

enum TaskStatus: String, Codable {
    case pending, inProgress, completed, delayed, cancelled
}

enum TaskCategory: String, Codable, CaseIterable {
    case general, work, personal, shopping, health, fitness, commute, home
}

struct TaskLocation: Codable {
    let coordinate: CLLocationCoordinate2D
    let address: String
    let radius: Double // Geofencing radius in meters
    
    var isWithinRange: Bool {
        // TODO: Implement location checking logic
        false
    }
}

struct RouteInfo: Codable {
    let startLocation: TaskLocation
    let endLocation: TaskLocation
    let preferredTransportMode: TransportMode
    let alternativeRoutes: Bool
    let estimatedDuration: TimeInterval
}

enum TransportMode: String, Codable {
    case driving, walking, cycling, transit
}

struct IoTDevice: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: IoTDeviceType
    let macAddress: String
    var isConnected: Bool
    var lastSyncDate: Date?
}

enum IoTDeviceType: String, Codable {
    case smartLight, thermostat, speaker, lock, camera, sensor
}

struct HabitData: Codable {
    var frequency: HabitFrequency
    var streak: Int
    var bestStreak: Int
    var startDate: Date
    var completedDates: [Date]
    var reminderTime: Date?
    var linkedTasks: [UUID]
}

enum HabitFrequency: String, Codable {
    case daily, weekly, monthly, custom
    var description: String {
        rawValue.capitalized
    }
}

// Extension for Smart Task Analysis
extension SmartTask {
    var isOverdue: Bool {
        dueDate < Date() && status == .pending
    }
    
    var requiresWeatherCheck: Bool {
        weatherDependent && dueDate > Date()
    }
    
    var requiresRouteUpdate: Bool {
        routeInfo != nil && dueDate > Date()
    }
    
    func getPriorityScore() -> Double {
        var score = Double(priority.score)
        
        // Adjust score based on due date proximity
        let timeToDeadline = dueDate.timeIntervalSinceNow
        if timeToDeadline < 3600 { // Less than 1 hour
            score *= 2.0
        } else if timeToDeadline < 86400 { // Less than 24 hours
            score *= 1.5
        }
        
        // Adjust for weather dependency
        if weatherDependent {
            score *= 1.2
        }
        
        // Adjust for location requirements
        if location != nil {
            score *= 1.1
        }
        
        return score
    }
    
    func suggestOptimalTime() -> Date? {
        // TODO: Implement ML-based optimal time suggestion
        // Consider: Weather, traffic, user's schedule, habits
        nil
    }
    
    func checkDeviceAvailability() -> Bool {
        linkedDevices.allSatisfy { $0.isConnected }
    }
} 
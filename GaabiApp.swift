import SwiftUI
import CoreData
import CoreLocation

@main
struct GaabiApp: App {
    // Core managers
    @StateObject private var taskManager = TaskManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    
    // Core Data container
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(taskManager)
                .environmentObject(locationManager)
                .environmentObject(voiceManager)
                .environmentObject(aiManager)
        }
    }
}

// MARK: - Core Managers
class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var reminders: [Reminder] = []
    
    func addTask(_ task: Task) {
        tasks.append(task)
        // Add persistence logic here
    }
}

class LocationManager: ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    init() {
        self.authorizationStatus = locationManager.authorizationStatus
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
}

class VoiceManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    
    func startRecording() {
        // Implement voice recording
    }
    
    func stopRecording() {
        // Implement stop recording
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false
    
    func processTask(_ task: String) async -> String {
        // Implement OpenAI integration
        return ""
    }
}

// MARK: - Models
struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var dueDate: Date
    var priority: Int
    var isCompleted: Bool
    var notes: String?
}

struct Reminder: Identifiable, Codable {
    let id: UUID
    var title: String
    var time: Date
    var isEnabled: Bool
    var repeatDays: Set<Int>
}

// MARK: - Persistence
struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "Gaabi")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
} 
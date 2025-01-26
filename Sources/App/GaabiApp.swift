import SwiftUI
import CoreData
import CoreLocation
import CoreBluetooth

@main
struct GaabiApp: App {
    // Core managers
    @StateObject private var taskManager = TaskManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var smartHomeManager = SmartHomeManager()
    @StateObject private var habitManager = HabitManager()
    
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
                .environmentObject(smartHomeManager)
                .environmentObject(habitManager)
        }
    }
}

// MARK: - Core Managers

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var reminders: [Reminder] = []
    @Published var categories: [TaskCategory] = []
    
    init() {
        loadTasks()
        loadCategories()
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decodedTasks
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }
    
    private func loadCategories() {
        categories = TaskCategory.defaultCategories
    }
}

class LocationManager: ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var placemark: CLPlacemark?
    
    init() {
        self.authorizationStatus = locationManager.authorizationStatus
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Reverse geocode the location
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self?.placemark = placemark
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

class VoiceManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var audioURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    
    init() {
        setupSpeechRecognition()
    }
    
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer()
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                default:
                    print("Speech recognition not authorized")
                }
            }
        }
    }
    
    func startRecording() {
        // Implement voice recording
    }
    
    func stopRecording() {
        // Implement stop recording
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false
    private let openAIClient: OpenAIClient
    
    init() {
        self.openAIClient = OpenAIClient()
    }
    
    func processTask(_ task: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let response = try await openAIClient.generateResponse(for: task)
            return response
        } catch {
            print("AI processing error: \(error.localizedDescription)")
            return ""
        }
    }
    
    func analyzeVoiceNote(_ text: String) async -> AIAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let analysis = try await openAIClient.analyzeText(text)
            return analysis
        } catch {
            print("Voice note analysis error: \(error.localizedDescription)")
            return AIAnalysis()
        }
    }
}

class HabitManager: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var habitProgress: [UUID: [Date: Double]] = [:]
    
    init() {
        loadHabits()
        loadProgress()
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        saveHabits()
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        habitProgress.removeValue(forKey: habit.id)
        saveHabits()
        saveProgress()
    }
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: "habits"),
           let decodedHabits = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decodedHabits
        }
    }
    
    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: "habits")
        }
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: "habitProgress"),
           let decodedProgress = try? JSONDecoder().decode([UUID: [Date: Double]].self, from: data) {
            habitProgress = decodedProgress
        }
    }
    
    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(habitProgress) {
            UserDefaults.standard.set(encoded, forKey: "habitProgress")
        }
    }
} 
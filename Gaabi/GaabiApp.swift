import SwiftUI
import UserNotifications

@main
struct GaabiApp: App {
    @StateObject private var taskManager = TaskManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var smartHomeManager = SmartHomeManager()
    
    init() {
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskManager)
                .environmentObject(locationManager)
                .environmentObject(voiceManager)
                .environmentObject(aiManager)
                .environmentObject(smartHomeManager)
                .preferredColorScheme(.dark) // Start with dark mode
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
} 
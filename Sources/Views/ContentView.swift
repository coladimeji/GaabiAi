import SwiftUI
import Foundation

// Import managers
@_spi(Gaabi) import TaskManager
@_spi(Gaabi) import LocationManager
@_spi(Gaabi) import VoiceManager
@_spi(Gaabi) import AIManager
@_spi(Gaabi) import SmartHomeManager

struct ContentView: View {
    @StateObject private var taskManager = TaskManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var smartHomeManager = SmartHomeManager()
    
    var body: some View {
        TabView {
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            
            NavigationView {
                TaskListView()
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            
            NavigationView {
                VoiceNoteListView()
            }
            .tabItem {
                Label("Voice", systemImage: "mic")
            }
            
            NavigationView {
                HabitListView()
            }
            .tabItem {
                Label("Habits", systemImage: "repeat")
            }
            
            NavigationView {
                SmartHomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
        }
        .environmentObject(taskManager)
        .environmentObject(locationManager)
        .environmentObject(voiceManager)
        .environmentObject(aiManager)
        .environmentObject(smartHomeManager)
    }
}

#Preview {
    ContentView()
} 
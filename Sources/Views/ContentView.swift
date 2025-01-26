import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = TaskManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var smartHomeManager = SmartHomeManager()
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
            
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            VoiceNoteListView()
                .tabItem {
                    Label("Voice Notes", systemImage: "waveform")
                }
            
            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "chart.bar.fill")
                }
            
            SmartHomeView()
                .tabItem {
                    Label("Smart Home", systemImage: "homekit")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(taskManager)
        .environmentObject(locationManager)
        .environmentObject(voiceManager)
        .environmentObject(aiManager)
        .environmentObject(smartHomeManager)
    }
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
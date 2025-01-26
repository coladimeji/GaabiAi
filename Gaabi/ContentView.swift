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
                .environmentObject(taskManager)
                .environmentObject(locationManager)
                .environmentObject(aiManager)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            TaskListView()
                .environmentObject(taskManager)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            VoiceNoteListView()
                .environmentObject(voiceManager)
                .tabItem {
                    Label("Voice", systemImage: "waveform")
                }
            
            HabitListView()
                .environmentObject(taskManager)
                .tabItem {
                    Label("Habits", systemImage: "chart.bar.fill")
                }
            
            SmartHomeView()
                .environmentObject(smartHomeManager)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
        }
    }
}

#Preview {
    ContentView()
} 
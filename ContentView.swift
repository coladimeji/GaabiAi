import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var aiManager: AIManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            VoiceCommandView()
                .tabItem {
                    Label("Voice", systemImage: "mic.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    WeatherSummaryCard()
                    DailyScheduleCard()
                    TaskSummaryCard()
                    TrafficUpdateCard()
                }
                .padding()
            }
            .navigationTitle("Gaabi")
        }
    }
}

struct WeatherSummaryCard: View {
    var body: some View {
        VStack {
            Text("Weather Summary")
                .font(.headline)
            // Implement weather details
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct DailyScheduleCard: View {
    var body: some View {
        VStack {
            Text("Today's Schedule")
                .font(.headline)
            // Implement schedule list
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct TaskSummaryCard: View {
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        VStack {
            Text("Tasks")
                .font(.headline)
            // Implement task list
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct TrafficUpdateCard: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack {
            Text("Traffic Updates")
                .font(.headline)
            // Implement traffic information
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TaskManager())
            .environmentObject(LocationManager())
            .environmentObject(VoiceManager())
            .environmentObject(AIManager())
    }
} 
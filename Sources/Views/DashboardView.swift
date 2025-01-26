import SwiftUI
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var aiManager: AIManager
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    
    @State private var showingAIAssistant = false
    @State private var aiPrompt = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LocationSummaryCard(locationManager: locationManager)
                
                TasksOverviewCard(taskManager: taskManager)
                
                HabitsProgressCard(taskManager: taskManager)
                
                AIAssistantCard(isPresented: $showingAIAssistant)
                
                QuickActionsCard()
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingAIAssistant) {
            AIAssistantView(aiManager: aiManager, prompt: $aiPrompt)
        }
    }
}

struct LocationSummaryCard: View {
    let locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Current Location")
                .font(.headline)
            if let address = locationManager.lastKnownAddress {
                Text(address)
                    .font(.subheadline)
            } else {
                Text("Updating location...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let trafficInfo = locationManager.trafficInfo {
                Text(trafficInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TasksOverviewCard: View {
    let taskManager: TaskManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(taskManager.tasks.filter { $0.isOverdue }.count)")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("Overdue")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(taskManager.tasks.filter { $0.dueDate.isToday }.count)")
                        .font(.title)
                        .foregroundColor(.primary)
                    Text("Today")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(taskManager.tasks.filter { $0.isCompleted }.count)")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct HabitsProgressCard: View {
    let taskManager: TaskManager
    
    var completionRate: Double {
        let habits = taskManager.habits
        guard !habits.isEmpty else { return 0 }
        let completedToday = habits.filter { $0.isCompletedToday }.count
        return Double(completedToday) / Double(habits.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habits")
                .font(.headline)
            
            ProgressView(value: completionRate)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                Text("\(Int(completionRate * 100))% Complete")
                    .font(.caption)
                Spacer()
                Text("\(taskManager.habits.filter { $0.isCompletedToday }.count)/\(taskManager.habits.count) Today")
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct AIAssistantCard: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        Button(action: { isPresented = true }) {
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("AI Assistant")
                        .font(.headline)
                    Text("Get help with tasks and automation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(title: "New Task", systemImage: "plus.circle", color: .blue)
                QuickActionButton(title: "New Habit", systemImage: "repeat.circle", color: .green)
                QuickActionButton(title: "Smart Home", systemImage: "homekit", color: .orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct AIAssistantView: View {
    let aiManager: AIManager
    @Binding var prompt: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Ask me anything...", text: $prompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                if let response = aiManager.lastResponse {
                    Text(response)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .navigationTitle("AI Assistant")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(TaskManager())
        .environmentObject(LocationManager())
        .environmentObject(VoiceManager())
        .environmentObject(AIManager())
        .environmentObject(SmartHomeManager())
} 
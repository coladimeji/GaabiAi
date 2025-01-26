import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var aiManager: AIManager
    @State private var showingAIAssistant = false
    @State private var aiPrompt = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Weather and Location Card
                    LocationSummaryCard(location: locationManager.lastKnownAddress ?? "Updating location...")
                    
                    // Tasks Overview
                    TasksOverviewCard(tasks: taskManager.tasks)
                    
                    // Habits Progress
                    HabitsProgressCard(habits: taskManager.habits)
                    
                    // AI Assistant Quick Access
                    AIAssistantCard()
                        .onTapGesture {
                            showingAIAssistant = true
                        }
                    
                    // Quick Actions
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingAIAssistant) {
                AIAssistantView()
            }
        }
    }
}

// MARK: - Supporting Views
struct LocationSummaryCard: View {
    let location: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current Location", systemImage: "location.fill")
                .font(.headline)
            Text(location)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct TasksOverviewCard: View {
    let tasks: [Task]
    
    var overdueTasks: [Task] {
        tasks.filter { $0.isOverdue }
    }
    
    var todaysTasks: [Task] {
        tasks.filter { $0.isDueToday }
    }
    
    var completedTodayCount: Int {
        todaysTasks.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Tasks Overview", systemImage: "list.bullet.circle.fill")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(todaysTasks.count)")
                        .font(.title)
                        .bold()
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(completedTodayCount)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !overdueTasks.isEmpty {
                    VStack {
                        Text("\(overdueTasks.count)")
                            .font(.title)
                            .bold()
                            .foregroundColor(.red)
                        Text("Overdue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !todaysTasks.isEmpty {
                Divider()
                
                Text("Today's Tasks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(todaysTasks.prefix(3)) { task in
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .green : .gray)
                        Text(task.title)
                            .strikethrough(task.isCompleted)
                        Spacer()
                        if task.hasReminder {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if todaysTasks.count > 3 {
                    Text("+ \(todaysTasks.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct HabitsProgressCard: View {
    let habits: [Habit]
    
    var completedToday: Int {
        habits.filter { $0.isCompletedToday }.count
    }
    
    var completionRate: Double {
        guard !habits.isEmpty else { return 0 }
        return Double(completedToday) / Double(habits.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Habits Progress", systemImage: "chart.bar.fill")
                .font(.headline)
            
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(completionRate * 100))%")
                            .font(.title2)
                            .bold()
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(completedToday)/\(habits.count) habits completed today")
                        .font(.subheadline)
                    
                    if let topHabit = habits.max(by: { $0.currentStreak < $1.currentStreak }),
                       topHabit.currentStreak > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(topHabit.currentStreak) day streak: \(topHabit.title)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct AIAssistantCard: View {
    @EnvironmentObject var aiManager: AIManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI Assistant", systemImage: "brain")
                .font(.headline)
            
            Text("Ask me anything...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let lastResponse = aiManager.lastResponse {
                Text(lastResponse)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct QuickActionsCard: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingNewTask = false
    @State private var showingNewHabit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)
            
            HStack {
                Button(action: { showingNewTask = true }) {
                    VStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                        Text("New Task")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Button(action: { showingNewHabit = true }) {
                    VStack {
                        Image(systemName: "repeat.circle.fill")
                            .font(.system(size: 30))
                        Text("New Habit")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: SmartHomeView()) {
                    VStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 30))
                        Text("Smart Home")
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showingNewTask) {
            NewTaskView()
        }
        .sheet(isPresented: $showingNewHabit) {
            NewHabitView()
        }
    }
}

struct AIAssistantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiManager: AIManager
    @State private var prompt = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if aiManager.isProcessing {
                    ProgressView()
                        .padding()
                } else if let error = aiManager.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                } else if let response = aiManager.lastResponse {
                    ScrollView {
                        Text(response)
                            .padding()
                    }
                }
                
                Spacer()
                
                HStack {
                    TextField("Ask me anything...", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        Task {
                            await aiManager.generateResponse(for: prompt)
                            prompt = ""
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(prompt.isEmpty || aiManager.isProcessing)
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(TaskManager())
        .environmentObject(LocationManager())
        .environmentObject(AIManager())
} 
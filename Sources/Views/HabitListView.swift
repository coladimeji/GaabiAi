import SwiftUI

struct HabitListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingNewHabit = false
    @State private var selectedTimeframe: Timeframe = .day
    @State private var searchText = ""
    
    enum Timeframe: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }
    
    var filteredHabits: [Habit] {
        taskManager.habits.filter { habit in
            if searchText.isEmpty {
                return true
            }
            return habit.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var completionRate: Double {
        let habits = filteredHabits
        guard !habits.isEmpty else { return 0 }
        
        let completedCount: Int
        switch selectedTimeframe {
        case .day:
            completedCount = habits.filter { $0.isCompletedToday }.count
        case .week:
            completedCount = habits.filter { $0.isCompletedThisWeek }.count
        case .month:
            completedCount = habits.filter { $0.isCompletedThisMonth }.count
        }
        
        return Double(completedCount) / Double(habits.count)
    }
    
    var body: some View {
        List {
            Section {
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                HabitProgressView(completionRate: completionRate)
            }
            .listRowBackground(Color.clear)
            
            if filteredHabits.isEmpty {
                Section {
                    Text("No habits yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                Section {
                    ForEach(filteredHabits) { habit in
                        HabitRow(habit: habit)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    taskManager.removeHabit(habit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    taskManager.toggleHabitCompletion(habit)
                                } label: {
                                    Label(
                                        habit.isCompletedToday ? "Incomplete" : "Complete",
                                        systemImage: habit.isCompletedToday ? "xmark.circle" : "checkmark.circle"
                                    )
                                }
                                .tint(habit.isCompletedToday ? .orange : .green)
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search habits")
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewHabit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewHabit) {
            NewHabitView()
        }
    }
}

struct HabitProgressView: View {
    let completionRate: Double
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(completionRate * 100))%")
                        .font(.title)
                        .bold()
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        HStack {
            Button {
                taskManager.toggleHabitCompletion(habit)
            } label: {
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(habit.isCompletedToday ? .green : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .strikethrough(habit.isCompletedToday)
                
                HStack {
                    Label("\(habit.currentStreak) day streak", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    if habit.hasReminder {
                        Label("Reminder set", systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(habit.frequency.description)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                if habit.bestStreak > 0 {
                    Text("Best: \(habit.bestStreak) days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewHabitView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    
    @State private var title = ""
    @State private var frequency = Frequency.daily
    @State private var reminder = false
    @State private var reminderTime = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: $frequency) {
                        Text("Daily").tag(Frequency.daily)
                        Text("Weekly").tag(Frequency.weekly)
                        Text("Monthly").tag(Frequency.monthly)
                    }
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Set Reminder", isOn: $reminder)
                    
                    if reminder {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    let habit = Habit(
                        title: title,
                        frequency: frequency,
                        reminder: reminder ? reminderTime : nil,
                        notes: notes
                    )
                    taskManager.addHabit(habit)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

#Preview {
    HabitListView()
        .environmentObject(TaskManager())
} 
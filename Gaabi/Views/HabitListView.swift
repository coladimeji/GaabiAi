import SwiftUI

struct HabitListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingNewHabitSheet = false
    @State private var selectedTimeframe: Timeframe = .week
    
    enum Timeframe: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Timeframe Picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Progress Overview
                HabitProgressView(habits: taskManager.habits,
                                timeframe: selectedTimeframe)
                
                // Habits List
                List {
                    ForEach(taskManager.habits) { habit in
                        HabitRow(habit: habit)
                    }
                    .onDelete(perform: deleteHabit)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewHabitSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewHabitSheet) {
                NewHabitView()
            }
        }
    }
    
    private func deleteHabit(at offsets: IndexSet) {
        offsets.forEach { index in
            let habit = taskManager.habits[index]
            taskManager.removeHabit(habit)
        }
    }
}

struct HabitProgressView: View {
    let habits: [Habit]
    let timeframe: HabitListView.Timeframe
    
    var completionRate: Double {
        guard !habits.isEmpty else { return 0 }
        let completed = habits.filter { $0.isCompletedForTimeframe(timeframe) }.count
        return Double(completed) / Double(habits.count)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 15)
                
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 15, lineCap: .round))
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
            .frame(width: 150, height: 150)
            .padding()
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(habits.filter { $0.isCompletedForTimeframe(timeframe) }.count)")
                        .font(.title2)
                        .bold()
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(habits.count)")
                        .font(.title2)
                        .bold()
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

struct HabitRow: View {
    @EnvironmentObject var taskManager: TaskManager
    let habit: Habit
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(habit.title)
                    Text(habit.frequency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if habit.isCompletedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button(action: { taskManager.toggleHabitCompletion(habit) }) {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            HabitDetailView(habit: habit)
        }
    }
}

struct NewHabitView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    
    @State private var title = ""
    @State private var frequency = Habit.Frequency.daily
    @State private var reminder = false
    @State private var reminderTime = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Title", text: $title)
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Habit.Frequency.allCases) { frequency in
                            Text(frequency.description).tag(frequency)
                        }
                    }
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Set Reminder", isOn: $reminder)
                    if reminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
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

struct HabitDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    let habit: Habit
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Details")) {
                    LabeledContent("Frequency", value: habit.frequency.description)
                    if let reminder = habit.reminder {
                        LabeledContent("Reminder", value: reminder.formatted(date: .omitted, time: .shortened))
                    }
                    if !habit.notes.isEmpty {
                        Text(habit.notes)
                    }
                }
                
                Section(header: Text("Progress")) {
                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(habit.currentStreak) days")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Best Streak")
                        Spacer()
                        Text("\(habit.bestStreak) days")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("History")) {
                    ForEach(habit.completionHistory.prefix(7)) { completion in
                        HStack {
                            Text(completion.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle(habit.title)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    HabitListView()
        .environmentObject(TaskManager())
} 
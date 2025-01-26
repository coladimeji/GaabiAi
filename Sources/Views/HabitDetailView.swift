import SwiftUI
import Charts

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: HabitDetailViewModel
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    init(habit: Habit) {
        _viewModel = StateObject(wrappedValue: HabitDetailViewModel(habit: habit))
    }
    
    var body: some View {
        List {
            // Basic Info Section
            Section {
                if isEditing {
                    TextField("Title", text: $viewModel.title)
                    TextField("Description", text: $viewModel.description)
                } else {
                    Text(viewModel.title)
                        .font(.headline)
                    Text(viewModel.description)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats Section
            Section("Statistics") {
                HStack {
                    StatBox(title: "Current Streak", value: "\(viewModel.currentStreak) 🔥")
                    StatBox(title: "Best Streak", value: "\(viewModel.bestStreak) ⭐️")
                    StatBox(title: "Completion Rate", value: "\(Int(viewModel.completionRate * 100))%")
                }
                .listRowInsets(EdgeInsets())
                .padding()
                
                // Completion Chart
                Chart {
                    ForEach(viewModel.weeklyCompletions) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .week),
                            y: .value("Completions", week.completions)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 200)
                .padding(.vertical)
            }
            
            // Schedule Section
            Section("Schedule") {
                if isEditing {
                    Picker("Frequency", selection: $viewModel.frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.description).tag(frequency)
                        }
                    }
                    
                    if viewModel.frequency == .weekly {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Toggle(day.description, isOn: Binding(
                                get: { viewModel.selectedDays.contains(day) },
                                set: { isSelected in
                                    if isSelected {
                                        viewModel.selectedDays.insert(day)
                                    } else {
                                        viewModel.selectedDays.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                    
                    DatePicker("Reminder Time", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                } else {
                    LabeledContent("Frequency", value: viewModel.frequency.description)
                    if viewModel.frequency == .weekly {
                        Text(viewModel.selectedDaysDescription)
                    }
                    LabeledContent("Reminder Time", value: viewModel.reminderTimeFormatted)
                }
            }
            
            // Location Section
            Section("Location") {
                if isEditing {
                    Toggle("Location Based", isOn: $viewModel.isLocationBased)
                    
                    if viewModel.isLocationBased {
                        Button {
                            viewModel.showingLocationPicker = true
                        } label: {
                            if let location = viewModel.location {
                                Text(location.name)
                            } else {
                                Text("Select Location")
                            }
                        }
                    }
                } else if let location = viewModel.location {
                    LabeledContent("Location", value: location.name)
                    
                    // Mini Map
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))
                    .frame(height: 150)
                    .cornerRadius(10)
                }
            }
            
            // Linked Tasks Section
            Section("Linked Tasks") {
                ForEach(viewModel.linkedTasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        TaskRow(task: task)
                    }
                }
                
                Button {
                    viewModel.showingTaskPicker = true
                } label: {
                    Label("Link Task", systemImage: "link")
                }
            }
            
            // Completion History Section
            Section("Completion History") {
                ForEach(viewModel.completionHistory) { completion in
                    HStack {
                        Text(completion.date.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            if !isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Habit", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Habit" : "Habit Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if isEditing {
                        viewModel.saveChanges()
                    }
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingLocationPicker) {
            LocationPickerView(selectedLocation: $viewModel.location)
        }
        .sheet(isPresented: $viewModel.showingTaskPicker) {
            TaskPickerView(selectedTasks: $viewModel.linkedTasks)
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteHabit()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

class HabitDetailViewModel: ObservableObject {
    @Published var title: String
    @Published var description: String
    @Published var frequency: HabitFrequency
    @Published var selectedDays: Set<DayOfWeek>
    @Published var reminderTime: Date
    @Published var isLocationBased: Bool
    @Published var location: TaskLocation?
    @Published var linkedTasks: [SmartTask]
    @Published var showingLocationPicker = false
    @Published var showingTaskPicker = false
    
    private let habit: Habit
    private let habitTracker: HabitTracker
    
    init(habit: Habit) {
        self.habit = habit
        self.habitTracker = HabitTracker()
        
        self.title = habit.title
        self.description = habit.description
        self.frequency = habit.frequency
        self.selectedDays = habit.selectedDays
        self.reminderTime = habit.reminderTime
        self.isLocationBased = habit.location != nil
        self.location = habit.location
        self.linkedTasks = []
        
        // Load linked tasks
        Task {
            await loadLinkedTasks()
        }
    }
    
    var currentStreak: Int {
        habit.currentStreak
    }
    
    var bestStreak: Int {
        habit.bestStreak
    }
    
    var completionRate: Double {
        habit.completionRate
    }
    
    var weeklyCompletions: [WeeklyCompletion] {
        // Group completions by week
        let calendar = Calendar.current
        let groupedCompletions = Dictionary(grouping: habit.completedDates) { date in
            calendar.startOfWeek(for: date)
        }
        
        return groupedCompletions.map { weekStart, dates in
            WeeklyCompletion(weekStart: weekStart, completions: dates.count)
        }.sorted { $0.weekStart < $1.weekStart }
    }
    
    var completionHistory: [HabitCompletion] {
        habit.completedDates.map { date in
            HabitCompletion(id: UUID(), date: date)
        }.sorted { $0.date > $1.date }
    }
    
    var selectedDaysDescription: String {
        selectedDays.map { $0.description }.sorted().joined(separator: ", ")
    }
    
    var reminderTimeFormatted: String {
        reminderTime.formatted(date: .omitted, time: .shortened)
    }
    
    @MainActor
    private func loadLinkedTasks() async {
        // Load linked tasks from database
    }
    
    func saveChanges() {
        let updatedHabit = Habit(
            id: habit.id,
            title: title,
            description: description,
            frequency: frequency,
            selectedDays: selectedDays,
            reminderTime: reminderTime,
            location: isLocationBased ? location : nil,
            createdDate: habit.createdDate,
            isActive: habit.isActive,
            currentStreak: habit.currentStreak,
            completionRate: habit.completionRate,
            completedDates: habit.completedDates
        )
        
        Task {
            await habitTracker.updateHabit(updatedHabit)
        }
    }
    
    func deleteHabit() {
        Task {
            await habitTracker.deleteHabit(habit)
        }
    }
}

struct WeeklyCompletion: Identifiable {
    let id = UUID()
    let weekStart: Date
    let completions: Int
}

struct HabitCompletion: Identifiable {
    let id: UUID
    let date: Date
} 
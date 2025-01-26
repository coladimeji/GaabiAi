import SwiftUI

struct HabitListView: View {
    @StateObject private var viewModel = HabitListViewModel()
    @State private var showingNewHabit = false
    @State private var searchText = ""
    @State private var selectedSortOption: HabitSortOption = .name
    
    var body: some View {
        NavigationView {
            List {
                // Active Habits Section
                if !viewModel.activeHabits.isEmpty {
                    Section("Active Habits") {
                        ForEach(filteredHabits.filter { $0.isActive }) { habit in
                            NavigationLink {
                                HabitDetailView(habit: habit)
                            } label: {
                                HabitRow(habit: habit)
                            }
                        }
                    }
                }
                
                // Inactive Habits Section
                if !viewModel.inactiveHabits.isEmpty {
                    Section("Inactive Habits") {
                        ForEach(filteredHabits.filter { !$0.isActive }) { habit in
                            NavigationLink {
                                HabitDetailView(habit: habit)
                            } label: {
                                HabitRow(habit: habit)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $selectedSortOption) {
                            ForEach(HabitSortOption.allCases, id: \.self) { option in
                                Text(option.description).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingNewHabit) {
                NewHabitView { habit in
                    viewModel.addHabit(habit)
                }
            }
        }
    }
    
    private var filteredHabits: [Habit] {
        let habits = viewModel.habits
        
        let filtered = searchText.isEmpty ? habits : habits.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        return filtered.sorted { first, second in
            switch selectedSortOption {
            case .name:
                return first.title < second.title
            case .streak:
                return first.currentStreak > second.currentStreak
            case .completion:
                return first.completionRate > second.completionRate
            case .created:
                return first.createdDate > second.createdDate
            }
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(habit.title)
                    .font(.headline)
                
                Spacer()
                
                if habit.isActive {
                    Text("\(habit.currentStreak) 🔥")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text(habit.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(Int(habit.completionRate * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * habit.completionRate, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

struct NewHabitView: View {
    @Environment(\.dismiss) private var dismiss
    let onHabitCreated: (Habit) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var frequency = HabitFrequency.daily
    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
    @State private var selectedDays: Set<DayOfWeek> = Set(DayOfWeek.allCases)
    @State private var isLocationBased = false
    @State private var location: TaskLocation?
    @State private var showingLocationPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.description).tag(frequency)
                        }
                    }
                    
                    if frequency == .weekly {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Toggle(day.description, isOn: Binding(
                                get: { selectedDays.contains(day) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDays.insert(day)
                                    } else {
                                        selectedDays.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                    
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Location") {
                    Toggle("Location Based", isOn: $isLocationBased)
                    
                    if isLocationBased {
                        Button {
                            showingLocationPicker = true
                        } label: {
                            if let location = location {
                                Text(location.name)
                            } else {
                                Text("Select Location")
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createHabit()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $location)
            }
        }
    }
    
    private func createHabit() {
        let habit = Habit(
            id: UUID(),
            title: title,
            description: description,
            frequency: frequency,
            selectedDays: selectedDays,
            reminderTime: reminderTime,
            location: isLocationBased ? location : nil,
            createdDate: Date(),
            isActive: true,
            currentStreak: 0,
            completionRate: 0,
            completedDates: []
        )
        
        onHabitCreated(habit)
        dismiss()
    }
}

enum HabitSortOption: String, CaseIterable {
    case name
    case streak
    case completion
    case created
    
    var description: String {
        switch self {
        case .name: return "Name"
        case .streak: return "Streak"
        case .completion: return "Completion Rate"
        case .created: return "Recently Created"
        }
    }
}

class HabitListViewModel: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    
    var activeHabits: [Habit] {
        habits.filter { $0.isActive }
    }
    
    var inactiveHabits: [Habit] {
        habits.filter { !$0.isActive }
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
    }
    
    func toggleHabitStatus(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isActive.toggle()
        }
    }
} 
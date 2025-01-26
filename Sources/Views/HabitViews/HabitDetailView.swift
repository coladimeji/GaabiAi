import SwiftUI

struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var selectedTimeframe: Timeframe = .week
    @State private var progressValue: Double = 0
    
    enum Timeframe: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    HabitHeaderCard(habit: habit)
                    
                    // Progress Input
                    ProgressInputCard(
                        habit: habit,
                        value: $progressValue,
                        onSave: {
                            viewModel.logProgress(for: habit, value: progressValue)
                        }
                    )
                    
                    // Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistics")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Timeframe", selection: $selectedTimeframe) {
                            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                Text(timeframe.rawValue).tag(timeframe)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        StatisticsGrid(habit: habit, timeframe: selectedTimeframe)
                        
                        ProgressChart(habit: habit, timeframe: selectedTimeframe)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    
                    // Reminders
                    if let reminder = habit.reminder {
                        ReminderCard(reminder: reminder)
                    }
                    
                    // Notes
                    if let notes = habit.notes {
                        NotesCard(notes: notes)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Text("Delete Habit")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitle(habit.name, displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Edit") {
                    showingEditSheet = true
                }
            )
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Habit"),
                    message: Text("Are you sure you want to delete this habit?"),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteHabit(habit)
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingEditSheet) {
                EditHabitView(habit: habit, viewModel: viewModel)
            }
        }
    }
}

struct HabitHeaderCard: View {
    let habit: Habit
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: iconName(for: habit.category))
                    .font(.title)
                    .foregroundColor(.blue)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(habit.streak) day streak")
                            .font(.headline)
                    }
                    
                    Text(frequencyDescription(for: habit.frequency))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(habit.target.value)) \(habit.target.unit)")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(habit.category.description)
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func iconName(for category: HabitCategory) -> String {
        switch category {
        case .fitness: return "figure.walk"
        case .health: return "heart.fill"
        case .productivity: return "checkmark.circle.fill"
        case .mindfulness: return "brain.head.profile"
        case .learning: return "book.fill"
        case .custom: return "star.fill"
        }
    }
    
    private func frequencyDescription(for frequency: HabitFrequency) -> String {
        switch frequency {
        case .daily(let times):
            return "\(times) time\(times > 1 ? "s" : "") daily"
        case .weekly(let days, let times):
            return "\(times) time\(times > 1 ? "s" : "") on \(days.count) day\(days.count > 1 ? "s" : "")"
        case .monthly(let days):
            return "\(days.count) day\(days.count > 1 ? "s" : "") monthly"
        case .custom(let interval, let unit):
            return "Every \(interval) \(unit.description)"
        }
    }
}

struct ProgressInputCard: View {
    let habit: Habit
    @Binding var value: Double
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Log Progress")
                .font(.headline)
            
            if habit.target.type == .completion {
                Button(action: {
                    value = habit.target.value
                    onSave()
                }) {
                    Text("Complete")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                VStack(spacing: 8) {
                    Slider(value: $value, in: 0...habit.target.value * 2)
                    
                    HStack {
                        Text("0")
                        Spacer()
                        Text("\(Int(value)) \(habit.target.unit)")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(habit.target.value * 2))")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Button(action: onSave) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct StatisticsGrid: View {
    let habit: Habit
    let timeframe: HabitDetailView.Timeframe
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(title: "Total", value: "42", unit: habit.target.unit)
            StatCard(title: "Average", value: "3.5", unit: "per day")
            StatCard(title: "Best Streak", value: "\(habit.streak)", unit: "days")
            StatCard(title: "Completion Rate", value: "85", unit: "%")
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProgressChart: View {
    let habit: Habit
    let timeframe: HabitDetailView.Timeframe
    
    var body: some View {
        // Placeholder for actual chart implementation
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay(
                Text("Progress Chart")
                    .foregroundColor(.gray)
            )
    }
}

struct ReminderCard: View {
    let reminder: HabitReminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                Text("Reminder")
                    .font(.headline)
            }
            
            Text(timeString(from: reminder.time))
                .font(.subheadline)
            
            if !reminder.days.isEmpty {
                Text(daysDescription(for: reminder.days))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let message = reminder.message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func daysDescription(for days: Set<WeekDay>) -> String {
        days.map { $0.rawValue.capitalized }.joined(separator: ", ")
    }
}

struct NotesCard: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.blue)
                Text("Notes")
                    .font(.headline)
            }
            
            Text(notes)
                .font(.body)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
} 
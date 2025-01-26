import SwiftUI

struct AddHabitView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var category: HabitCategory = .fitness
    @State private var customCategory = ""
    @State private var showingCustomCategory = false
    @State private var frequency = HabitFrequency.daily(times: 1)
    @State private var selectedDays: Set<WeekDay> = []
    @State private var timesPerDay = 1
    @State private var targetType: TargetType = .completion
    @State private var targetValue: Double = 1
    @State private var targetUnit = ""
    @State private var hasReminder = false
    @State private var reminderTime = Date()
    @State private var reminderDays: Set<WeekDay> = []
    @State private var reminderMessage = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases.filter {
                            if case .custom = $0 { return false }
                            return true
                        }, id: \.self) { category in
                            Text(category.description).tag(category)
                        }
                        Text("Custom").tag(HabitCategory.custom(""))
                    }
                    .onChange(of: category) { newValue in
                        if case .custom = newValue {
                            showingCustomCategory = true
                        }
                    }
                    
                    if showingCustomCategory {
                        TextField("Custom Category", text: $customCategory)
                    }
                }
                
                Section(header: Text("Frequency")) {
                    Picker("Repeat", selection: $frequency) {
                        Text("Daily").tag(HabitFrequency.daily(times: timesPerDay))
                        Text("Weekly").tag(HabitFrequency.weekly(days: selectedDays, times: timesPerDay))
                        Text("Monthly").tag(HabitFrequency.monthly(days: []))
                    }
                    
                    if case .daily = frequency {
                        Stepper("Times per day: \(timesPerDay)", value: $timesPerDay, in: 1...10)
                    } else if case .weekly = frequency {
                        ForEach(WeekDay.allCases, id: \.self) { day in
                            Toggle(day.rawValue.capitalized, isOn: Binding(
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
                        Stepper("Times per day: \(timesPerDay)", value: $timesPerDay, in: 1...10)
                    }
                }
                
                Section(header: Text("Target")) {
                    Picker("Type", selection: $targetType) {
                        Text("Completion").tag(TargetType.completion)
                        Text("Duration").tag(TargetType.duration)
                        Text("Distance").tag(TargetType.distance)
                        Text("Quantity").tag(TargetType.quantity)
                        Text("Weight").tag(TargetType.weight)
                    }
                    
                    if targetType != .completion {
                        HStack {
                            TextField("Value", value: $targetValue, format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Unit", text: $targetUnit)
                        }
                    }
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    
                    if hasReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        
                        ForEach(WeekDay.allCases, id: \.self) { day in
                            Toggle(day.rawValue.capitalized, isOn: Binding(
                                get: { reminderDays.contains(day) },
                                set: { isSelected in
                                    if isSelected {
                                        reminderDays.insert(day)
                                    } else {
                                        reminderDays.remove(day)
                                    }
                                }
                            ))
                        }
                        
                        TextField("Reminder Message", text: $reminderMessage)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationBarTitle("Add Habit", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    addHabit()
                }
                .disabled(name.isEmpty || (showingCustomCategory && customCategory.isEmpty))
            )
        }
    }
    
    private func addHabit() {
        let finalCategory = showingCustomCategory ? HabitCategory.custom(customCategory) : category
        let target = HabitTarget(
            type: targetType,
            value: targetValue,
            unit: targetUnit.isEmpty ? defaultUnit(for: targetType) : targetUnit
        )
        
        let reminder = hasReminder ? HabitReminder(
            time: reminderTime,
            days: reminderDays,
            message: reminderMessage.isEmpty ? nil : reminderMessage,
            isEnabled: true
        ) : nil
        
        let habit = Habit(
            name: name,
            category: finalCategory,
            frequency: frequency,
            target: target,
            reminder: reminder,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.addHabit(habit)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func defaultUnit(for type: TargetType) -> String {
        switch type {
        case .completion: return "times"
        case .duration: return "minutes"
        case .distance: return "km"
        case .quantity: return "times"
        case .weight: return "kg"
        }
    }
} 
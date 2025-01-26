import Foundation
import SwiftUI

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedDate: Date = Date()
    @Published var habitProgress: [UUID: [Date: Double]] = [:]
    
    init() {
        loadHabits()
        loadProgress()
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        saveHabits()
        
        if let reminder = habit.reminder {
            scheduleHabitReminder(habit, reminder)
        }
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
            
            if let reminder = habit.reminder {
                scheduleHabitReminder(habit, reminder)
            }
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        habitProgress.removeValue(forKey: habit.id)
        saveHabits()
        saveProgress()
    }
    
    func logProgress(for habit: Habit, value: Double, date: Date = Date()) {
        var progress = habitProgress[habit.id] ?? [:]
        progress[date] = value
        habitProgress[habit.id] = progress
        
        updateStreak(for: habit)
        saveProgress()
    }
    
    func getProgress(for habit: Habit, on date: Date) -> Double? {
        return habitProgress[habit.id]?[date]
    }
    
    func updateStreak(for habit: Habit) {
        guard var updatedHabit = habits.first(where: { $0.id == habit.id }) else { return }
        
        let calendar = Calendar.current
        var currentDate = habit.startDate
        var streak = 0
        
        while currentDate <= Date() {
            if let progress = getProgress(for: habit, on: currentDate),
               progress >= habit.target.value {
                streak += 1
            } else {
                streak = 0
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
        }
        
        updatedHabit.streak = streak
        updateHabit(updatedHabit)
    }
    
    private func scheduleHabitReminder(_ habit: Habit, _ reminder: HabitReminder) {
        guard reminder.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder: \(habit.name)"
        if let message = reminder.message {
            content.body = message
        } else {
            content.body = "Time to work on your \(habit.name) habit!"
        }
        content.sound = .default
        
        for day in reminder.days {
            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminder.time)
            dateComponents.weekday = day.rawValue
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(habit.id)-\(day.rawValue)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: "habits"),
           let decodedHabits = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decodedHabits
        }
    }
    
    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: "habits")
        }
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: "habitProgress"),
           let decodedProgress = try? JSONDecoder().decode([UUID: [Date: Double]].self, from: data) {
            habitProgress = decodedProgress
        }
    }
    
    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(habitProgress) {
            UserDefaults.standard.set(encoded, forKey: "habitProgress")
        }
    }
} 
import Foundation
import SwiftUI

@MainActor
class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var habits: [Habit] = []
    @Published var selectedDate: Date = Date()
    
    private let tasksKey = "saved_tasks"
    private let habitsKey = "saved_habits"
    
    init() {
        loadTasks()
        loadHabits()
    }
    
    // MARK: - Tasks Management
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decodedTasks
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
        if task.hasReminder {
            scheduleReminder(for: task)
        }
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
            if task.hasReminder {
                scheduleReminder(for: task)
            }
        }
    }
    
    func removeTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
        if task.hasReminder {
            cancelReminder(for: task)
        }
    }
    
    func toggleTaskCompletion(_ task: Task) {
        if var task = tasks.first(where: { $0.id == task.id }) {
            task.toggleCompletion()
            updateTask(task)
        }
    }
    
    var todaysTasks: [Task] {
        tasks.filter { $0.isDueToday }
    }
    
    // MARK: - Habits Management
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decodedHabits = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decodedHabits
        }
    }
    
    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: habitsKey)
        }
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        saveHabits()
        if let reminder = habit.reminder {
            scheduleHabitReminder(for: habit, at: reminder)
        }
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
            if let reminder = habit.reminder {
                scheduleHabitReminder(for: habit, at: reminder)
            }
        }
    }
    
    func removeHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        saveHabits()
        if habit.reminder != nil {
            cancelHabitReminder(for: habit)
        }
    }
    
    func toggleHabitCompletion(_ habit: Habit) {
        if var habit = habits.first(where: { $0.id == habit.id }) {
            habit.toggleCompletion()
            updateHabit(habit)
        }
    }
    
    // MARK: - Notifications
    
    private func scheduleReminder(for task: Task) {
        guard let reminderDate = task.reminderDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "task-\(task.id.uuidString)",
                                          content: content,
                                          trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelReminder(for task: Task) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["task-\(task.id.uuidString)"])
    }
    
    private func scheduleHabitReminder(for habit: Habit, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = "Time to complete your habit: \(habit.title)"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "habit-\(habit.id.uuidString)",
                                          content: content,
                                          trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelHabitReminder(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["habit-\(habit.id.uuidString)"])
    }
} 
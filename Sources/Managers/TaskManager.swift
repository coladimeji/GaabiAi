import Foundation
import SwiftUI

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var selectedDate: Date = Date()
    
    init() {
        loadTasks()
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let savedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = savedTasks
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func removeTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func tasksForDate(_ date: Date) -> [Task] {
        tasks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func toggleTaskCompletion(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            saveTasks()
        }
    }
    
    func setReminder(for task: Task, at date: Date) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].reminderTime = date
            tasks[index].hasReminder = true
            saveTasks()
            
            // Schedule local notification
            let content = UNMutableNotificationContent()
            content.title = "Task Reminder"
            content.body = task.title
            content.sound = .default
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func removeReminder(for task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].hasReminder = false
            tasks[index].reminderTime = nil
            saveTasks()
            
            // Remove scheduled notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        }
    }
} 
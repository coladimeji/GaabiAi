import Foundation
import SwiftUI

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var selectedDate: Date = Date()
    
    init() {
        loadTasks()
    }
    
    func loadTasks() {
        // Load tasks from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let savedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = savedTasks
        }
    }
    
    func saveTasks() {
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
} 
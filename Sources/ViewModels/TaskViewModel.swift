import Foundation
import SwiftUI

class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var todayTasks: [Task] = []
    @Published var tomorrowTasks: [Task] = []
    @Published var upcomingTasks: [Task] = []
    @Published var selectedDate: Date = Date()
    
    private var weatherService: WeatherService
    private var trafficService: TrafficService
    private var voiceService: VoiceService
    
    init(
        weatherService: WeatherService,
        trafficService: TrafficService,
        voiceService: VoiceService
    ) {
        self.weatherService = weatherService
        self.trafficService = trafficService
        self.voiceService = voiceService
        loadTasks()
        categorizeTasksByDate()
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
        categorizeTasksByDate()
        
        if task.hasReminder {
            scheduleReminder(for: task)
        }
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
            categorizeTasksByDate()
            
            if task.hasReminder {
                scheduleReminder(for: task)
            }
        }
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
        categorizeTasksByDate()
    }
    
    func getTasksForDate(_ date: Date) -> [Task] {
        return tasks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private func categorizeTasksByDate() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        todayTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: today) }
        tomorrowTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }
        upcomingTasks = tasks.filter { $0.date > tomorrow }
    }
    
    private func scheduleReminder(for task: Task) {
        guard task.hasReminder, let reminderTime = task.reminderTime else { return }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.description
        content.sound = .default
        
        // Add weather and traffic info if enabled
        if task.weatherAlert {
            Task {
                if let weather = await weatherService.getForecast(for: reminderTime) {
                    content.body += "\nWeather: \(weather.condition), \(weather.temperature)°"
                }
            }
        }
        
        if task.trafficAlert {
            Task {
                if let traffic = await trafficService.getTrafficInfo(for: reminderTime) {
                    content.body += "\nTraffic: \(traffic.currentConditions)"
                    if task.alternativeRoutes, !traffic.alternativeRoutes.isEmpty {
                        content.body += "\nAlternative routes available"
                    }
                }
            }
        }
        
        // Schedule notification
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decodedTasks
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }
} 
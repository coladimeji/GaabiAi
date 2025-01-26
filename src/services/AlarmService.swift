import Foundation
import Vapor

enum AlarmType {
    case daily
    case weekly
    case custom
    case smart // Adjusts based on weather/traffic
}

enum AlarmStatus {
    case active
    case snoozed
    case completed
    case cancelled
}

struct Alarm {
    let id: String
    let userId: String
    let title: String
    let type: AlarmType
    let scheduledTime: Date
    let adjustedTime: Date?
    let location: Location?
    let route: (from: Location, to: Location)?
    let status: AlarmStatus
    let smartAdjustment: Bool
    let weatherSensitive: Bool
    let trafficSensitive: Bool
    let snoozeCount: Int
    let metadata: [String: String]
}

final class AlarmService {
    private let database: MongoDatabase
    private let alarmCollection: MongoCollection<Alarm>
    private let weatherTrafficService: WeatherTrafficService
    private let weatherAnalysisService: WeatherAnalysisService
    private let trafficAnalysisService: TrafficAnalysisService
    private let routeOptimizationService: RouteOptimizationService
    private let notificationService: NotificationService
    
    private var activeAlarms: [String: Timer] = [:] // alarmId: Timer
    
    init(
        database: MongoDatabase,
        weatherTrafficService: WeatherTrafficService,
        weatherAnalysisService: WeatherAnalysisService,
        trafficAnalysisService: TrafficAnalysisService,
        routeOptimizationService: RouteOptimizationService,
        notificationService: NotificationService
    ) {
        self.database = database
        self.alarmCollection = database.collection("alarms", withType: Alarm.self)
        self.weatherTrafficService = weatherTrafficService
        self.weatherAnalysisService = weatherAnalysisService
        self.trafficAnalysisService = trafficAnalysisService
        self.routeOptimizationService = routeOptimizationService
        self.notificationService = notificationService
    }
    
    // Create a new alarm
    func createAlarm(
        userId: String,
        title: String,
        type: AlarmType,
        scheduledTime: Date,
        location: Location? = nil,
        route: (from: Location, to: Location)? = nil,
        smartAdjustment: Bool = false,
        weatherSensitive: Bool = false,
        trafficSensitive: Bool = false,
        metadata: [String: String] = [:]
    ) async throws -> Alarm {
        let alarm = Alarm(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            type: type,
            scheduledTime: scheduledTime,
            adjustedTime: nil,
            location: location,
            route: route,
            status: .active,
            smartAdjustment: smartAdjustment,
            weatherSensitive: weatherSensitive,
            trafficSensitive: trafficSensitive,
            snoozeCount: 0,
            metadata: metadata
        )
        
        try await alarmCollection.insertOne(alarm)
        scheduleAlarm(alarm)
        return alarm
    }
    
    // Get all alarms for user
    func getAlarms(userId: String) async throws -> [Alarm] {
        return try await alarmCollection.find(["userId": userId]).toArray()
    }
    
    // Update alarm status
    func updateAlarmStatus(alarmId: String, status: AlarmStatus) async throws {
        try await alarmCollection.updateOne(
            where: ["id": alarmId],
            to: ["$set": ["status": status]]
        )
        
        if status == .cancelled {
            activeAlarms[alarmId]?.invalidate()
            activeAlarms.removeValue(forKey: alarmId)
        }
    }
    
    // Snooze alarm
    func snoozeAlarm(alarmId: String, duration: TimeInterval = 600) async throws {
        guard var alarm = try await alarmCollection.findOne(["id": alarmId]) else {
            return
        }
        
        // Create new alarm with updated time and snooze count
        alarm = Alarm(
            id: alarm.id,
            userId: alarm.userId,
            title: alarm.title,
            type: alarm.type,
            scheduledTime: alarm.scheduledTime,
            adjustedTime: Date().addingTimeInterval(duration),
            location: alarm.location,
            route: alarm.route,
            status: .snoozed,
            smartAdjustment: alarm.smartAdjustment,
            weatherSensitive: alarm.weatherSensitive,
            trafficSensitive: alarm.trafficSensitive,
            snoozeCount: alarm.snoozeCount + 1,
            metadata: alarm.metadata
        )
        
        try await alarmCollection.replaceOne(
            where: ["id": alarmId],
            replacement: alarm
        )
        
        scheduleAlarm(alarm)
    }
    
    // Check and adjust alarms based on conditions
    func checkAndAdjustAlarms() async throws {
        let activeAlarms = try await alarmCollection.find([
            "status": ["$in": ["active", "snoozed"]],
            "scheduledTime": ["$gt": Date()]
        ]).toArray()
        
        for alarm in activeAlarms {
            if alarm.smartAdjustment {
                try await adjustAlarmTime(alarm)
            }
        }
    }
    
    // Private helper methods
    private func scheduleAlarm(_ alarm: Alarm) {
        // Cancel existing timer if any
        activeAlarms[alarm.id]?.invalidate()
        
        // Calculate time until alarm
        let timeUntilAlarm = alarm.adjustedTime?.timeIntervalSinceNow ?? 
            alarm.scheduledTime.timeIntervalSinceNow
        
        guard timeUntilAlarm > 0 else { return }
        
        // Create new timer
        let timer = Timer.scheduledTimer(withTimeInterval: timeUntilAlarm, repeats: false) { [weak self] _ in
            Task {
                try await self?.triggerAlarm(alarm)
            }
        }
        
        activeAlarms[alarm.id] = timer
    }
    
    private func adjustAlarmTime(_ alarm: Alarm) async throws {
        var adjustmentNeeded = false
        var additionalTime: TimeInterval = 0
        var reason = ""
        
        if alarm.weatherSensitive, let location = alarm.location {
            // Check weather conditions
            let weather = try await weatherTrafficService.getCurrentWeather(
                latitude: location.latitude,
                longitude: location.longitude
            )
            let impact = try await weatherAnalysisService.analyzeWeatherImpact(weatherData: weather)
            
            if impact.severity >= 0.5 {
                adjustmentNeeded = true
                additionalTime += 900 * Double(impact.severity) // Up to 15 minutes for severe weather
                reason += "Weather conditions may affect travel. "
            }
        }
        
        if alarm.trafficSensitive, let route = alarm.route {
            // Check traffic conditions
            let optimizedRoute = try await routeOptimizationService.getOptimizedRoute(
                from: route.from,
                to: route.to
            )
            
            if optimizedRoute.riskLevel >= 0.5 {
                adjustmentNeeded = true
                additionalTime += 1200 * optimizedRoute.riskLevel // Up to 20 minutes for heavy traffic
                reason += "Traffic conditions may affect travel time. "
            }
        }
        
        if adjustmentNeeded {
            // Update alarm with adjusted time
            let adjustedTime = alarm.scheduledTime.addingTimeInterval(-additionalTime)
            
            var updatedAlarm = alarm
            updatedAlarm = Alarm(
                id: alarm.id,
                userId: alarm.userId,
                title: alarm.title,
                type: alarm.type,
                scheduledTime: alarm.scheduledTime,
                adjustedTime: adjustedTime,
                location: alarm.location,
                route: alarm.route,
                status: alarm.status,
                smartAdjustment: alarm.smartAdjustment,
                weatherSensitive: alarm.weatherSensitive,
                trafficSensitive: alarm.trafficSensitive,
                snoozeCount: alarm.snoozeCount,
                metadata: alarm.metadata
            )
            
            try await alarmCollection.replaceOne(
                where: ["id": alarm.id],
                replacement: updatedAlarm
            )
            
            // Notify user about adjustment
            try await notificationService.sendNotification(
                to: alarm.userId,
                title: "Alarm Adjusted",
                message: "Your alarm has been adjusted earlier due to: \(reason)",
                metadata: ["alarmId": alarm.id]
            )
            
            // Reschedule alarm
            scheduleAlarm(updatedAlarm)
        }
    }
    
    private func triggerAlarm(_ alarm: Alarm) async throws {
        // Send notification
        try await notificationService.sendNotification(
            to: alarm.userId,
            title: alarm.title,
            message: "Time to wake up!",
            metadata: [
                "alarmId": alarm.id,
                "type": "alarm_trigger"
            ]
        )
        
        // Update alarm status if not repeating
        if alarm.type == .custom {
            try await updateAlarmStatus(alarmId: alarm.id, status: .completed)
        }
    }
} 
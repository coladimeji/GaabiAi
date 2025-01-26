import Foundation
import Vapor

struct CreateAlarmRequest: Content {
    let title: String
    let type: AlarmType
    let scheduledTime: Date
    let location: Location?
    let route: (from: Location, to: Location)?
    let smartAdjustment: Bool
    let weatherSensitive: Bool
    let trafficSensitive: Bool
    let metadata: [String: String]?
}

struct UpdateAlarmStatusRequest: Content {
    let status: AlarmStatus
}

struct SnoozeAlarmRequest: Content {
    let duration: TimeInterval?
}

final class AlarmController {
    private let alarmService: AlarmService
    
    init(alarmService: AlarmService) {
        self.alarmService = alarmService
    }
    
    func configureRoutes(_ app: Application) throws {
        let alarms = app.grouped("api", "alarms")
        
        // Create new alarm
        alarms.post { req -> Alarm in
            guard let user = try? req.auth.require(User.self) else {
                throw Abort(.unauthorized)
            }
            
            let createRequest = try req.content.decode(CreateAlarmRequest.self)
            
            return try await self.alarmService.createAlarm(
                userId: user.id,
                title: createRequest.title,
                type: createRequest.type,
                scheduledTime: createRequest.scheduledTime,
                location: createRequest.location,
                route: createRequest.route,
                smartAdjustment: createRequest.smartAdjustment,
                weatherSensitive: createRequest.weatherSensitive,
                trafficSensitive: createRequest.trafficSensitive,
                metadata: createRequest.metadata ?? [:]
            )
        }
        
        // Get all alarms for user
        alarms.get { req -> [Alarm] in
            guard let user = try? req.auth.require(User.self) else {
                throw Abort(.unauthorized)
            }
            
            return try await self.alarmService.getAlarms(userId: user.id)
        }
        
        // Update alarm status
        alarms.put(":alarmId", "status") { req -> HTTPStatus in
            guard let user = try? req.auth.require(User.self) else {
                throw Abort(.unauthorized)
            }
            
            let alarmId = req.parameters.get("alarmId")!
            let updateRequest = try req.content.decode(UpdateAlarmStatusRequest.self)
            
            // Verify alarm belongs to user
            let alarms = try await self.alarmService.getAlarms(userId: user.id)
            guard alarms.contains(where: { $0.id == alarmId }) else {
                throw Abort(.forbidden)
            }
            
            try await self.alarmService.updateAlarmStatus(
                alarmId: alarmId,
                status: updateRequest.status
            )
            
            return .ok
        }
        
        // Snooze alarm
        alarms.put(":alarmId", "snooze") { req -> HTTPStatus in
            guard let user = try? req.auth.require(User.self) else {
                throw Abort(.unauthorized)
            }
            
            let alarmId = req.parameters.get("alarmId")!
            let snoozeRequest = try req.content.decode(SnoozeAlarmRequest.self)
            
            // Verify alarm belongs to user
            let alarms = try await self.alarmService.getAlarms(userId: user.id)
            guard alarms.contains(where: { $0.id == alarmId }) else {
                throw Abort(.forbidden)
            }
            
            try await self.alarmService.snoozeAlarm(
                alarmId: alarmId,
                duration: snoozeRequest.duration ?? 600
            )
            
            return .ok
        }
    }
} 
import Foundation
import CoreLocation

actor DailyScheduleManager {
    private var schedules: [Date: DailySchedule] = [:]
    private let weatherClient: OpenWeatherClient
    private let mapsClient: GoogleMapsClient
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    
    init(
        weatherClient: OpenWeatherClient,
        mapsClient: GoogleMapsClient,
        locationManager: LocationManager,
        notificationManager: NotificationManager
    ) {
        self.weatherClient = weatherClient
        self.mapsClient = mapsClient
        self.locationManager = locationManager
        self.notificationManager = notificationManager
    }
    
    func createSchedule(for date: Date) async throws -> DailySchedule {
        let schedule = DailySchedule(date: date)
        schedules[date] = schedule
        return schedule
    }
    
    func addEvent(_ event: ScheduleEvent, to date: Date) async throws {
        guard var schedule = schedules[date] else {
            throw ScheduleError.scheduleNotFound
        }
        
        // Check for conflicts
        if let conflict = schedule.events.first(where: { $0.timeSlot.overlaps(with: event.timeSlot) }) {
            throw ScheduleError.timeSlotConflict(conflict)
        }
        
        // Update route information if location is provided
        if let location = event.location {
            if let currentLocation = await locationManager.getCurrentLocation() {
                let route = try await mapsClient.getDirections(
                    from: currentLocation.coordinate,
                    to: location.coordinate
                )
                
                var updatedEvent = event
                updatedEvent.routeInfo = RouteInfo(
                    startLocation: TaskLocation(
                        coordinate: currentLocation.coordinate,
                        address: "Current Location",
                        radius: 100
                    ),
                    endLocation: location,
                    preferredTransportMode: .driving,
                    alternativeRoutes: true,
                    estimatedDuration: TimeInterval(route.routes[0].legs[0].duration.value)
                )
                
                // Add travel time buffer
                updatedEvent.timeSlot.start = updatedEvent.timeSlot.start.addingTimeInterval(
                    -updatedEvent.routeInfo!.estimatedDuration
                )
                
                schedule.events.append(updatedEvent)
            }
        } else {
            schedule.events.append(event)
        }
        
        // Sort events by start time
        schedule.events.sort { $0.timeSlot.start < $1.timeSlot.start }
        
        // Update schedule
        schedules[date] = schedule
        
        // Schedule notifications
        await scheduleEventNotifications(for: event)
    }
    
    func optimizeSchedule(for date: Date) async throws {
        guard var schedule = schedules[date] else {
            throw ScheduleError.scheduleNotFound
        }
        
        var optimizedEvents = schedule.events
        
        // Get weather forecast
        if let location = await locationManager.getCurrentLocation() {
            let weather = try await weatherClient.getCurrentWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            // Adjust outdoor events based on weather
            optimizedEvents = optimizedEvents.map { event in
                var updatedEvent = event
                if event.isOutdoor && weather.current.weather.first?.main.lowercased().contains("rain") == true {
                    updatedEvent.needsRescheduling = true
                }
                return updatedEvent
            }
        }
        
        // Optimize travel times
        for i in 0..<optimizedEvents.count-1 {
            if let currentLocation = optimizedEvents[i].location,
               let nextLocation = optimizedEvents[i+1].location {
                let route = try await mapsClient.getDirections(
                    from: currentLocation.coordinate,
                    to: nextLocation.coordinate
                )
                
                let travelTime = TimeInterval(route.routes[0].legs[0].duration.value)
                let buffer = travelTime * 1.2 // Add 20% buffer
                
                // Adjust start time of next event if needed
                let earliestNextStart = optimizedEvents[i].timeSlot.end.addingTimeInterval(buffer)
                if optimizedEvents[i+1].timeSlot.start < earliestNextStart {
                    optimizedEvents[i+1].timeSlot.start = earliestNextStart
                    optimizedEvents[i+1].timeSlot.end = earliestNextStart.addingTimeInterval(
                        optimizedEvents[i+1].timeSlot.end.timeIntervalSince(optimizedEvents[i+1].timeSlot.start)
                    )
                }
            }
        }
        
        schedule.events = optimizedEvents
        schedules[date] = schedule
    }
    
    func suggestRescheduling(for date: Date) async throws -> [ScheduleSuggestion] {
        guard let schedule = schedules[date] else {
            throw ScheduleError.scheduleNotFound
        }
        
        var suggestions: [ScheduleSuggestion] = []
        
        for event in schedule.events where event.needsRescheduling {
            // Find available time slots
            let availableSlots = findAvailableTimeSlots(
                in: schedule,
                duration: event.timeSlot.end.timeIntervalSince(event.timeSlot.start)
            )
            
            // Check weather for outdoor events
            if event.isOutdoor, let location = event.location {
                let weather = try await weatherClient.getCurrentWeather(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                // Filter slots based on weather
                let suitableSlots = availableSlots.filter { slot in
                    !weather.hourly.contains { hourly in
                        let hourlyDate = Date(timeIntervalSince1970: hourly.dt)
                        return slot.contains(hourlyDate) && 
                        hourly.weather.first?.main.lowercased().contains("rain") == true
                    }
                }
                
                if let bestSlot = suitableSlots.first {
                    suggestions.append(ScheduleSuggestion(
                        event: event,
                        suggestedTimeSlot: bestSlot,
                        reason: .weather
                    ))
                }
            }
        }
        
        return suggestions
    }
    
    private func findAvailableTimeSlots(in schedule: DailySchedule, duration: TimeInterval) -> [TimeSlot] {
        var availableSlots: [TimeSlot] = []
        let calendar = Calendar.current
        
        // Get start and end of day
        let startOfDay = calendar.startOfDay(for: schedule.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Sort events by start time
        let sortedEvents = schedule.events.sorted { $0.timeSlot.start < $1.timeSlot.start }
        
        // Find gaps between events
        var currentTime = startOfDay
        for event in sortedEvents {
            let gap = event.timeSlot.start.timeIntervalSince(currentTime)
            if gap >= duration {
                availableSlots.append(TimeSlot(
                    start: currentTime,
                    end: currentTime.addingTimeInterval(duration)
                ))
            }
            currentTime = event.timeSlot.end
        }
        
        // Check final gap
        let finalGap = endOfDay.timeIntervalSince(currentTime)
        if finalGap >= duration {
            availableSlots.append(TimeSlot(
                start: currentTime,
                end: currentTime.addingTimeInterval(duration)
            ))
        }
        
        return availableSlots
    }
    
    private func scheduleEventNotifications(for event: ScheduleEvent) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.description
        
        // Notification 15 minutes before event
        let reminderDate = event.timeSlot.start.addingTimeInterval(-900)
        if reminderDate > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "event-\(event.id)",
                content: content,
                trigger: trigger
            )
            
            try? await notificationManager.add(request)
        }
        
        // Additional notification if travel time is required
        if let routeInfo = event.routeInfo {
            let travelReminderDate = event.timeSlot.start.addingTimeInterval(
                -(routeInfo.estimatedDuration + 900) // Travel time + 15 minutes
            )
            
            if travelReminderDate > Date() {
                let travelContent = UNMutableNotificationContent()
                travelContent.title = "Time to leave for: \(event.title)"
                travelContent.body = "Estimated travel time: \(Int(routeInfo.estimatedDuration / 60)) minutes"
                
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: travelReminderDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let request = UNNotificationRequest(
                    identifier: "travel-\(event.id)",
                    content: travelContent,
                    trigger: trigger
                )
                
                try? await notificationManager.add(request)
            }
        }
    }
}

struct DailySchedule: Identifiable, Codable {
    let id: UUID
    let date: Date
    var events: [ScheduleEvent]
    
    init(id: UUID = UUID(), date: Date, events: [ScheduleEvent] = []) {
        self.id = id
        self.date = date
        self.events = events
    }
}

struct ScheduleEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var timeSlot: TimeSlot
    var location: TaskLocation?
    var routeInfo: RouteInfo?
    var isOutdoor: Bool
    var priority: EventPriority
    var needsRescheduling: Bool
    var linkedTasks: [UUID]?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        timeSlot: TimeSlot,
        location: TaskLocation? = nil,
        routeInfo: RouteInfo? = nil,
        isOutdoor: Bool = false,
        priority: EventPriority = .medium,
        needsRescheduling: Bool = false,
        linkedTasks: [UUID]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.timeSlot = timeSlot
        self.location = location
        self.routeInfo = routeInfo
        self.isOutdoor = isOutdoor
        self.priority = priority
        self.needsRescheduling = needsRescheduling
        self.linkedTasks = linkedTasks
    }
}

struct TimeSlot: Codable {
    var start: Date
    var end: Date
    
    func overlaps(with other: TimeSlot) -> Bool {
        start < other.end && end > other.start
    }
    
    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}

enum EventPriority: Int, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
}

struct ScheduleSuggestion {
    let event: ScheduleEvent
    let suggestedTimeSlot: TimeSlot
    let reason: ReschedulingReason
}

enum ReschedulingReason {
    case weather
    case traffic
    case conflict
    case optimization
}

enum ScheduleError: Error {
    case scheduleNotFound
    case timeSlotConflict(ScheduleEvent)
    case invalidTimeSlot
    
    var localizedDescription: String {
        switch self {
        case .scheduleNotFound:
            return "Schedule not found"
        case .timeSlotConflict(let event):
            return "Time slot conflicts with event: \(event.title)"
        case .invalidTimeSlot:
            return "Invalid time slot"
        }
    }
} 
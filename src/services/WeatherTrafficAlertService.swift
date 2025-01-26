import Foundation
import Vapor

enum AlertType {
    case weather
    case traffic
    case route
}

enum AlertSeverity {
    case low
    case medium
    case high
    case critical
}

struct Alert {
    let id: String
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let timestamp: Date
    let location: Location
    let metadata: [String: String]
    let isRead: Bool
}

struct AlertSubscription {
    let userId: String
    let location: Location
    let radius: Double // in kilometers
    let alertTypes: Set<AlertType>
    let minSeverity: AlertSeverity
}

final class WeatherTrafficAlertService {
    private let weatherTrafficService: WeatherTrafficService
    private let weatherAnalysisService: WeatherAnalysisService
    private let trafficAnalysisService: TrafficAnalysisService
    private let routeOptimizationService: RouteOptimizationService
    private let notificationService: NotificationService
    
    private var subscriptions: [String: [AlertSubscription]] = [:] // userId: [subscriptions]
    private var activeAlerts: [String: Alert] = [:] // alertId: Alert
    
    init(
        weatherTrafficService: WeatherTrafficService,
        weatherAnalysisService: WeatherAnalysisService,
        trafficAnalysisService: TrafficAnalysisService,
        routeOptimizationService: RouteOptimizationService,
        notificationService: NotificationService
    ) {
        self.weatherTrafficService = weatherTrafficService
        self.weatherAnalysisService = weatherAnalysisService
        self.trafficAnalysisService = trafficAnalysisService
        self.routeOptimizationService = routeOptimizationService
        self.notificationService = notificationService
    }
    
    // Subscribe to alerts
    func subscribe(
        userId: String,
        location: Location,
        radius: Double = 10.0,
        alertTypes: Set<AlertType> = Set(AlertType.allCases),
        minSeverity: AlertSeverity = .medium
    ) {
        let subscription = AlertSubscription(
            userId: userId,
            location: location,
            radius: radius,
            alertTypes: alertTypes,
            minSeverity: minSeverity
        )
        
        subscriptions[userId, default: []].append(subscription)
    }
    
    // Unsubscribe from alerts
    func unsubscribe(userId: String) {
        subscriptions.removeValue(forKey: userId)
    }
    
    // Check for alerts (called periodically)
    func checkAlerts() async throws {
        for (userId, userSubscriptions) in subscriptions {
            for subscription in userSubscriptions {
                try await checkWeatherAlerts(userId: userId, subscription: subscription)
                try await checkTrafficAlerts(userId: userId, subscription: subscription)
                try await checkRouteAlerts(userId: userId, subscription: subscription)
            }
        }
    }
    
    // Get active alerts for user
    func getActiveAlerts(userId: String) -> [Alert] {
        return activeAlerts.values.filter { alert in
            guard let subscriptions = subscriptions[userId] else { return false }
            return subscriptions.contains { subscription in
                isAlertRelevant(alert: alert, subscription: subscription)
            }
        }
    }
    
    // Mark alert as read
    func markAlertAsRead(alertId: String) {
        guard var alert = activeAlerts[alertId] else { return }
        alert = Alert(
            id: alert.id,
            type: alert.type,
            severity: alert.severity,
            title: alert.title,
            message: alert.message,
            timestamp: alert.timestamp,
            location: alert.location,
            metadata: alert.metadata,
            isRead: true
        )
        activeAlerts[alertId] = alert
    }
    
    // Private helper methods
    private func checkWeatherAlerts(userId: String, subscription: AlertSubscription) async throws {
        guard subscription.alertTypes.contains(.weather) else { return }
        
        // Get weather data
        let weather = try await weatherTrafficService.getCurrentWeather(
            latitude: subscription.location.latitude,
            longitude: subscription.location.longitude
        )
        
        // Analyze weather impact
        let impact = try await weatherAnalysisService.analyzeWeatherImpact(weatherData: weather)
        
        // Create alert if conditions are severe
        if impact.severity >= 0.7 {
            let alert = Alert(
                id: UUID().uuidString,
                type: .weather,
                severity: getSeverity(from: impact.severity),
                title: "Severe Weather Alert",
                message: impact.recommendations.joined(separator: " "),
                timestamp: Date(),
                location: subscription.location,
                metadata: ["condition": weather.condition],
                isRead: false
            )
            
            if shouldNotify(alert: alert, subscription: subscription) {
                activeAlerts[alert.id] = alert
                try await notificationService.sendNotification(
                    to: userId,
                    title: alert.title,
                    message: alert.message,
                    metadata: ["alertId": alert.id]
                )
            }
        }
    }
    
    private func checkTrafficAlerts(userId: String, subscription: AlertSubscription) async throws {
        guard subscription.alertTypes.contains(.traffic) else { return }
        
        // Get traffic conditions
        let traffic = try await weatherTrafficService.getTrafficConditions(
            latitude: subscription.location.latitude,
            longitude: subscription.location.longitude,
            radius: subscription.radius
        )
        
        // Create alert if congestion is high
        if traffic.congestionLevel >= 0.8 {
            let alert = Alert(
                id: UUID().uuidString,
                type: .traffic,
                severity: getSeverity(from: traffic.congestionLevel),
                title: "Heavy Traffic Alert",
                message: "Significant traffic congestion detected in your area. Consider alternative routes.",
                timestamp: Date(),
                location: subscription.location,
                metadata: ["incidents": String(traffic.incidents.count)],
                isRead: false
            )
            
            if shouldNotify(alert: alert, subscription: subscription) {
                activeAlerts[alert.id] = alert
                try await notificationService.sendNotification(
                    to: userId,
                    title: alert.title,
                    message: alert.message,
                    metadata: ["alertId": alert.id]
                )
            }
        }
    }
    
    private func checkRouteAlerts(userId: String, subscription: AlertSubscription) async throws {
        guard subscription.alertTypes.contains(.route) else { return }
        
        // Get saved routes for user
        // TODO: Implement saved routes functionality
        let savedRoutes: [(from: Location, to: Location)] = []
        
        for route in savedRoutes {
            let optimizedRoute = try await routeOptimizationService.getOptimizedRoute(
                from: route.from,
                to: route.to
            )
            
            if optimizedRoute.riskLevel >= 0.7 {
                let alert = Alert(
                    id: UUID().uuidString,
                    type: .route,
                    severity: getSeverity(from: optimizedRoute.riskLevel),
                    title: "Route Risk Alert",
                    message: optimizedRoute.recommendations.joined(separator: " "),
                    timestamp: Date(),
                    location: route.from,
                    metadata: ["destination": "\(route.to.latitude),\(route.to.longitude)"],
                    isRead: false
                )
                
                if shouldNotify(alert: alert, subscription: subscription) {
                    activeAlerts[alert.id] = alert
                    try await notificationService.sendNotification(
                        to: userId,
                        title: alert.title,
                        message: alert.message,
                        metadata: ["alertId": alert.id]
                    )
                }
            }
        }
    }
    
    private func shouldNotify(alert: Alert, subscription: AlertSubscription) -> Bool {
        // Check if alert meets minimum severity
        guard getSeverityLevel(alert.severity) >= getSeverityLevel(subscription.minSeverity) else {
            return false
        }
        
        // Check if similar alert was recently sent
        let recentAlerts = activeAlerts.values.filter { existing in
            existing.type == alert.type &&
            existing.location.latitude == alert.location.latitude &&
            existing.location.longitude == alert.location.longitude &&
            Date().timeIntervalSince(existing.timestamp) < 3600 // Within last hour
        }
        
        return recentAlerts.isEmpty
    }
    
    private func isAlertRelevant(alert: Alert, subscription: AlertSubscription) -> Bool {
        // Check if alert type is subscribed
        guard subscription.alertTypes.contains(alert.type) else {
            return false
        }
        
        // Check if alert meets minimum severity
        guard getSeverityLevel(alert.severity) >= getSeverityLevel(subscription.minSeverity) else {
            return false
        }
        
        // Check if alert is within subscription radius
        let distance = calculateDistance(
            from: alert.location,
            to: subscription.location
        )
        
        return distance <= subscription.radius
    }
    
    private func getSeverity(from value: Double) -> AlertSeverity {
        switch value {
        case 0.0..<0.4:
            return .low
        case 0.4..<0.7:
            return .medium
        case 0.7..<0.9:
            return .high
        default:
            return .critical
        }
    }
    
    private func getSeverityLevel(_ severity: AlertSeverity) -> Int {
        switch severity {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        case .critical:
            return 4
        }
    }
    
    private func calculateDistance(from: Location, to: Location) -> Double {
        // Haversine formula for calculating distance between coordinates
        let R = 6371.0 // Earth's radius in kilometers
        
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
            cos(lat1) * cos(lat2) *
            sin(deltaLon/2) * sin(deltaLon/2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    }
} 
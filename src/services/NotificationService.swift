import Foundation
import Vapor
import MongoDBVapor

struct Notification: Codable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let severity: NotificationSeverity
    let timestamp: Date
    var isRead: Bool
    let metadata: [String: String]
}

enum NotificationType: String, Codable {
    case anomalyDetected
    case experimentCompleted
    case significantChange
    case alert
}

enum NotificationSeverity: String, Codable {
    case low
    case medium
    case high
    case critical
}

final class NotificationService {
    private let database: MongoDatabase
    private let notificationsCollection: MongoCollection<Notification>
    private let webSocketClients: [String: [WebSocket]] // userId: [WebSocket]
    private let eventLoop: EventLoop
    
    init(database: MongoDatabase, eventLoop: EventLoop) {
        self.database = database
        self.notificationsCollection = database.collection("notifications", withType: Notification.self)
        self.webSocketClients = [:]
        self.eventLoop = eventLoop
    }
    
    // Create and send anomaly notification
    func notifyAnomalyDetected(
        userId: String,
        anomaly: AnomalyDetection,
        additionalContext: [String: String] = [:]
    ) async throws {
        let severity = determineSeverity(zScore: anomaly.zScore)
        
        let notification = Notification(
            id: UUID().uuidString,
            userId: userId,
            type: .anomalyDetected,
            title: "Unusual Pattern Detected",
            message: createAnomalyMessage(anomaly: anomaly),
            severity: severity,
            timestamp: Date(),
            isRead: false,
            metadata: additionalContext
        )
        
        // Store notification
        try await notificationsCollection.insertOne(notification)
        
        // Send real-time notification if user is connected
        try await sendRealTimeNotification(notification)
    }
    
    // Create and send experiment results notification
    func notifyExperimentResults(
        experimentId: String,
        results: [String: Any],
        affectedUsers: [String]
    ) async throws {
        let isSignificant = results["statisticalAnalysis"] as? [String: [String: Any]]
        let improvements = results["improvements"] as? [String: Double]
        
        for userId in affectedUsers {
            let notification = Notification(
                id: UUID().uuidString,
                userId: userId,
                type: .experimentCompleted,
                title: "Experiment Results Available",
                message: createExperimentResultsMessage(results: results),
                severity: .medium,
                timestamp: Date(),
                isRead: false,
                metadata: ["experimentId": experimentId]
            )
            
            try await notificationsCollection.insertOne(notification)
            try await sendRealTimeNotification(notification)
        }
    }
    
    // Get unread notifications for user
    func getUnreadNotifications(userId: String) async throws -> [Notification] {
        return try await notificationsCollection
            .find([
                "userId": userId,
                "isRead": false
            ])
            .sort(["timestamp": -1])
            .toArray()
    }
    
    // Mark notification as read
    func markAsRead(notificationId: String, userId: String) async throws {
        try await notificationsCollection.updateOne(
            where: ["id": notificationId, "userId": userId],
            to: ["$set": ["isRead": true]]
        )
    }
    
    // Register WebSocket connection for real-time notifications
    func registerWebSocket(_ ws: WebSocket, for userId: String) {
        webSocketClients[userId, default: []].append(ws)
        
        // Handle disconnection
        ws.onClose.whenComplete { [weak self] _ in
            self?.webSocketClients[userId]?.removeAll { $0 === ws }
        }
    }
    
    // Private helper methods
    
    private func determineSeverity(zScore: Double) -> NotificationSeverity {
        switch zScore {
        case 0..<2.0:
            return .low
        case 2.0..<3.0:
            return .medium
        case 3.0..<4.0:
            return .high
        default:
            return .critical
        }
    }
    
    private func createAnomalyMessage(anomaly: AnomalyDetection) -> String {
        let percentDiff = abs((anomaly.actualValue - anomaly.expectedValue) / anomaly.expectedValue * 100)
        
        return """
        Detected unusual pattern in \(anomaly.metric):
        • Current value: \(String(format: "%.2f", anomaly.actualValue))
        • Expected range: \(String(format: "%.2f", anomaly.expectedValue)) ± \(String(format: "%.2f", anomaly.zScore))σ
        • Deviation: \(String(format: "%.1f", percentDiff))%
        """
    }
    
    private func createExperimentResultsMessage(results: [String: Any]) -> String {
        guard let improvements = results["improvements"] as? [String: Double],
              let analysis = results["statisticalAnalysis"] as? [String: [String: Any]] else {
            return "Experiment results are available for review."
        }
        
        var message = "Experiment results summary:\n"
        
        for (metric, improvement) in improvements {
            let sign = improvement >= 0 ? "+" : ""
            message += "• \(metric): \(sign)\(String(format: "%.1f", improvement))%"
            
            if let stats = analysis[metric] as? [String: Any],
               let isSignificant = stats["isSignificant"] as? Bool {
                message += isSignificant ? " (Statistically significant)\n" : "\n"
            }
        }
        
        return message
    }
    
    private func sendRealTimeNotification(_ notification: Notification) async throws {
        guard let clients = webSocketClients[notification.userId] else { return }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        let jsonString = String(data: data, encoding: .utf8)!
        
        for ws in clients {
            ws.send(jsonString)
        }
    }
} 
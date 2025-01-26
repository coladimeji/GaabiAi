import Foundation
import Vapor
import MongoDBVapor

struct Dashboard: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String
    let layout: [DashboardPanel]
    let filters: [DashboardFilter]
    let lastModified: Date
    let isPublic: Bool
}

struct DashboardPanel: Codable {
    let id: String
    let visualizationId: String
    let position: PanelPosition
    let size: PanelSize
    let title: String?
    let refreshInterval: Int? // in seconds
}

struct PanelPosition: Codable {
    let row: Int
    let col: Int
}

struct PanelSize: Codable {
    let width: Int  // number of grid columns
    let height: Int // number of grid rows
}

struct DashboardFilter: Codable {
    let field: String
    let type: FilterType
    let defaultValue: String?
    let options: [String]?
}

enum FilterType: String, Codable {
    case dateRange
    case select
    case multiSelect
    case search
}

final class DashboardService {
    private let database: MongoDatabase
    private let dashboardsCollection: MongoCollection<Dashboard>
    private let visualizationService: StatisticsVisualizationService
    
    init(database: MongoDatabase, visualizationService: StatisticsVisualizationService) {
        self.database = database
        self.dashboardsCollection = database.collection("dashboards", withType: Dashboard.self)
        self.visualizationService = visualizationService
    }
    
    // Create a new dashboard
    func createDashboard(
        userId: String,
        name: String,
        description: String,
        layout: [DashboardPanel],
        filters: [DashboardFilter] = [],
        isPublic: Bool = false
    ) async throws -> Dashboard {
        let dashboard = Dashboard(
            id: UUID().uuidString,
            userId: userId,
            name: name,
            description: description,
            layout: layout,
            filters: filters,
            lastModified: Date(),
            isPublic: isPublic
        )
        
        try await dashboardsCollection.insertOne(dashboard)
        return dashboard
    }
    
    // Get dashboard by ID
    func getDashboard(id: String, userId: String) async throws -> Dashboard {
        guard let dashboard = try await dashboardsCollection.findOne([
            "$or": [
                ["id": id, "userId": userId],
                ["id": id, "isPublic": true]
            ]
        ]) else {
            throw Abort(.notFound)
        }
        return dashboard
    }
    
    // Get user's dashboards
    func getUserDashboards(userId: String) async throws -> [Dashboard] {
        return try await dashboardsCollection
            .find([
                "$or": [
                    ["userId": userId],
                    ["isPublic": true]
                ]
            ])
            .sort(["lastModified": -1])
            .toArray()
    }
    
    // Update dashboard layout
    func updateDashboardLayout(
        id: String,
        userId: String,
        layout: [DashboardPanel]
    ) async throws -> Dashboard {
        guard let dashboard = try await dashboardsCollection.findOne([
            "id": id,
            "userId": userId
        ]) else {
            throw Abort(.notFound)
        }
        
        let updatedDashboard = Dashboard(
            id: dashboard.id,
            userId: dashboard.userId,
            name: dashboard.name,
            description: dashboard.description,
            layout: layout,
            filters: dashboard.filters,
            lastModified: Date(),
            isPublic: dashboard.isPublic
        )
        
        try await dashboardsCollection.replaceOne(
            where: ["id": id],
            replacement: updatedDashboard
        )
        
        return updatedDashboard
    }
    
    // Update dashboard filters
    func updateDashboardFilters(
        id: String,
        userId: String,
        filters: [DashboardFilter]
    ) async throws -> Dashboard {
        guard let dashboard = try await dashboardsCollection.findOne([
            "id": id,
            "userId": userId
        ]) else {
            throw Abort(.notFound)
        }
        
        let updatedDashboard = Dashboard(
            id: dashboard.id,
            userId: dashboard.userId,
            name: dashboard.name,
            description: dashboard.description,
            layout: dashboard.layout,
            filters: filters,
            lastModified: Date(),
            isPublic: dashboard.isPublic
        )
        
        try await dashboardsCollection.replaceOne(
            where: ["id": id],
            replacement: updatedDashboard
        )
        
        return updatedDashboard
    }
    
    // Get dashboard data (visualizations and their data)
    func getDashboardData(
        id: String,
        userId: String,
        filterValues: [String: String]? = nil
    ) async throws -> [String: Any] {
        let dashboard = try await getDashboard(id: id, userId: userId)
        
        var panelData: [String: VisualizationData] = [:]
        for panel in dashboard.layout {
            if let visualization = try? await visualizationService.visualizationsCollection
                .findOne(["id": panel.visualizationId]) {
                panelData[panel.id] = visualization
            }
        }
        
        return [
            "dashboard": dashboard,
            "visualizations": panelData
        ]
    }
    
    // Delete dashboard
    func deleteDashboard(id: String, userId: String) async throws {
        let result = try await dashboardsCollection.deleteOne([
            "id": id,
            "userId": userId
        ])
        
        if result.deletedCount == 0 {
            throw Abort(.notFound)
        }
    }
    
    // Share dashboard
    func shareDashboard(id: String, userId: String, isPublic: Bool) async throws -> Dashboard {
        guard let dashboard = try await dashboardsCollection.findOne([
            "id": id,
            "userId": userId
        ]) else {
            throw Abort(.notFound)
        }
        
        let updatedDashboard = Dashboard(
            id: dashboard.id,
            userId: dashboard.userId,
            name: dashboard.name,
            description: dashboard.description,
            layout: dashboard.layout,
            filters: dashboard.filters,
            lastModified: Date(),
            isPublic: isPublic
        )
        
        try await dashboardsCollection.replaceOne(
            where: ["id": id],
            replacement: updatedDashboard
        )
        
        return updatedDashboard
    }
} 
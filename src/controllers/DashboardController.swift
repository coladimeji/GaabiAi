import Foundation
import Vapor

struct CreateDashboardRequest: Content {
    let name: String
    let description: String
    let layout: [DashboardPanel]
    let filters: [DashboardFilter]?
    let isPublic: Bool?
}

struct UpdateLayoutRequest: Content {
    let layout: [DashboardPanel]
}

struct UpdateFiltersRequest: Content {
    let filters: [DashboardFilter]
}

struct ShareDashboardRequest: Content {
    let isPublic: Bool
}

final class DashboardController {
    private let dashboardService: DashboardService
    
    init(dashboardService: DashboardService) {
        self.dashboardService = dashboardService
    }
    
    func configureRoutes(_ app: Application) throws {
        let dashboards = app.grouped("api", "dashboards")
        
        // Create dashboard
        dashboards.post { req -> Dashboard in
            let user = try req.auth.require(User.self)
            let createRequest = try req.content.decode(CreateDashboardRequest.self)
            
            return try await self.dashboardService.createDashboard(
                userId: user.id,
                name: createRequest.name,
                description: createRequest.description,
                layout: createRequest.layout,
                filters: createRequest.filters ?? [],
                isPublic: createRequest.isPublic ?? false
            )
        }
        
        // Get user's dashboards
        dashboards.get { req -> [Dashboard] in
            let user = try req.auth.require(User.self)
            return try await self.dashboardService.getUserDashboards(userId: user.id)
        }
        
        // Get dashboard by ID
        dashboards.get(":id") { req -> [String: Any] in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            
            // Get filter values from query parameters
            let filterValues = try req.query.decode([String: String].self)
            
            return try await self.dashboardService.getDashboardData(
                id: id,
                userId: user.id,
                filterValues: filterValues
            )
        }
        
        // Update dashboard layout
        dashboards.put(":id", "layout") { req -> Dashboard in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            
            let updateRequest = try req.content.decode(UpdateLayoutRequest.self)
            return try await self.dashboardService.updateDashboardLayout(
                id: id,
                userId: user.id,
                layout: updateRequest.layout
            )
        }
        
        // Update dashboard filters
        dashboards.put(":id", "filters") { req -> Dashboard in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            
            let updateRequest = try req.content.decode(UpdateFiltersRequest.self)
            return try await self.dashboardService.updateDashboardFilters(
                id: id,
                userId: user.id,
                filters: updateRequest.filters
            )
        }
        
        // Delete dashboard
        dashboards.delete(":id") { req -> Response in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            
            try await self.dashboardService.deleteDashboard(id: id, userId: user.id)
            return Response(status: .noContent)
        }
        
        // Share dashboard
        dashboards.put(":id", "share") { req -> Dashboard in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            
            let shareRequest = try req.content.decode(ShareDashboardRequest.self)
            return try await self.dashboardService.shareDashboard(
                id: id,
                userId: user.id,
                isPublic: shareRequest.isPublic
            )
        }
    }
} 
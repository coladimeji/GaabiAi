import Foundation
import Vapor

struct TaskPrioritizationController: RouteCollection {
    let prioritizationService: TaskPrioritizationService
    
    init(prioritizationService: TaskPrioritizationService) {
        self.prioritizationService = prioritizationService
    }
    
    func boot(routes: RoutesBuilder) throws {
        let tasks = routes.grouped("api", "tasks", "priority")
        tasks.get("recommended", use: getRecommendedTasks)
        tasks.get("insights", use: getTaskInsights)
    }
    
    // Get recommended task order
    func getRecommendedTasks(req: Request) async throws -> [Task] {
        guard let userId = req.auth.get(User.self)?.id else {
            throw Abort(.unauthorized)
        }
        
        return try await prioritizationService.getRecommendedTaskOrder(for: userId)
    }
    
    // Get task insights
    func getTaskInsights(req: Request) async throws -> Response {
        guard let userId = req.auth.get(User.self)?.id else {
            throw Abort(.unauthorized)
        }
        
        let insights = try await prioritizationService.getTaskInsights(for: userId)
        
        let response = Response(status: .ok)
        try response.content.encode(insights)
        
        return response
    }
} 
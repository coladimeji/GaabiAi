import Foundation
import Vapor

struct VisualizationInteractionRequest: Content {
    let visualizationId: String
    let elementId: String
    let interactionType: String
    let data: [String: String]?
}

final class VisualizationController {
    private let visualizationService: StatisticsVisualizationService
    
    init(visualizationService: StatisticsVisualizationService) {
        self.visualizationService = visualizationService
    }
    
    func configureRoutes(_ app: Application) throws {
        let visualizations = app.grouped("api", "visualizations")
        
        // Get visualization by ID
        visualizations.get(":id") { req -> VisualizationData in
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            return try await self.getVisualization(id: id)
        }
        
        // Handle visualization interactions
        visualizations.post("interact") { req -> Response in
            let interaction = try req.content.decode(VisualizationInteractionRequest.self)
            return try await self.handleInteraction(req: interaction)
        }
        
        // Get raw data for client-side processing
        visualizations.get(":id", "data") { req -> [String: [Double]] in
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            return try await self.getRawData(id: id)
        }
        
        // Update visualization view (e.g., zoom level, visible range)
        visualizations.put(":id", "view") { req -> Response in
            guard let id = req.parameters.get("id") else {
                throw Abort(.badRequest)
            }
            let viewState = try req.content.decode([String: Any].self)
            return try await self.updateView(id: id, state: viewState)
        }
    }
    
    // Handler methods
    
    private func getVisualization(id: String) async throws -> VisualizationData {
        guard let visualization = try await visualizationService.visualizationsCollection
            .findOne(["id": id]) else {
            throw Abort(.notFound)
        }
        return visualization
    }
    
    private func handleInteraction(req: VisualizationInteractionRequest) async throws -> Response {
        // Get the visualization
        guard let visualization = try await visualizationService.visualizationsCollection
            .findOne(["id": req.visualizationId]) else {
            throw Abort(.notFound)
        }
        
        // Find the interactive element
        guard let element = visualization.interactiveElements.first(where: { $0.elementId == req.elementId }) else {
            throw Abort(.badRequest, reason: "Interactive element not found")
        }
        
        // Handle different interaction types
        switch element.type {
        case .tooltip:
            // Return tooltip content
            return try await makeJsonResponse([
                "type": "tooltip",
                "content": element.tooltipContent ?? "",
                "position": req.data?["position"] ?? ""
            ])
            
        case .clickable:
            // Handle click interaction
            return try await makeJsonResponse([
                "type": "click",
                "elementId": element.elementId,
                "data": element.data
            ])
            
        case .zoomable:
            // Handle zoom interaction
            let zoomLevel = Double(req.data?["zoomLevel"] ?? "1.0") ?? 1.0
            let center = req.data?["center"] ?? "0,0"
            
            return try await makeJsonResponse([
                "type": "zoom",
                "elementId": element.elementId,
                "zoomLevel": zoomLevel,
                "center": center
            ])
            
        case .hoverable:
            // Handle hover interaction
            return try await makeJsonResponse([
                "type": "hover",
                "elementId": element.elementId,
                "data": element.data,
                "tooltipContent": element.tooltipContent ?? ""
            ])
        }
    }
    
    private func getRawData(id: String) async throws -> [String: [Double]] {
        guard let visualization = try await visualizationService.visualizationsCollection
            .findOne(["id": id]) else {
            throw Abort(.notFound)
        }
        return visualization.rawData
    }
    
    private func updateView(id: String, state: [String: Any]) async throws -> Response {
        // Update the visualization view state in the database
        try await visualizationService.visualizationsCollection.updateOne(
            where: ["id": id],
            to: ["$set": ["viewState": state]]
        )
        
        return try await makeJsonResponse([
            "status": "success",
            "message": "View state updated successfully"
        ])
    }
    
    private func makeJsonResponse(_ data: [String: Any]) async throws -> Response {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: jsonData)
        )
    }
} 
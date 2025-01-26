import Foundation
import Vapor

struct UpdateAIModelRequest: Content {
    let model: AIModel
}

struct UpdateProviderRequest: Content {
    let provider: String
}

struct UpdateAPIKeyRequest: Content {
    let provider: String
    let key: String
}

final class APIConfigurationController {
    private let configService: AIConfigurationService
    
    init(configService: AIConfigurationService) {
        self.configService = configService
    }
    
    func configureRoutes(_ app: Application) throws {
        let group = app.grouped("api", "config")
        
        // Get current configuration
        group.get("current") { req async throws -> APIConfiguration in
            return self.configService.getCurrentConfiguration()
        }
        
        // Update AI model
        group.put("ai-model") { req async throws -> Response in
            let update = try req.content.decode(UpdateAIModelRequest.self)
            try await self.configService.updateAIModel(update.model)
            return Response(status: .ok)
        }
        
        // Update Maps provider
        group.put("maps-provider") { req async throws -> Response in
            let update = try req.content.decode(UpdateProviderRequest.self)
            guard let provider = MapsProvider(rawValue: update.provider) else {
                throw Abort(.badRequest, reason: "Invalid maps provider")
            }
            try await self.configService.updateMapsProvider(provider)
            return Response(status: .ok)
        }
        
        // Update Weather provider
        group.put("weather-provider") { req async throws -> Response in
            let update = try req.content.decode(UpdateProviderRequest.self)
            guard let provider = WeatherProvider(rawValue: update.provider) else {
                throw Abort(.badRequest, reason: "Invalid weather provider")
            }
            try await self.configService.updateWeatherProvider(provider)
            return Response(status: .ok)
        }
        
        // Update API key
        group.put("api-key") { req async throws -> Response in
            let update = try req.content.decode(UpdateAPIKeyRequest.self)
            
            // Validate API key before updating
            guard try await self.configService.validateAPIKey(for: update.provider, key: update.key) else {
                throw Abort(.badRequest, reason: "Invalid API key")
            }
            
            try await self.configService.updateAPIKey(for: update.provider, key: update.key)
            return Response(status: .ok)
        }
        
        // Get available AI models
        group.get("ai-models") { req async throws -> [String: [String]] in
            return [
                "models": AIModel.allCases.map { $0.rawValue }
            ]
        }
        
        // Get available Maps providers
        group.get("maps-providers") { req async throws -> [String: [String]] in
            return [
                "providers": MapsProvider.allCases.map { $0.rawValue }
            ]
        }
        
        // Get available Weather providers
        group.get("weather-providers") { req async throws -> [String: [String]] in
            return [
                "providers": WeatherProvider.allCases.map { $0.rawValue }
            ]
        }
    }
} 
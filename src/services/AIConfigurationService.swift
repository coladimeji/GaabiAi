import Foundation
import Vapor

// Supported AI Models
enum AIModel: String, Codable {
    case claude3Sonnet = "claude-3-sonnet"
    case gpt4 = "gpt-4"
    case gpt4Mini = "gpt-4-mini"
    case o1Mini = "01-mini"
    case o1Preview = "01-preview"
    case deepseek = "deepseek"
    
    var provider: AIProvider {
        switch self {
        case .claude3Sonnet:
            return .anthropic
        case .gpt4, .gpt4Mini:
            return .openAI
        case .o1Mini, .o1Preview:
            return .o1AI
        case .deepseek:
            return .deepseek
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .claude3Sonnet: return 200000
        case .gpt4: return 128000
        case .gpt4Mini: return 64000
        case .o1Mini: return 32000
        case .o1Preview: return 128000
        case .deepseek: return 64000
        }
    }
}

// AI Providers
enum AIProvider: String, Codable {
    case anthropic
    case openAI
    case o1AI
    case deepseek
}

// Maps API Providers
enum MapsProvider: String, Codable {
    case google
    case openStreetMap
    case mapbox
}

// Weather API Providers
enum WeatherProvider: String, Codable {
    case openWeather
    case weatherAPI
    case tomorrow
}

struct APIConfiguration: Codable {
    var selectedAIModel: AIModel
    var selectedMapsProvider: MapsProvider
    var selectedWeatherProvider: WeatherProvider
    var apiKeys: [String: String]
}

final class AIConfigurationService {
    private let database: MongoDatabase
    private var currentConfig: APIConfiguration
    private let configCollection: MongoCollection<APIConfiguration>
    
    init(database: MongoDatabase) throws {
        self.database = database
        self.configCollection = database.collection("api_configurations")
        
        // Load or create default configuration
        if let existingConfig = try? configCollection.findOne() {
            self.currentConfig = existingConfig
        } else {
            self.currentConfig = APIConfiguration(
                selectedAIModel: .gpt4,
                selectedMapsProvider: .google,
                selectedWeatherProvider: .openWeather,
                apiKeys: [:]
            )
            try configCollection.insertOne(self.currentConfig)
        }
    }
    
    // Update AI model
    func updateAIModel(_ model: AIModel) async throws {
        currentConfig.selectedAIModel = model
        try await configCollection.updateOne(
            filter: [:],
            to: currentConfig
        )
    }
    
    // Update Maps provider
    func updateMapsProvider(_ provider: MapsProvider) async throws {
        currentConfig.selectedMapsProvider = provider
        try await configCollection.updateOne(
            filter: [:],
            to: currentConfig
        )
    }
    
    // Update Weather provider
    func updateWeatherProvider(_ provider: WeatherProvider) async throws {
        currentConfig.selectedWeatherProvider = provider
        try await configCollection.updateOne(
            filter: [:],
            to: currentConfig
        )
    }
    
    // Get current configuration
    func getCurrentConfiguration() -> APIConfiguration {
        return currentConfig
    }
    
    // Update API key
    func updateAPIKey(for provider: String, key: String) async throws {
        currentConfig.apiKeys[provider] = key
        try await configCollection.updateOne(
            filter: [:],
            to: currentConfig
        )
    }
    
    // Get API key for provider
    func getAPIKey(for provider: String) -> String? {
        return currentConfig.apiKeys[provider]
    }
    
    // Validate API key
    func validateAPIKey(for provider: String, key: String) async throws -> Bool {
        // Implement validation logic for each provider
        switch provider {
        case AIProvider.openAI.rawValue:
            return try await validateOpenAIKey(key)
        case MapsProvider.google.rawValue:
            return try await validateGoogleMapsKey(key)
        case WeatherProvider.openWeather.rawValue:
            return try await validateOpenWeatherKey(key)
        default:
            return false
        }
    }
    
    // Private validation methods
    private func validateOpenAIKey(_ key: String) async throws -> Bool {
        // Implement OpenAI key validation
        return true // Placeholder
    }
    
    private func validateGoogleMapsKey(_ key: String) async throws -> Bool {
        // Implement Google Maps key validation
        return true // Placeholder
    }
    
    private func validateOpenWeatherKey(_ key: String) async throws -> Bool {
        // Implement OpenWeather key validation
        return true // Placeholder
    }
} 
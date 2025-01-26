import Foundation
import Vapor

struct AIModelResponse: Content {
    let text: String
    let confidence: Double
    let metadata: [String: String]
}

final class AIModelService {
    private let configService: AIConfigurationService
    private var openAIClient: OpenAIClient?
    private var anthropicClient: AnthropicClient?
    private var deepseekClient: DeepseekClient?
    
    init(configService: AIConfigurationService) {
        self.configService = configService
        setupClients()
    }
    
    private func setupClients() {
        let config = configService.getCurrentConfiguration()
        
        // Setup OpenAI client if using GPT models
        if [.gpt4, .gpt4Mini].contains(config.aiModel) {
            openAIClient = OpenAIClient(apiKey: config.apiKeys["openai"] ?? "")
        }
        
        // Setup Anthropic client if using Claude models
        if [.claude3Sonnet].contains(config.aiModel) {
            anthropicClient = AnthropicClient(apiKey: config.apiKeys["anthropic"] ?? "")
        }
        
        // Setup Deepseek client if using Deepseek models
        if [.deepseek].contains(config.aiModel) {
            deepseekClient = DeepseekClient(apiKey: config.apiKeys["deepseek"] ?? "")
        }
    }
    
    func processText(_ text: String) async throws -> AIModelResponse {
        let config = configService.getCurrentConfiguration()
        
        switch config.aiModel {
        case .gpt4, .gpt4Mini:
            guard let client = openAIClient else {
                throw Abort(.internalServerError, reason: "OpenAI client not configured")
            }
            return try await client.processText(text, model: config.aiModel)
            
        case .claude3Sonnet:
            guard let client = anthropicClient else {
                throw Abort(.internalServerError, reason: "Anthropic client not configured")
            }
            return try await client.processText(text)
            
        case .deepseek:
            guard let client = deepseekClient else {
                throw Abort(.internalServerError, reason: "Deepseek client not configured")
            }
            return try await client.processText(text)
        }
    }
    
    func updateConfiguration() {
        setupClients()
    }
}

// Protocol for AI clients
protocol AIClient {
    func processText(_ text: String, model: AIModel?) async throws -> AIModelResponse
}

// OpenAI client implementation
final class OpenAIClient: AIClient {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func processText(_ text: String, model: AIModel?) async throws -> AIModelResponse {
        // Check cache first
        let cacheKey = "openai_\(text)_\(model?.rawValue ?? "default")"
        if let cached: AIModelResponse = await CacheUtility.shared.get(forKey: cacheKey) {
            return cached
        }
        
        // Prepare request
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        let requestBody = OpenAIRequest(
            model: model?.rawValue ?? "gpt-4",
            messages: [
                OpenAIMessage(role: "system", content: "You are a helpful assistant."),
                OpenAIMessage(role: "user", content: text)
            ],
            temperature: 0.7,
            maxTokens: model?.maxTokens ?? 150
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        do {
            let response: OpenAIResponse = try await NetworkUtility.shared.performRequest(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData
            )
            
            let result = AIModelResponse(
                text: response.choices.first?.message.content ?? "",
                confidence: response.choices.first?.confidence ?? 0.0,
                metadata: [
                    "model": response.model,
                    "finish_reason": response.choices.first?.finishReason ?? "unknown"
                ]
            )
            
            // Cache the response
            await CacheUtility.shared.set(result, forKey: cacheKey, ttl: 3600)
            
            return result
        } catch {
            throw error
        }
    }
}

// OpenAI API models
private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable {
    let id: String
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: OpenAIMessage
        let finishReason: String
        let confidence: Double?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
            case confidence
        }
    }
}

// Anthropic client implementation
final class AnthropicClient: AIClient {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func processText(_ text: String, model: AIModel? = nil) async throws -> AIModelResponse {
        // Check cache first
        let cacheKey = "anthropic_\(text)_claude"
        if let cached: AIModelResponse = await CacheUtility.shared.get(forKey: cacheKey) {
            return cached
        }
        
        // Prepare request
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw NetworkError.invalidURL
        }
        
        let requestBody = AnthropicRequest(
            model: "claude-3-sonnet-20240229",
            messages: [
                AnthropicMessage(role: "user", content: text)
            ],
            max_tokens: 1024,
            temperature: 0.7,
            system: "You are Claude, a helpful AI assistant."
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        ]
        
        do {
            let response: AnthropicResponse = try await NetworkUtility.shared.performRequest(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData
            )
            
            let result = AIModelResponse(
                text: response.content.first?.text ?? "",
                confidence: response.usage?.confidence ?? 0.0,
                metadata: [
                    "model": response.model,
                    "finish_reason": response.stop_reason ?? "unknown",
                    "usage.input_tokens": String(response.usage?.input_tokens ?? 0),
                    "usage.output_tokens": String(response.usage?.output_tokens ?? 0)
                ]
            )
            
            // Cache the response
            await CacheUtility.shared.set(result, forKey: cacheKey, ttl: 3600)
            
            return result
        } catch let error as NetworkError {
            switch error {
            case .rateLimitExceeded:
                // Implement rate limit handling with exponential backoff
                throw error
            case .unauthorized:
                // Log authentication errors
                print("Authentication error with Anthropic API: \(error.description)")
                throw error
            case .serverError(let code):
                // Log server errors
                print("Anthropic API server error: \(code)")
                throw error
            default:
                throw error
            }
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

// Anthropic API models
private struct AnthropicRequest: Codable {
    let model: String
    let messages: [AnthropicMessage]
    let max_tokens: Int
    let temperature: Double
    let system: String
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Codable {
    let id: String
    let model: String
    let content: [MessageContent]
    let usage: Usage?
    let stop_reason: String?
    
    struct MessageContent: Codable {
        let text: String
        let type: String
    }
    
    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
        let confidence: Double?
    }
}

// Deepseek client implementation
final class DeepseekClient: AIClient {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func processText(_ text: String, model: AIModel? = nil) async throws -> AIModelResponse {
        // Check cache first
        let cacheKey = "deepseek_\(text)_chat"
        if let cached: AIModelResponse = await CacheUtility.shared.get(forKey: cacheKey) {
            return cached
        }
        
        // Prepare request
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        let requestBody = DeepseekRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekMessage(role: "system", content: "You are a helpful AI assistant."),
                DeepseekMessage(role: "user", content: text)
            ],
            temperature: 0.7,
            max_tokens: 1024,
            stream: false
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        do {
            let response: DeepseekResponse = try await NetworkUtility.shared.performRequest(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData
            )
            
            let result = AIModelResponse(
                text: response.choices.first?.message.content ?? "",
                confidence: response.choices.first?.confidence ?? 0.0,
                metadata: [
                    "model": response.model,
                    "finish_reason": response.choices.first?.finish_reason ?? "unknown",
                    "usage.prompt_tokens": String(response.usage.prompt_tokens),
                    "usage.completion_tokens": String(response.usage.completion_tokens),
                    "usage.total_tokens": String(response.usage.total_tokens)
                ]
            )
            
            // Cache the response
            await CacheUtility.shared.set(result, forKey: cacheKey, ttl: 3600)
            
            return result
        } catch let error as NetworkError {
            switch error {
            case .rateLimitExceeded:
                // Handle rate limiting with exponential backoff
                print("Rate limit exceeded for Deepseek API: \(error.description)")
                throw error
            case .unauthorized:
                // Log authentication errors
                print("Authentication error with Deepseek API: \(error.description)")
                throw error
            case .serverError(let code):
                // Log server errors
                print("Deepseek API server error: \(code)")
                throw error
            default:
                throw error
            }
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

// Deepseek API models
private struct DeepseekRequest: Codable {
    let model: String
    let messages: [DeepseekMessage]
    let temperature: Double
    let max_tokens: Int
    let stream: Bool
}

private struct DeepseekMessage: Codable {
    let role: String
    let content: String
}

private struct DeepseekResponse: Codable {
    let id: String
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: DeepseekMessage
        let finish_reason: String
        let confidence: Double?
    }
    
    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
} 
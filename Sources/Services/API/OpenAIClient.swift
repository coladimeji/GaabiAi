import Foundation

actor OpenAIClient {
    private let baseURL = "https://api.openai.com/v1"
    private let settingsViewModel: SettingsViewModel
    private let cache = CacheUtility.shared
    private let networkUtility = NetworkUtility.shared
    
    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
    }
    
    func generateCompletion(prompt: String, model: String = "gpt-4-turbo-preview") async throws -> String {
        // Check cache first
        let cacheKey = "openai_\(model)_\(prompt.hashValue)"
        if let cachedResponse: String = try? await cache.get(key: cacheKey) {
            return cachedResponse
        }
        
        let apiKey = settingsViewModel.getAPIKey(for: "OPENAI_API_KEY")
        guard !apiKey.isEmpty else {
            throw NetworkError.missingAPIKey
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let (data, response) = try await networkUtility.performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            let responseText = decodedResponse.choices.first?.message.content ?? ""
            
            // Cache the successful response
            try? await cache.set(key: cacheKey, value: responseText, expirationDuration: 3600) // Cache for 1 hour
            
            return responseText
            
        case 401:
            throw NetworkError.unauthorized
        case 429:
            throw NetworkError.rateLimitExceeded
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
}

// Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
} 
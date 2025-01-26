import Foundation
import SwiftUI

@MainActor
class AIManager: ObservableObject {
    @Published var isProcessing = false
    @Published var lastResponse: String?
    @Published var error: Error?
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    init() {
        // Get API key from environment
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("OpenAI API key not found in environment variables")
        }
        self.apiKey = apiKey
    }
    
    func generateResponse(for prompt: String) async {
        isProcessing = true
        error = nil
        
        let message = [
            "role": "user",
            "content": prompt
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [message],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            lastResponse = result.choices.first?.message.content
        } catch {
            self.error = error
        }
        
        isProcessing = false
    }
    
    func clearResponse() {
        lastResponse = nil
        error = nil
    }
}

// MARK: - Supporting Types
enum AIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        }
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
} 
import Foundation

class AIManager: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    @Published var isProcessing = false
    @Published var lastResponse: String?
    @Published var error: Error?
    
    init(apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "") {
        self.apiKey = apiKey
    }
    
    func analyzeText(_ text: String) async {
        guard !apiKey.isEmpty else {
            error = NSError(domain: "AIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let endpoint = "\(baseURL)/chat/completions"
        let messages = [["role": "user", "content": text]]
        
        let parameters: [String: Any] = [
            "model": "gpt-4",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 150
        ]
        
        guard let url = URL(string: endpoint),
              let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            error = NSError(domain: "AIManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid request data"])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                DispatchQueue.main.async {
                    self.lastResponse = content
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func generateSuggestions(for text: String) async -> [String] {
        // Implement suggestion generation using the OpenAI API
        return []
    }
    
    func summarizeText(_ text: String) async -> String? {
        // Implement text summarization using the OpenAI API
        return nil
    }
} 
import Foundation

enum AIModel: String, CaseIterable {
    case gpt4
    case gpt35Turbo
    case claude2
    case claudeInstant
    
    var description: String {
        switch self {
        case .gpt4: return "GPT-4"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        case .claude2: return "Claude 2"
        case .claudeInstant: return "Claude Instant"
        }
    }
    
    var configKey: String {
        switch self {
        case .gpt4, .gpt35Turbo: return "openai"
        case .claude2, .claudeInstant: return "anthropic"
        }
    }
} 
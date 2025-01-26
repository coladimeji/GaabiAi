import XCTest
@testable import App

// Mock Network Utility for testing
class MockNetworkUtility: NetworkUtility {
    static let mockShared = MockNetworkUtility()
    var mockResponses: [String: Any] = [:]
    
    func setMockResponse<T: Encodable>(_ response: T, for url: String) {
        mockResponses[url] = response
    }
    
    override func performRequest<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> T {
        if let mockResponse = mockResponses[url.absoluteString] as? T {
            return mockResponse
        }
        
        if url.absoluteString.contains("invalid_key") {
            throw NetworkError.unauthorized
        }
        
        throw NetworkError.invalidResponse
    }
}

final class AIModelServiceTests: XCTestCase {
    var configService: AIConfigurationService!
    var aiModelService: AIModelService!
    let mockNetworkUtility = MockNetworkUtility.mockShared
    
    override func setUp() {
        super.setUp()
        configService = AIConfigurationService(database: app.mongoDB.client.db("test_db"))
        aiModelService = AIModelService(configService: configService)
        
        // Set up mock responses
        setupMockResponses()
    }
    
    override func tearDown() {
        mockNetworkUtility.mockResponses.removeAll()
        configService = nil
        aiModelService = nil
        super.tearDown()
    }
    
    private func setupMockResponses() {
        // Mock OpenAI response
        let openAIResponse = OpenAIResponse(
            id: "mock-id",
            model: "gpt-4",
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIMessage(role: "assistant", content: "Hello! I'm doing well, thank you for asking."),
                    finishReason: "stop",
                    confidence: 0.95
                )
            ]
        )
        mockNetworkUtility.setMockResponse(openAIResponse, for: "https://api.openai.com/v1/chat/completions")
        
        // Mock Anthropic response
        let anthropicResponse = AnthropicResponse(
            id: "mock-id",
            model: "claude-3-sonnet-20240229",
            content: [
                AnthropicResponse.MessageContent(text: "It's sunny today!", type: "text")
            ],
            usage: AnthropicResponse.Usage(
                input_tokens: 10,
                output_tokens: 20,
                confidence: 0.92
            ),
            stop_reason: "stop"
        )
        mockNetworkUtility.setMockResponse(anthropicResponse, for: "https://api.anthropic.com/v1/messages")
        
        // Mock Deepseek response
        let deepseekResponse = DeepseekResponse(
            id: "mock-id",
            model: "deepseek-chat",
            choices: [
                DeepseekResponse.Choice(
                    index: 0,
                    message: DeepseekMessage(role: "assistant", content: "Why did the programmer quit his job? Because he didn't get arrays!"),
                    finish_reason: "stop",
                    confidence: 0.88
                )
            ],
            usage: DeepseekResponse.Usage(
                prompt_tokens: 15,
                completion_tokens: 25,
                total_tokens: 40
            )
        )
        mockNetworkUtility.setMockResponse(deepseekResponse, for: "https://api.deepseek.com/v1/chat/completions")
    }
    
    func testOpenAIProcessText() async throws {
        // Configure for OpenAI
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": "test_openai_key"]
        )
        configService.updateConfiguration(config)
        
        // Test text processing
        let response = try await aiModelService.processText("Hello, how are you?")
        
        // Verify response
        XCTAssertEqual(response.text, "Hello! I'm doing well, thank you for asking.")
        XCTAssertEqual(response.confidence, 0.95)
        XCTAssertEqual(response.metadata["model"], "gpt-4")
        XCTAssertEqual(response.metadata["finish_reason"], "stop")
    }
    
    func testAnthropicProcessText() async throws {
        // Configure for Anthropic
        let config = AIConfiguration(
            aiModel: .claude3Sonnet,
            apiKeys: ["anthropic": "test_anthropic_key"]
        )
        configService.updateConfiguration(config)
        
        // Test text processing
        let response = try await aiModelService.processText("What's the weather like?")
        
        // Verify response
        XCTAssertEqual(response.text, "It's sunny today!")
        XCTAssertEqual(response.confidence, 0.92)
        XCTAssertEqual(response.metadata["model"], "claude-3-sonnet-20240229")
        XCTAssertEqual(response.metadata["finish_reason"], "stop")
        XCTAssertEqual(response.metadata["usage.input_tokens"], "10")
        XCTAssertEqual(response.metadata["usage.output_tokens"], "20")
    }
    
    func testDeepseekProcessText() async throws {
        // Configure for Deepseek
        let config = AIConfiguration(
            aiModel: .deepseek,
            apiKeys: ["deepseek": "test_deepseek_key"]
        )
        configService.updateConfiguration(config)
        
        // Test text processing
        let response = try await aiModelService.processText("Tell me a joke")
        
        // Verify response
        XCTAssertEqual(response.text, "Why did the programmer quit his job? Because he didn't get arrays!")
        XCTAssertEqual(response.confidence, 0.88)
        XCTAssertEqual(response.metadata["model"], "deepseek-chat")
        XCTAssertEqual(response.metadata["finish_reason"], "stop")
        XCTAssertEqual(response.metadata["usage.prompt_tokens"], "15")
        XCTAssertEqual(response.metadata["usage.completion_tokens"], "25")
        XCTAssertEqual(response.metadata["usage.total_tokens"], "40")
    }
    
    func testCaching() async throws {
        // Configure for OpenAI
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": "test_openai_key"]
        )
        configService.updateConfiguration(config)
        
        // First request
        let text = "This is a test message"
        let firstResponse = try await aiModelService.processText(text)
        
        // Modify mock response to ensure we're getting cached response
        let modifiedResponse = OpenAIResponse(
            id: "modified-id",
            model: "gpt-4",
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIMessage(role: "assistant", content: "Modified response"),
                    finishReason: "stop",
                    confidence: 0.8
                )
            ]
        )
        mockNetworkUtility.setMockResponse(modifiedResponse, for: "https://api.openai.com/v1/chat/completions")
        
        // Second request (should be cached)
        let secondResponse = try await aiModelService.processText(text)
        
        // Verify responses are identical (from cache)
        XCTAssertEqual(firstResponse.text, secondResponse.text)
        XCTAssertEqual(firstResponse.confidence, secondResponse.confidence)
        XCTAssertEqual(firstResponse.metadata, secondResponse.metadata)
    }
    
    func testErrorHandling() async throws {
        // Configure with invalid API key
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": "invalid_key"]
        )
        configService.updateConfiguration(config)
        
        // Test error handling
        do {
            _ = try await aiModelService.processText("Test message")
            XCTFail("Should have thrown an error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, NetworkError.unauthorized)
        }
    }
    
    func testModelSwitching() async throws {
        // Test switching between models
        var config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": "test_openai_key"]
        )
        configService.updateConfiguration(config)
        
        let gptResponse = try await aiModelService.processText("Test message")
        XCTAssertTrue(gptResponse.metadata["model"]?.contains("gpt") ?? false)
        
        config = AIConfiguration(
            aiModel: .claude3Sonnet,
            apiKeys: ["anthropic": "test_anthropic_key"]
        )
        configService.updateConfiguration(config)
        
        let claudeResponse = try await aiModelService.processText("Test message")
        XCTAssertTrue(claudeResponse.metadata["model"]?.contains("claude") ?? false)
    }
} 
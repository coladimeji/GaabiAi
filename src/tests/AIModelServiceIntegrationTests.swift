import XCTest
@testable import App

final class AIModelServiceIntegrationTests: XCTestCase {
    var configService: AIConfigurationService!
    var aiModelService: AIModelService!
    
    override func setUp() {
        super.setUp()
        configService = AIConfigurationService(database: app.mongoDB.client.db("test_db"))
        aiModelService = AIModelService(configService: configService)
    }
    
    override func tearDown() {
        configService = nil
        aiModelService = nil
        super.tearDown()
    }
    
    // MARK: - Required OpenAI Tests
    
    func testOpenAIBasicFunctionality() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        // Test factual knowledge
        let factResponse = try await aiModelService.processText("What is the capital of France?")
        XCTAssertTrue(factResponse.text.lowercased().contains("paris"))
        
        // Test mathematical computation
        let mathResponse = try await aiModelService.processText("What is the square root of 144?")
        XCTAssertTrue(mathResponse.text.contains("12"))
        
        // Test language understanding
        let languageResponse = try await aiModelService.processText("What's the opposite of 'optimistic'?")
        XCTAssertTrue(languageResponse.text.lowercased().contains("pessimistic"))
        
        // Verify response structure for all
        for response in [factResponse, mathResponse, languageResponse] {
            XCTAssertFalse(response.text.isEmpty)
            XCTAssertTrue(response.metadata["model"]?.contains("gpt") ?? false)
            XCTAssertNotNil(response.metadata["finish_reason"])
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testOpenAICodeGeneration() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let codePrompts = [
            (
                "Write a Swift function to check if a string is a palindrome",
                ["func", "String", "reversed", "return", "=="]
            ),
            (
                "Create a Swift struct for a User with name, age, and email properties",
                ["struct", "User", "String", "Int", "init"]
            ),
            (
                "Write a Swift extension to convert a Date to ISO8601 string",
                ["extension", "Date", "ISO8601", "DateFormatter", "string"]
            )
        ]
        
        for (prompt, expectedTerms) in codePrompts {
            let response = try await aiModelService.processText(prompt)
            
            // Verify code contains expected terms
            let responseText = response.text.lowercased()
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term.lowercased()),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify code structure
            XCTAssertTrue(response.text.contains("{"))
            XCTAssertTrue(response.text.contains("}"))
            XCTAssertFalse(response.text.contains("```")) // Should not contain markdown
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testOpenAIContextAwareness() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let conversationPrompts = [
            (
                "My name is John. What's your name?",
                ["assistant", "help", "name"]
            ),
            (
                "What's my name?",
                ["john"]
            ),
            (
                "What did I ask you first?",
                ["name", "asked"]
            )
        ]
        
        for (prompt, expectedTerms) in conversationPrompts {
            let response = try await aiModelService.processText(prompt)
            
            // Verify context awareness
            let responseText = response.text.lowercased()
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term.lowercased()),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testOpenAICaching() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        // Test multiple prompts for caching
        let prompts = [
            "What is 2 + 2?",
            "Who wrote Romeo and Juliet?",
            "What is the speed of light?"
        ]
        
        for prompt in prompts {
            // First request
            let startTime = Date()
            let firstResponse = try await aiModelService.processText(prompt)
            let firstDuration = Date().timeIntervalSince(startTime)
            
            // Second request (should be cached)
            let cacheStartTime = Date()
            let secondResponse = try await aiModelService.processText(prompt)
            let secondDuration = Date().timeIntervalSince(cacheStartTime)
            
            // Verify responses are identical
            XCTAssertEqual(firstResponse.text, secondResponse.text)
            XCTAssertEqual(firstResponse.confidence, secondResponse.confidence)
            XCTAssertEqual(firstResponse.metadata, secondResponse.metadata)
            
            // Verify second request was significantly faster (cached)
            XCTAssertLessThan(secondDuration, firstDuration / 2)
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testOpenAIErrorHandling() async throws {
        // Test various error scenarios
        let errorTests = [
            ("invalid_key_test", NetworkError.unauthorized, "Invalid API key"),
            ("", NetworkError.unauthorized, "Empty API key"),
            ("sk_test_expired_key", NetworkError.unauthorized, "Expired API key")
        ]
        
        for (apiKey, expectedError, scenario) in errorTests {
            let config = AIConfiguration(
                aiModel: .gpt4,
                apiKeys: ["openai": apiKey]
            )
            configService.updateConfiguration(config)
            
            do {
                _ = try await aiModelService.processText("Test message")
                XCTFail("Should have thrown an error for \(scenario)")
            } catch let error as NetworkError {
                XCTAssertEqual(error, expectedError, "Unexpected error for \(scenario)")
            }
        }
    }
    
    func testOpenAIRateLimiting() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        // Test with different prompt lengths
        let prompts = [
            String(repeating: "Short test. ", count: 1),    // Short prompt
            String(repeating: "Medium length test. ", count: 10),  // Medium prompt
            String(repeating: "Longer test prompt. ", count: 20)   // Long prompt
        ]
        
        for prompt in prompts {
            var successCount = 0
            var rateLimitHit = false
            
            print("Testing rate limiting with prompt length: \(prompt.count) characters")
            
            // Make rapid requests
            for _ in 1...5 {
                do {
                    let response = try await aiModelService.processText(prompt)
                    XCTAssertFalse(response.text.isEmpty)
                    successCount += 1
                } catch let error as NetworkError {
                    if case .rateLimitExceeded = error {
                        rateLimitHit = true
                        break
                    }
                    throw error
                }
            }
            
            print("Prompt length \(prompt.count): \(successCount) successful requests")
            if rateLimitHit {
                print("Rate limit hit as expected for prompt length \(prompt.count)")
            }
            
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds delay between prompt sets
        }
    }
    
    // MARK: - Optional Provider Tests
    
    func testOptionalProviders() async throws {
        var availableProviders = [String]()
        
        // Test Anthropic if available
        if let anthropicKey = Environment.get("ANTHROPIC_API_KEY") {
            availableProviders.append("Anthropic")
            try await testProvider(
                model: .claude3Sonnet,
                apiKey: anthropicKey,
                keyName: "anthropic",
                expectedModelString: "claude"
            )
        }
        
        // Test Deepseek if available
        if let deepseekKey = Environment.get("DEEPSEEK_API_KEY") {
            availableProviders.append("Deepseek")
            try await testProvider(
                model: .deepseek,
                apiKey: deepseekKey,
                keyName: "deepseek",
                expectedModelString: "deepseek"
            )
        }
        
        if availableProviders.isEmpty {
            print("No optional providers available for testing")
        } else {
            print("Tested optional providers: \(availableProviders.joined(separator: ", "))")
        }
    }
    
    private func testProvider(
        model: AIModel,
        apiKey: String,
        keyName: String,
        expectedModelString: String
    ) async throws {
        let config = AIConfiguration(
            aiModel: model,
            apiKeys: [keyName: apiKey]
        )
        configService.updateConfiguration(config)
        
        let response = try await aiModelService.processText("Hello, how are you?")
        
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertTrue(response.metadata["model"]?.contains(expectedModelString) ?? false)
    }
    
    func testSwiftSpecificQueries() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let swiftPrompts = [
            (
                "What's the difference between struct and class in Swift?",
                ["value type", "reference type", "inheritance", "stack", "heap"]
            ),
            (
                "Explain Swift's optional binding and optional chaining",
                ["if let", "guard let", "?", "!", "nil", "optional", "unwrap"]
            ),
            (
                "How do protocols work in Swift?",
                ["protocol", "conform", "delegate", "requirements", "extension"]
            )
        ]
        
        for (prompt, expectedTerms) in swiftPrompts {
            let response = try await aiModelService.processText(prompt)
            
            // Verify response contains expected terms
            let responseText = response.text.lowercased()
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term.lowercased()),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testSwiftCodeExamples() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let codePrompts = [
            (
                "Write a Swift protocol for a TaskManager with methods for CRUD operations",
                [
                    "protocol TaskManager",
                    "func create",
                    "func read",
                    "func update",
                    "func delete"
                ]
            ),
            (
                "Create a Swift enum for HTTP methods with associated values for parameters",
                [
                    "enum HTTPMethod",
                    "case get",
                    "case post",
                    "associated",
                    "parameters"
                ]
            ),
            (
                "Write an async Swift function to fetch and decode JSON data",
                [
                    "async",
                    "URLSession",
                    "try await",
                    "JSONDecoder",
                    "Data"
                ]
            ),
            (
                "Create a Swift actor for thread-safe caching",
                [
                    "actor",
                    "private var",
                    "async",
                    "nonisolated",
                    "await"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in codePrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify code contains expected terms
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify Swift syntax elements
            XCTAssertTrue(responseText.contains("{"))
            XCTAssertTrue(responseText.contains("}"))
            XCTAssertTrue(responseText.contains(":"))
            
            // Verify no markdown
            XCTAssertFalse(responseText.contains("```"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testSwiftErrorHandling() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let errorPrompts = [
            (
                "Write a Swift error enum for network errors",
                [
                    "enum NetworkError: Error",
                    "case invalidURL",
                    "case serverError",
                    "case decodingError"
                ]
            ),
            (
                "Show how to use try-catch in Swift with custom errors",
                [
                    "do {",
                    "try",
                    "catch",
                    "throw",
                    "Error"
                ]
            ),
            (
                "Implement Result type handling in Swift",
                [
                    "Result<",
                    "success",
                    "failure",
                    "switch",
                    "case"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in errorPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify error handling code
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify proper code structure
            XCTAssertTrue(responseText.contains("{"))
            XCTAssertTrue(responseText.contains("}"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testSwiftConcurrencyPatterns() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let concurrencyPrompts = [
            (
                "Write a Swift async/await function with Task groups",
                [
                    "async",
                    "await",
                    "withTaskGroup",
                    "group.addTask",
                    "for await"
                ]
            ),
            (
                "Implement an actor with async methods in Swift",
                [
                    "actor",
                    "nonisolated",
                    "async",
                    "await",
                    "private"
                ]
            ),
            (
                "Show how to use async sequences in Swift",
                [
                    "AsyncSequence",
                    "AsyncIteratorProtocol",
                    "for await",
                    "yield",
                    "next()"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in concurrencyPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify concurrency patterns
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify proper async/await usage
            XCTAssertTrue(responseText.contains("async"))
            XCTAssertTrue(responseText.contains("await"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testSwiftUICodeGeneration() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let swiftUIPrompts = [
            (
                "Create a SwiftUI view for a custom button with an icon and label",
                [
                    "struct",
                    "View",
                    "var body:",
                    "Button",
                    "Image",
                    "Text",
                    "some View"
                ]
            ),
            (
                "Write a SwiftUI MVVM implementation for a task list",
                [
                    "class TaskViewModel",
                    "ObservableObject",
                    "@Published",
                    "struct TaskListView",
                    "List",
                    "ForEach",
                    "@StateObject"
                ]
            ),
            (
                "Create a custom SwiftUI modifier for card-style views",
                [
                    "struct CardModifier",
                    "ViewModifier",
                    "func body",
                    "content",
                    "background",
                    "cornerRadius",
                    "shadow"
                ]
            ),
            (
                "Implement a SwiftUI navigation stack with deep linking",
                [
                    "NavigationStack",
                    "navigationDestination",
                    "NavigationLink",
                    "path",
                    "@State",
                    "Hashable"
                ]
            ),
            (
                "Create a custom SwiftUI chart view using Swift Charts",
                [
                    "Chart",
                    "LineMark",
                    "PointMark",
                    "chartXAxis",
                    "chartYAxis",
                    "foregroundStyle"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in swiftUIPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify SwiftUI code
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify SwiftUI structure
            XCTAssertTrue(responseText.contains("import SwiftUI"))
            XCTAssertTrue(responseText.contains("var body:"))
            XCTAssertTrue(responseText.contains("some View"))
            
            // Verify no markdown
            XCTAssertFalse(responseText.contains("```"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testCombineIntegration() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let combinePrompts = [
            (
                "Create a Combine publisher for handling network requests",
                [
                    "import Combine",
                    "AnyPublisher",
                    "Future",
                    "URLSession",
                    "dataTaskPublisher",
                    "eraseToAnyPublisher"
                ]
            ),
            (
                "Implement a debounced search using Combine",
                [
                    "@Published",
                    "debounce",
                    "removeDuplicates",
                    "sink",
                    "cancellable",
                    "store"
                ]
            ),
            (
                "Create a Combine pipeline for data transformation",
                [
                    "map",
                    "flatMap",
                    "compactMap",
                    "receive(on:)",
                    "subscribe(on:)",
                    "assign"
                ]
            ),
            (
                "Implement error handling in a Combine pipeline",
                [
                    "catch",
                    "tryMap",
                    "mapError",
                    "retry",
                    "handleEvents",
                    "Publishers.Retry"
                ]
            ),
            (
                "Create a custom Combine operator",
                [
                    "Publisher",
                    "Subscriber",
                    "Subscription",
                    "receive",
                    "request",
                    "cancel"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in combinePrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify Combine code
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify Combine imports and structure
            XCTAssertTrue(responseText.contains("import Combine"))
            
            // Verify proper type declarations
            XCTAssertTrue(responseText.contains("class") || 
                         responseText.contains("struct") ||
                         responseText.contains("extension"))
            
            // Verify no markdown
            XCTAssertFalse(responseText.contains("```"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testSwiftUIAndCombineIntegration() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let integrationPrompts = [
            (
                "Create a SwiftUI view model with Combine for real-time data updates",
                [
                    "class ViewModel: ObservableObject",
                    "@Published",
                    "AnyPublisher",
                    "cancellable",
                    "sink",
                    "assign"
                ]
            ),
            (
                "Implement a search bar with Combine debounce in SwiftUI",
                [
                    "SearchBar",
                    "@State",
                    "debounce",
                    "TextField",
                    "onReceive",
                    "Just"
                ]
            ),
            (
                "Create a SwiftUI form with Combine validation",
                [
                    "Form",
                    "Publishers",
                    "CombineLatest",
                    "ValidationPublisher",
                    "isValid",
                    "disabled"
                ]
            ),
            (
                "Implement real-time data filtering in SwiftUI using Combine",
                [
                    "List",
                    "filter",
                    "map",
                    "Published",
                    "ForEach",
                    "onChange"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in integrationPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify SwiftUI and Combine integration
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for prompt: '\(prompt)'"
                )
            }
            
            // Verify imports
            XCTAssertTrue(responseText.contains("import SwiftUI"))
            XCTAssertTrue(responseText.contains("import Combine"))
            
            // Verify MVVM structure
            XCTAssertTrue(responseText.contains("class") && responseText.contains("ObservableObject"))
            XCTAssertTrue(responseText.contains("View"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testRealWorldIntegrationScenarios() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let scenarios = [
            (
                "Create a weather dashboard with SwiftUI and Combine using OpenWeather API",
                [
                    // Architecture
                    "class WeatherViewModel: ObservableObject",
                    "@Published var weatherData",
                    "struct WeatherDashboardView",
                    
                    // Networking
                    "URLSession.shared.dataTaskPublisher",
                    "JSONDecoder().decode",
                    
                    // UI Components
                    "VStack", "HStack", "ScrollView",
                    "AsyncImage",
                    "Chart",
                    
                    // Error Handling
                    "catch", "handleEvents", "retry"
                ]
            ),
            (
                "Implement a real-time chat feature with WebSocket and Combine in SwiftUI",
                [
                    // WebSocket
                    "URLSessionWebSocketTask",
                    "connect()",
                    "receive()",
                    
                    // Combine
                    "PassthroughSubject",
                    "CurrentValueSubject",
                    "sink",
                    
                    // SwiftUI
                    "ScrollViewReader",
                    "MessageBubble",
                    "@StateObject"
                ]
            ),
            (
                "Create a task management app with Core Data, SwiftUI, and Combine",
                [
                    // Core Data
                    "NSManagedObject",
                    "NSPersistentContainer",
                    "FetchRequest",
                    
                    // MVVM
                    "TaskViewModel",
                    "@FetchedResults",
                    "@Environment(\\.managedObjectContext)",
                    
                    // UI
                    "List", "ForEach", "Section"
                ]
            ),
            (
                "Build a photo gallery with async image loading and caching in SwiftUI",
                [
                    // Image Loading
                    "AsyncImage",
                    "NSCache",
                    "ImageLoader",
                    
                    // Grid Layout
                    "LazyVGrid",
                    "GridItem",
                    
                    // Memory Management
                    "weak", "self", "cache"
                ]
            ),
            (
                "Implement authentication flow with Combine and SwiftUI",
                [
                    // Authentication
                    "AuthenticationManager",
                    "KeychainAccess",
                    "JWT",
                    
                    // Flow Control
                    "AppStorage",
                    "NavigationPath",
                    "switchToMain",
                    
                    // Security
                    "Keychain", "encrypt", "secure"
                ]
            ),
            (
                "Create a map-based location tracker with CoreLocation and SwiftUI",
                [
                    // Location Services
                    "CLLocationManager",
                    "MKMapView",
                    "MapKit",
                    
                    // SwiftUI Integration
                    "Map",
                    "LocationManager",
                    "@StateObject"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in scenarios {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify implementation includes required components
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for scenario: '\(prompt)'"
                )
            }
            
            // Verify proper imports
            XCTAssertTrue(responseText.contains("import SwiftUI"))
            XCTAssertTrue(responseText.contains("import Combine"))
            
            // Verify MVVM architecture
            XCTAssertTrue(responseText.contains("ViewModel"))
            XCTAssertTrue(responseText.contains("ObservableObject"))
            
            // Verify error handling
            XCTAssertTrue(responseText.contains("catch") || responseText.contains("Error"))
            
            // Verify memory management
            XCTAssertTrue(
                responseText.contains("weak") || 
                responseText.contains("cancellable") ||
                responseText.contains("deinit")
            )
            
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds delay
        }
    }
    
    func testAdvancedIntegrationPatterns() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let patterns = [
            (
                "Implement dependency injection in SwiftUI with property wrappers",
                [
                    "@PropertyWrapper",
                    "DependencyContainer",
                    "Environment",
                    "inject",
                    "provide"
                ]
            ),
            (
                "Create a custom SwiftUI navigation coordinator pattern",
                [
                    "NavigationCoordinator",
                    "Path",
                    "Router",
                    "Coordinator",
                    "NavigationPath"
                ]
            ),
            (
                "Implement advanced Combine operators for retry and throttling",
                [
                    "retry(times:delay:)",
                    "throttle(for:scheduler:)",
                    "share()",
                    "multicast",
                    "ConnectablePublisher"
                ]
            ),
            (
                "Create a modular architecture with feature flags in SwiftUI",
                [
                    "FeatureFlag",
                    "ModuleBuilder",
                    "DynamicFeature",
                    "FeatureProvider",
                    "Configuration"
                ]
            ),
            (
                "Implement advanced state management with Combine and SwiftUI",
                [
                    "Store",
                    "Reducer",
                    "Action",
                    "State",
                    "Middleware"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in patterns {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify pattern implementation
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for pattern: '\(prompt)'"
                )
            }
            
            // Verify architectural principles
            XCTAssertTrue(responseText.contains("protocol") || responseText.contains("class"))
            XCTAssertTrue(responseText.contains("init"))
            
            // Verify documentation
            XCTAssertTrue(responseText.contains("///") || responseText.contains("//"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testUIUXDesignPatterns() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let designPrompts = [
            (
                "Create an accessible SwiftUI form with validation and error states",
                [
                    // Accessibility
                    "accessibilityLabel",
                    "accessibilityHint",
                    "accessibilityValue",
                    "VoiceOver",
                    
                    // Validation
                    "validationError",
                    "errorMessage",
                    "isValid",
                    
                    // Visual Feedback
                    "foregroundColor",
                    "border",
                    "animation"
                ]
            ),
            (
                "Design a dark mode compatible SwiftUI dashboard with dynamic color scheme",
                [
                    // Color Scheme
                    "ColorScheme",
                    "preferredColorScheme",
                    "Color.primary",
                    "adaptable",
                    
                    // Dynamic Colors
                    "Asset Catalog",
                    "semantic colors",
                    "dark mode",
                    
                    // UI Components
                    "background",
                    "overlay",
                    "blur"
                ]
            ),
            (
                "Implement SwiftUI animations and transitions for smooth user interactions",
                [
                    // Animations
                    "withAnimation",
                    "animation(.spring())",
                    "easeInOut",
                    
                    // Transitions
                    "transition",
                    "move",
                    "opacity",
                    
                    // Timing
                    "duration",
                    "delay",
                    "repeatForever"
                ]
            ),
            (
                "Create responsive SwiftUI layouts with dynamic type support",
                [
                    // Dynamic Type
                    "dynamicTypeSize",
                    "scaledFont",
                    "minimumScaleFactor",
                    
                    // Responsive Layout
                    "GeometryReader",
                    "flexible",
                    "adaptable",
                    
                    // Constraints
                    "maxWidth",
                    "frame",
                    "padding"
                ]
            ),
            (
                "Design a custom SwiftUI loading and error state system",
                [
                    // Loading States
                    "ProgressView",
                    "redacted",
                    "shimmer",
                    
                    // Error States
                    "AlertError",
                    "errorView",
                    "retry",
                    
                    // User Feedback
                    "haptic",
                    "feedback",
                    "alert"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in designPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify UI/UX patterns
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for design: '\(prompt)'"
                )
            }
            
            // Verify SwiftUI imports
            XCTAssertTrue(responseText.contains("import SwiftUI"))
            
            // Verify preview provider
            XCTAssertTrue(responseText.contains("PreviewProvider"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
    
    func testAdvancedUIComponents() async throws {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw XCTSkip("OpenAI API key not available")
        }
        
        let config = AIConfiguration(
            aiModel: .gpt4,
            apiKeys: ["openai": apiKey]
        )
        configService.updateConfiguration(config)
        
        let componentPrompts = [
            (
                "Create a custom SwiftUI carousel view with infinite scrolling",
                [
                    // Layout
                    "ScrollViewReader",
                    "scrollTo",
                    "offset",
                    
                    // Gestures
                    "DragGesture",
                    "gesture",
                    "onChanged",
                    
                    // Animation
                    "withAnimation",
                    "spring",
                    "transition"
                ]
            ),
            (
                "Design a SwiftUI bottom sheet with drag interaction and snap points",
                [
                    // Sheet
                    "bottomSheet",
                    "dragIndicator",
                    "snapPoints",
                    
                    // Gestures
                    "DragGesture",
                    "translation",
                    "velocity",
                    
                    // Animation
                    "spring",
                    "damping",
                    "response"
                ]
            ),
            (
                "Implement a custom SwiftUI tab bar with animations and badges",
                [
                    // Tab Bar
                    "TabView",
                    "selection",
                    "badge",
                    
                    // Custom Design
                    "customTabItem",
                    "indicator",
                    "active",
                    
                    // Animation
                    "transition",
                    "scale",
                    "offset"
                ]
            ),
            (
                "Create an advanced SwiftUI search bar with suggestions and filters",
                [
                    // Search
                    "searchBar",
                    "suggestions",
                    "filter",
                    
                    // UI Components
                    "TextField",
                    "List",
                    "Chip",
                    
                    // Interaction
                    "onSubmit",
                    "onChange",
                    "dismiss"
                ]
            ),
            (
                "Design a custom SwiftUI calendar with event management",
                [
                    // Calendar
                    "CalendarView",
                    "DateFormatter",
                    "events",
                    
                    // Layout
                    "LazyVGrid",
                    "GridItem",
                    "month",
                    
                    // Interaction
                    "selection",
                    "gesture",
                    "update"
                ]
            )
        ]
        
        for (prompt, expectedTerms) in componentPrompts {
            let response = try await aiModelService.processText(prompt)
            let responseText = response.text
            
            // Verify component implementation
            for term in expectedTerms {
                XCTAssertTrue(
                    responseText.contains(term),
                    "Response should contain '\(term)' for component: '\(prompt)'"
                )
            }
            
            // Verify reusability
            XCTAssertTrue(responseText.contains("struct") && responseText.contains("View"))
            
            // Verify customization options
            XCTAssertTrue(responseText.contains("var") || responseText.contains("let"))
            
            // Verify preview
            XCTAssertTrue(responseText.contains("Preview"))
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        }
    }
} 
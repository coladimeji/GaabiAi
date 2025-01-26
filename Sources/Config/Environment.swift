import Foundation

enum Environment {
    enum Keys {
        static let openAIApiKey = "OPENAI_API_KEY"
        static let weatherApiKey = "WEATHER_API_KEY"
        static let mapsApiKey = "MAPS_API_KEY"
        static let aiServiceURL = "AI_SERVICE_URL"
        static let weatherServiceURL = "WEATHER_SERVICE_URL"
        static let mapsServiceURL = "MAPS_SERVICE_URL"
    }
    
    static func value(for key: String) -> String? {
        let value = Bundle.main.infoDictionary?[key] as? String
        
        guard let value = value, !value.isEmpty else {
            #if DEBUG
            print("⚠️ No value found for key: \(key)")
            #endif
            return nil
        }
        
        return value
    }
    
    static var openAIApiKey: String {
        guard let value = value(for: Keys.openAIApiKey) else {
            fatalError("OpenAI API Key not found")
        }
        return value
    }
    
    static var weatherApiKey: String {
        guard let value = value(for: Keys.weatherApiKey) else {
            fatalError("Weather API Key not found")
        }
        return value
    }
    
    static var mapsApiKey: String {
        guard let value = value(for: Keys.mapsApiKey) else {
            fatalError("Maps API Key not found")
        }
        return value
    }
    
    static var aiServiceURL: URL {
        guard let urlString = value(for: Keys.aiServiceURL),
              let url = URL(string: urlString) else {
            fatalError("AI Service URL not found or invalid")
        }
        return url
    }
    
    static var weatherServiceURL: URL {
        guard let urlString = value(for: Keys.weatherServiceURL),
              let url = URL(string: urlString) else {
            fatalError("Weather Service URL not found or invalid")
        }
        return url
    }
    
    static var mapsServiceURL: URL {
        guard let urlString = value(for: Keys.mapsServiceURL),
              let url = URL(string: urlString) else {
            fatalError("Maps Service URL not found or invalid")
        }
        return url
    }
} 
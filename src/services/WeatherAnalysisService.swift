import Foundation
import Vapor

struct WeatherImpact {
    let severity: Double // 0-1 scale
    let description: String
    let recommendations: [String]
}

struct WeatherPattern {
    let timeOfDay: Int // 0-23
    let dayOfWeek: Int // 1-7
    let season: String
    let temperature: Double
    let precipitation: Double
    let windSpeed: Double
    let visibility: Double
    let confidence: Double // 0-1
}

struct WeatherTrend {
    let pattern: String
    let frequency: Double
    let impact: Double
    let reliability: Double
}

final class WeatherAnalysisService {
    private let database: MongoDatabase
    private let weatherCollection: MongoCollection<WeatherData>
    private let patternCollection: MongoCollection<WeatherPattern>
    private let weatherTrafficService: WeatherTrafficService
    
    init(database: MongoDatabase, weatherTrafficService: WeatherTrafficService) {
        self.database = database
        self.weatherCollection = database.collection("weather_history", withType: WeatherData.self)
        self.patternCollection = database.collection("weather_patterns")
        self.weatherTrafficService = weatherTrafficService
    }
    
    // Analyze weather impact on travel
    func analyzeWeatherImpact(weatherData: WeatherData) -> WeatherImpact {
        var severity = 0.0
        var recommendations: [String] = []
        
        // Analyze temperature impact
        if weatherData.temperature < 0 {
            severity += 0.3
            recommendations.append("Icy conditions likely. Consider postponing non-essential travel.")
        } else if weatherData.temperature > 35 {
            severity += 0.2
            recommendations.append("High temperature may affect vehicle performance. Ensure cooling system is working.")
        }
        
        // Analyze precipitation impact
        if weatherData.precipitation > 0 {
            if weatherData.precipitation < 2.5 {
                severity += 0.2
                recommendations.append("Light rain. Reduce speed and increase following distance.")
            } else if weatherData.precipitation < 7.6 {
                severity += 0.4
                recommendations.append("Moderate rain. Consider alternate routes with better drainage.")
            } else {
                severity += 0.6
                recommendations.append("Heavy rain. Avoid flood-prone areas and consider postponing travel.")
            }
        }
        
        // Analyze wind impact
        if weatherData.windSpeed > 50 {
            severity += 0.5
            recommendations.append("High winds. High-profile vehicles should seek alternate routes.")
        } else if weatherData.windSpeed > 30 {
            severity += 0.3
            recommendations.append("Moderate winds. Exercise caution on bridges and exposed areas.")
        }
        
        // Analyze visibility based on conditions
        if weatherData.condition.lowercased().contains("fog") {
            severity += 0.4
            recommendations.append("Reduced visibility. Use fog lights and reduce speed significantly.")
        }
        
        // Cap severity at 1.0
        severity = min(severity, 1.0)
        
        let description = generateWeatherDescription(severity: severity, weatherData: weatherData)
        
        return WeatherImpact(
            severity: severity,
            description: description,
            recommendations: recommendations
        )
    }
    
    // Store weather data for historical analysis
    func storeWeatherData(_ weatherData: WeatherData, location: Location) async throws {
        var storedData = weatherData
        try await weatherCollection.insertOne(storedData)
    }
    
    // Analyze weather patterns for a location
    func analyzeWeatherPatterns(
        latitude: Double,
        longitude: Double,
        days: Int = 30
    ) async throws -> [WeatherPattern] {
        let historicalData = try await weatherCollection.find([
            "location.latitude": ["$gte": latitude - 0.1, "$lte": latitude + 0.1],
            "location.longitude": ["$gte": longitude - 0.1, "$lte": longitude + 0.1],
            "timestamp": ["$gte": Date().addingTimeInterval(-Double(days) * 86400)]
        ]).toArray()
        
        return try await processHistoricalData(historicalData)
    }
    
    // Get weather risk level for a route
    func getRouteWeatherRisk(
        from startLocation: Location,
        to endLocation: Location
    ) async throws -> Double {
        async let startWeather = weatherTrafficService.getCurrentWeather(
            latitude: startLocation.latitude,
            longitude: startLocation.longitude
        )
        async let endWeather = weatherTrafficService.getCurrentWeather(
            latitude: endLocation.latitude,
            longitude: endLocation.longitude
        )
        
        let (weatherStart, weatherEnd) = try await (startWeather, endWeather)
        
        let startImpact = analyzeWeatherImpact(weatherData: weatherStart)
        let endImpact = analyzeWeatherImpact(weatherData: weatherEnd)
        
        // Return the higher risk level between start and end locations
        return max(startImpact.severity, endImpact.severity)
    }
    
    // Private helper methods
    private func generateWeatherDescription(severity: Double, weatherData: WeatherData) -> String {
        var description = "Current conditions: \(weatherData.condition). "
        
        if severity < 0.2 {
            description += "Weather conditions are favorable for travel."
        } else if severity < 0.4 {
            description += "Minor weather-related travel impacts expected."
        } else if severity < 0.6 {
            description += "Moderate weather-related travel impacts expected."
        } else if severity < 0.8 {
            description += "Significant weather-related travel impacts expected."
        } else {
            description += "Severe weather-related travel impacts expected."
        }
        
        return description
    }
    
    private func processHistoricalData(_ data: [WeatherData]) async throws -> [WeatherPattern] {
        var patterns: [WeatherPattern] = []
        let calendar = Calendar.current
        
        for weatherData in data {
            let components = calendar.dateComponents([.hour, .weekday], from: weatherData.timestamp)
            let season = getSeason(date: weatherData.timestamp)
            
            let pattern = WeatherPattern(
                timeOfDay: components.hour ?? 0,
                dayOfWeek: components.weekday ?? 1,
                season: season,
                temperature: weatherData.temperature,
                precipitation: weatherData.precipitation,
                windSpeed: weatherData.windSpeed,
                visibility: weatherData.visibility,
                confidence: calculatePatternConfidence(weatherData)
            )
            
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func getSeason(date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        switch month {
        case 12, 1, 2: return "winter"
        case 3, 4, 5: return "spring"
        case 6, 7, 8: return "summer"
        case 9, 10, 11: return "fall"
        default: return "unknown"
        }
    }
    
    private func calculatePatternConfidence(_ data: WeatherData) -> Double {
        // Calculate confidence based on data quality and sample size
        // Returns a value between 0 and 1
        return 0.8 // Placeholder implementation
    }
    
    private func calculateWeatherSeverity(_ data: WeatherData, patterns: [WeatherPattern]) -> Double {
        var severity = 0.0
        
        // Temperature extremes
        severity += calculateTemperatureImpact(data.temperature, patterns: patterns)
        
        // Precipitation intensity
        severity += calculatePrecipitationImpact(data.precipitation)
        
        // Wind conditions
        severity += calculateWindImpact(data.windSpeed)
        
        // Visibility conditions
        severity += calculateVisibilityImpact(data.visibility)
        
        return min(max(severity / 4.0, 0.0), 1.0)
    }
    
    private func calculateRiskLevel(_ data: WeatherData, patterns: [WeatherPattern]) -> Double {
        var risk = 0.0
        
        // Historical pattern matching
        risk += calculateHistoricalRisk(data, patterns: patterns)
        
        // Current conditions
        risk += calculateCurrentConditionsRisk(data)
        
        // Trend analysis
        risk += calculateTrendRisk(data)
        
        return min(max(risk / 3.0, 0.0), 1.0)
    }
    
    private func calculateTemperatureImpact(_ temperature: Double, patterns: [WeatherPattern]) -> Double {
        // Implement temperature impact calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculatePrecipitationImpact(_ precipitation: Double) -> Double {
        // Implement precipitation impact calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateWindImpact(_ windSpeed: Double) -> Double {
        // Implement wind impact calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateVisibilityImpact(_ visibility: Double) -> Double {
        // Implement visibility impact calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateHistoricalRisk(_ data: WeatherData, patterns: [WeatherPattern]) -> Double {
        // Implement historical risk calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateCurrentConditionsRisk(_ data: WeatherData) -> Double {
        // Implement current conditions risk calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateTrendRisk(_ data: WeatherData) -> Double {
        // Implement trend risk calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func calculateExpectedDuration(_ forecast: WeatherForecast) -> TimeInterval {
        // Implement expected duration calculation logic
        return 0.0 // Placeholder implementation
    }
    
    private func generateRecommendations(severity: Double, riskLevel: Double) -> [String] {
        // Implement recommendation generation logic
        return [] // Placeholder implementation
    }
}

// Extension to find most frequent element
extension Array where Element: Hashable {
    var mostFrequent: Element? {
        let counts = self.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
} 
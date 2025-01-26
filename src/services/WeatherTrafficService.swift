import Foundation
import Vapor

struct WeatherData: Codable {
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double
    let precipitation: Double
    let forecast: [WeatherForecast]
    let timestamp: Date
}

struct WeatherForecast: Codable {
    let date: Date
    let temperature: Double
    let condition: String
    let precipitation: Double
}

struct TrafficData: Codable {
    let incidents: [TrafficIncident]
    let congestionLevel: Int // 1-10 scale
    let estimatedDelays: [RouteDelay]
    let timestamp: Date
}

struct TrafficIncident: Codable {
    let type: String
    let severity: Int
    let location: Location
    let description: String
    let startTime: Date
    let endTime: Date?
}

struct RouteDelay: Codable {
    let startLocation: Location
    let endLocation: Location
    let duration: Int // in minutes
    let distance: Double // in kilometers
    let congestionLevel: Int
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
}

final class WeatherTrafficService {
    private let weatherApiKey: String
    private let trafficApiKey: String
    private let client: Client
    private let cache: Cache
    
    init(weatherApiKey: String, trafficApiKey: String, client: Client, cache: Cache) {
        self.weatherApiKey = weatherApiKey
        self.trafficApiKey = trafficApiKey
        self.client = client
        self.cache = cache
    }
    
    // Get current weather for location
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let cacheKey = "weather:\(latitude):\(longitude)"
        
        // Check cache first
        if let cached = try? await cache.get(cacheKey, as: WeatherData.self) {
            // Return cached data if less than 30 minutes old
            if Date().timeIntervalSince(cached.timestamp) < 1800 {
                return cached
            }
        }
        
        // Fetch from OpenWeatherMap API
        let url = "https://api.openweathermap.org/data/2.5/weather"
        let response = try await client.get(URI(string: url)) { req in
            try req.query.encode([
                "lat": latitude,
                "lon": longitude,
                "appid": weatherApiKey,
                "units": "metric"
            ])
        }
        
        // Parse response and create WeatherData
        let weatherData = try response.content.decode(WeatherData.self)
        
        // Cache the result
        try await cache.set(cacheKey, to: weatherData, expiresIn: .minutes(30))
        
        return weatherData
    }
    
    // Get weather forecast for next 5 days
    func getWeatherForecast(latitude: Double, longitude: Double) async throws -> [WeatherForecast] {
        let cacheKey = "forecast:\(latitude):\(longitude)"
        
        if let cached = try? await cache.get(cacheKey, as: [WeatherForecast].self) {
            return cached
        }
        
        let url = "https://api.openweathermap.org/data/2.5/forecast"
        let response = try await client.get(URI(string: url)) { req in
            try req.query.encode([
                "lat": latitude,
                "lon": longitude,
                "appid": weatherApiKey,
                "units": "metric"
            ])
        }
        
        let forecast = try response.content.decode([WeatherForecast].self)
        try await cache.set(cacheKey, to: forecast, expiresIn: .hours(3))
        
        return forecast
    }
    
    // Get current traffic conditions
    func getTrafficConditions(latitude: Double, longitude: Double, radius: Double) async throws -> TrafficData {
        let cacheKey = "traffic:\(latitude):\(longitude):\(radius)"
        
        if let cached = try? await cache.get(cacheKey, as: TrafficData.self) {
            // Return cached data if less than 5 minutes old
            if Date().timeIntervalSince(cached.timestamp) < 300 {
                return cached
            }
        }
        
        // Fetch from TomTom Traffic API
        let url = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json"
        let response = try await client.get(URI(string: url)) { req in
            try req.query.encode([
                "point": "\(latitude),\(longitude)",
                "radius": radius,
                "key": trafficApiKey
            ])
        }
        
        let trafficData = try response.content.decode(TrafficData.self)
        try await cache.set(cacheKey, to: trafficData, expiresIn: .minutes(5))
        
        return trafficData
    }
    
    // Get route with traffic information
    func getRouteWithTraffic(
        from startLocation: Location,
        to endLocation: Location
    ) async throws -> RouteDelay {
        let cacheKey = "route:\(startLocation.latitude):\(startLocation.longitude):\(endLocation.latitude):\(endLocation.longitude)"
        
        if let cached = try? await cache.get(cacheKey, as: RouteDelay.self) {
            return cached
        }
        
        // Fetch from TomTom Routing API
        let url = "https://api.tomtom.com/routing/1/calculateRoute/\(startLocation.latitude),\(startLocation.longitude):\(endLocation.latitude),\(endLocation.longitude)/json"
        let response = try await client.get(URI(string: url)) { req in
            try req.query.encode([
                "key": trafficApiKey,
                "traffic": true
            ])
        }
        
        let routeDelay = try response.content.decode(RouteDelay.self)
        try await cache.set(cacheKey, to: routeDelay, expiresIn: .minutes(15))
        
        return routeDelay
    }
    
    // Get weather-adjusted travel time
    func getWeatherAdjustedTravelTime(
        from startLocation: Location,
        to endLocation: Location
    ) async throws -> RouteDelay {
        async let route = getRouteWithTraffic(from: startLocation, to: endLocation)
        async let weather = getCurrentWeather(latitude: startLocation.latitude, longitude: startLocation.longitude)
        
        let (routeData, weatherData) = try await (route, weather)
        
        // Adjust travel time based on weather conditions
        var adjustedDuration = Double(routeData.duration)
        
        // Apply weather-based adjustments
        switch weatherData.condition.lowercased() {
        case let condition where condition.contains("rain"):
            adjustedDuration *= 1.2 // 20% longer in rain
        case let condition where condition.contains("snow"):
            adjustedDuration *= 1.5 // 50% longer in snow
        case let condition where condition.contains("fog"):
            adjustedDuration *= 1.3 // 30% longer in fog
        default:
            break
        }
        
        // Create adjusted route delay
        return RouteDelay(
            startLocation: routeData.startLocation,
            endLocation: routeData.endLocation,
            duration: Int(adjustedDuration),
            distance: routeData.distance,
            congestionLevel: routeData.congestionLevel
        )
    }
    
    // Get severe weather alerts
    func getSevereWeatherAlerts(latitude: Double, longitude: Double) async throws -> [String] {
        let url = "https://api.openweathermap.org/data/2.5/onecall"
        let response = try await client.get(URI(string: url)) { req in
            try req.query.encode([
                "lat": latitude,
                "lon": longitude,
                "appid": weatherApiKey,
                "exclude": "current,minutely,hourly,daily"
            ])
        }
        
        struct AlertResponse: Codable {
            let alerts: [WeatherAlert]?
        }
        
        struct WeatherAlert: Codable {
            let event: String
            let description: String
        }
        
        let alertData = try response.content.decode(AlertResponse.self)
        return alertData.alerts?.map { "\($0.event): \($0.description)" } ?? []
    }
} 
import Foundation
import Vapor

struct TrafficPattern {
    let timeOfDay: Int // hour 0-23
    let dayOfWeek: Int // 1-7
    let averageCongestion: Double // 0-1 scale
    let typicalDuration: Int // in minutes
    let confidence: Double // 0-1 scale
}

struct RouteAnalysis {
    let historicalPatterns: [TrafficPattern]
    let predictedCongestion: Double
    let bestTravelTimes: [Int] // hours of day
    let worstTravelTimes: [Int] // hours of day
    let reliability: Double // 0-1 scale
}

final class TrafficAnalysisService {
    private let database: MongoDatabase
    private let trafficCollection: MongoCollection<TrafficData>
    private let routeCollection: MongoCollection<RouteDelay>
    private let weatherAnalysisService: WeatherAnalysisService
    
    init(database: MongoDatabase, weatherAnalysisService: WeatherAnalysisService) {
        self.database = database
        self.trafficCollection = database.collection("traffic_history", withType: TrafficData.self)
        self.routeCollection = database.collection("route_history", withType: RouteDelay.self)
        self.weatherAnalysisService = weatherAnalysisService
    }
    
    // Store traffic data for historical analysis
    func storeTrafficData(_ trafficData: TrafficData) async throws {
        try await trafficCollection.insertOne(trafficData)
    }
    
    // Store route data for historical analysis
    func storeRouteData(_ routeData: RouteDelay) async throws {
        try await routeCollection.insertOne(routeData)
    }
    
    // Analyze historical traffic patterns for a route
    func analyzeRoutePatterns(
        from startLocation: Location,
        to endLocation: Location,
        days: Int = 30
    ) async throws -> RouteAnalysis {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        // Get historical route data
        let routeData = try await routeCollection.find([
            "timestamp": ["$gte": startDate],
            "startLocation.latitude": ["$gte": startLocation.latitude - 0.1, "$lte": startLocation.latitude + 0.1],
            "startLocation.longitude": ["$gte": startLocation.longitude - 0.1, "$lte": startLocation.longitude + 0.1],
            "endLocation.latitude": ["$gte": endLocation.latitude - 0.1, "$lte": endLocation.latitude + 0.1],
            "endLocation.longitude": ["$gte": endLocation.longitude - 0.1, "$lte": endLocation.longitude + 0.1]
        ]).toArray()
        
        return analyzePatterns(from: routeData)
    }
    
    // Get predicted congestion level for a route
    func predictCongestion(
        from startLocation: Location,
        to endLocation: Location,
        at date: Date
    ) async throws -> Double {
        // Get historical patterns
        let patterns = try await analyzeRoutePatterns(
            from: startLocation,
            to: endLocation
        )
        
        // Get current hour and day
        let hour = Calendar.current.component(.hour, from: date)
        let day = Calendar.current.component(.weekday, from: date)
        
        // Find matching pattern
        if let pattern = patterns.historicalPatterns.first(where: { 
            $0.timeOfDay == hour && $0.dayOfWeek == day 
        }) {
            return pattern.averageCongestion
        }
        
        // If no exact match, return average congestion
        return patterns.historicalPatterns.reduce(0.0) { $0 + $1.averageCongestion } / 
            Double(patterns.historicalPatterns.count)
    }
    
    // Get optimal travel times for a route
    func getOptimalTravelTimes(
        from startLocation: Location,
        to endLocation: Location
    ) async throws -> [Int] {
        let patterns = try await analyzeRoutePatterns(
            from: startLocation,
            to: endLocation
        )
        
        // Sort patterns by congestion and return top 3 hours
        return patterns.historicalPatterns
            .sorted { $0.averageCongestion < $1.averageCongestion }
            .prefix(3)
            .map { $0.timeOfDay }
    }
    
    // Private helper methods
    private func analyzePatterns(from routeData: [RouteDelay]) -> RouteAnalysis {
        var patterns: [TrafficPattern] = []
        var hourlyData: [Int: [RouteDelay]] = [:]
        var dailyData: [Int: [RouteDelay]] = [:]
        
        // Group data by hour and day
        for route in routeData {
            let hour = Calendar.current.component(.hour, from: route.startTime)
            let day = Calendar.current.component(.weekday, from: route.startTime)
            
            hourlyData[hour, default: []].append(route)
            dailyData[day, default: []].append(route)
        }
        
        // Analyze patterns for each time period
        for hour in 0...23 {
            for day in 1...7 {
                let relevantData = routeData.filter {
                    Calendar.current.component(.hour, from: $0.startTime) == hour &&
                    Calendar.current.component(.weekday, from: $0.startTime) == day
                }
                
                if !relevantData.isEmpty {
                    let avgCongestion = Double(relevantData.reduce(0) { $0 + $1.congestionLevel }) / 
                        Double(relevantData.count) / 10.0
                    let avgDuration = relevantData.reduce(0) { $0 + $1.duration } / relevantData.count
                    let confidence = min(Double(relevantData.count) / 30.0, 1.0) // Based on sample size
                    
                    patterns.append(TrafficPattern(
                        timeOfDay: hour,
                        dayOfWeek: day,
                        averageCongestion: avgCongestion,
                        typicalDuration: avgDuration,
                        confidence: confidence
                    ))
                }
            }
        }
        
        // Calculate best and worst travel times
        let sortedByDuration = patterns.sorted { $0.typicalDuration < $1.typicalDuration }
        let bestTimes = Array(sortedByDuration.prefix(3).map { $0.timeOfDay })
        let worstTimes = Array(sortedByDuration.suffix(3).map { $0.timeOfDay })
        
        // Calculate overall reliability
        let reliability = patterns.reduce(0.0) { $0 + $1.confidence } / Double(patterns.count)
        
        return RouteAnalysis(
            historicalPatterns: patterns,
            predictedCongestion: calculateAverageCongestion(patterns),
            bestTravelTimes: bestTimes,
            worstTravelTimes: worstTimes,
            reliability: reliability
        )
    }
    
    private func calculateAverageCongestion(_ patterns: [TrafficPattern]) -> Double {
        let weightedSum = patterns.reduce(0.0) { $0 + ($1.averageCongestion * $1.confidence) }
        let totalWeight = patterns.reduce(0.0) { $0 + $1.confidence }
        return weightedSum / totalWeight
    }
} 
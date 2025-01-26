import Foundation
import Vapor

struct LocationRequest: Content {
    let latitude: Double
    let longitude: Double
    let radius: Double?
}

struct RouteRequest: Content {
    let startLocation: Location
    let endLocation: Location
}

final class WeatherTrafficController {
    private let weatherTrafficService: WeatherTrafficService
    
    init(weatherTrafficService: WeatherTrafficService) {
        self.weatherTrafficService = weatherTrafficService
    }
    
    func configureRoutes(_ app: Application) throws {
        let weatherTraffic = app.grouped("api", "weather-traffic")
        
        // Get current weather
        weatherTraffic.post("weather") { req -> WeatherData in
            let locationRequest = try req.content.decode(LocationRequest.self)
            return try await self.weatherTrafficService.getCurrentWeather(
                latitude: locationRequest.latitude,
                longitude: locationRequest.longitude
            )
        }
        
        // Get weather forecast
        weatherTraffic.post("forecast") { req -> [WeatherForecast] in
            let locationRequest = try req.content.decode(LocationRequest.self)
            return try await self.weatherTrafficService.getWeatherForecast(
                latitude: locationRequest.latitude,
                longitude: locationRequest.longitude
            )
        }
        
        // Get traffic conditions
        weatherTraffic.post("traffic") { req -> TrafficData in
            let locationRequest = try req.content.decode(LocationRequest.self)
            return try await self.weatherTrafficService.getTrafficConditions(
                latitude: locationRequest.latitude,
                longitude: locationRequest.longitude,
                radius: locationRequest.radius ?? 5.0
            )
        }
        
        // Get route with traffic
        weatherTraffic.post("route") { req -> RouteDelay in
            let routeRequest = try req.content.decode(RouteRequest.self)
            return try await self.weatherTrafficService.getRouteWithTraffic(
                from: routeRequest.startLocation,
                to: routeRequest.endLocation
            )
        }
        
        // Get weather-adjusted travel time
        weatherTraffic.post("route", "weather-adjusted") { req -> RouteDelay in
            let routeRequest = try req.content.decode(RouteRequest.self)
            return try await self.weatherTrafficService.getWeatherAdjustedTravelTime(
                from: routeRequest.startLocation,
                to: routeRequest.endLocation
            )
        }
        
        // Get severe weather alerts
        weatherTraffic.post("alerts") { req -> [String] in
            let locationRequest = try req.content.decode(LocationRequest.self)
            return try await self.weatherTrafficService.getSevereWeatherAlerts(
                latitude: locationRequest.latitude,
                longitude: locationRequest.longitude
            )
        }
    }
} 
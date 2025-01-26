import Foundation

enum MapsProvider: String, CaseIterable {
    case appleMaps
    case googleMaps
    case mapbox
    case openStreetMap
    
    var description: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .googleMaps: return "Google Maps"
        case .mapbox: return "Mapbox"
        case .openStreetMap: return "OpenStreetMap"
        }
    }
    
    var configKey: String {
        switch self {
        case .googleMaps: return "googleMaps"
        case .mapbox: return "mapbox"
        case .appleMaps, .openStreetMap: return ""
        }
    }
}

enum WeatherProvider: String, CaseIterable {
    case weatherKit
    case openWeather
    case weatherAPI
    case tomorrow
    
    var description: String {
        switch self {
        case .weatherKit: return "WeatherKit"
        case .openWeather: return "OpenWeather"
        case .weatherAPI: return "WeatherAPI"
        case .tomorrow: return "Tomorrow.io"
        }
    }
    
    var configKey: String {
        switch self {
        case .openWeather: return "openWeather"
        case .weatherAPI: return "weatherAPI"
        case .tomorrow: return "tomorrow"
        case .weatherKit: return ""
        }
    }
} 
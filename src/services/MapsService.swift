import Foundation
import Vapor

struct Location: Content {
    let latitude: Double
    let longitude: Double
    let address: String?
}

struct Route: Content {
    let origin: Location
    let destination: Location
    let waypoints: [Location]
    let distance: Double // in meters
    let duration: Double // in seconds
    let polyline: String
    let steps: [RouteStep]
}

struct RouteStep: Content {
    let instruction: String
    let distance: Double
    let duration: Double
    let startLocation: Location
    let endLocation: Location
}

final class MapsService {
    private let configService: AIConfigurationService
    private var googleMapsClient: GoogleMapsClient?
    private var tomTomClient: TomTomClient?
    
    init(configService: AIConfigurationService) {
        self.configService = configService
        setupClients()
    }
    
    private func setupClients() {
        let config = configService.getCurrentConfiguration()
        
        switch config.mapsProvider {
        case .googleMaps:
            googleMapsClient = GoogleMapsClient(apiKey: config.apiKeys["google_maps"] ?? "")
        case .tomTom:
            tomTomClient = TomTomClient(apiKey: config.apiKeys["tomtom"] ?? "")
        }
    }
    
    func geocode(address: String) async throws -> Location {
        let config = configService.getCurrentConfiguration()
        
        switch config.mapsProvider {
        case .googleMaps:
            guard let client = googleMapsClient else {
                throw Abort(.internalServerError, reason: "Google Maps client not configured")
            }
            return try await client.geocode(address: address)
            
        case .tomTom:
            guard let client = tomTomClient else {
                throw Abort(.internalServerError, reason: "TomTom client not configured")
            }
            return try await client.geocode(address: address)
        }
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> Location {
        let config = configService.getCurrentConfiguration()
        
        switch config.mapsProvider {
        case .googleMaps:
            guard let client = googleMapsClient else {
                throw Abort(.internalServerError, reason: "Google Maps client not configured")
            }
            return try await client.reverseGeocode(latitude: latitude, longitude: longitude)
            
        case .tomTom:
            guard let client = tomTomClient else {
                throw Abort(.internalServerError, reason: "TomTom client not configured")
            }
            return try await client.reverseGeocode(latitude: latitude, longitude: longitude)
        }
    }
    
    func getRoute(origin: Location, destination: Location, waypoints: [Location] = []) async throws -> Route {
        let config = configService.getCurrentConfiguration()
        
        switch config.mapsProvider {
        case .googleMaps:
            guard let client = googleMapsClient else {
                throw Abort(.internalServerError, reason: "Google Maps client not configured")
            }
            return try await client.getRoute(origin: origin, destination: destination, waypoints: waypoints)
            
        case .tomTom:
            guard let client = tomTomClient else {
                throw Abort(.internalServerError, reason: "TomTom client not configured")
            }
            return try await client.getRoute(origin: origin, destination: destination, waypoints: waypoints)
        }
    }
    
    func updateConfiguration() {
        setupClients()
    }
}

// Protocol for Maps clients
protocol MapsClient {
    func geocode(address: String) async throws -> Location
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> Location
    func getRoute(origin: Location, destination: Location, waypoints: [Location]) async throws -> Route
}

// Google Maps client implementation
final class GoogleMapsClient: MapsClient {
    private let apiKey: String
    private let baseURL = "https://maps.googleapis.com/maps/api"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func geocode(address: String) async throws -> Location {
        guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/geocode/json?address=\(encodedAddress)&key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }
        
        let response: GoogleGeocodingResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        guard let result = response.results.first,
              let location = result.geometry.location else {
            throw NetworkError.invalidResponse
        }
        
        return Location(
            latitude: location.lat,
            longitude: location.lng,
            address: result.formattedAddress
        )
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> Location {
        guard let url = URL(string: "\(baseURL)/geocode/json?latlng=\(latitude),\(longitude)&key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }
        
        let response: GoogleGeocodingResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        guard let result = response.results.first,
              let location = result.geometry.location else {
            throw NetworkError.invalidResponse
        }
        
        return Location(
            latitude: location.lat,
            longitude: location.lng,
            address: result.formattedAddress
        )
    }
    
    func getRoute(origin: Location, destination: Location, waypoints: [Location] = []) async throws -> Route {
        var urlComponents = URLComponents(string: "\(baseURL)/directions/json")
        
        let waypointString = waypoints.isEmpty ? "" : "&waypoints=" + waypoints.map {
            "\($0.latitude),\($0.longitude)"
        }.joined(separator: "|")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "alternatives", value: "true")
        ]
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        let response: GoogleDirectionsResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        guard let route = response.routes.first,
              let leg = route.legs.first else {
            throw NetworkError.invalidResponse
        }
        
        let steps = leg.steps.map { step in
            RouteStep(
                instruction: step.htmlInstructions.stripHTML(),
                distance: step.distance.value,
                duration: Double(step.duration.value),
                startLocation: Location(
                    latitude: step.startLocation.lat,
                    longitude: step.startLocation.lng,
                    address: nil
                ),
                endLocation: Location(
                    latitude: step.endLocation.lat,
                    longitude: step.endLocation.lng,
                    address: nil
                )
            )
        }
        
        return Route(
            origin: origin,
            destination: destination,
            waypoints: waypoints,
            distance: leg.distance.value,
            duration: Double(leg.duration.value),
            polyline: route.overviewPolyline.points,
            steps: steps
        )
    }
    
    // Generate route visualization
    func generateRouteVisualization(route: Route) -> VisualizationData {
        // Decode polyline to coordinates
        let coordinates = decodePolyline(route.polyline)
        
        // Calculate bounds
        let bounds = calculateBounds(coordinates: coordinates)
        
        // Generate SVG map
        let svg = generateRouteMap(
            coordinates: coordinates,
            bounds: bounds,
            width: 800,
            height: 600
        )
        
        return VisualizationData(
            id: UUID().uuidString,
            type: "route_map",
            svgContent: svg,
            title: "Route Map",
            description: "Route visualization with waypoints",
            timestamp: Date(),
            interactiveElements: createRouteInteractiveElements(route: route),
            rawData: [
                "coordinates": coordinates.flatMap { [$0.latitude, $0.longitude] }
            ]
        )
    }
    
    private func decodePolyline(_ encoded: String) -> [(latitude: Double, longitude: Double)] {
        var coordinates: [(latitude: Double, longitude: Double)] = []
        var index = 0
        var lat = 0.0
        var lng = 0.0
        
        while index < encoded.count {
            var shift = 0
            var result = 0
            
            // Decode latitude
            repeat {
                let char = encoded[encoded.index(encoded.startIndex, offsetBy: index)]
                index += 1
                result |= (Int(char.asciiValue!) - 63) << shift
                shift += 5
            } while result & 0x1F != 0
            
            lat += Double((result >> 1) * (result & 1 != 0 ? -1 : 1)) / 100000.0
            
            // Decode longitude
            shift = 0
            result = 0
            
            repeat {
                let char = encoded[encoded.index(encoded.startIndex, offsetBy: index)]
                index += 1
                result |= (Int(char.asciiValue!) - 63) << shift
                shift += 5
            } while result & 0x1F != 0
            
            lng += Double((result >> 1) * (result & 1 != 0 ? -1 : 1)) / 100000.0
            
            coordinates.append((latitude: lat, longitude: lng))
        }
        
        return coordinates
    }
    
    private func calculateBounds(coordinates: [(latitude: Double, longitude: Double)]) -> (
        minLat: Double, maxLat: Double, minLng: Double, maxLng: Double
    ) {
        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        
        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLng: lngs.min() ?? 0,
            maxLng: lngs.max() ?? 0
        )
    }
    
    private func generateRouteMap(
        coordinates: [(latitude: Double, longitude: Double)],
        bounds: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double),
        width: Int,
        height: Int
    ) -> String {
        let padding = 40
        let mapWidth = width - 2 * padding
        let mapHeight = height - 2 * padding
        
        // Project coordinates to pixels
        let points = coordinates.map { coord -> (x: Int, y: Int) in
            let x = padding + Int(
                (coord.longitude - bounds.minLng) * Double(mapWidth) /
                (bounds.maxLng - bounds.minLng)
            )
            let y = height - padding - Int(
                (coord.latitude - bounds.minLat) * Double(mapHeight) /
                (bounds.maxLat - bounds.minLat)
            )
            return (x: x, y: y)
        }
        
        // Generate SVG path
        let pathData = points.enumerated().map { index, point in
            index == 0 ? "M \(point.x),\(point.y)" : "L \(point.x),\(point.y)"
        }.joined(separator: " ")
        
        return """
        <svg width="\(width)" height="\(height)" xmlns="http://www.w3.org/2000/svg">
            <style>
                .route-path { fill: none; stroke: #4285f4; stroke-width: 3; }
                .waypoint { fill: #ea4335; }
                .start-point { fill: #34a853; }
                .end-point { fill: #fbbc05; }
            </style>
            <!-- Route path -->
            <path d="\(pathData)" class="route-path"/>
            <!-- Start point -->
            <circle cx="\(points.first?.x ?? 0)" cy="\(points.first?.y ?? 0)" r="6" class="start-point"/>
            <!-- End point -->
            <circle cx="\(points.last?.x ?? 0)" cy="\(points.last?.y ?? 0)" r="6" class="end-point"/>
        </svg>
        """
    }
    
    private func createRouteInteractiveElements(route: Route) -> [InteractiveElement] {
        var elements: [InteractiveElement] = []
        
        // Add interactive elements for each step
        for (index, step) in route.steps.enumerated() {
            elements.append(
                InteractiveElement(
                    elementId: "route_step_\(index)",
                    type: .hoverable,
                    data: [
                        "instruction": step.instruction,
                        "distance": String(format: "%.1f km", step.distance / 1000),
                        "duration": String(format: "%.0f min", step.duration / 60)
                    ]
                )
            )
        }
        
        return elements
    }
}

// Google Maps API response models
private struct GoogleGeocodingResponse: Codable {
    let results: [GeocodingResult]
    let status: String
    
    struct GeocodingResult: Codable {
        let formattedAddress: String
        let geometry: Geometry
        
        enum CodingKeys: String, CodingKey {
            case formattedAddress = "formatted_address"
            case geometry
        }
    }
    
    struct Geometry: Codable {
        let location: LatLng?
    }
    
    struct LatLng: Codable {
        let lat: Double
        let lng: Double
    }
}

private struct GoogleDirectionsResponse: Codable {
    let routes: [DirectionsRoute]
    let status: String
    
    struct DirectionsRoute: Codable {
        let legs: [RouteLeg]
        let overviewPolyline: Polyline
        
        enum CodingKeys: String, CodingKey {
            case legs
            case overviewPolyline = "overview_polyline"
        }
    }
    
    struct RouteLeg: Codable {
        let steps: [RouteStep]
        let distance: TextValue
        let duration: TextValue
    }
    
    struct RouteStep: Codable {
        let htmlInstructions: String
        let distance: TextValue
        let duration: TextValue
        let startLocation: LatLng
        let endLocation: LatLng
        
        enum CodingKeys: String, CodingKey {
            case htmlInstructions = "html_instructions"
            case distance
            case duration
            case startLocation = "start_location"
            case endLocation = "end_location"
        }
    }
    
    struct TextValue: Codable {
        let text: String
        let value: Double
    }
    
    struct Polyline: Codable {
        let points: String
    }
    
    struct LatLng: Codable {
        let lat: Double
        let lng: Double
    }
}

private extension String {
    func stripHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// TomTom client implementation
final class TomTomClient: MapsClient {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func geocode(address: String) async throws -> Location {
        // Implement TomTom geocoding API call
        return Location(latitude: 0, longitude: 0, address: nil)
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> Location {
        // Implement TomTom reverse geocoding API call
        return Location(latitude: latitude, longitude: longitude, address: nil)
    }
    
    func getRoute(origin: Location, destination: Location, waypoints: [Location]) async throws -> Route {
        // Implement TomTom routing API call
        return Route(origin: origin, destination: destination, waypoints: waypoints,
                    distance: 0, duration: 0, polyline: "", steps: [])
    }
} 
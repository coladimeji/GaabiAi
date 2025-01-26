import Foundation
import CoreLocation
import SwiftUI
import MapKit

actor GoogleMapsClient {
    private let settingsViewModel: SettingsViewModel
    private let networkUtility = NetworkUtility.shared
    private let cache = CacheUtility.shared
    
    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
    }
    
    func getDirections(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> DirectionsResponse {
        let apiKey = settingsViewModel.getAPIKey(for: "GOOGLE_MAPS_API_KEY")
        guard !apiKey.isEmpty else {
            throw NetworkError.missingAPIKey
        }
        
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin.latitude),\(origin.longitude)&destination=\(destination.latitude),\(destination.longitude)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let cacheKey = "directions_\(origin.latitude)_\(origin.longitude)_\(destination.latitude)_\(destination.longitude)"
        if let cachedResponse: DirectionsResponse = await cache.get(key: cacheKey) {
            return cachedResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await networkUtility.performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let directionsResponse = try decoder.decode(DirectionsResponse.self, from: data)
            await cache.set(key: cacheKey, value: directionsResponse, expirationInterval: 3600) // Cache for 1 hour
            return directionsResponse
        case 401:
            throw NetworkError.unauthorized
        case 429:
            throw NetworkError.rateLimitExceeded
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
    
    func generateRouteVisualization(route: Route) -> some View {
        MapView(route: route)
    }
}

// MARK: - Data Models
struct DirectionsResponse: Codable {
    let routes: [Route]
    let status: String
}

struct Route: Codable {
    let overviewPolyline: Polyline
    let legs: [Leg]
    let summary: String
}

struct Leg: Codable {
    let distance: TextValue
    let duration: TextValue
    let startAddress: String
    let endAddress: String
    let steps: [Step]
}

struct Step: Codable {
    let distance: TextValue
    let duration: TextValue
    let htmlInstructions: String
    let polyline: Polyline
}

struct TextValue: Codable {
    let text: String
    let value: Int
}

struct Polyline: Codable {
    let points: String
}

// MARK: - Map View
struct MapView: View {
    let route: Route
    @State private var region: MKCoordinateRegion
    @State private var polylineCoordinates: [CLLocationCoordinate2D] = []
    
    init(route: Route) {
        self.route = route
        let coordinates = decodePolyline(route.overviewPolyline.points)
        self._region = State(initialValue: MKCoordinateRegion(
            center: coordinates[coordinates.count/2],
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        ))
        self.polylineCoordinates = coordinates
    }
    
    var body: some View {
        VStack {
            Map(coordinateRegion: $region) {
                MapPolyline(coordinates: polylineCoordinates)
                    .stroke(.blue, lineWidth: 3)
            }
            .frame(height: 300)
            
            List(route.legs[0].steps, id: \.htmlInstructions) { step in
                VStack(alignment: .leading) {
                    Text(step.htmlInstructions.stripHTML())
                        .padding(.vertical, 4)
                    Text("\(step.distance.text) - \(step.duration.text)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Helper Functions
private func decodePolyline(_ polyline: String) -> [CLLocationCoordinate2D] {
    var coordinates: [CLLocationCoordinate2D] = []
    var index = polyline.startIndex
    var lat = 0.0
    var lng = 0.0
    
    while index < polyline.endIndex {
        var shift = 0
        var result = 0
        
        // Decode latitude
        repeat {
            let byte = Int(polyline[index].asciiValue! - 63) - 1
            result |= (byte & 0x1F) << shift
            shift += 5
            index = polyline.index(after: index)
        } while index < polyline.endIndex && polyline[index].asciiValue! >= 63
        
        lat += Double((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
        
        shift = 0
        result = 0
        
        // Decode longitude
        repeat {
            let byte = Int(polyline[index].asciiValue! - 63) - 1
            result |= (byte & 0x1F) << shift
            shift += 5
            index = polyline.index(after: index)
        } while index < polyline.endIndex && polyline[index].asciiValue! >= 63
        
        lng += Double((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
        
        coordinates.append(CLLocationCoordinate2D(
            latitude: lat * 1e-5,
            longitude: lng * 1e-5
        ))
    }
    
    return coordinates
}

extension String {
    func stripHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
} 
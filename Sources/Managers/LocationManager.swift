import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastKnownAddress: String = ""
    @Published var trafficInfo: [String: Any] = [:]
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        // Reverse geocode the location to get the address
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first else { return }
            
            let address = [
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode,
                placemark.country
            ].compactMap { $0 }.joined(separator: ", ")
            
            DispatchQueue.main.async {
                self.lastKnownAddress = address
            }
        }
        
        // Update traffic info
        updateTrafficInfo(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - Traffic Info
    
    private func updateTrafficInfo(for location: CLLocation) {
        // Here you would typically make an API call to a traffic service
        // For now, we'll just simulate some traffic data
        let simulatedTrafficInfo: [String: Any] = [
            "congestionLevel": "moderate",
            "averageSpeed": 35,
            "incidents": [
                ["type": "construction", "description": "Road work ahead"],
                ["type": "accident", "description": "Minor collision"]
            ]
        ]
        
        DispatchQueue.main.async {
            self.trafficInfo = simulatedTrafficInfo
        }
    }
    
    func getAlternativeRoutes(to destination: CLLocation, completion: @escaping ([[CLLocation]]) -> Void) {
        guard let currentLocation = location else {
            completion([])
            return
        }
        
        // Here you would typically make an API call to a routing service
        // For now, we'll just simulate some routes
        let simulatedRoutes = [
            [currentLocation, destination],
            [currentLocation, 
             CLLocation(latitude: currentLocation.coordinate.latitude + 0.01, 
                       longitude: currentLocation.coordinate.longitude + 0.01),
             destination]
        ]
        
        completion(simulatedRoutes)
    }
} 
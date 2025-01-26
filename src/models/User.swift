import Foundation
import MongoDBVapor
import Vapor

final class User: Content {
    var _id: BSONObjectID?
    var email: String
    var passwordHash: String
    var firstName: String
    var lastName: String
    var createdAt: Date
    var updatedAt: Date
    var settings: UserSettings
    
    init(id: BSONObjectID? = nil,
         email: String,
         passwordHash: String,
         firstName: String,
         lastName: String,
         settings: UserSettings = UserSettings(),
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self._id = id
        self.email = email
        self.passwordHash = passwordHash
        self.firstName = firstName
        self.lastName = lastName
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct UserSettings: Content {
    var defaultWorkLocation: Location?
    var defaultHomeLocation: Location?
    var notificationsEnabled: Bool
    var weatherAlerts: Bool
    var trafficAlerts: Bool
    
    init(defaultWorkLocation: Location? = nil,
         defaultHomeLocation: Location? = nil,
         notificationsEnabled: Bool = true,
         weatherAlerts: Bool = true,
         trafficAlerts: Bool = true) {
        self.defaultWorkLocation = defaultWorkLocation
        self.defaultHomeLocation = defaultHomeLocation
        self.notificationsEnabled = notificationsEnabled
        self.weatherAlerts = weatherAlerts
        self.trafficAlerts = trafficAlerts
    }
}

struct Location: Content {
    var latitude: Double
    var longitude: Double
    var address: String
    var name: String
    
    init(latitude: Double,
         longitude: Double,
         address: String,
         name: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.name = name
    }
} 
import Foundation

struct SmartDevice: Identifiable, Codable {
    var id: String
    var name: String
    var type: DeviceType
    var connectionType: ConnectionType
    var isConnected: Bool
    var schedule: [Schedule]?
    var customSettings: [String: String]?
    
    enum DeviceType: Codable {
        case light
        case thermostat
        case lock
        case camera
        case speaker
        case custom(String)
        
        private enum CodingKeys: String, CodingKey {
            case type
            case customValue
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .light, .thermostat, .lock, .camera, .speaker:
                try container.encode(String(describing: self), forKey: .type)
            case .custom(let value):
                try container.encode("custom", forKey: .type)
                try container.encode(value, forKey: .customValue)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "light": self = .light
            case "thermostat": self = .thermostat
            case "lock": self = .lock
            case "camera": self = .camera
            case "speaker": self = .speaker
            case "custom":
                let value = try container.decode(String.self, forKey: .customValue)
                self = .custom(value)
            default:
                self = .custom("Unknown")
            }
        }
    }
    
    enum ConnectionType: String, Codable {
        case wifi
        case bluetooth
        case zigbee
        case zwave
    }
    
    struct Schedule: Codable {
        var id: UUID
        var time: Date
        var action: String
        var isEnabled: Bool
        
        init(id: UUID = UUID(), time: Date, action: String, isEnabled: Bool = true) {
            self.id = id
            self.time = time
            self.action = action
            self.isEnabled = isEnabled
        }
    }
    
    init(id: String,
         name: String,
         type: DeviceType,
         connectionType: ConnectionType,
         isConnected: Bool = false,
         schedule: [Schedule]? = nil,
         customSettings: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.connectionType = connectionType
        self.isConnected = isConnected
        self.schedule = schedule
        self.customSettings = customSettings
    }
}

enum DeviceType: String, Codable {
    case light
    case thermostat
    case lock
    case camera
    case speaker
    case tv
    case custom(String)
    
    var description: String {
        switch self {
        case .custom(let name): return name
        default: return rawValue.capitalized
        }
    }
}

enum ConnectionType: String, Codable {
    case bluetooth
    case wifi
    case zigbee
    case zwave
}

struct DeviceSchedule: Codable {
    var time: Date
    var action: DeviceAction
    var isEnabled: Bool
}

enum DeviceAction: String, Codable {
    case turnOn
    case turnOff
    case adjust(value: Double)
} 
import Foundation
import SwiftUI

@MainActor
class SmartHomeManager: ObservableObject {
    @Published var devices: [SmartDevice] = []
    @Published var rooms: [Room] = []
    @Published var scenes: [Scene] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init() {
        loadDemoData()
    }
    
    func loadDemoData() {
        // Demo rooms
        rooms = [
            Room(id: UUID(), name: "Living Room", type: .living),
            Room(id: UUID(), name: "Bedroom", type: .bedroom),
            Room(id: UUID(), name: "Kitchen", type: .kitchen),
            Room(id: UUID(), name: "Office", type: .office)
        ]
        
        // Demo devices
        devices = [
            SmartDevice(id: UUID(), name: "Main Light", type: .light, roomId: rooms[0].id, isOn: true, brightness: 80),
            SmartDevice(id: UUID(), name: "TV", type: .tv, roomId: rooms[0].id, isOn: false),
            SmartDevice(id: UUID(), name: "AC", type: .thermostat, roomId: rooms[0].id, isOn: true, temperature: 22),
            SmartDevice(id: UUID(), name: "Bedroom Light", type: .light, roomId: rooms[1].id, isOn: false, brightness: 50),
            SmartDevice(id: UUID(), name: "Kitchen Light", type: .light, roomId: rooms[2].id, isOn: false),
            SmartDevice(id: UUID(), name: "Coffee Maker", type: .outlet, roomId: rooms[2].id, isOn: false),
            SmartDevice(id: UUID(), name: "Office Light", type: .light, roomId: rooms[3].id, isOn: false),
            SmartDevice(id: UUID(), name: "Monitor", type: .outlet, roomId: rooms[3].id, isOn: true)
        ]
        
        // Demo scenes
        scenes = [
            Scene(id: UUID(), name: "Movie Night", icon: "film", actions: [
                .init(deviceId: devices[0].id, state: .init(isOn: true, brightness: 20)),
                .init(deviceId: devices[1].id, state: .init(isOn: true))
            ]),
            Scene(id: UUID(), name: "Good Morning", icon: "sun.rise.fill", actions: [
                .init(deviceId: devices[0].id, state: .init(isOn: true, brightness: 100)),
                .init(deviceId: devices[5].id, state: .init(isOn: true))
            ]),
            Scene(id: UUID(), name: "Good Night", icon: "moon.stars.fill", actions: [
                .init(deviceId: devices[0].id, state: .init(isOn: false)),
                .init(deviceId: devices[1].id, state: .init(isOn: false)),
                .init(deviceId: devices[2].id, state: .init(isOn: true, temperature: 20))
            ])
        ]
    }
    
    func toggleDevice(_ device: SmartDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].isOn.toggle()
        }
    }
    
    func updateDevice(_ device: SmartDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        }
    }
    
    func activateScene(_ scene: Scene) {
        for action in scene.actions {
            if let deviceIndex = devices.firstIndex(where: { $0.id == action.deviceId }) {
                devices[deviceIndex].applyState(action.state)
            }
        }
    }
    
    func devicesInRoom(_ roomId: UUID) -> [SmartDevice] {
        devices.filter { $0.roomId == roomId }
    }
}

// MARK: - Supporting Types
struct Room: Identifiable {
    let id: UUID
    let name: String
    let type: RoomType
    
    enum RoomType: String {
        case living = "Living Room"
        case bedroom = "Bedroom"
        case kitchen = "Kitchen"
        case office = "Office"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .living: return "sofa.fill"
            case .bedroom: return "bed.double.fill"
            case .kitchen: return "refrigerator.fill"
            case .office: return "desktopcomputer"
            case .other: return "house.fill"
            }
        }
    }
}

struct SmartDevice: Identifiable {
    let id: UUID
    let name: String
    let type: DeviceType
    let roomId: UUID
    var isOn: Bool
    var brightness: Int?
    var temperature: Int?
    
    enum DeviceType: String {
        case light = "Light"
        case outlet = "Outlet"
        case thermostat = "Thermostat"
        case tv = "TV"
        
        var icon: String {
            switch self {
            case .light: return "lightbulb.fill"
            case .outlet: return "poweroutlet.type.b.fill"
            case .thermostat: return "thermometer"
            case .tv: return "tv.fill"
            }
        }
    }
    
    mutating func applyState(_ state: DeviceState) {
        isOn = state.isOn
        if let brightness = state.brightness {
            self.brightness = brightness
        }
        if let temperature = state.temperature {
            self.temperature = temperature
        }
    }
}

struct Scene: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let actions: [SceneAction]
    
    struct SceneAction {
        let deviceId: UUID
        let state: DeviceState
    }
}

struct DeviceState {
    let isOn: Bool
    var brightness: Int?
    var temperature: Int?
} 
import SwiftUI

struct SmartHomeView: View {
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    @State private var selectedRoom: Room?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Scenes
                    ScenesSection(scenes: smartHomeManager.scenes)
                    
                    // Rooms Grid
                    RoomsGrid(rooms: smartHomeManager.rooms,
                             selectedRoom: $selectedRoom)
                    
                    // Devices in Selected Room or All Devices
                    DevicesSection(devices: selectedRoom.map { smartHomeManager.devicesInRoom($0.id) } ?? smartHomeManager.devices,
                                 roomName: selectedRoom?.name ?? "All Devices")
                }
                .padding()
            }
            .navigationTitle("Smart Home")
        }
    }
}

struct ScenesSection: View {
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    let scenes: [Scene]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Scenes")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(scenes) { scene in
                        Button(action: { smartHomeManager.activateScene(scene) }) {
                            VStack {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 30))
                                Text(scene.name)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct RoomsGrid: View {
    let rooms: [Room]
    @Binding var selectedRoom: Room?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Rooms")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(rooms) { room in
                    Button(action: { selectedRoom = selectedRoom == room ? nil : room }) {
                        VStack {
                            Image(systemName: room.type.icon)
                                .font(.system(size: 30))
                            Text(room.name)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(selectedRoom == room ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DevicesSection: View {
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    let devices: [SmartDevice]
    let roomName: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(roomName)
                .font(.headline)
            
            ForEach(devices) { device in
                DeviceRow(device: device)
            }
        }
    }
}

struct DeviceRow: View {
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    let device: SmartDevice
    @State private var isShowingDetails = false
    
    var body: some View {
        Button(action: { isShowingDetails = true }) {
            HStack {
                Image(systemName: device.type.icon)
                    .foregroundColor(device.isOn ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    Text(device.name)
                    if let brightness = device.brightness {
                        Text("Brightness: \(brightness)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let temperature = device.temperature {
                        Text("Temperature: \(temperature)°C")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { device.isOn },
                    set: { _ in smartHomeManager.toggleDevice(device) }
                ))
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingDetails) {
            DeviceDetailView(device: device)
        }
    }
}

struct DeviceDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    let device: SmartDevice
    @State private var updatedDevice: SmartDevice
    
    init(device: SmartDevice) {
        self.device = device
        _updatedDevice = State(initialValue: device)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Power", isOn: $updatedDevice.isOn)
                    
                    if device.type == .light {
                        VStack {
                            Text("Brightness: \(updatedDevice.brightness ?? 0)%")
                            Slider(value: Binding(
                                get: { Double(updatedDevice.brightness ?? 0) },
                                set: { updatedDevice.brightness = Int($0) }
                            ), in: 0...100)
                        }
                    }
                    
                    if device.type == .thermostat {
                        Stepper("Temperature: \(updatedDevice.temperature ?? 20)°C",
                               value: Binding(
                                get: { Double(updatedDevice.temperature ?? 20) },
                                set: { updatedDevice.temperature = Int($0) }
                               ),
                               in: 16...30)
                    }
                }
            }
            .navigationTitle(device.name)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    smartHomeManager.updateDevice(updatedDevice)
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    SmartHomeView()
        .environmentObject(SmartHomeManager())
} 
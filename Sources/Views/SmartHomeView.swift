import SwiftUI
import CoreBluetooth

struct SmartHomeView: View {
    @EnvironmentObject var smartHomeManager: SmartHomeManager
    @State private var selectedRoom: Room?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScenesSection(smartHomeManager: smartHomeManager)
                
                RoomsGrid(selectedRoom: $selectedRoom, smartHomeManager: smartHomeManager)
                
                DevicesSection(
                    devices: selectedRoom == nil ? smartHomeManager.devices : smartHomeManager.devices.filter { $0.room == selectedRoom },
                    smartHomeManager: smartHomeManager
                )
            }
            .padding()
        }
        .navigationTitle("Smart Home")
    }
}

struct ScenesSection: View {
    let smartHomeManager: SmartHomeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenes")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(smartHomeManager.scenes) { scene in
                        SceneButton(scene: scene) {
                            smartHomeManager.activateScene(scene)
                        }
                    }
                }
            }
        }
    }
}

struct SceneButton: View {
    let scene: Scene
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scene.icon)
                    .font(.title2)
                Text(scene.name)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct RoomsGrid: View {
    @Binding var selectedRoom: Room?
    let smartHomeManager: SmartHomeManager
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rooms")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(smartHomeManager.rooms) { room in
                    RoomButton(
                        room: room,
                        isSelected: selectedRoom == room,
                        deviceCount: smartHomeManager.devices.filter { $0.room == room }.count
                    ) {
                        if selectedRoom == room {
                            selectedRoom = nil
                        } else {
                            selectedRoom = room
                        }
                    }
                }
            }
        }
    }
}

struct RoomButton: View {
    let room: Room
    let isSelected: Bool
    let deviceCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: room.icon)
                    .font(.title2)
                Text(room.name)
                    .font(.caption)
                Text("\(deviceCount) devices")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct DevicesSection: View {
    let devices: [SmartDevice]
    let smartHomeManager: SmartHomeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.headline)
            
            ForEach(devices) { device in
                DeviceRow(device: device, smartHomeManager: smartHomeManager)
            }
        }
    }
}

struct DeviceRow: View {
    let device: SmartDevice
    let smartHomeManager: SmartHomeManager
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack {
                Image(systemName: device.icon)
                    .font(.title2)
                    .foregroundColor(device.isOn ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.room.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if device.type == .light || device.type == .thermostat {
                    Text(device.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("", isOn: Binding(
                    get: { device.isOn },
                    set: { smartHomeManager.toggleDevice(device, isOn: $0) }
                ))
                .labelsHidden()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            DeviceDetailView(device: device, smartHomeManager: smartHomeManager)
        }
    }
}

struct DeviceDetailView: View {
    let device: SmartDevice
    let smartHomeManager: SmartHomeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: device.icon)
                            .font(.title)
                            .foregroundColor(device.isOn ? .blue : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.headline)
                            Text(device.room.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Power") {
                    Toggle("Power", isOn: Binding(
                        get: { device.isOn },
                        set: { smartHomeManager.toggleDevice(device, isOn: $0) }
                    ))
                }
                
                if device.type == .light {
                    Section("Brightness") {
                        Slider(
                            value: Binding(
                                get: { Double(device.brightness ?? 0) },
                                set: { smartHomeManager.updateDevice(device, brightness: Int($0)) }
                            ),
                            in: 0...100,
                            step: 1
                        ) {
                            Text("Brightness")
                        } minimumValueLabel: {
                            Image(systemName: "sun.min")
                        } maximumValueLabel: {
                            Image(systemName: "sun.max")
                        }
                    }
                }
                
                if device.type == .thermostat {
                    Section("Temperature") {
                        Slider(
                            value: Binding(
                                get: { Double(device.temperature ?? 20) },
                                set: { smartHomeManager.updateDevice(device, temperature: Int($0)) }
                            ),
                            in: 16...30,
                            step: 1
                        ) {
                            Text("Temperature")
                        } minimumValueLabel: {
                            Image(systemName: "thermometer.low")
                        } maximumValueLabel: {
                            Image(systemName: "thermometer.high")
                        }
                        
                        Text("\(device.temperature ?? 20)°C")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    SmartHomeView()
        .environmentObject(SmartHomeManager())
} 
import SwiftUI

struct AddSceneView: View {
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sceneName = ""
    @State private var selectedDevices: [SmartDevice] = []
    @State private var deviceActions: [UUID: DeviceAction] = [:]
    @State private var showingDevicePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Scene Details") {
                    TextField("Scene Name", text: $sceneName)
                }
                
                Section {
                    Button {
                        showingDevicePicker = true
                    } label: {
                        Label("Add Devices", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("Add devices and set their actions for this scene")
                }
                
                if !selectedDevices.isEmpty {
                    Section("Device Actions") {
                        ForEach(selectedDevices) { device in
                            DeviceActionRow(
                                device: device,
                                action: deviceActions[device.id] ?? .turnOn,
                                onActionChanged: { action in
                                    deviceActions[device.id] = action
                                }
                            )
                        }
                        .onDelete { indexSet in
                            let devicesToRemove = indexSet.map { selectedDevices[$0] }
                            selectedDevices.remove(atOffsets: indexSet)
                            devicesToRemove.forEach { device in
                                deviceActions.removeValue(forKey: device.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveScene()
                    }
                    .disabled(sceneName.isEmpty || selectedDevices.isEmpty)
                }
            }
            .sheet(isPresented: $showingDevicePicker) {
                DevicePickerView(selectedDevices: $selectedDevices)
            }
        }
    }
    
    private func saveScene() {
        let actions = selectedDevices.compactMap { device -> DeviceCommand? in
            guard let action = deviceActions[device.id] else { return nil }
            return action
        }
        
        let scene = HomeScene(
            name: sceneName,
            devices: selectedDevices,
            actions: actions
        )
        
        viewModel.addScene(scene)
        dismiss()
    }
}

struct DeviceActionRow: View {
    let device: SmartDevice
    let action: DeviceAction
    let onActionChanged: (DeviceAction) -> Void
    
    @State private var adjustmentValue: Double = 50
    @State private var selectedAction: String
    
    init(device: SmartDevice, action: DeviceAction, onActionChanged: @escaping (DeviceAction) -> Void) {
        self.device = device
        self.action = action
        self.onActionChanged = onActionChanged
        
        // Initialize selected action
        switch action {
        case .turnOn:
            _selectedAction = State(initialValue: "turnOn")
        case .turnOff:
            _selectedAction = State(initialValue: "turnOff")
        case .adjust:
            _selectedAction = State(initialValue: "adjust")
        }
        
        // Initialize adjustment value if needed
        if case .adjust(let value) = action {
            _adjustmentValue = State(initialValue: value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(device.name)
                .font(.headline)
            
            Picker("Action", selection: $selectedAction) {
                Text("Turn On").tag("turnOn")
                Text("Turn Off").tag("turnOff")
                if device.type == .light || device.type == .speaker {
                    Text("Adjust").tag("adjust")
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedAction) { newValue in
                switch newValue {
                case "turnOn":
                    onActionChanged(.turnOn)
                case "turnOff":
                    onActionChanged(.turnOff)
                case "adjust":
                    onActionChanged(.adjust(value: adjustmentValue))
                default:
                    break
                }
            }
            
            if selectedAction == "adjust" {
                VStack(spacing: 4) {
                    Slider(value: $adjustmentValue, in: 0...100, step: 1)
                        .onChange(of: adjustmentValue) { newValue in
                            onActionChanged(.adjust(value: newValue))
                        }
                    
                    Text("Value: \(Int(adjustmentValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DevicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: SmartHomeViewModel
    @Binding var selectedDevices: [SmartDevice]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.devices) { device in
                    Button {
                        if selectedDevices.contains(where: { $0.id == device.id }) {
                            selectedDevices.removeAll { $0.id == device.id }
                        } else {
                            selectedDevices.append(device)
                        }
                    } label: {
                        HStack {
                            Image(systemName: iconForDevice(device.type))
                                .foregroundColor(device.isConnected ? .green : .gray)
                            
                            Text(device.name)
                            
                            Spacer()
                            
                            if selectedDevices.contains(where: { $0.id == device.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func iconForDevice(_ type: DeviceType) -> String {
        switch type {
        case .light: return "lightbulb"
        case .thermostat: return "thermometer"
        case .lock: return "lock"
        case .camera: return "camera"
        case .speaker: return "speaker.wave.2"
        case .tv: return "tv"
        case .custom: return "cube"
        }
    }
} 
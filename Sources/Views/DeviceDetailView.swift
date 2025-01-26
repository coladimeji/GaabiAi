import SwiftUI

struct DeviceDetailView: View {
    let device: SmartDevice
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var editedDevice: SmartDevice
    @State private var showingDeleteAlert = false
    @State private var showingScheduleSheet = false
    
    init(device: SmartDevice, viewModel: SmartHomeViewModel) {
        self.device = device
        self.viewModel = viewModel
        self._editedDevice = State(initialValue: device)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Device Status Section
                Section("Status") {
                    HStack {
                        Image(systemName: iconForDevice(device.type))
                            .foregroundColor(device.isConnected ? .green : .gray)
                        Text(device.isConnected ? "Connected" : "Disconnected")
                        Spacer()
                        Toggle("Power", isOn: Binding(
                            get: { device.isOn },
                            set: { newValue in
                                var updatedDevice = device
                                updatedDevice.isOn = newValue
                                viewModel.updateDevice(updatedDevice)
                            }
                        ))
                    }
                }
                
                // Device Info Section
                Section("Information") {
                    if isEditing {
                        TextField("Device Name", text: $editedDevice.name)
                    } else {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(device.name)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(device.type.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connection")
                        Spacer()
                        Text(device.connectionType.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Custom Settings Section
                if let settings = device.customSettings {
                    Section("Settings") {
                        ForEach(Array(settings.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key.capitalized)
                                Spacer()
                                Text("\(String(describing: settings[key]!))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Schedule Section
                Section {
                    Button {
                        showingScheduleSheet = true
                    } label: {
                        Label("Add Schedule", systemImage: "clock")
                    }
                    
                    if let schedules = device.schedule {
                        ForEach(schedules, id: \.time) { schedule in
                            ScheduleRow(schedule: schedule)
                        }
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Set up automated actions for your device")
                }
                
                // Remove Device Button
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Remove Device", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            viewModel.updateDevice(editedDevice)
                            isEditing = false
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Remove Device", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    viewModel.removeDevice(device)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove this device? This action cannot be undone.")
            }
            .sheet(isPresented: $showingScheduleSheet) {
                AddScheduleView(device: device, viewModel: viewModel)
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

struct ScheduleRow: View {
    let schedule: DeviceSchedule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(schedule.time, style: .time)
                    .font(.headline)
                Text(actionDescription(schedule.action))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("Enabled", isOn: .constant(schedule.isEnabled))
        }
    }
    
    private func actionDescription(_ action: DeviceAction) -> String {
        switch action {
        case .turnOn:
            return "Turn On"
        case .turnOff:
            return "Turn Off"
        case .adjust(let value):
            return "Adjust to \(Int(value))"
        }
    }
}

struct AddScheduleView: View {
    let device: SmartDevice
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTime = Date()
    @State private var selectedAction: DeviceAction = .turnOn
    @State private var adjustmentValue: Double = 50
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    
                    Picker("Action", selection: $selectedAction) {
                        Text("Turn On").tag(DeviceAction.turnOn)
                        Text("Turn Off").tag(DeviceAction.turnOff)
                        Text("Adjust").tag(DeviceAction.adjust(value: adjustmentValue))
                    }
                    
                    if case .adjust = selectedAction {
                        VStack {
                            Slider(value: $adjustmentValue, in: 0...100, step: 1)
                            Text("Value: \(Int(adjustmentValue))")
                        }
                    }
                }
            }
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let schedule = DeviceSchedule(
                            time: selectedTime,
                            action: selectedAction,
                            isEnabled: true
                        )
                        var updatedDevice = device
                        updatedDevice.schedule = (device.schedule ?? []) + [schedule]
                        viewModel.updateDevice(updatedDevice)
                        dismiss()
                    }
                }
            }
        }
    }
} 
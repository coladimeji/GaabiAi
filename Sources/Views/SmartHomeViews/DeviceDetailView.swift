import SwiftUI

struct DeviceDetailView: View {
    let device: SmartDevice
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editedDevice: SmartDevice
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingAddSchedule = false
    
    init(device: SmartDevice, viewModel: SmartHomeViewModel) {
        self.device = device
        self.viewModel = viewModel
        _editedDevice = State(initialValue: device)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Status")) {
                    HStack {
                        Image(systemName: device.isConnected ? "wifi" : "wifi.slash")
                            .foregroundColor(device.isConnected ? .green : .red)
                        Text(device.isConnected ? "Connected" : "Disconnected")
                    }
                    
                    Toggle("Power", isOn: Binding(
                        get: { editedDevice.isOn },
                        set: { newValue in
                            editedDevice.isOn = newValue
                            viewModel.updateDevice(editedDevice)
                        }
                    ))
                }
                
                Section(header: Text("Device Information")) {
                    if isEditing {
                        TextField("Name", text: $editedDevice.name)
                    } else {
                        Text("Name: \(device.name)")
                    }
                    
                    Text("Type: \(device.type.description)")
                    Text("Connection: \(device.connectionType.rawValue.capitalized)")
                }
                
                if let settings = device.customSettings {
                    Section(header: Text("Custom Settings")) {
                        ForEach(Array(settings.keys), id: \.self) { key in
                            if let value = settings[key] {
                                HStack {
                                    Text(key)
                                    Spacer()
                                    Text("\(String(describing: value))")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                Section(header: HStack {
                    Text("Schedules")
                    Spacer()
                    Button(action: { showingAddSchedule = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }) {
                    if let schedules = device.schedule {
                        ForEach(schedules, id: \.time) { schedule in
                            ScheduleRow(schedule: schedule)
                        }
                    } else {
                        Text("No schedules set")
                            .foregroundColor(.gray)
                    }
                }
                
                if !isEditing {
                    Section {
                        Button(action: { showingDeleteAlert = true }) {
                            Text("Remove Device")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationBarTitle(device.name, displayMode: .inline)
            .navigationBarItems(
                trailing: Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        viewModel.updateDevice(editedDevice)
                    }
                    isEditing.toggle()
                }
            )
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Remove Device"),
                    message: Text("Are you sure you want to remove this device?"),
                    primaryButton: .destructive(Text("Remove")) {
                        viewModel.removeDevice(device)
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddScheduleView(device: device, viewModel: viewModel)
            }
        }
    }
}

struct ScheduleRow: View {
    let schedule: DeviceSchedule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(timeFormatter.string(from: schedule.time))
                    .font(.headline)
                Text(actionDescription(for: schedule.action))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(schedule.isEnabled))
        }
    }
    
    private func actionDescription(for action: DeviceAction) -> String {
        switch action {
        case .turnOn:
            return "Turn On"
        case .turnOff:
            return "Turn Off"
        case .adjust(let value):
            return "Adjust to \(Int(value))"
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct AddScheduleView: View {
    let device: SmartDevice
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var time = Date()
    @State private var action: DeviceAction = .turnOn
    @State private var adjustValue: Double = 0
    @State private var isEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schedule Time")) {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Action")) {
                    Picker("Action", selection: $action) {
                        Text("Turn On").tag(DeviceAction.turnOn)
                        Text("Turn Off").tag(DeviceAction.turnOff)
                        Text("Adjust").tag(DeviceAction.adjust(value: adjustValue))
                    }
                    
                    if case .adjust = action {
                        Slider(value: $adjustValue, in: 0...100, step: 1) {
                            Text("Value")
                        }
                    }
                }
                
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .navigationBarTitle("Add Schedule", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    addSchedule()
                }
            )
        }
    }
    
    private func addSchedule() {
        var updatedDevice = device
        let schedule = DeviceSchedule(
            time: time,
            action: action,
            isEnabled: isEnabled
        )
        
        if var schedules = updatedDevice.schedule {
            schedules.append(schedule)
            updatedDevice.schedule = schedules
        } else {
            updatedDevice.schedule = [schedule]
        }
        
        viewModel.updateDevice(updatedDevice)
        presentationMode.wrappedValue.dismiss()
    }
} 
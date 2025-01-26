import SwiftUI

struct AddDeviceView: View {
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var customType = ""
    @State private var selectedType: DeviceType = .light
    @State private var connectionType: ConnectionType = .bluetooth
    @State private var showingCustomType = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Details")) {
                    TextField("Device Name", text: $name)
                    
                    Picker("Device Type", selection: $selectedType) {
                        Text("Light").tag(DeviceType.light)
                        Text("Thermostat").tag(DeviceType.thermostat)
                        Text("Lock").tag(DeviceType.lock)
                        Text("Camera").tag(DeviceType.camera)
                        Text("Speaker").tag(DeviceType.speaker)
                        Text("TV").tag(DeviceType.tv)
                        Text("Custom").tag(DeviceType.custom(""))
                    }
                    .onChange(of: selectedType) { newValue in
                        if case .custom = newValue {
                            showingCustomType = true
                        }
                    }
                    
                    if showingCustomType {
                        TextField("Custom Device Type", text: $customType)
                    }
                }
                
                Section(header: Text("Connection")) {
                    Picker("Connection Type", selection: $connectionType) {
                        Text("Bluetooth").tag(ConnectionType.bluetooth)
                        Text("Wi-Fi").tag(ConnectionType.wifi)
                        Text("Zigbee").tag(ConnectionType.zigbee)
                        Text("Z-Wave").tag(ConnectionType.zwave)
                    }
                }
            }
            .navigationBarTitle("Add Device", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    addDevice()
                }
                .disabled(name.isEmpty || (showingCustomType && customType.isEmpty))
            )
        }
    }
    
    private func addDevice() {
        let finalType: DeviceType = showingCustomType ? .custom(customType) : selectedType
        let device = SmartDevice(
            id: UUID(),
            name: name,
            type: finalType,
            isOn: false,
            isConnected: false,
            connectionType: connectionType
        )
        viewModel.addDevice(device)
        presentationMode.wrappedValue.dismiss()
    }
} 
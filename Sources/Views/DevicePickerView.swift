import SwiftUI
import CoreBluetooth

struct DevicePickerView: View {
    @Binding var selectedDevices: [IoTDevice]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DevicePickerViewModel()
    @State private var showingDeviceSetup = false
    @State private var selectedDeviceType: IoTDeviceType?
    
    var body: some View {
        NavigationView {
            List {
                // Available Devices Section
                if !viewModel.availableDevices.isEmpty {
                    Section("Available Devices") {
                        ForEach(viewModel.availableDevices) { device in
                            DeviceRow(
                                device: device,
                                isSelected: selectedDevices.contains { $0.id == device.id }
                            ) {
                                if selectedDevices.contains(where: { $0.id == device.id }) {
                                    selectedDevices.removeAll { $0.id == device.id }
                                } else {
                                    selectedDevices.append(device)
                                }
                            }
                        }
                    }
                }
                
                // Selected Devices Section
                if !selectedDevices.isEmpty {
                    Section("Selected Devices") {
                        ForEach(selectedDevices) { device in
                            DeviceRow(device: device, isSelected: true) {
                                selectedDevices.removeAll { $0.id == device.id }
                            }
                        }
                    }
                }
                
                // Add New Device Section
                Section {
                    Button {
                        showingDeviceSetup = true
                    } label: {
                        Label("Add New Device", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Select Devices")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.scanForDevices()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .overlay {
                if viewModel.isScanning {
                    ScanningOverlay()
                }
            }
            .sheet(isPresented: $showingDeviceSetup) {
                DeviceSetupView(deviceType: $selectedDeviceType) { device in
                    selectedDevices.append(device)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: IoTDevice
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconForDevice(device.type))
                    .foregroundColor(device.isConnected ? .green : .gray)
                
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }
    
    private func iconForDevice(_ type: IoTDeviceType) -> String {
        switch type {
        case .smartLight: return "lightbulb"
        case .thermostat: return "thermometer"
        case .speaker: return "speaker.wave.2"
        case .lock: return "lock"
        case .camera: return "camera"
        case .sensor: return "sensor"
        }
    }
}

struct ScanningOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Scanning for Devices...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
    }
}

struct DeviceSetupView: View {
    @Binding var deviceType: IoTDeviceType?
    @Environment(\.dismiss) private var dismiss
    let onDeviceAdded: (IoTDevice) -> Void
    
    @State private var deviceName = ""
    @State private var selectedType: IoTDeviceType = .smartLight
    @State private var isConfiguring = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Information") {
                    TextField("Device Name", text: $deviceName)
                    
                    Picker("Device Type", selection: $selectedType) {
                        ForEach(IoTDeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }
                
                Section {
                    Button {
                        configureDevice()
                    } label: {
                        if isConfiguring {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Configure Device")
                        }
                    }
                    .disabled(deviceName.isEmpty || isConfiguring)
                }
            }
            .navigationTitle("Add Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func configureDevice() {
        isConfiguring = true
        
        // Simulate device configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let device = IoTDevice(
                id: UUID(),
                name: deviceName,
                type: selectedType,
                macAddress: UUID().uuidString,
                isConnected: true,
                lastSyncDate: Date()
            )
            
            onDeviceAdded(device)
            isConfiguring = false
            dismiss()
        }
    }
}

class DevicePickerViewModel: ObservableObject {
    @Published var availableDevices: [IoTDevice] = []
    @Published var isScanning = false
    
    private let smartHomeManager: SmartHomeManager
    
    init() {
        self.smartHomeManager = SmartHomeManager()
    }
    
    @MainActor
    func scanForDevices() async {
        guard !isScanning else { return }
        
        isScanning = true
        defer { isScanning = false }
        
        do {
            let deviceStream = try await smartHomeManager.scanForDevices()
            for await device in deviceStream {
                if !availableDevices.contains(where: { $0.id == device.id }) {
                    availableDevices.append(device)
                }
            }
        } catch {
            print("Scanning error: \(error)")
        }
    }
}

extension IoTDeviceType: CaseIterable {
    static var allCases: [IoTDeviceType] = [
        .smartLight,
        .thermostat,
        .speaker,
        .lock,
        .camera,
        .sensor
    ]
} 
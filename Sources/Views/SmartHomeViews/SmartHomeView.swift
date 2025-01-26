import SwiftUI

struct SmartHomeView: View {
    @StateObject private var viewModel = SmartHomeViewModel()
    @State private var showingAddDevice = false
    @State private var showingScanner = false
    @State private var selectedDevice: SmartDevice?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.devices) { device in
                        DeviceCard(device: device)
                            .onTapGesture {
                                selectedDevice = device
                            }
                    }
                    
                    AddDeviceButton(action: { showingAddDevice = true })
                }
                .padding()
            }
            .navigationBarTitle("Smart Home", displayMode: .large)
            .navigationBarItems(
                trailing: Button(action: { showingScanner = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingAddDevice) {
                AddDeviceView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingScanner) {
                DeviceScannerView(viewModel: viewModel)
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device, viewModel: viewModel)
            }
        }
    }
}

struct DeviceCard: View {
    let device: SmartDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: device.type))
                    .font(.title)
                    .foregroundColor(device.isOn ? .blue : .gray)
                
                Spacer()
                
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                Text(device.type.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let schedule = device.schedule?.first {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeFormatter.string(from: schedule.time))
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func iconName(for type: DeviceType) -> String {
        switch type {
        case .light: return "lightbulb.fill"
        case .thermostat: return "thermometer"
        case .lock: return "lock.fill"
        case .camera: return "video.fill"
        case .speaker: return "speaker.wave.2.fill"
        case .tv: return "tv.fill"
        case .custom: return "cube.box.fill"
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct AddDeviceButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                Text("Add Device")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DeviceScannerView: View {
    @ObservedObject var viewModel: SmartHomeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Devices")) {
                    if viewModel.isScanning {
                        ForEach(viewModel.discoveredDevices, id: \.identifier) { peripheral in
                            Button(action: {
                                viewModel.connectToDevice(peripheral)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Text(peripheral.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        if viewModel.discoveredDevices.isEmpty {
                            Text("Scanning for devices...")
                                .foregroundColor(.gray)
                        }
                    } else {
                        Button(action: viewModel.startScanning) {
                            Text("Start Scanning")
                        }
                    }
                }
            }
            .navigationBarTitle("Add Device", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    viewModel.stopScanning()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onDisappear {
                viewModel.stopScanning()
            }
        }
    }
} 
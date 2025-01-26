import SwiftUI
import CoreBluetooth

struct SmartHomeView: View {
    @StateObject private var viewModel = SmartHomeViewModel()
    @State private var showingAddDevice = false
    @State private var showingDeviceScanner = false
    @State private var showingAddScene = false
    @State private var selectedDevice: SmartDevice?
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Devices").tag(0)
                    Text("Scenes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if selectedTab == 0 {
                    // Devices View
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            // Add Device Button
                            AddDeviceButton(showingAddDevice: $showingAddDevice)
                            
                            // Device Cards
                            ForEach(filteredDevices) { device in
                                DeviceCard(device: device)
                                    .onTapGesture {
                                        selectedDevice = device
                                    }
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $searchText, prompt: "Search devices")
                } else {
                    // Scenes View
                    List {
                        Section {
                            Button {
                                showingAddScene = true
                            } label: {
                                Label("Add Scene", systemImage: "plus.circle")
                            }
                        }
                        
                        if !viewModel.automationScenes.isEmpty {
                            Section("Automation Scenes") {
                                ForEach(viewModel.automationScenes, id: \.name) { scene in
                                    SceneRow(scene: scene, viewModel: viewModel)
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { index in
                                        let scene = viewModel.automationScenes[index]
                                        viewModel.removeScene(scene)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Smart Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 {
                        Button {
                            showingDeviceScanner = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDeviceScanner) {
                DeviceScannerView(viewModel: viewModel)
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device, viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddScene) {
                AddSceneView(viewModel: viewModel)
            }
        }
    }
    
    private var filteredDevices: [SmartDevice] {
        if searchText.isEmpty {
            return viewModel.devices
        } else {
            return viewModel.devices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.type.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct DeviceCard: View {
    let device: SmartDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForDevice(device.type))
                    .font(.title2)
                    .foregroundColor(device.isConnected ? .green : .gray)
                
                Spacer()
                
                Circle()
                    .fill(device.isOn ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
            }
            
            Text(device.name)
                .font(.headline)
            
            Text(device.type.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let schedule = device.schedule?.first {
                Text("Next: \(schedule.time, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
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

struct SceneRow: View {
    let scene: HomeScene
    @ObservedObject var viewModel: SmartHomeViewModel
    @State private var isActivating = false
    
    var body: some View {
        Button {
            activateScene()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name)
                        .font(.headline)
                    
                    Text("\(scene.devices.count) devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isActivating {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .disabled(isActivating)
    }
    
    private func activateScene() {
        isActivating = true
        
        Task {
            await viewModel.activateScene(scene)
            isActivating = false
        }
    }
}

struct AddDeviceButton: View {
    @Binding var showingAddDevice: Bool
    
    var body: some View {
        Button {
            showingAddDevice = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title)
                
                Text("Add Device")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .foregroundColor(.accentColor)
    }
}

struct DeviceScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SmartHomeViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if viewModel.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing)
                            Text("Scanning for devices...")
                        }
                    } else {
                        Button {
                            viewModel.startScanning()
                        } label: {
                            Text("Start Scanning")
                        }
                    }
                }
                
                if !viewModel.discoveredDevices.isEmpty {
                    Section("Available Devices") {
                        ForEach(viewModel.discoveredDevices, id: \.identifier) { peripheral in
                            Button {
                                viewModel.connectToDevice(peripheral)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(peripheral.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 
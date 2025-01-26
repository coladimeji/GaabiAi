import Foundation
import CoreBluetooth

class SmartHomeViewModel: NSObject, ObservableObject {
    @Published var devices: [SmartDevice] = []
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var automationScenes: [HomeScene] = []
    @Published var deviceStates: [UUID: DeviceState] = [:]
    
    private var centralManager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []
    private var deviceCharacteristics: [UUID: [CBUUID: CBCharacteristic]] = [:]
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        loadDevices()
        loadScenes()
    }
    
    // MARK: - Device Management
    
    func addDevice(_ device: SmartDevice) {
        devices.append(device)
        saveDevices()
    }
    
    func updateDevice(_ device: SmartDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveDevices()
            
            // Update device state if connected
            if device.isConnected {
                sendDeviceCommand(device)
            }
        }
    }
    
    func removeDevice(_ device: SmartDevice) {
        if device.isConnected {
            if let peripheral = peripherals.first(where: { $0.name == device.name }) {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
        devices.removeAll { $0.id == device.id }
        deviceStates.removeValue(forKey: device.id)
        saveDevices()
    }
    
    // MARK: - Bluetooth Operations
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Auto-stop scanning after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        peripherals.append(peripheral)
    }
    
    func disconnectDevice(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // MARK: - Device Commands
    
    private func sendDeviceCommand(_ device: SmartDevice) {
        guard let peripheral = peripherals.first(where: { $0.name == device.name }),
              let characteristics = deviceCharacteristics[device.id] else {
            return
        }
        
        // Send power state
        if let powerCharacteristic = characteristics[CBUUID(string: "2A57")] {
            let value: UInt8 = device.isOn ? 1 : 0
            peripheral.writeValue(Data([value]), for: powerCharacteristic, type: .withResponse)
        }
        
        // Send custom settings if available
        if let settings = device.customSettings {
            for (key, value) in settings {
                if let characteristic = characteristics[CBUUID(string: key)],
                   let data = try? JSONSerialization.data(withJSONObject: value) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
            }
        }
    }
    
    // MARK: - Scene Management
    
    func addScene(_ scene: HomeScene) {
        automationScenes.append(scene)
        saveScenes()
    }
    
    func removeScene(_ scene: HomeScene) {
        automationScenes.removeAll { $0.name == scene.name }
        saveScenes()
    }
    
    func activateScene(_ scene: HomeScene) async {
        for (device, command) in zip(scene.devices, scene.actions) {
            if let deviceToUpdate = devices.first(where: { $0.id == device.id }) {
                var updatedDevice = deviceToUpdate
                
                switch command {
                case .turnOn:
                    updatedDevice.isOn = true
                case .turnOff:
                    updatedDevice.isOn = false
                case .adjust(let value):
                    if var settings = updatedDevice.customSettings {
                        settings["brightness"] = value
                        updatedDevice.customSettings = settings
                    }
                }
                
                updateDevice(updatedDevice)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: "smartDevices"),
           let decodedDevices = try? JSONDecoder().decode([SmartDevice].self, from: data) {
            devices = decodedDevices
        }
    }
    
    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: "smartDevices")
        }
    }
    
    private func loadScenes() {
        if let data = UserDefaults.standard.data(forKey: "automationScenes"),
           let decodedScenes = try? JSONDecoder().decode([HomeScene].self, from: data) {
            automationScenes = decodedScenes
        }
    }
    
    private func saveScenes() {
        if let encoded = try? JSONEncoder().encode(automationScenes) {
            UserDefaults.standard.set(encoded, forKey: "automationScenes")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension SmartHomeViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on")
        } else {
            print("Bluetooth is not available: \(central.state.rawValue)")
            isScanning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let device = devices.first(where: { $0.name == peripheral.name }) {
            var updatedDevice = device
            updatedDevice.isConnected = true
            updateDevice(updatedDevice)
            
            // Discover services
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let device = devices.first(where: { $0.name == peripheral.name }) {
            var updatedDevice = device
            updatedDevice.isConnected = false
            updateDevice(updatedDevice)
            
            // Clean up
            deviceCharacteristics.removeValue(forKey: device.id)
        }
        peripherals.removeAll { $0 == peripheral }
    }
}

// MARK: - CBPeripheralDelegate

extension SmartHomeViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        if let device = devices.first(where: { $0.name == peripheral.name }) {
            var characteristics: [CBUUID: CBCharacteristic] = [:]
            
            service.characteristics?.forEach { characteristic in
                characteristics[characteristic.uuid] = characteristic
            }
            
            deviceCharacteristics[device.id] = characteristics
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating characteristic value: \(error!.localizedDescription)")
            return
        }
        
        if let device = devices.first(where: { $0.name == peripheral.name }),
           let data = characteristic.value {
            // Handle different characteristic types
            switch characteristic.uuid.uuidString {
            case "2A57": // Power state
                let isOn = data.first == 1
                var updatedDevice = device
                updatedDevice.isOn = isOn
                updateDevice(updatedDevice)
                
            case "2A6E": // Temperature
                if data.count >= 2 {
                    let temperature = Double(data[0]) + Double(data[1]) / 100.0
                    deviceStates[device.id] = .temperature(temperature)
                }
                
            case "2A6D": // Brightness
                if let brightness = data.first {
                    deviceStates[device.id] = .brightness(Int(brightness))
                }
                
            default:
                break
            }
        }
    }
} 
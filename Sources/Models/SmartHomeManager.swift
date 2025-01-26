import Foundation
import CoreBluetooth

class SmartHomeManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    
    @Published var devices: [SmartDevice] = []
    @Published var isScanning = false
    @Published var error: Error?
    @Published var bluetoothState: CBManagerState = .unknown
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        loadDevices()
    }
    
    // MARK: - Device Management
    
    func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: "smartDevices"),
           let savedDevices = try? JSONDecoder().decode([SmartDevice].self, from: data) {
            devices = savedDevices
        }
    }
    
    func saveDevices() {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: "smartDevices")
        }
    }
    
    func addDevice(_ device: SmartDevice) {
        devices.append(device)
        saveDevices()
    }
    
    func updateDevice(_ device: SmartDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveDevices()
        }
    }
    
    func removeDevice(_ device: SmartDevice) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    // MARK: - Bluetooth Scanning
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            error = NSError(domain: "SmartHomeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not available"])
            return
        }
        
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        if central.state == .poweredOn {
            print("Bluetooth is powered on")
        } else {
            stopScanning()
            error = NSError(domain: "SmartHomeManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not powered on"])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            
            // Create a SmartDevice from the discovered peripheral
            let device = SmartDevice(
                id: peripheral.identifier.uuidString,
                name: peripheral.name ?? "Unknown Device",
                type: .custom("Unknown"),
                connectionType: .bluetooth,
                isConnected: false
            )
            
            // Only add the device if it's not already in the devices array
            if !devices.contains(where: { $0.id == device.id }) {
                DispatchQueue.main.async {
                    self.devices.append(device)
                    self.saveDevices()
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier.uuidString }) {
            devices[index].isConnected = true
            saveDevices()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.error = error
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier.uuidString }) {
            devices[index].isConnected = false
            saveDevices()
        }
        
        if let error = error {
            self.error = error
        }
    }
} 
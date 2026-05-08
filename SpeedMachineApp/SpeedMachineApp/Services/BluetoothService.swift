//
//  BluetoothService.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothService: NSObject, ObservableObject {
    // Published properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var currentSpeed: Float = 0.0
    @Published var batteryLevel: Int = 100
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?

    // BLE objects
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var speedCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?

    // UUIDs
    private let serviceUUID = CBUUID(string: BLEConstants.serviceUUID)
    private let speedCharUUID = CBUUID(string: BLEConstants.speedCharacteristicUUID)
    private let batteryCharUUID = CBUUID(string: BLEConstants.batteryCharacteristicUUID)

    // Last connected device
    private var lastConnectedDeviceIdentifier: UUID?
    private let lastDeviceKey = "lastConnectedDevice"

    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case connected = "Connected"
        case reconnecting = "Reconnecting..."
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        loadLastDevice()
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth is not available"
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetConnection()
    }

    private func resetConnection() {
        isConnected = false
        connectionState = .disconnected
        speedCharacteristic = nil
        batteryCharacteristic = nil
        currentSpeed = 0.0
    }

    private func saveLastDevice(_ identifier: UUID) {
        lastConnectedDeviceIdentifier = identifier
        UserDefaults.standard.set(identifier.uuidString, forKey: lastDeviceKey)
    }

    private func loadLastDevice() {
        if let uuidString = UserDefaults.standard.string(forKey: lastDeviceKey),
           let uuid = UUID(uuidString: uuidString) {
            lastConnectedDeviceIdentifier = uuid
        }
    }

    private func attemptAutoReconnect() {
        guard let lastIdentifier = lastConnectedDeviceIdentifier else { return }

        // Retrieve peripherals with known identifier
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [lastIdentifier])
        if let peripheral = peripherals.first {
            connectionState = .reconnecting
            connect(to: peripheral)
        }
    }

    // MARK: - Speed Processing

    private func processSpeedData(_ data: Data) {
        guard data.count == 4 else { return }

        let speed = data.withUnsafeBytes { $0.load(as: Float.self) }

        // Validate speed (0-30 MPH reasonable range)
        guard speed >= 0 && speed <= 30 else { return }

        DispatchQueue.main.async {
            self.currentSpeed = speed
        }
    }

    private func processBatteryData(_ data: Data) {
        guard data.count == 1 else { return }

        let battery = Int(data[0])
        guard battery >= 0 && battery <= 100 else { return }

        DispatchQueue.main.async {
            self.batteryLevel = battery
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Attempt auto-reconnect
            attemptAutoReconnect()
        case .poweredOff:
            errorMessage = "Bluetooth is turned off"
            resetConnection()
        case .unauthorized:
            errorMessage = "Bluetooth permission not granted"
        case .unsupported:
            errorMessage = "Bluetooth is not supported on this device"
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check if device name matches
        if let name = peripheral.name, name.contains(BLEConstants.deviceName) {
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        isConnected = true
        saveLastDevice(peripheral.identifier)
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        resetConnection()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            errorMessage = "Connection lost. Reconnecting..."
            // Attempt auto-reconnect up to 3 times
            var retryCount = 0
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                retryCount += 1
                if retryCount > 3 {
                    timer.invalidate()
                    self.errorMessage = "Could not reconnect. Please try again manually."
                    return
                }

                if self.isConnected {
                    timer.invalidate()
                } else {
                    self.connect(to: peripheral)
                }
            }
        }
        resetConnection()
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([speedCharUUID, batteryCharUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case speedCharUUID:
                speedCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)

            case batteryCharUUID:
                batteryCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)

            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case speedCharUUID:
            processSpeedData(data)

        case batteryCharUUID:
            processBatteryData(data)

        default:
            break
        }
    }
}

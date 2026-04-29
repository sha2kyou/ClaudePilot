import Foundation
import Combine
import SystemConfiguration
import CoreWLAN
import CoreLocation

@MainActor
final class WiFiMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WiFiMonitor()

    @Published private(set) var currentSSID: String?
    @Published private(set) var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    private var dynamicStore: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationAuthStatus = locationManager.authorizationStatus
        print("[WiFiMonitor] init, authStatus=\(locationAuthStatus.rawValue)")

        if locationAuthStatus == .authorizedAlways {
            currentSSID = Self.readCurrentSSID()
            startMonitoring()
        } else if locationAuthStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else {
            print("[WiFiMonitor] location not authorized, status=\(locationAuthStatus.rawValue)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            print("[WiFiMonitor] authorizationStatus changed to \(status.rawValue)")
            self.locationAuthStatus = status
            if status == .authorizedAlways {
                self.currentSSID = Self.readCurrentSSID()
                self.startMonitoring()
            }
        }
    }

    private func startMonitoring() {
        guard dynamicStore == nil else { return }

        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let store = SCDynamicStoreCreate(
            nil,
            "ClaudePilot.WiFiMonitor" as CFString,
            { _, changedKeys, info in
                let keys = changedKeys as? [String] ?? []
                print("[WiFiMonitor] SCDynamicStore callback fired, changedKeys=\(keys)")
                guard let info else { return }
                let monitor = Unmanaged<WiFiMonitor>.fromOpaque(info).takeUnretainedValue()
                Task { @MainActor in
                    monitor.handleNetworkChange()
                }
            },
            &context
        ) else {
            print("[WiFiMonitor] SCDynamicStoreCreate failed")
            return
        }

        let keys: CFArray = [
            "State:/Network/Interface/en0/AirPort",
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6"
        ] as CFArray
        let patterns: CFArray = [
            "State:/Network/Interface/.*/AirPort"
        ] as CFArray

        let ok = SCDynamicStoreSetNotificationKeys(store, keys, patterns)
        print("[WiFiMonitor] SCDynamicStoreSetNotificationKeys ok=\(ok)")

        guard let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else {
            print("[WiFiMonitor] SCDynamicStoreCreateRunLoopSource failed")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        print("[WiFiMonitor] monitoring started")

        dynamicStore = store
        runLoopSource = source
    }

    private func handleNetworkChange() {
        let ssid = Self.readCurrentSSID()
        print("[WiFiMonitor] handleNetworkChange: newSSID=\(ssid ?? "nil"), currentSSID=\(currentSSID ?? "nil")")
        guard ssid != currentSSID else {
            print("[WiFiMonitor] SSID unchanged, skip")
            return
        }
        currentSSID = ssid
        print("[WiFiMonitor] SSID changed to \(ssid ?? "nil"), calling evaluateWiFi")
        TriggerStore.shared.evaluateWiFi(ssid: ssid)
    }

    static func readCurrentSSID() -> String? {
        let ssid = CWWiFiClient.shared().interface()?.ssid()
        print("[WiFiMonitor] readCurrentSSID=\(ssid ?? "nil")")
        return ssid
    }

    var isLocationDenied: Bool {
        locationAuthStatus == .denied || locationAuthStatus == .restricted
    }
}

import Foundation
import Combine

enum TriggerCondition: Codable, Equatable {
    case wifiConnected(ssid: String)
    case dailyTime(hour: Int, minute: Int)

    private enum CodingKeys: String, CodingKey {
        case type, ssid, hour, minute
    }

    private enum ConditionType: String, Codable {
        case wifiConnected, dailyTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ConditionType.self, forKey: .type)
        switch type_ {
        case .wifiConnected:
            let ssid = try container.decode(String.self, forKey: .ssid)
            self = .wifiConnected(ssid: ssid)
        case .dailyTime:
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .dailyTime(hour: hour, minute: minute)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .wifiConnected(let ssid):
            try container.encode(ConditionType.wifiConnected, forKey: .type)
            try container.encode(ssid, forKey: .ssid)
        case .dailyTime(let hour, let minute):
            try container.encode(ConditionType.dailyTime, forKey: .type)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        }
    }

    var displaySummary: String {
        switch self {
        case .wifiConnected(let ssid):
            return String(format: String(localized: "trigger.condition.wifi_connected"), ssid)
        case .dailyTime(let hour, let minute):
            return String(format: "%02d:%02d", hour, minute)
        }
    }
}

struct Trigger: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var condition: TriggerCondition
    var targetProfileID: UUID

    init(
        id: UUID = UUID(),
        name: String,
        condition: TriggerCondition,
        targetProfileID: UUID
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.targetProfileID = targetProfileID
    }
}

struct TriggerLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let message: String
}

@MainActor
final class TriggerStore: ObservableObject {
    static let shared = TriggerStore()

    @Published var triggers: [Trigger] = []
    @Published private(set) var triggerLogEntries: [TriggerLogEntry] = []

    private let profileStore = SharedProfileStore.instance
    private let fileManager = FileManager.default

    private let maxTriggerLogEntries = 50
    
    private enum TriggerSource {
        case wifi(ssid: String)
        case time(hour: Int, minute: Int)
    }

    private init() {
        load()
    }

    func addTrigger(_ trigger: Trigger) {
        triggers.append(trigger)
        persist()
    }

    func updateTrigger(_ trigger: Trigger) {
        guard let index = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[index] = trigger
        persist()
    }

    func deleteTrigger(id: UUID) {
        triggers.removeAll { $0.id == id }
        persist()
    }

    func clearTriggerLog() {
        triggerLogEntries.removeAll()
        persistTriggerLog()
    }

    func evaluateWiFi(ssid: String?) {
        guard let ssid, !ssid.isEmpty else { return }
        let matched = triggers.filter { trigger in
            if case .wifiConnected(let targetSSID) = trigger.condition {
                return targetSSID == ssid
            }
            return false
        }
        fire(triggers: matched, source: .wifi(ssid: ssid))
    }

    func evaluateTime(date: Date = Date()) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return }
        let matched = triggers.filter { trigger in
            if case .dailyTime(let h, let m) = trigger.condition {
                return h == hour && m == minute
            }
            return false
        }
        fire(triggers: matched, source: .time(hour: hour, minute: minute))
    }

    private func appendTriggerLog(_ message: String) {
        let entry = TriggerLogEntry(id: UUID(), date: Date(), message: message)
        triggerLogEntries.insert(entry, at: 0)
        if triggerLogEntries.count > maxTriggerLogEntries {
            triggerLogEntries.removeLast(triggerLogEntries.count - maxTriggerLogEntries)
        }
        persistTriggerLog()
    }

    private func targetProfileDisplayName(for trigger: Trigger) -> String {
        profileStore.profiles.first(where: { $0.id == trigger.targetProfileID })?.name
            ?? String(localized: "trigger.profile.unknown")
    }

    private func fire(triggers: [Trigger], source: TriggerSource) {
        var firstSameProfile: Trigger?
        var didFire = false
        
        for trigger in triggers {
            if profileStore.currentProfileID == trigger.targetProfileID {
                if firstSameProfile == nil {
                    firstSameProfile = trigger
                }
                continue
            }
            let profileName = targetProfileDisplayName(for: trigger)
            profileStore.switchProfileAndApply(profileID: trigger.targetProfileID)
            appendTriggerLog(messageForFired(source: source, triggerName: trigger.name, profileName: profileName))
            didFire = true
            break
        }
        
        if !didFire, let trigger = firstSameProfile {
            appendTriggerLog(messageForSameProfile(source: source, triggerName: trigger.name))
        }
    }
    
    private func messageForFired(source: TriggerSource, triggerName: String, profileName: String) -> String {
        switch source {
        case .wifi(let ssid):
            return String(
                format: String(localized: "trigger.log.wifi.fired"),
                ssid,
                triggerName,
                profileName
            )
        case .time(let hour, let minute):
            return String(
                format: String(localized: "trigger.log.time.fired"),
                hour,
                minute,
                triggerName,
                profileName
            )
        }
    }
    
    private func messageForSameProfile(source: TriggerSource, triggerName: String) -> String {
        switch source {
        case .wifi(let ssid):
            return String(
                format: String(localized: "trigger.log.wifi.same_profile"),
                ssid,
                triggerName
            )
        case .time(let hour, let minute):
            return String(
                format: String(localized: "trigger.log.time.same_profile"),
                hour,
                minute,
                triggerName
            )
        }
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(triggers) else { return }
        do {
            let dir = try appSupportDirectory()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = triggersFileURL()
            let tmp = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
            var shouldCleanupTemp = true
            defer {
                if shouldCleanupTemp {
                    try? fileManager.removeItem(at: tmp)
                }
            }
            guard fileManager.createFile(atPath: tmp.path, contents: nil) else { return }
            let handle = try FileHandle(forWritingTo: tmp)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: url)
            }
            shouldCleanupTemp = false
        } catch {}
    }

    private func load() {
        guard let data = try? Data(contentsOf: triggersFileURL()),
              let decoded = try? JSONDecoder().decode([Trigger].self, from: data) else {
            triggers = []
            loadTriggerLog()
            return
        }
        triggers = decoded
        loadTriggerLog()
    }
    
    private func persistTriggerLog() {
        guard let data = try? JSONEncoder().encode(triggerLogEntries) else { return }
        do {
            let dir = try appSupportDirectory()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = triggerLogsFileURL()
            let tmp = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
            var shouldCleanupTemp = true
            defer {
                if shouldCleanupTemp {
                    try? fileManager.removeItem(at: tmp)
                }
            }
            guard fileManager.createFile(atPath: tmp.path, contents: nil) else { return }
            let handle = try FileHandle(forWritingTo: tmp)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: url)
            }
            shouldCleanupTemp = false
        } catch {}
    }
    
    private func loadTriggerLog() {
        guard let data = try? Data(contentsOf: triggerLogsFileURL()),
              let decoded = try? JSONDecoder().decode([TriggerLogEntry].self, from: data) else {
            triggerLogEntries = []
            return
        }
        if decoded.count > maxTriggerLogEntries {
            triggerLogEntries = Array(decoded.prefix(maxTriggerLogEntries))
        } else {
            triggerLogEntries = decoded
        }
    }

    private func triggersFileURL() -> URL {
        (try? appSupportDirectory().appendingPathComponent("triggers.json", isDirectory: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("triggers.json")
    }
    
    private func triggerLogsFileURL() -> URL {
        (try? appSupportDirectory().appendingPathComponent("trigger_logs.json", isDirectory: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("trigger_logs.json")
    }

    private func appSupportDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("ClaudePilot", isDirectory: true)
    }
}

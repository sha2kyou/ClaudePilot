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

@MainActor
final class TriggerStore: ObservableObject {
    static let shared = TriggerStore()

    @Published var triggers: [Trigger] = []

    private let profileStore = SharedProfileStore.instance
    private let fileManager = FileManager.default

    // 防抖：记录上次触发时间，同一触发器 60 秒内只执行一次
    private var lastFiredAt: [UUID: Date] = [:]

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
        lastFiredAt.removeValue(forKey: id)
        persist()
    }

    func evaluateWiFi(ssid: String?) {
        print("[TriggerStore] evaluateWiFi ssid=\(ssid ?? "nil"), triggers=\(triggers.map { "\($0.name):\($0.condition)" })")
        guard let ssid, !ssid.isEmpty else {
            print("[TriggerStore] evaluateWiFi: ssid nil or empty, skip")
            return
        }
        let matched = triggers.filter { trigger in
            if case .wifiConnected(let targetSSID) = trigger.condition {
                print("[TriggerStore] comparing targetSSID='\(targetSSID)' vs ssid='\(ssid)' -> \(targetSSID == ssid)")
                return targetSSID == ssid
            }
            return false
        }
        print("[TriggerStore] matched \(matched.count) trigger(s)")
        fire(triggers: matched)
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
        fire(triggers: matched)
    }

    private func fire(triggers: [Trigger]) {
        let now = Date()
        for trigger in triggers {
            if let last = lastFiredAt[trigger.id], now.timeIntervalSince(last) < 60 {
                print("[TriggerStore] trigger '\(trigger.name)' debounced, skip")
                continue
            }
            print("[TriggerStore] firing trigger '\(trigger.name)' -> profileID=\(trigger.targetProfileID)")
            lastFiredAt[trigger.id] = now
            profileStore.switchProfileAndApply(profileID: trigger.targetProfileID)
            break
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
            return
        }
        triggers = decoded
    }

    private func triggersFileURL() -> URL {
        (try? appSupportDirectory().appendingPathComponent("triggers.json", isDirectory: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("triggers.json")
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

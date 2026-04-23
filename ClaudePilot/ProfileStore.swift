import Foundation
import Combine
import Darwin

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [ClaudeProfile] = []
    @Published var currentProfileID: UUID?
    @Published var statusMessage: String = ""

    private struct StoredState: Codable {
        var profiles: [ClaudeProfile]
        var currentProfileID: UUID?
    }

    private let fileManager = FileManager.default

    init() {
        load()
    }

    func addProfile(
        name: String,
        baseURL: String,
        model: String,
        apiKey: String,
        customEnvEntries: [CustomEnvEntry]
    ) {
        let profile = ClaudeProfile(
            name: name,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            customEnvEntries: customEnvEntries
        )
        profiles.append(profile)
        persist()
    }

    func updateProfile(_ profile: ClaudeProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }
        profiles[index] = profile
        persist()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if currentProfileID == id {
            currentProfileID = nil
        }
        persist()
    }

    func applyCurrentProfile() {
        guard let id = currentProfileID,
              let profile = profiles.first(where: { $0.id == id }) else {
            statusMessage = "未找到当前配置"
            return
        }

        do {
            try writeClaudeSettingsFile(profile: profile)
            statusMessage = "已更新 ~/.claude/settings.json"
            persist()
        } catch {
            statusMessage = "应用失败: \(error.localizedDescription)"
        }
    }

    func clearStatus() {
        statusMessage = ""
    }

    private func persist() {
        let payload = StoredState(profiles: profiles, currentProfileID: currentProfileID)
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        do {
            let dir = try appSupportDirectory()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try atomicWrite(data, to: stateFileURL())
        } catch {
            statusMessage = "保存配置失败: \(error.localizedDescription)"
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: stateFileURL())
            let payload = try JSONDecoder().decode(StoredState.self, from: data)
            profiles = payload.profiles
            if let id = payload.currentProfileID,
               payload.profiles.contains(where: { $0.id == id }) {
                currentProfileID = id
            } else {
                currentProfileID = nil
            }
        } catch {
            profiles = []
            currentProfileID = nil
        }
    }

    private func writeClaudeSettingsFile(profile: ClaudeProfile) throws {
        let home = realUserHomeDirectory()
        let folder = home.appendingPathComponent(".claude", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let file = folder.appendingPathComponent("settings.json", isDirectory: false)
        var root: [String: Any] = [:]

        if fileManager.fileExists(atPath: file.path) {
            let existingData = try Data(contentsOf: file)
            if !existingData.isEmpty {
                let object = try JSONSerialization.jsonObject(with: existingData)
                if let dictionary = object as? [String: Any] {
                    root = dictionary
                } else {
                    throw NSError(
                        domain: "ClaudePilot",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "settings.json 不是 JSON 对象"]
                    )
                }
            }
        }

        let normalizedAPIKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let builtInEntries: [CustomEnvEntry] = [
            CustomEnvEntry(keyPath: "env.ANTHROPIC_BASE_URL", value: normalizedBaseURL),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_API_KEY", value: normalizedAPIKey),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_MODEL", value: normalizedModel)
        ]

        for entry in builtInEntries + profile.customEnvEntries {
            let pathComponents = entry.keyPath
                .split(separator: ".")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !pathComponents.isEmpty,
                  !entry.value.isEmpty else {
                continue
            }
            setValue(in: &root, path: pathComponents, value: entry.value)
        }

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try atomicWrite(data, to: file)
    }

    private func atomicWrite(_ data: Data, to destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        let temporaryFile = parent.appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")

        var shouldCleanupTemp = true
        defer {
            if shouldCleanupTemp {
                try? fileManager.removeItem(at: temporaryFile)
            }
        }

        guard fileManager.createFile(atPath: temporaryFile.path, contents: nil) else {
            throw NSError(
                domain: "ClaudePilot",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "创建临时文件失败: \(temporaryFile.path)"]
            )
        }

        let handle = try FileHandle(forWritingTo: temporaryFile)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryFile)
        } else {
            try fileManager.moveItem(at: temporaryFile, to: destination)
        }
        try synchronizeDirectory(parent)
        shouldCleanupTemp = false
    }

    private func synchronizeDirectory(_ directory: URL) throws {
        let fd = open(directory.path, O_RDONLY)
        if fd < 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "打开目录失败: \(directory.path)"]
            )
        }
        defer { close(fd) }

        if fsync(fd) != 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "同步目录失败: \(directory.path)"]
            )
        }
    }

    private func realUserHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let homePtr = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: homePtr), isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
    }

    private func stateFileURL() -> URL {
        (try? appSupportDirectory().appendingPathComponent("profiles.json", isDirectory: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("profiles.json")
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

    private func setValue(in root: inout [String: Any], path: [String], value: String) {
        guard let first = path.first else {
            return
        }
        if path.count == 1 {
            root[first] = value
            return
        }

        var child = root[first] as? [String: Any] ?? [:]
        setValue(in: &child, path: Array(path.dropFirst()), value: value)
        root[first] = child
    }
}

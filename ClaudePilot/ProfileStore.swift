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

    func addProfile(name: String, baseURL: String, model: String, apiKey: String, apiKeyPath: String) {
        let profile = ClaudeProfile(
            name: name,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            apiKeyPath: apiKeyPath
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
            try data.write(to: stateFileURL(), options: .atomic)
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

        var env = root["env"] as? [String: Any] ?? [:]
        env.removeValue(forKey: "ANTHROPIC_API_KEY")
        env.removeValue(forKey: "ANTHROPIC_BASE_URL")
        env.removeValue(forKey: "ANTHROPIC_MODEL")

        let normalizedAPIKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKeyPath = profile.apiKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKeyEnvKey = parseEnvKey(from: normalizedAPIKeyPath) ?? "ANTHROPIC_API_KEY"

        env.removeValue(forKey: apiKeyEnvKey)
        if !normalizedBaseURL.isEmpty {
            env["ANTHROPIC_BASE_URL"] = normalizedBaseURL
        }
        if !normalizedModel.isEmpty {
            env["ANTHROPIC_MODEL"] = normalizedModel
        }
        if !normalizedAPIKey.isEmpty {
            env[apiKeyEnvKey] = normalizedAPIKey
        }
        root["env"] = env

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: file, options: .atomic)
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

    private func parseEnvKey(from path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("env.") {
            let key = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        }
        return nil
    }
}

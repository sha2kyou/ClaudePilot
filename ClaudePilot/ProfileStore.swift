import Foundation
import Combine
import Darwin

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [ClaudeProfile] = []
    @Published var currentProfileID: UUID?
    @Published var statusMessage: String = ""
    @Published var customClaudeSettingsFilePath: String?
    var userRelativeClaudeSettingsPath: String {
        let settingsFile = claudeSettingsFileURL().standardizedFileURL.path
        let home = realUserHomeDirectory().standardizedFileURL.path
        if settingsFile == home {
            return "~"
        }
        if settingsFile.hasPrefix(home + "/") {
            return "~" + String(settingsFile.dropFirst(home.count))
        }
        return settingsFile
    }

    private struct StoredState: Codable {
        var profiles: [ClaudeProfile]
        var currentProfileID: UUID?
        var customClaudeSettingsFilePath: String?
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
        authToken: String,
        customEnvEntries: [CustomEnvEntry]
    ) {
        let profile = ClaudeProfile(
            name: name,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            authToken: authToken,
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
            statusMessage = String(localized: "profile_store.status.current_profile_not_found")
            return
        }

        do {
            try writeClaudeSettingsFile(profile: profile, removing: [])
            statusMessage = String(
                format: String(localized: "profile_store.status.settings_updated_at_path"),
                userRelativeClaudeSettingsPath
            )
            persist()
        } catch {
            statusMessage = String(format: String(localized: "profile_store.status.apply_failed"), error.localizedDescription)
        }
    }

    func switchProfileAndApply(profileID: UUID) {
        let previousProfile = profiles.first(where: { $0.id == currentProfileID })
        currentProfileID = profileID
        guard let nextProfile = profiles.first(where: { $0.id == profileID }) else {
            statusMessage = String(localized: "profile_store.status.current_profile_not_found")
            return
        }

        let previousManagedKeyPaths = managedKeyPaths(for: previousProfile)
        do {
            try writeClaudeSettingsFile(profile: nextProfile, removing: previousManagedKeyPaths)
            statusMessage = String(
                format: String(localized: "profile_store.status.settings_updated_at_path"),
                userRelativeClaudeSettingsPath
            )
            persist()
        } catch {
            statusMessage = String(format: String(localized: "profile_store.status.apply_failed"), error.localizedDescription)
        }
    }

    func clearStatus() {
        statusMessage = ""
    }

    func updateClaudeSettingsFilePath(_ url: URL) {
        let standardized = url.standardizedFileURL.path
        let defaultPath = defaultClaudeSettingsFileURL().standardizedFileURL.path
        customClaudeSettingsFilePath = (standardized == defaultPath) ? nil : standardized
        persist()
    }

    private func persist() {
        let payload = StoredState(
            profiles: profiles,
            currentProfileID: currentProfileID,
            customClaudeSettingsFilePath: customClaudeSettingsFilePath
        )
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        do {
            let dir = try appSupportDirectory()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try atomicWrite(data, to: stateFileURL())
        } catch {
            statusMessage = String(format: String(localized: "profile_store.status.save_failed"), error.localizedDescription)
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: stateFileURL())
            let payload = try JSONDecoder().decode(StoredState.self, from: data)
            profiles = payload.profiles
            customClaudeSettingsFilePath = payload.customClaudeSettingsFilePath
            if let id = payload.currentProfileID,
               payload.profiles.contains(where: { $0.id == id }) {
                currentProfileID = id
            } else {
                currentProfileID = nil
            }
        } catch {
            profiles = []
            currentProfileID = nil
            customClaudeSettingsFilePath = nil
        }
    }

    private func writeClaudeSettingsFile(profile: ClaudeProfile, removing staleManagedKeyPaths: Set<String>) throws {
        let file = claudeSettingsFileURL()
        let folder = file.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
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
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "profile_store.error.settings_not_json_object")]
                    )
                }
            }
        }

        let normalizedAPIKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuthToken = profile.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let builtInEntries: [CustomEnvEntry] = [
            CustomEnvEntry(keyPath: "env.ANTHROPIC_BASE_URL", value: normalizedBaseURL),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_API_KEY", value: normalizedAPIKey),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_AUTH_TOKEN", value: normalizedAuthToken),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_MODEL", value: normalizedModel)
        ]
        for stalePath in staleManagedKeyPaths {
            removeValue(in: &root, path: stalePath.split(separator: ".").map(String.init))
        }

        for entry in builtInEntries {
            guard let normalizedPath = normalizedKeyPath(entry.keyPath) else {
                continue
            }
            let pathComponents = normalizedPath.split(separator: ".").map(String.init)

            if entry.value.isEmpty {
                removeValue(in: &root, path: pathComponents)
            } else {
                setValue(in: &root, path: pathComponents, value: entry.value)
            }
        }

        for entry in profile.customEnvEntries {
            guard let normalizedPath = normalizedKeyPath(entry.keyPath) else {
                continue
            }
            let pathComponents = normalizedPath.split(separator: ".").map(String.init)
            let normalizedValue = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedValue.isEmpty {
                removeValue(in: &root, path: pathComponents)
            } else {
                setValue(in: &root, path: pathComponents, value: normalizedValue)
            }
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
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        format: String(localized: "profile_store.error.create_temp_file_failed"),
                        temporaryFile.path
                    )
                ]
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
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        format: String(localized: "profile_store.error.open_directory_failed"),
                        directory.path
                    )
                ]
            )
        }
        defer { close(fd) }

        if fsync(fd) != 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        format: String(localized: "profile_store.error.sync_directory_failed"),
                        directory.path
                    )
                ]
            )
        }
    }

    private func realUserHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let homePtr = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: homePtr), isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
    }

    private func claudeSettingsFileURL() -> URL {
        if let rawPath = customClaudeSettingsFilePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawPath.isEmpty {
            let expandedPath = (rawPath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath, isDirectory: false)
        }
        return defaultClaudeSettingsFileURL()
    }

    private func defaultClaudeSettingsFileURL() -> URL {
        realUserHomeDirectory()
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
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

    @discardableResult
    private func removeValue(in root: inout [String: Any], path: [String]) -> Bool {
        guard let first = path.first else {
            return root.isEmpty
        }

        if path.count == 1 {
            root.removeValue(forKey: first)
            return root.isEmpty
        }

        guard var child = root[first] as? [String: Any] else {
            return root.isEmpty
        }

        let childIsEmpty = removeValue(in: &child, path: Array(path.dropFirst()))
        if childIsEmpty {
            root.removeValue(forKey: first)
        } else {
            root[first] = child
        }
        return root.isEmpty
    }

    private func normalizedKeyPath(_ rawPath: String) -> String? {
        let components = rawPath
            .split(separator: ".")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !components.isEmpty else {
            return nil
        }
        return components.joined(separator: ".")
    }

    private func managedKeyPaths(for profile: ClaudeProfile?) -> Set<String> {
        guard let profile else {
            return []
        }

        let normalizedAPIKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuthToken = profile.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let builtInEntries: [CustomEnvEntry] = [
            CustomEnvEntry(keyPath: "env.ANTHROPIC_BASE_URL", value: normalizedBaseURL),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_API_KEY", value: normalizedAPIKey),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_AUTH_TOKEN", value: normalizedAuthToken),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_MODEL", value: normalizedModel)
        ]
        return Set((builtInEntries + profile.customEnvEntries).compactMap {
            normalizedKeyPath($0.keyPath)
        })
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(profileStore.userRelativeClaudeSettingsPath)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            .padding(.bottom, 6)

            Divider()

            if profileStore.profiles.isEmpty {
                Text("menu_bar.empty.no_profiles")
                    .foregroundColor(.secondary)
            } else {
                ForEach(profileStore.profiles) { profile in
                    Button {
                        selectAndApply(profileID: profile.id)
                    } label: {
                        HStack {
                            Text(profile.name)
                            Spacer()
                            if profile.id == profileStore.currentProfileID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button("menu_bar.action.edit_profiles") {
                NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            }

            Button("menu_bar.action.edit_settings_path") {
                editSettingsPath()
            }

            Divider()

            Button {
                toggleLaunchAtLogin()
            } label: {
                HStack {
                    Text("menu_bar.action.launch_at_login")
                    Spacer()
                    if launchAtLoginEnabled {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .disabled(!LaunchAtLoginManager.isSupported)

            Divider()

            Picker("menu_bar.language.title", selection: $languageManager.currentLanguage) {
                ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .onChange(of: languageManager.currentLanguage) { _, _ in
                restartApp()
            }

            Divider()

            Button("menu_bar.action.quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            refreshLaunchAtLoginStatus()
        }
    }

    private func selectAndApply(profileID: UUID) {
        profileStore.switchProfileAndApply(profileID: profileID)
    }

    private func toggleLaunchAtLogin() {
        let target = !launchAtLoginEnabled
        do {
            try LaunchAtLoginManager.setEnabled(target)
        } catch {
            // keep current state when system registration fails
        }
        refreshLaunchAtLoginStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled()
    }

    private func editSettingsPath() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: ("~/.claude" as NSString).expandingTildeInPath, isDirectory: true)
        panel.title = String(localized: "menu_bar.action.edit_settings_path")
        let filterDelegate = SettingsJSONOpenPanelDelegate()
        panel.delegate = filterDelegate

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        profileStore.updateClaudeSettingsFilePath(url)
    }

    private func restartApp() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "sleep 1 && open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        NSApplication.shared.terminate(nil)
    }
}

private final class SettingsJSONOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            return true
        }
        return url.lastPathComponent == "settings.json"
    }
}

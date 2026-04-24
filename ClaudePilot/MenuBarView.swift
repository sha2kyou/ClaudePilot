import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var profileStore: ProfileStore
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
}

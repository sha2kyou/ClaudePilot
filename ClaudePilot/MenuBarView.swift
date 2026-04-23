import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if profileStore.profiles.isEmpty {
                Text("暂无配置")
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

            Button("编辑配置…") {
                NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            }

            Divider()

            Button {
                toggleLaunchAtLogin()
            } label: {
                HStack {
                    Text("开机启动")
                    Spacer()
                    if launchAtLoginEnabled {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .disabled(!LaunchAtLoginManager.isSupported)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            refreshLaunchAtLoginStatus()
        }
    }

    private func selectAndApply(profileID: UUID) {
        profileStore.currentProfileID = profileID
        profileStore.applyCurrentProfile()
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

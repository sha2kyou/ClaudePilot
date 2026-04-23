import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var profileStore: ProfileStore

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

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func selectAndApply(profileID: UUID) {
        profileStore.currentProfileID = profileID
        profileStore.applyCurrentProfile()
    }
}

import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ClaudePilot"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text(appName)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(0.3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                AboutVersionRow(label: String(localized: "about.version"), value: version)
                AboutVersionRow(label: String(localized: "about.build"), value: build)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Text("© 2026 Zhuoming Liu. \(String(localized: "about.copyright"))")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AboutVersionRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.9))
        }
    }
}

#Preview {
    AboutView()
}

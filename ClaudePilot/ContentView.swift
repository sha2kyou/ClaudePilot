import AppKit
import SwiftUI

private let customKVColumnWidth: CGFloat = 220
private let customKVActionWidth: CGFloat = 20

struct ContentView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var selectedProfileID: UUID?
    @State private var profilePendingDeleteID: UUID?
    @State private var confirmingDelete = false
    @State private var isLoadingSelection = false
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var apiKey: String = ""
    @State private var customEnvEntries: [CustomEnvEntry] = []

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedProfileID) {
                    ForEach(profileStore.profiles) { profile in
                        HStack(spacing: 8) {
                            Text(profile.name)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Button {
                                profilePendingDeleteID = profile.id
                                confirmingDelete = true
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("删除配置")
                        }
                            .tag(Optional(profile.id))
                    }
                }
            }
            .navigationTitle("配置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addProfileFromList()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("新增配置")
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220, maxWidth: 220)
            .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
        } detail: {
            if selectedProfileID == nil {
                ContentUnavailableView("请选择左侧配置", systemImage: "sidebar.left")
            } else {
                Form {
                    Section("基本信息") {
                        LabeledContent("配置名称") {
                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    Section("默认配置") {
                        LabeledContent {
                            TextField("", text: $baseURL)
                                .textFieldStyle(.roundedBorder)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Base URL")
                                Text("env.ANTHROPIC_BASE_URL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent {
                            SecureField("", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("API Key")
                                Text("env.ANTHROPIC_API_KEY")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent {
                            TextField("", text: $model)
                                .textFieldStyle(.roundedBorder)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Model")
                                Text("env.ANTHROPIC_MODEL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("自定义配置") {
                        CustomEnvEntriesEditor(entries: $customEnvEntries)
                    }
                    Section("JSON 配置预览") {
                        ScrollView {
                            Text(previewJSONText)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(minHeight: 180)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .onAppear {
            selectedProfileID = profileStore.currentProfileID ?? profileStore.profiles.first?.id
            loadSelection()
        }
        .onChange(of: selectedProfileID) { _, _ in
            loadSelection()
        }
        .onChange(of: name) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .onChange(of: baseURL) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .onChange(of: model) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .onChange(of: apiKey) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .onChange(of: customEnvEntries) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .confirmationDialog("确认删除当前配置？", isPresented: $confirmingDelete) {
            Button("删除", role: .destructive) {
                deletePendingProfile()
            }
            Button("取消", role: .cancel) { }
        }
    }

    private func loadSelection() {
        profileStore.clearStatus()
        isLoadingSelection = true
        defer { isLoadingSelection = false }

        guard let id = selectedProfileID,
              let profile = profileStore.profiles.first(where: { $0.id == id }) else {
            name = ""
            baseURL = ""
            model = ""
            apiKey = ""
            customEnvEntries = []
            return
        }

        name = profile.name
        baseURL = profile.baseURL
        model = profile.model
        apiKey = profile.apiKey
        customEnvEntries = profile.customEnvEntries
    }

    private func saveSelectedProfile() {
        guard let id = selectedProfileID else {
            return
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCustomEntries = normalizedEntries(customEnvEntries)

        guard !normalizedName.isEmpty else {
            return
        }

        let updated = ClaudeProfile(
            id: id,
            name: normalizedName,
            baseURL: normalizedBaseURL,
            model: normalizedModel,
            apiKey: normalizedAPIKey,
            customEnvEntries: normalizedCustomEntries
        )
        profileStore.updateProfile(updated)
    }

    private func deletePendingProfile() {
        guard let id = profilePendingDeleteID else {
            return
        }
        profilePendingDeleteID = nil
        profileStore.deleteProfile(id: id)
        selectedProfileID = profileStore.profiles.first?.id
    }

    private func autoSaveAndApplyIfNeeded() {
        guard !isLoadingSelection,
              let id = selectedProfileID,
              let profile = profileStore.profiles.first(where: { $0.id == id }) else {
            return
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCustomEntries = normalizedEntries(customEnvEntries)

        let hasChanges = normalizedName != profile.name
            || normalizedBaseURL != profile.baseURL
            || normalizedModel != profile.model
            || normalizedAPIKey != profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            || normalizedCustomEntries != normalizedEntries(profile.customEnvEntries)
        guard hasChanges else {
            return
        }

        saveSelectedProfile()
    }

    private func addProfileFromList() {
        let baseName = "新配置"
        let normalizedExistingNames = Set(
            profileStore.profiles.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        let newName: String
        if !normalizedExistingNames.contains(baseName) {
            newName = baseName
        } else {
            var index = 2
            var candidate = "\(baseName) \(index)"
            while normalizedExistingNames.contains(candidate) {
                index += 1
                candidate = "\(baseName) \(index)"
            }
            newName = candidate
        }
        profileStore.addProfile(
            name: newName,
            baseURL: "",
            model: "",
            apiKey: "",
            customEnvEntries: []
        )
        selectedProfileID = profileStore.profiles.last?.id
    }

    private func normalizedEntries(_ entries: [CustomEnvEntry]) -> [CustomEnvEntry] {
        entries.map { entry in
            CustomEnvEntry(
                id: entry.id,
                keyPath: entry.keyPath.trimmingCharacters(in: .whitespacesAndNewlines),
                value: entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private var previewJSONText: String {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCustomEntries = normalizedEntries(customEnvEntries)

        let builtInEntries: [CustomEnvEntry] = [
            CustomEnvEntry(keyPath: "env.ANTHROPIC_BASE_URL", value: normalizedBaseURL),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_API_KEY", value: normalizedAPIKey),
            CustomEnvEntry(keyPath: "env.ANTHROPIC_MODEL", value: normalizedModel)
        ]

        var root: [String: Any] = [:]
        for entry in builtInEntries + normalizedCustomEntries {
            let pathComponents = entry.keyPath
                .split(separator: ".")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !pathComponents.isEmpty,
                  !entry.value.isEmpty else {
                continue
            }
            setPreviewValue(in: &root, path: pathComponents, value: entry.value)
        }

        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(
                  withJSONObject: root,
                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func setPreviewValue(in root: inout [String: Any], path: [String], value: String) {
        guard let first = path.first else {
            return
        }
        if path.count == 1 {
            root[first] = value
            return
        }

        var child = root[first] as? [String: Any] ?? [:]
        setPreviewValue(in: &child, path: Array(path.dropFirst()), value: value)
        root[first] = child
    }
}

private struct CustomEnvEntriesEditor: View {
    @Binding var entries: [CustomEnvEntry]
    @State private var entryPendingDeleteID: UUID?
    @State private var confirmingDeleteEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Button {
                    entries.append(CustomEnvEntry())
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("新增自定义配置")
            }

            HStack(spacing: 8) {
                Text("键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: customKVColumnWidth, alignment: .leading)
                Text("值")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: customKVColumnWidth, alignment: .leading)
                Color.clear.frame(width: customKVActionWidth)
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    FixedWidthTextField(text: $entries[index].keyPath)
                        .frame(width: customKVColumnWidth, height: 22)
                    FixedWidthTextField(text: $entries[index].value)
                        .frame(width: customKVColumnWidth, height: 22)
                    Button {
                        let key = entries[index].keyPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = entries[index].value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if key.isEmpty && value.isEmpty {
                            entries.remove(at: index)
                            return
                        }
                        entryPendingDeleteID = entries[index].id
                        confirmingDeleteEntry = true
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("删除自定义配置")
                    .frame(width: customKVActionWidth)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("确认删除该自定义配置？", isPresented: $confirmingDeleteEntry) {
            Button("删除", role: .destructive) {
                guard let id = entryPendingDeleteID,
                      let index = entries.firstIndex(where: { $0.id == id }) else {
                    entryPendingDeleteID = nil
                    return
                }
                entries.remove(at: index)
                entryPendingDeleteID = nil
            }
            Button("取消", role: .cancel) {
                entryPendingDeleteID = nil
            }
        }
    }
}

private struct FixedWidthTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.bezelStyle = .roundedBezel
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            text = field.stringValue
        }
    }
}

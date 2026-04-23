import SwiftUI

struct ContentView: View {
    struct CreateDraft {
        var name: String = ""
        var baseURL: String = ""
        var model: String = ""
        var apiKey: String = ""
        var apiKeyPath: String = "env.ANTHROPIC_API_KEY"
    }

    @EnvironmentObject private var profileStore: ProfileStore
    @State private var selectedProfileID: UUID?
    @State private var profilePendingDeleteID: UUID?
    @State private var confirmingDelete = false
    @State private var showingCreateSheet = false
    @State private var isLoadingSelection = false
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var apiKey: String = ""
    @State private var apiKeyPath: String = "env.ANTHROPIC_API_KEY"

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedProfileID) {
                    ForEach(profileStore.profiles) { profile in
                        Text(profile.name)
                            .tag(Optional(profile.id))
                            .contextMenu {
                                Button("删除配置", role: .destructive) {
                                    profilePendingDeleteID = profile.id
                                    confirmingDelete = true
                                }
                            }
                    }
                }
            }
            .navigationTitle("配置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
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
                    Section("配置详情") {
                        LabeledContent("配置名称") {
                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledContent("Base URL") {
                            TextField("", text: $baseURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledContent("API Key") {
                            SecureField("", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledContent("API Key 路径") {
                            TextField("env.ANTHROPIC_API_KEY", text: $apiKeyPath)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledContent("Model") {
                            TextField("", text: $model)
                                .textFieldStyle(.roundedBorder)
                        }
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
        .onChange(of: apiKeyPath) { _, _ in
            autoSaveAndApplyIfNeeded()
        }
        .confirmationDialog("确认删除当前配置？", isPresented: $confirmingDelete) {
            Button("删除", role: .destructive) {
                deletePendingProfile()
            }
            Button("取消", role: .cancel) { }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProfileSheet(
                onCancel: {
                    showingCreateSheet = false
                },
                onSave: { draft in
                    createProfile(draft)
                    showingCreateSheet = false
                }
            )
        }
    }

    private var canSaveProfile: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            apiKeyPath = "env.ANTHROPIC_API_KEY"
            return
        }

        name = profile.name
        baseURL = profile.baseURL
        model = profile.model
        apiKey = profile.apiKey
        apiKeyPath = profile.apiKeyPath
    }

    private func saveSelectedProfile() {
        guard let id = selectedProfileID else {
            return
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKeyPath = apiKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else {
            return
        }

        let updated = ClaudeProfile(
            id: id,
            name: normalizedName,
            baseURL: normalizedBaseURL,
            model: normalizedModel,
            apiKey: normalizedAPIKey,
            apiKeyPath: normalizedAPIKeyPath.isEmpty ? "env.ANTHROPIC_API_KEY" : normalizedAPIKeyPath
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
        let normalizedAPIKeyPath = apiKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasChanges = normalizedName != profile.name
            || normalizedBaseURL != profile.baseURL
            || normalizedModel != profile.model
            || normalizedAPIKey != profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            || normalizedAPIKeyPath != profile.apiKeyPath
        guard hasChanges else {
            return
        }

        saveSelectedProfile()
    }

    private func createProfile(_ draft: CreateDraft) {
        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKeyPath = draft.apiKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            return
        }

        profileStore.addProfile(
            name: normalizedName,
            baseURL: normalizedBaseURL,
            model: normalizedModel,
            apiKey: normalizedAPIKey,
            apiKeyPath: normalizedAPIKeyPath.isEmpty ? "env.ANTHROPIC_API_KEY" : normalizedAPIKeyPath
        )
    }
}

private struct CreateProfileSheet: View {
    @State private var draft = ContentView.CreateDraft()
    let onCancel: () -> Void
    let onSave: (ContentView.CreateDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("配置名称") {
                    TextField("", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Base URL") {
                    TextField("", text: $draft.baseURL)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("API Key") {
                    SecureField("", text: $draft.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("API Key 路径") {
                    TextField("env.ANTHROPIC_API_KEY", text: $draft.apiKeyPath)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Model") {
                    TextField("", text: $draft.model)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新增配置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 500)
    }
}

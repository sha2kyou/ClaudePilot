import SwiftUI
import CoreWLAN

private let customKVColumnWidth: CGFloat = 220

struct TriggerListView: View {
    @ObservedObject private var triggerStore = TriggerStore.shared
    @ObservedObject private var wifiMonitor = WiFiMonitor.shared
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var selectedTriggerID: UUID?
    @State private var pendingDeleteID: UUID?
    @State private var confirmingDelete = false
    @State private var showTriggerLog = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedTriggerID) {
                    ForEach(triggerStore.triggers) { trigger in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trigger.name)
                                    .lineLimit(1)
                                Text(conditionSummary(trigger))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            if isWiFiTrigger(trigger) && wifiMonitor.isLocationDenied {
                                Image(systemName: "location.slash.fill")
                                    .foregroundStyle(.orange)
                                    .help(String(localized: "trigger.warning.location_denied"))
                            } else if isProfileMissing(trigger) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .help(String(localized: "trigger.warning.profile_deleted"))
                            }

                            Button {
                                pendingDeleteID = trigger.id
                                confirmingDelete = true
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help(String(localized: "trigger.help.delete"))
                        }
                        .tag(Optional(trigger.id))
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("trigger.navigation.title")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showTriggerLog = true
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .help(String(localized: "trigger.help.log"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addTrigger()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(String(localized: "trigger.help.add"))
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220, maxWidth: 220)
            .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
        } detail: {
            if let id = selectedTriggerID,
               let trigger = triggerStore.triggers.first(where: { $0.id == id }) {
                TriggerDetailView(trigger: trigger)
                    .environmentObject(profileStore)
                    .id(id)
            } else {
                EmptyView()
            }
        }
        .confirmationDialog(
            String(localized: "trigger.dialog.delete.title"),
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "content.action.delete"), role: .destructive) {
                if let id = pendingDeleteID {
                    if selectedTriggerID == id { selectedTriggerID = nil }
                    triggerStore.deleteTrigger(id: id)
                }
            }
            Button(String(localized: "content.action.cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showTriggerLog) {
            TriggerLogSheet()
        }
        .onAppear {
            ensureSelection()
        }
        .onChange(of: triggerStore.triggers) { _, _ in
            ensureSelection()
        }
    }

    private func addTrigger() {
        guard let firstProfile = profileStore.profiles.first else { return }
        let trigger = Trigger(
            name: String(localized: "trigger.default_name"),
            condition: .wifiConnected(ssid: ""),
            targetProfileID: firstProfile.id
        )
        triggerStore.addTrigger(trigger)
        selectedTriggerID = trigger.id
    }

    private func isProfileMissing(_ trigger: Trigger) -> Bool {
        profileStore.profiles.first(where: { $0.id == trigger.targetProfileID }) == nil
    }

    private func isWiFiTrigger(_ trigger: Trigger) -> Bool {
        if case .wifiConnected = trigger.condition { return true }
        return false
    }

    private func conditionSummary(_ trigger: Trigger) -> String {
        let arrow = "→"
        let profileName = profileStore.profiles.first(where: { $0.id == trigger.targetProfileID })?.name
            ?? String(localized: "trigger.profile.unknown")
        return "\(trigger.condition.displaySummary) \(arrow) \(profileName)"
    }

    private func ensureSelection() {
        if let selectedTriggerID,
           triggerStore.triggers.contains(where: { $0.id == selectedTriggerID }) {
            return
        }
        selectedTriggerID = triggerStore.triggers.first?.id
    }
}

private struct TriggerLogSheet: View {
    @ObservedObject private var triggerStore = TriggerStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if triggerStore.triggerLogEntries.isEmpty {
                    ContentUnavailableView("trigger.log.empty", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(triggerStore.triggerLogEntries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(entry.date.formatted(date: .omitted, time: .standard))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            Text(entry.message)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 5)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("trigger.log.title")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "trigger.log.done")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "trigger.log.clear")) {
                        triggerStore.clearTriggerLog()
                    }
                    .disabled(triggerStore.triggerLogEntries.isEmpty)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}

struct TriggerDetailView: View {
    @ObservedObject private var triggerStore = TriggerStore.shared
    @ObservedObject private var wifiMonitor = WiFiMonitor.shared
    @EnvironmentObject private var profileStore: ProfileStore

    let trigger: Trigger

    @State private var name: String
    @State private var conditionType: ConditionType
    @State private var wifiSSID: String
    @State private var timeDate: Date
    @State private var targetProfileID: UUID?
    @State private var isLoading = false

    enum ConditionType: CaseIterable {
        case wifi, time

        var localizedName: String {
            switch self {
            case .wifi: return "WiFi"
            case .time: return String(localized: "trigger.condition.type.time")
            }
        }
    }

    init(trigger: Trigger) {
        self.trigger = trigger
        _name = State(initialValue: trigger.name)
        _targetProfileID = State(initialValue: trigger.targetProfileID)

        switch trigger.condition {
        case .wifiConnected(let ssid):
            _conditionType = State(initialValue: .wifi)
            _wifiSSID = State(initialValue: ssid)
            _timeDate = State(initialValue: Self.makeDate(hour: 9, minute: 0))
        case .dailyTime(let h, let m):
            _conditionType = State(initialValue: .time)
            _wifiSSID = State(initialValue: "")
            _timeDate = State(initialValue: Self.makeDate(hour: h, minute: m))
        }
    }

    var body: some View {
        Form {
            if conditionType == .wifi && wifiMonitor.isLocationDenied {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("trigger.warning.location_denied.title")
                                .font(.headline)
                            Text("trigger.warning.location_denied.detail")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("trigger.warning.location_denied.open_settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("content.section.basic") {
                LabeledContent("trigger.editor.field.name") {
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: customKVColumnWidth)
                }
            }

            Section("trigger.editor.section.condition") {
                LabeledContent("trigger.editor.field.condition_type") {
                    Picker("", selection: $conditionType) {
                        ForEach(ConditionType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: customKVColumnWidth)
                }

                if conditionType == .wifi {
                    LabeledContent("trigger.editor.field.ssid") {
                        TextField("", text: $wifiSSID)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: customKVColumnWidth)
                    }
                } else {
                    LabeledContent("trigger.editor.field.time") {
                        DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }

            Section("trigger.editor.section.action") {
                LabeledContent("trigger.editor.field.target_profile") {
                    Picker("", selection: $targetProfileID) {
                        ForEach(profileStore.profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: customKVColumnWidth)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: name) { _, _ in autoSave() }
        .onChange(of: conditionType) { _, _ in autoSave() }
        .onChange(of: wifiSSID) { _, _ in autoSave() }
        .onChange(of: timeDate) { _, _ in autoSave() }
        .onChange(of: targetProfileID) { _, _ in autoSave() }
    }

    private func autoSave() {
        guard !isLoading else { return }
        guard let profileID = targetProfileID else { return }

        let condition: TriggerCondition
        switch conditionType {
        case .wifi:
            let ssid = wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            condition = .wifiConnected(ssid: ssid)
        case .time:
            let c = Calendar.current.dateComponents([.hour, .minute], from: timeDate)
            condition = .dailyTime(hour: c.hour ?? 9, minute: c.minute ?? 0)
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = Trigger(
            id: trigger.id,
            name: normalizedName.isEmpty ? condition.displaySummary : normalizedName,
            condition: condition,
            targetProfileID: profileID
        )
        triggerStore.updateTrigger(updated)
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }
}

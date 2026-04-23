import Foundation

struct CustomEnvEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var keyPath: String
    var value: String

    init(id: UUID = UUID(), keyPath: String = "", value: String = "") {
        self.id = id
        self.keyPath = keyPath
        self.value = value
    }
}

struct ClaudeProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var baseURL: String
    var model: String
    var apiKey: String
    var customEnvEntries: [CustomEnvEntry]

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        model: String,
        apiKey: String = "",
        customEnvEntries: [CustomEnvEntry] = []
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.customEnvEntries = customEnvEntries
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case model
        case apiKey
        case customEnvEntries
        case apiKeyPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        let decodedApiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        let decodedCustomEnvEntries = try container.decodeIfPresent([CustomEnvEntry].self, forKey: .customEnvEntries) ?? []
        let legacyAPIKeyPath = try container.decodeIfPresent(String.self, forKey: .apiKeyPath) ?? "env.ANTHROPIC_API_KEY"

        if decodedCustomEnvEntries.isEmpty,
           legacyAPIKeyPath != "env.ANTHROPIC_API_KEY",
           !decodedApiKey.isEmpty {
            apiKey = ""
            customEnvEntries = [CustomEnvEntry(keyPath: legacyAPIKeyPath, value: decodedApiKey)]
        } else {
            apiKey = decodedApiKey
            customEnvEntries = decodedCustomEnvEntries
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(customEnvEntries, forKey: .customEnvEntries)
    }
}

import Foundation

struct ClaudeProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var baseURL: String
    var model: String
    var apiKey: String
    var apiKeyPath: String

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        model: String,
        apiKey: String = "",
        apiKeyPath: String = "env.ANTHROPIC_API_KEY"
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.apiKeyPath = apiKeyPath
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case model
        case apiKey
        case apiKeyPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        apiKeyPath = try container.decodeIfPresent(String.self, forKey: .apiKeyPath) ?? "env.ANTHROPIC_API_KEY"
    }
}

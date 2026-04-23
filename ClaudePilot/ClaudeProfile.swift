import Foundation

struct ClaudeProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var baseURL: String
    var model: String

    init(id: UUID = UUID(), name: String, baseURL: String, model: String) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
    }
}

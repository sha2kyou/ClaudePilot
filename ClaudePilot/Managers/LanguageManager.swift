import Foundation
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    enum Language: String, CaseIterable {
        case system = "system"
        case chinese = "zh-Hans"
        case english = "en"

        var displayName: String {
            switch self {
            case .system:
                return String(localized: "language.follow_system")
            case .chinese:
                return "中文"
            case .english:
                return "English"
            }
        }
    }

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.userDefaultsKey)
            applyLanguage()
        }
    }

    private static let userDefaultsKey = "app.language.preference"

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? Language.system.rawValue
        currentLanguage = Language(rawValue: savedLanguage) ?? .system
        applyLanguageOnStartup()
    }

    private func applyLanguageOnStartup() {
        switch currentLanguage {
        case .system:
            return
        case .chinese:
            UserDefaults.standard.set(["zh-Hans", "zh-CN"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    private func applyLanguage() {
        switch currentLanguage {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        case .chinese:
            UserDefaults.standard.set(["zh-Hans", "zh-CN"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
}

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var configDict: [String: Any]?
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Warning: Could not load Config.plist. Make sure to copy Config.plist.template to Config.plist and fill in your actual values.")
            return
        }
        configDict = dict
    }
    
    func getString(for key: String) -> String? {
        return configDict?[key] as? String
    }
    
    func getString(for key: String, defaultValue: String) -> String {
        return getString(for: key) ?? defaultValue
    }
    
    // MARK: - Appwrite Configuration
    
    var appwriteEndpoint: String {
        return getString(for: "AppwriteEndpoint", defaultValue: "")
    }
    
    var appwriteProjectId: String {
        return getString(for: "AppwriteProjectId", defaultValue: "")
    }
    
    var appwriteDatabaseId: String {
        return getString(for: "AppwriteDatabaseId", defaultValue: "")
    }
    
    var appwriteCollectionId: String {
        return getString(for: "AppwriteCollectionId", defaultValue: "")
    }
    
    var appwriteApiKey: String {
        return getString(for: "AppwriteApiKey", defaultValue: "")
    }
} 
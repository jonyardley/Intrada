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
    

} 
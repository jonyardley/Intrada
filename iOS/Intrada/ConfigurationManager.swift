import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()

    private var configDict: [String: Any]?
    private var currentEnvironment: String = "development"

    // Use generated configuration as fallback
    private var generatedConfig: GeneratedConfig.Type = GeneratedConfig.self

    private init() {
        loadConfiguration()
    }

    private func loadConfiguration() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
        else {
            print("⚠️ Could not load Config.plist. Using default development configuration.")
            print("🔍 Bundle path: \(Bundle.main.bundlePath)")
            print("🔍 Config.plist path: \(Bundle.main.path(forResource: "Config", ofType: "plist") ?? "nil")")
            return
        }

        configDict = dict

        // Determine environment based on build configuration
        #if DEBUG
        // For device builds, you might want to force a specific environment
        if let forcedEnv = ProcessInfo.processInfo.environment["FORCE_ENVIRONMENT"] {
            currentEnvironment = forcedEnv
            print("🔧 Forced environment from environment variable: \(forcedEnv)")
        } else {
            currentEnvironment = dict["CurrentEnvironment"] as? String ?? generatedConfig.currentEnvironment
        }
        #else
        currentEnvironment = "production"
        #endif

        print("🔧 Configuration loaded for environment: \(currentEnvironment)")
    }

    // MARK: - Environment Configuration

    private var environmentConfig: [String: Any]? {
        guard let environments = configDict?["Environments"] as? [String: [String: Any]] else {
            print("⚠️ No environments found in Config.plist")
            return nil
        }
        return environments[currentEnvironment]
    }

    // MARK: - Public API

    /// Get the current environment name
    var environment: String {
        return currentEnvironment
    }

    /// Get the server base URL for the current environment
    var serverBaseURL: String {
        let url = getEnvironmentString(for: "ServerBaseURL", defaultValue: generatedConfig.serverBaseURL)
        print("🔧 ConfigurationManager.serverBaseURL: \(url) (environment: \(currentEnvironment))")
        return url
    }

    /// Get the display name for the current environment
    var displayName: String {
        return getEnvironmentString(for: "DisplayName", defaultValue: generatedConfig.displayName)
    }

    /// Check if we're in development mode
    var isDevelopment: Bool {
        return currentEnvironment == "development"
    }

    /// Check if we're in production mode
    var isProduction: Bool {
        return currentEnvironment == "production"
    }

    // MARK: - Private Helpers

    private func getEnvironmentString(for key: String, defaultValue: String) -> String {
        return environmentConfig?[key] as? String ?? defaultValue
    }

    // MARK: - Legacy API (for backward compatibility)

    func getString(for key: String) -> String? {
        return environmentConfig?[key] as? String ?? configDict?[key] as? String
    }

    func getString(for key: String, defaultValue: String) -> String {
        return getString(for: key) ?? defaultValue
    }

    // MARK: - Debug Information

    func printConfiguration() {
        print("🔧 Current Configuration:")
        print("   Environment: \(environment)")
        print("   Server URL: \(serverBaseURL)")
        print("   Display Name: \(displayName)")
        print("   Is Development: \(isDevelopment)")
        print("   Is Production: \(isProduction)")
    }
}

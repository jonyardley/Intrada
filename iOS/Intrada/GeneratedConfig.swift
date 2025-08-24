// Generated configuration file - DO NOT EDIT MANUALLY
// This file is auto-generated from Config.plist

import Foundation

/// Auto-generated configuration from Config.plist
public struct GeneratedConfig {

    /// Current environment
    public static let currentEnvironment: String = {
        // Try to read from Config.plist first
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let env = dict["CurrentEnvironment"] as? String {
            return env
        }

        // Fallback to development
        return "development"
    }()

    /// Server base URL for current environment
    public static let serverBaseURL: String = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let environments = dict["Environments"] as? [String: [String: Any]],
           let currentEnv = environments[currentEnvironment],
           let url = currentEnv["ServerBaseURL"] as? String {
            return url
        }

        // Fallback URLs
        switch currentEnvironment {
        case "development":
            return "http://localhost:3000"
        case "staging":
            return "https://staging.intrada.app"
        case "production":
            return "https://api.intrada.app"
        default:
            return "http://localhost:3000"
        }
    }()

    /// Display name for current environment
    public static let displayName: String = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let environments = dict["Environments"] as? [String: [String: Any]],
           let currentEnv = environments[currentEnvironment],
           let name = currentEnv["DisplayName"] as? String {
            return name
        }

        // Fallback names
        switch currentEnvironment {
        case "development":
            return "Intrada (Dev)"
        case "staging":
            return "Intrada (Staging)"
        case "production":
            return "Intrada"
        default:
            return "Intrada"
        }
    }()

    /// Check if running in development mode
    public static var isDevelopment: Bool {
        return currentEnvironment == "development"
    }

    /// Check if running in staging mode
    public static var isStaging: Bool {
        return currentEnvironment == "staging"
    }

    /// Check if running in production mode
    public static var isProduction: Bool {
        return currentEnvironment == "production"
    }

    /// Get configuration for a specific environment
    public static func config(for environment: String) -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let environments = dict["Environments"] as? [String: [String: Any]] else {
            return nil
        }

        return environments[environment]
    }

    /// Get server URL for a specific environment
    public static func serverURL(for environment: String) -> String? {
        return config(for: environment)?["ServerBaseURL"] as? String
    }

    /// Get display name for a specific environment
    public static func displayName(for environment: String) -> String? {
        return config(for: environment)?["DisplayName"] as? String
    }
}

// MARK: - Environment-specific convenience properties

public extension GeneratedConfig {
    /// Development environment configuration
    static var development: [String: Any]? {
        return config(for: "development")
    }

    /// Staging environment configuration
    static var staging: [String: Any]? {
        return config(for: "staging")
    }

    /// Production environment configuration
    static var production: [String: Any]? {
        return config(for: "production")
    }
}

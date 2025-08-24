use crate::app::{Effect, Event, HttpResult};
/// HTTP utilities for common request patterns
use crux_core::Command;
use crux_http::command::Http;
use serde::{Deserialize, Serialize};
use std::str::FromStr;

/// Creates a GET request command
pub fn get_request<T: for<'de> Deserialize<'de> + 'static>(
    url: &str,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    Http::get(url)
        .expect_json()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a POST request command with JSON body
pub fn post_json_request<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
    url: &str,
    body: &B,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let json_string = serde_json::to_string(body).expect("Failed to serialize JSON");

    Http::post(url)
        .header("Content-Type", "application/json")
        .body(json_string)
        .expect_json::<T>()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a PUT request command with JSON body
pub fn put_json_request<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
    url: &str,
    body: &B,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let json_string = serde_json::to_string(body).expect("Failed to serialize JSON");

    Http::put(url)
        .header("Content-Type", "application/json")
        .body(json_string)
        .expect_json::<T>()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a DELETE request command
pub fn delete_request<T: for<'de> Deserialize<'de> + 'static>(
    url: &str,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    Http::delete(url)
        .expect_json()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Environment configuration
#[derive(Debug, Clone, PartialEq)]
pub enum Environment {
    Development,
    Staging,
    Production,
}

impl FromStr for Environment {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "development" | "dev" => Ok(Environment::Development),
            "staging" | "stage" => Ok(Environment::Staging),
            "production" | "prod" => Ok(Environment::Production),
            _ => Ok(Environment::Development), // Default fallback
        }
    }
}

impl Environment {
    pub fn default_base_url(&self) -> &'static str {
        match self {
            Environment::Development => "http://localhost:3000",
            Environment::Staging => "https://staging.intrada.app",
            Environment::Production => "https://api.intrada.app",
        }
    }
}

/// Base URL configuration
#[derive(Debug, Clone)]
pub struct ApiConfig {
    pub base_url: String,
    pub environment: Environment,
}

impl Default for ApiConfig {
    fn default() -> Self {
        let env = Environment::Development;
        Self {
            base_url: env.default_base_url().to_string(),
            environment: env,
        }
    }
}

impl ApiConfig {
    /// Create a new ApiConfig with a custom base URL
    pub fn new(base_url: String) -> Self {
        Self {
            environment: Environment::Development, // Default when custom URL provided
            base_url,
        }
    }

    /// Create a new ApiConfig for a specific environment
    pub fn for_environment(env: Environment) -> Self {
        Self {
            base_url: env.default_base_url().to_string(),
            environment: env,
        }
    }

    /// Create a new ApiConfig from environment string
    pub fn from_env_string(env_str: &str) -> Self {
        let env = Environment::from_str(env_str).unwrap_or(Environment::Development);
        Self::for_environment(env)
    }

    /// Check if running in development mode
    pub fn is_development(&self) -> bool {
        matches!(self.environment, Environment::Development)
    }

    /// Check if running in production mode
    pub fn is_production(&self) -> bool {
        matches!(self.environment, Environment::Production)
    }
}

impl ApiConfig {
    /// Constructs a full URL from a path
    pub fn url(&self, path: &str) -> String {
        format!("{}{}", self.base_url, path)
    }

    /// GET request to an API endpoint
    pub fn get<T: for<'de> Deserialize<'de> + 'static>(
        &self,
        path: &str,
        callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
    ) -> Command<Effect, Event> {
        get_request(&self.url(path), callback)
    }

    /// POST request to an API endpoint
    pub fn post<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
        &self,
        path: &str,
        body: &B,
        callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
    ) -> Command<Effect, Event> {
        post_json_request(&self.url(path), body, callback)
    }

    /// PUT request to an API endpoint
    pub fn put<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
        &self,
        path: &str,
        body: &B,
        callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
    ) -> Command<Effect, Event> {
        put_json_request(&self.url(path), body, callback)
    }

    /// DELETE request to an API endpoint
    pub fn delete<T: for<'de> Deserialize<'de> + 'static>(
        &self,
        path: &str,
        callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
    ) -> Command<Effect, Event> {
        delete_request(&self.url(path), callback)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_environment_from_string() {
        assert_eq!(
            Environment::from_str("development").unwrap(),
            Environment::Development
        );
        assert_eq!(
            Environment::from_str("dev").unwrap(),
            Environment::Development
        );
        assert_eq!(
            Environment::from_str("staging").unwrap(),
            Environment::Staging
        );
        assert_eq!(
            Environment::from_str("stage").unwrap(),
            Environment::Staging
        );
        assert_eq!(
            Environment::from_str("production").unwrap(),
            Environment::Production
        );
        assert_eq!(
            Environment::from_str("prod").unwrap(),
            Environment::Production
        );
        assert_eq!(
            Environment::from_str("unknown").unwrap(),
            Environment::Development
        );
    }

    #[test]
    fn test_environment_default_urls() {
        assert_eq!(
            Environment::Development.default_base_url(),
            "http://localhost:3000"
        );
        assert_eq!(
            Environment::Staging.default_base_url(),
            "https://staging.intrada.app"
        );
        assert_eq!(
            Environment::Production.default_base_url(),
            "https://api.intrada.app"
        );
    }

    #[test]
    fn test_api_config_default() {
        let config = ApiConfig::default();
        assert_eq!(config.base_url, "http://localhost:3000");
        assert_eq!(config.environment, Environment::Development);
        assert!(config.is_development());
        assert!(!config.is_production());
    }

    #[test]
    fn test_api_config_url() {
        let config = ApiConfig::default();
        assert_eq!(config.url("/goals"), "http://localhost:3000/goals");
        assert_eq!(config.url("goals"), "http://localhost:3000goals");
    }

    #[test]
    fn test_api_config_for_environment() {
        let config = ApiConfig::for_environment(Environment::Production);
        assert_eq!(config.base_url, "https://api.intrada.app");
        assert_eq!(config.environment, Environment::Production);
        assert!(!config.is_development());
        assert!(config.is_production());
    }

    #[test]
    fn test_api_config_from_env_string() {
        let config = ApiConfig::from_env_string("staging");
        assert_eq!(config.base_url, "https://staging.intrada.app");
        assert_eq!(config.environment, Environment::Staging);
    }

    #[test]
    fn test_custom_api_config() {
        let config = ApiConfig::new("https://custom.api.com".to_string());
        assert_eq!(config.base_url, "https://custom.api.com");
        assert_eq!(config.url("/users"), "https://custom.api.com/users");
    }
}

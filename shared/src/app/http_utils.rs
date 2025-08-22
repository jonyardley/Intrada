use crate::app::{Effect, Event, HttpResult};
/// HTTP utilities for common request patterns
use crux_core::Command;
use crux_http::command::Http;
use serde::{Deserialize, Serialize};

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

/// Base URL configuration
pub struct ApiConfig {
    pub base_url: String,
}

impl Default for ApiConfig {
    fn default() -> Self {
        Self {
            base_url: "http://localhost:3000".to_string(),
        }
    }
}

impl ApiConfig {
    /// Create a new ApiConfig with a custom base URL
    pub fn new(base_url: String) -> Self {
        Self { base_url }
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
    fn test_api_config_url() {
        let config = ApiConfig::default();
        assert_eq!(config.url("/goals"), "http://localhost:3000/goals");
        assert_eq!(config.url("goals"), "http://localhost:3000goals");
    }

    #[test]
    fn test_custom_api_config() {
        let config = ApiConfig {
            base_url: "https://api.example.com".to_string(),
        };
        assert_eq!(config.url("/users"), "https://api.example.com/users");
    }
}

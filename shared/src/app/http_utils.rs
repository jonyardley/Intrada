use crate::app::{Effect, Event, HttpResult};
/// HTTP utilities for common request patterns
use crux_core::Command;
use crux_http::command::Http;
use serde::{Deserialize, Serialize};
use url::Url;

// Base API URL - can be overridden by platforms if needed
const API_BASE_URL: &str = "https://intrada-server.fly.dev";

/// Creates a GET request command using API base URL + path
pub fn api_get<T: for<'de> Deserialize<'de> + 'static>(
    path: &str,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let base = Url::parse(API_BASE_URL).unwrap();
    let url = base.join(path).unwrap();
    Http::get(url)
        .expect_json()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a GET request command for custom URLs (backwards compatibility)
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

/// Creates a POST request command with JSON body using API base URL + path
pub fn api_post<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
    path: &str,
    body: &B,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let base = Url::parse(API_BASE_URL).unwrap();
    let url = base.join(path).unwrap();
    let json_string = serde_json::to_string(body).expect("Failed to serialize JSON");

    Http::post(url)
        .header("Content-Type", "application/json")
        .body(json_string)
        .expect_json::<T>()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a POST request command with JSON body for custom URLs (backwards compatibility)
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

/// Creates a PUT request command with JSON body using API base URL + path
pub fn api_put<T: for<'de> Deserialize<'de> + 'static, B: Serialize>(
    path: &str,
    body: &B,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let base = Url::parse(API_BASE_URL).unwrap();
    let url = base.join(path).unwrap();
    let json_string = serde_json::to_string(body).expect("Failed to serialize JSON");

    Http::put(url)
        .header("Content-Type", "application/json")
        .body(json_string)
        .expect_json::<T>()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a PUT request command with JSON body for custom URLs (backwards compatibility)
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

/// Creates a DELETE request command using API base URL + path
pub fn api_delete<T: for<'de> Deserialize<'de> + 'static>(
    path: &str,
    callback: fn(HttpResult<crux_http::Response<T>, crux_http::HttpError>) -> Event,
) -> Command<Effect, Event> {
    let base = Url::parse(API_BASE_URL).unwrap();
    let url = base.join(path).unwrap();
    Http::delete(url)
        .expect_json()
        .build()
        .map(Into::into)
        .then_send(callback)
}

/// Creates a DELETE request command for custom URLs (backwards compatibility)
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

#[cfg(test)]
mod tests {
    // HTTP utility functions are tested through integration tests
    // since they require mocking the HTTP layer
}

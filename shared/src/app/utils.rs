/// Utility functions for common operations across the application
use crux_http::HttpError;
use uuid::Uuid;

/// Generates a new unique ID using UUID v4
pub fn generate_id() -> String {
    Uuid::new_v4().to_string()
}

/// Validates that a string is a valid UUID
pub fn is_valid_id(id: &str) -> bool {
    Uuid::parse_str(id).is_ok()
}

/// Generates a shortened ID for display purposes (first 8 characters)
pub fn short_id(id: &str) -> String {
    if id.len() >= 8 {
        id[..8].to_string()
    } else {
        id.to_string()
    }
}

/// Centralized HTTP error handling
pub fn handle_http_error(error: HttpError, operation: &str) -> Result<(), HttpError> {
    log::error!("HTTP {operation} failed: {error:?}");
    // TODO: In a real implementation, this would dispatch an error event
    // that the UI can handle to show user-friendly error messages
    Err(error)
}

/// Centralized operation result handling
pub fn handle_operation_result<T, E: std::fmt::Debug>(
    result: Result<T, E>,
    operation: &str,
) -> Option<T> {
    match result {
        Ok(value) => Some(value),
        Err(error) => {
            log::error!("Operation '{operation}' failed: {error:?}");
            None
        }
    }
}

/// Validates and logs validation errors
pub fn validate_and_log<T>(value: T, validator: impl Fn(&T) -> bool, error_msg: &str) -> Option<T> {
    if validator(&value) {
        Some(value)
    } else {
        log::warn!("Validation failed: {error_msg}");
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_id() {
        let id1 = generate_id();
        let id2 = generate_id();

        // IDs should be different
        assert_ne!(id1, id2);

        // IDs should be valid UUIDs
        assert!(is_valid_id(&id1));
        assert!(is_valid_id(&id2));

        // IDs should be 36 characters long (UUID format)
        assert_eq!(id1.len(), 36);
        assert_eq!(id2.len(), 36);
    }

    #[test]
    fn test_is_valid_id() {
        let valid_id = generate_id();
        assert!(is_valid_id(&valid_id));

        assert!(!is_valid_id("invalid-id"));
        assert!(!is_valid_id(""));
        assert!(!is_valid_id("not-a-uuid"));
    }

    #[test]
    fn test_short_id() {
        let id = "12345678-1234-5678-9012-123456789012";
        assert_eq!(short_id(id), "12345678");

        let short = "123";
        assert_eq!(short_id(short), "123");

        let empty = "";
        assert_eq!(short_id(empty), "");
    }
}

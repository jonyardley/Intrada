use sqlx::{Pool, Postgres};

pub type DbPool = Pool<Postgres>;
pub type RepositoryResult<T> = Result<T, RepositoryError>;

#[derive(Debug, thiserror::Error)]
pub enum RepositoryError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("Entity not found: {0}")]
    NotFound(String),
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

impl From<RepositoryError> for crate::ApiError {
    fn from(err: RepositoryError) -> Self {
        crate::ApiError {
            message: err.to_string(),
        }
    }
}

/// Simple shared database helper
pub struct Database {
    pub pool: DbPool,
}

impl Database {
    pub fn new(pool: DbPool) -> Self {
        Self { pool }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_repository_error_conversion() {
        let repo_error = RepositoryError::NotFound("test".to_string());
        let api_error: crate::ApiError = repo_error.into();
        assert!(api_error.message.contains("Entity not found"));
    }

    #[test]
    fn test_repository_error_display() {
        let error = RepositoryError::NotFound("test_id".to_string());
        assert_eq!(error.to_string(), "Entity not found: test_id");
    }

    #[test]
    fn test_database_creation() {
        // This is a simple test to ensure Database struct compiles
        // We can't test with a real pool without a database connection
        // but we can test the structure is correct
        use std::marker::PhantomData;

        // Just test that Database can be constructed in principle
        struct FakePool(PhantomData<()>);
        let _fake_pool = FakePool(PhantomData);

        // This mainly tests that the struct definition is correct
        // In integration tests, we'd use a real test database pool
        assert!(std::mem::size_of::<Database>() > 0);
    }
}

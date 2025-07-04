use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::schema::{AttributeSchema, CollectionSchema, DatabaseSchema, IndexSchema, Permission};

/// Migration system for managing database schema changes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Migration {
    pub id: String,
    pub name: String,
    pub description: String,
    pub version: String,
    pub timestamp: DateTime<Utc>,
    pub operations: Vec<MigrationOperation>,
    pub rollback_operations: Vec<MigrationOperation>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MigrationOperation {
    CreateDatabase {
        database_id: String,
        name: String,
    },
    CreateCollection {
        database_id: String,
        collection: CollectionSchema,
    },
    UpdateCollection {
        database_id: String,
        collection_id: String,
        name: Option<String>,
        permissions: Option<Vec<Permission>>,
    },
    DeleteCollection {
        database_id: String,
        collection_id: String,
    },
    CreateAttribute {
        database_id: String,
        collection_id: String,
        attribute: AttributeSchema,
    },
    UpdateAttribute {
        database_id: String,
        collection_id: String,
        key: String,
        required: Option<bool>,
        default: Option<serde_json::Value>,
    },
    DeleteAttribute {
        database_id: String,
        collection_id: String,
        key: String,
    },
    CreateIndex {
        database_id: String,
        collection_id: String,
        index: IndexSchema,
    },
    DeleteIndex {
        database_id: String,
        collection_id: String,
        key: String,
    },
    Custom {
        command: String,
        description: String,
    },
}

/// Migration planner that generates migrations by comparing schemas
pub struct MigrationPlanner;

impl MigrationPlanner {
    /// Generate migration operations by comparing current schema with target schema
    pub fn plan_migration(
        current_schema: &Option<DatabaseSchema>,
        target_schema: &DatabaseSchema,
        migration_name: String,
        description: String,
    ) -> Migration {
        let mut operations = Vec::new();
        let mut rollback_operations = Vec::new();

        match current_schema {
            None => {
                // Fresh installation - create everything
                operations.push(MigrationOperation::CreateDatabase {
                    database_id: target_schema.database_id.clone(),
                    name: target_schema.name.clone(),
                });

                rollback_operations.push(MigrationOperation::Custom {
                    command: format!(
                        "appwrite databases delete --databaseId {}",
                        target_schema.database_id
                    ),
                    description: "Delete the entire database".to_string(),
                });

                for collection in &target_schema.collections {
                    operations.push(MigrationOperation::CreateCollection {
                        database_id: target_schema.database_id.clone(),
                        collection: collection.clone(),
                    });

                    rollback_operations.push(MigrationOperation::DeleteCollection {
                        database_id: target_schema.database_id.clone(),
                        collection_id: collection.collection_id.clone(),
                    });
                }
            }
            Some(current) => {
                // Incremental migration
                Self::plan_incremental_migration(
                    current,
                    target_schema,
                    &mut operations,
                    &mut rollback_operations,
                );
            }
        }

        Migration {
            id: uuid::Uuid::new_v4().to_string(),
            name: migration_name,
            description,
            version: format!("{}", Utc::now().format("%Y%m%d%H%M%S")),
            timestamp: Utc::now(),
            operations,
            rollback_operations,
        }
    }

    fn plan_incremental_migration(
        current: &DatabaseSchema,
        target: &DatabaseSchema,
        operations: &mut Vec<MigrationOperation>,
        rollback_operations: &mut Vec<MigrationOperation>,
    ) {
        // Build lookup maps for efficient comparison
        let current_collections: HashMap<_, _> = current
            .collections
            .iter()
            .map(|c| (c.collection_id.as_str(), c))
            .collect();

        let target_collections: HashMap<_, _> = target
            .collections
            .iter()
            .map(|c| (c.collection_id.as_str(), c))
            .collect();

        // Find new collections to create
        for (collection_id, target_collection) in &target_collections {
            if !current_collections.contains_key(collection_id) {
                operations.push(MigrationOperation::CreateCollection {
                    database_id: target.database_id.clone(),
                    collection: (*target_collection).clone(),
                });

                rollback_operations.push(MigrationOperation::DeleteCollection {
                    database_id: target.database_id.clone(),
                    collection_id: collection_id.to_string(),
                });
            }
        }

        // Find collections to delete
        for (collection_id, current_collection) in &current_collections {
            if !target_collections.contains_key(collection_id) {
                operations.push(MigrationOperation::DeleteCollection {
                    database_id: current.database_id.clone(),
                    collection_id: collection_id.to_string(),
                });

                rollback_operations.push(MigrationOperation::CreateCollection {
                    database_id: current.database_id.clone(),
                    collection: (*current_collection).clone(),
                });
            }
        }

        // Compare existing collections for changes
        for (collection_id, target_collection) in &target_collections {
            if let Some(current_collection) = current_collections.get(collection_id) {
                Self::plan_collection_changes(
                    &target.database_id,
                    current_collection,
                    target_collection,
                    operations,
                    rollback_operations,
                );
            }
        }
    }

    fn plan_collection_changes(
        database_id: &str,
        current: &CollectionSchema,
        target: &CollectionSchema,
        operations: &mut Vec<MigrationOperation>,
        rollback_operations: &mut Vec<MigrationOperation>,
    ) {
        // Check if collection name or permissions changed
        if current.name != target.name || current.permissions != target.permissions {
            operations.push(MigrationOperation::UpdateCollection {
                database_id: database_id.to_string(),
                collection_id: current.collection_id.clone(),
                name: if current.name != target.name {
                    Some(target.name.clone())
                } else {
                    None
                },
                permissions: if current.permissions != target.permissions {
                    Some(target.permissions.clone())
                } else {
                    None
                },
            });

            rollback_operations.push(MigrationOperation::UpdateCollection {
                database_id: database_id.to_string(),
                collection_id: current.collection_id.clone(),
                name: if current.name != target.name {
                    Some(current.name.clone())
                } else {
                    None
                },
                permissions: if current.permissions != target.permissions {
                    Some(current.permissions.clone())
                } else {
                    None
                },
            });
        }

        // Compare attributes
        Self::plan_attribute_changes(
            database_id,
            &current.collection_id,
            &current.attributes,
            &target.attributes,
            operations,
            rollback_operations,
        );

        // Compare indexes
        Self::plan_index_changes(
            database_id,
            &current.collection_id,
            &current.indexes,
            &target.indexes,
            operations,
            rollback_operations,
        );
    }

    fn plan_attribute_changes(
        database_id: &str,
        collection_id: &str,
        current_attrs: &[AttributeSchema],
        target_attrs: &[AttributeSchema],
        operations: &mut Vec<MigrationOperation>,
        rollback_operations: &mut Vec<MigrationOperation>,
    ) {
        let current_attrs_map: HashMap<_, _> =
            current_attrs.iter().map(|a| (a.key.as_str(), a)).collect();

        let target_attrs_map: HashMap<_, _> =
            target_attrs.iter().map(|a| (a.key.as_str(), a)).collect();

        // New attributes
        for (key, target_attr) in &target_attrs_map {
            if !current_attrs_map.contains_key(key) {
                operations.push(MigrationOperation::CreateAttribute {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    attribute: (*target_attr).clone(),
                });

                rollback_operations.push(MigrationOperation::DeleteAttribute {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    key: key.to_string(),
                });
            }
        }

        // Deleted attributes
        for (key, current_attr) in &current_attrs_map {
            if !target_attrs_map.contains_key(key) {
                operations.push(MigrationOperation::DeleteAttribute {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    key: key.to_string(),
                });

                rollback_operations.push(MigrationOperation::CreateAttribute {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    attribute: (*current_attr).clone(),
                });
            }
        }

        // Modified attributes (limited to what Appwrite allows)
        for (key, target_attr) in &target_attrs_map {
            if let Some(current_attr) = current_attrs_map.get(key) {
                let required_changed = current_attr.required != target_attr.required;
                let default_changed = current_attr.default != target_attr.default;

                if required_changed || default_changed {
                    operations.push(MigrationOperation::UpdateAttribute {
                        database_id: database_id.to_string(),
                        collection_id: collection_id.to_string(),
                        key: key.to_string(),
                        required: if required_changed {
                            Some(target_attr.required)
                        } else {
                            None
                        },
                        default: if default_changed {
                            target_attr.default.clone()
                        } else {
                            None
                        },
                    });

                    rollback_operations.push(MigrationOperation::UpdateAttribute {
                        database_id: database_id.to_string(),
                        collection_id: collection_id.to_string(),
                        key: key.to_string(),
                        required: if required_changed {
                            Some(current_attr.required)
                        } else {
                            None
                        },
                        default: if default_changed {
                            current_attr.default.clone()
                        } else {
                            None
                        },
                    });
                }
            }
        }
    }

    fn plan_index_changes(
        database_id: &str,
        collection_id: &str,
        current_indexes: &[IndexSchema],
        target_indexes: &[IndexSchema],
        operations: &mut Vec<MigrationOperation>,
        rollback_operations: &mut Vec<MigrationOperation>,
    ) {
        let current_indexes_map: HashMap<_, _> = current_indexes
            .iter()
            .map(|i| (i.key.as_str(), i))
            .collect();

        let target_indexes_map: HashMap<_, _> =
            target_indexes.iter().map(|i| (i.key.as_str(), i)).collect();

        // New indexes
        for (key, target_index) in &target_indexes_map {
            if !current_indexes_map.contains_key(key) {
                operations.push(MigrationOperation::CreateIndex {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    index: (*target_index).clone(),
                });

                rollback_operations.push(MigrationOperation::DeleteIndex {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    key: key.to_string(),
                });
            }
        }

        // Deleted indexes
        for (key, _) in &current_indexes_map {
            if !target_indexes_map.contains_key(key) {
                operations.push(MigrationOperation::DeleteIndex {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    key: key.to_string(),
                });

                rollback_operations.push(MigrationOperation::CreateIndex {
                    database_id: database_id.to_string(),
                    collection_id: collection_id.to_string(),
                    index: current_indexes_map[key].clone(),
                });
            }
        }
    }
}

/// Migration executor that applies migration operations
pub struct MigrationExecutor;

impl MigrationExecutor {
    /// Convert migration operations to Appwrite CLI commands
    pub fn generate_commands(migration: &Migration) -> Vec<String> {
        let mut commands = Vec::new();

        for operation in &migration.operations {
            match operation {
                MigrationOperation::CreateDatabase { database_id, name } => {
                    commands.push(format!(
                        "appwrite databases create --databaseId {} --name \"{}\"",
                        database_id, name
                    ));
                }
                MigrationOperation::CreateCollection {
                    database_id,
                    collection,
                } => {
                    commands.push(format!(
                        "appwrite databases createCollection --databaseId {} --collectionId {} --name \"{}\"",
                        database_id, collection.collection_id, collection.name
                    ));

                    // Add attributes
                    for attr in &collection.attributes {
                        commands.extend(Self::generate_attribute_command(
                            database_id,
                            &collection.collection_id,
                            attr,
                        ));
                    }

                    // Add indexes
                    for index in &collection.indexes {
                        commands.push(Self::generate_index_command(
                            database_id,
                            &collection.collection_id,
                            index,
                        ));
                    }
                }
                MigrationOperation::UpdateCollection {
                    database_id,
                    collection_id,
                    name,
                    permissions: _,
                } => {
                    if let Some(new_name) = name {
                        commands.push(format!(
                            "appwrite databases updateCollection --databaseId {} --collectionId {} --name \"{}\"",
                            database_id, collection_id, new_name
                        ));
                    }
                    // Note: Permissions would require separate API calls
                }
                MigrationOperation::DeleteCollection {
                    database_id,
                    collection_id,
                } => {
                    commands.push(format!(
                        "appwrite databases deleteCollection --databaseId {} --collectionId {}",
                        database_id, collection_id
                    ));
                }
                MigrationOperation::CreateAttribute {
                    database_id,
                    collection_id,
                    attribute,
                } => {
                    commands.extend(Self::generate_attribute_command(
                        database_id,
                        collection_id,
                        attribute,
                    ));
                }
                MigrationOperation::UpdateAttribute {
                    database_id,
                    collection_id,
                    key,
                    required,
                    default: _,
                } => {
                    if let Some(req) = required {
                        commands.push(format!(
                            "appwrite databases updateStringAttribute --databaseId {} --collectionId {} --key {} --required {}",
                            database_id, collection_id, key, req
                        ));
                    }
                    // Note: Default values would require different API calls
                }
                MigrationOperation::DeleteAttribute {
                    database_id,
                    collection_id,
                    key,
                } => {
                    commands.push(format!(
                        "appwrite databases deleteAttribute --databaseId {} --collectionId {} --key {}",
                        database_id, collection_id, key
                    ));
                }
                MigrationOperation::CreateIndex {
                    database_id,
                    collection_id,
                    index,
                } => {
                    commands.push(Self::generate_index_command(
                        database_id,
                        collection_id,
                        index,
                    ));
                }
                MigrationOperation::DeleteIndex {
                    database_id,
                    collection_id,
                    key,
                } => {
                    commands.push(format!(
                        "appwrite databases deleteIndex --databaseId {} --collectionId {} --key {}",
                        database_id, collection_id, key
                    ));
                }
                MigrationOperation::Custom {
                    command,
                    description: _,
                } => {
                    commands.push(command.clone());
                }
            }
        }

        commands
    }

    fn generate_attribute_command(
        database_id: &str,
        collection_id: &str,
        attr: &AttributeSchema,
    ) -> Vec<String> {
        match &attr.attribute_type {
            crate::schema::AttributeType::String { size } => {
                vec![format!(
                    "appwrite databases createStringAttribute --databaseId {} --collectionId {} --key {} --size {} --required {} --array {}",
                    database_id, collection_id, attr.key, size.unwrap_or(255), attr.required, attr.array
                )]
            }
            crate::schema::AttributeType::Integer { min, max } => {
                vec![format!(
                    "appwrite databases createIntegerAttribute --databaseId {} --collectionId {} --key {} --required {} --array {} --min {} --max {}",
                    database_id, collection_id, attr.key, attr.required, attr.array,
                    min.unwrap_or(i64::MIN), max.unwrap_or(i64::MAX)
                )]
            }
            crate::schema::AttributeType::Boolean => {
                vec![format!(
                    "appwrite databases createBooleanAttribute --databaseId {} --collectionId {} --key {} --required {} --array {}",
                    database_id, collection_id, attr.key, attr.required, attr.array
                )]
            }
            crate::schema::AttributeType::DateTime => {
                vec![format!(
                    "appwrite databases createDatetimeAttribute --databaseId {} --collectionId {} --key {} --required {} --array {}",
                    database_id, collection_id, attr.key, attr.required, attr.array
                )]
            }
            crate::schema::AttributeType::Enum { elements } => {
                vec![format!(
                    "appwrite databases createEnumAttribute --databaseId {} --collectionId {} --key {} --elements '{}' --required {} --array {}",
                    database_id, collection_id, attr.key, elements.join(","), attr.required, attr.array
                )]
            }
            _ => vec![], // Other types not implemented
        }
    }

    fn generate_index_command(
        database_id: &str,
        collection_id: &str,
        index: &IndexSchema,
    ) -> String {
        let index_type = match index.index_type {
            crate::schema::IndexType::Key => "key",
            crate::schema::IndexType::Fulltext => "fulltext",
            crate::schema::IndexType::Unique => "unique",
        };

        format!(
            "appwrite databases createIndex --databaseId {} --collectionId {} --key {} --type {} --attributes '{}'",
            database_id, collection_id, index.key, index_type, index.attributes.join(",")
        )
    }

    /// Generate rollback commands for a migration
    pub fn generate_rollback_commands(migration: &Migration) -> Vec<String> {
        let mut commands = Vec::new();

        // Apply rollback operations in reverse order
        for operation in migration.rollback_operations.iter().rev() {
            match operation {
                MigrationOperation::CreateDatabase { database_id, name } => {
                    commands.push(format!(
                        "appwrite databases create --databaseId {} --name \"{}\"",
                        database_id, name
                    ));
                }
                MigrationOperation::DeleteCollection {
                    database_id,
                    collection_id,
                } => {
                    commands.push(format!(
                        "appwrite databases deleteCollection --databaseId {} --collectionId {}",
                        database_id, collection_id
                    ));
                }
                MigrationOperation::Custom {
                    command,
                    description: _,
                } => {
                    commands.push(command.clone());
                }
                // Add other rollback operations as needed
                _ => {
                    // For simplicity, convert to forward operations
                    let temp_migration = Migration {
                        id: "rollback".to_string(),
                        name: "rollback".to_string(),
                        description: "rollback".to_string(),
                        version: "rollback".to_string(),
                        timestamp: Utc::now(),
                        operations: vec![operation.clone()],
                        rollback_operations: vec![],
                    };
                    commands.extend(Self::generate_commands(&temp_migration));
                }
            }
        }

        commands
    }
}

/// Migration history tracking
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MigrationHistory {
    pub applied_migrations: Vec<Migration>,
}

impl MigrationHistory {
    pub fn new() -> Self {
        Self {
            applied_migrations: Vec::new(),
        }
    }

    pub fn add_migration(&mut self, migration: Migration) {
        self.applied_migrations.push(migration);
    }

    pub fn get_latest_version(&self) -> Option<&str> {
        self.applied_migrations.last().map(|m| m.version.as_str())
    }

    pub fn has_migration(&self, migration_id: &str) -> bool {
        self.applied_migrations.iter().any(|m| m.id == migration_id)
    }
}

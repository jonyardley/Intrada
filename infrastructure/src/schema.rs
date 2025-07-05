use serde::{Deserialize, Serialize};

// Import types from the shared crate
use shared::{PracticeGoal, PracticeSession, Study, StudySession};

/// Schema management for Appwrite database structure
/// This module provides type-safe schema definitions based on existing app types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseSchema {
    pub database_id: String,
    pub name: String,
    pub collections: Vec<CollectionSchema>,
}

/// Platform configuration for Appwrite project
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlatformSchema {
    pub platforms: Vec<Platform>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Platform {
    pub platform_type: PlatformType,
    pub name: String,
    pub key: Option<String>, // Bundle ID for iOS/Android, hostname for Web
    pub store_id: Option<String>, // App Store ID for iOS
    pub hostname: Option<String>, // For web platforms
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PlatformType {
    iOS,
    Android,
    Web,
    Flutter,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollectionSchema {
    pub collection_id: String,
    pub name: String,
    pub attributes: Vec<AttributeSchema>,
    pub indexes: Vec<IndexSchema>,
    pub permissions: Vec<Permission>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttributeSchema {
    pub key: String,
    pub attribute_type: AttributeType,
    pub required: bool,
    pub default: Option<serde_json::Value>,
    pub array: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AttributeType {
    String { size: Option<u32> },
    Integer { min: Option<i64>, max: Option<i64> },
    Float { min: Option<f64>, max: Option<f64> },
    Boolean,
    DateTime,
    Email,
    Url,
    IP,
    Enum { elements: Vec<String> },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexSchema {
    pub key: String,
    pub index_type: IndexType,
    pub attributes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum IndexType {
    Key,
    Fulltext,
    Unique,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Permission {
    pub role: String,
    pub permission: String,
}

/// Schema traits for converting app types to database schemas
pub trait SchemaDefinition {
    fn collection_name() -> &'static str;
    fn collection_id() -> &'static str;
    fn attributes() -> Vec<AttributeSchema>;
    fn indexes() -> Vec<IndexSchema>;
    fn permissions() -> Vec<Permission>;

    fn to_collection_schema() -> CollectionSchema {
        CollectionSchema {
            collection_id: Self::collection_id().to_string(),
            name: Self::collection_name().to_string(),
            attributes: Self::attributes(),
            indexes: Self::indexes(),
            permissions: Self::permissions(),
        }
    }
}

/// Implementation for PracticeGoal
impl SchemaDefinition for PracticeGoal {
    fn collection_name() -> &'static str {
        "goals"
    }
    fn collection_id() -> &'static str {
        "goals"
    }

    fn attributes() -> Vec<AttributeSchema> {
        vec![
            AttributeSchema {
                key: "name".to_string(),
                attribute_type: AttributeType::String { size: Some(255) },
                required: true,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "description".to_string(),
                attribute_type: AttributeType::String { size: Some(1000) },
                required: false,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "status".to_string(),
                attribute_type: AttributeType::Enum {
                    elements: vec![
                        "NotStarted".to_string(),
                        "InProgress".to_string(),
                        "Completed".to_string(),
                    ],
                },
                required: true,
                default: Some(serde_json::Value::String("NotStarted".to_string())),
                array: false,
            },
            AttributeSchema {
                key: "startDate".to_string(),
                attribute_type: AttributeType::DateTime,
                required: false,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "targetDate".to_string(),
                attribute_type: AttributeType::DateTime,
                required: false,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "studyIds".to_string(),
                attribute_type: AttributeType::String { size: Some(36) },
                required: false,
                default: Some(serde_json::Value::Array(vec![])),
                array: true,
            },
            AttributeSchema {
                key: "tempoTarget".to_string(),
                attribute_type: AttributeType::Integer {
                    min: Some(1),
                    max: Some(300),
                },
                required: false,
                default: None,
                array: false,
            },
        ]
    }

    fn indexes() -> Vec<IndexSchema> {
        vec![
            IndexSchema {
                key: "status_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["status".to_string()],
            },
            IndexSchema {
                key: "target_date_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["targetDate".to_string()],
            },
            IndexSchema {
                key: "name_fulltext".to_string(),
                index_type: IndexType::Fulltext,
                attributes: vec!["name".to_string()],
            },
        ]
    }

    fn permissions() -> Vec<Permission> {
        vec![
            Permission {
                role: "any".to_string(),
                permission: "read".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "create".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "update".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "delete".to_string(),
            },
        ]
    }
}

/// Implementation for Study
impl SchemaDefinition for Study {
    fn collection_name() -> &'static str {
        "studies"
    }
    fn collection_id() -> &'static str {
        "studies"
    }

    fn attributes() -> Vec<AttributeSchema> {
        vec![
            AttributeSchema {
                key: "name".to_string(),
                attribute_type: AttributeType::String { size: Some(255) },
                required: true,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "description".to_string(),
                attribute_type: AttributeType::String { size: Some(1000) },
                required: false,
                default: None,
                array: false,
            },
        ]
    }

    fn indexes() -> Vec<IndexSchema> {
        vec![IndexSchema {
            key: "name_fulltext".to_string(),
            index_type: IndexType::Fulltext,
            attributes: vec!["name".to_string()],
        }]
    }

    fn permissions() -> Vec<Permission> {
        vec![
            Permission {
                role: "any".to_string(),
                permission: "read".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "create".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "update".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "delete".to_string(),
            },
        ]
    }
}

/// Implementation for PracticeSession
impl SchemaDefinition for PracticeSession {
    fn collection_name() -> &'static str {
        "sessions"
    }
    fn collection_id() -> &'static str {
        "sessions"
    }

    fn attributes() -> Vec<AttributeSchema> {
        vec![
            AttributeSchema {
                key: "goalIds".to_string(),
                attribute_type: AttributeType::String { size: Some(36) },
                required: true,
                default: Some(serde_json::Value::Array(vec![])),
                array: true,
            },
            AttributeSchema {
                key: "intention".to_string(),
                attribute_type: AttributeType::String { size: Some(500) },
                required: true,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "notes".to_string(),
                attribute_type: AttributeType::String { size: Some(2000) },
                required: false,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "state".to_string(),
                attribute_type: AttributeType::Enum {
                    elements: vec![
                        "NotStarted".to_string(),
                        "Started".to_string(),
                        "Ended".to_string(),
                    ],
                },
                required: true,
                default: Some(serde_json::Value::String("NotStarted".to_string())),
                array: false,
            },
            AttributeSchema {
                key: "startTime".to_string(),
                attribute_type: AttributeType::DateTime,
                required: false,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "endTime".to_string(),
                attribute_type: AttributeType::DateTime,
                required: false,
                default: None,
                array: false,
            },
        ]
    }

    fn indexes() -> Vec<IndexSchema> {
        vec![
            IndexSchema {
                key: "state_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["state".to_string()],
            },
            IndexSchema {
                key: "start_time_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["startTime".to_string()],
            },
            IndexSchema {
                key: "goal_ids_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["goalIds".to_string()],
            },
        ]
    }

    fn permissions() -> Vec<Permission> {
        vec![
            Permission {
                role: "any".to_string(),
                permission: "read".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "create".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "update".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "delete".to_string(),
            },
        ]
    }
}

/// Implementation for StudySession
impl SchemaDefinition for StudySession {
    fn collection_name() -> &'static str {
        "study_sessions"
    }
    fn collection_id() -> &'static str {
        "study_sessions"
    }

    fn attributes() -> Vec<AttributeSchema> {
        vec![
            AttributeSchema {
                key: "studyId".to_string(),
                attribute_type: AttributeType::String { size: Some(36) },
                required: true,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "sessionId".to_string(),
                attribute_type: AttributeType::String { size: Some(36) },
                required: true,
                default: None,
                array: false,
            },
            AttributeSchema {
                key: "score".to_string(),
                attribute_type: AttributeType::Integer {
                    min: Some(0),
                    max: Some(10),
                },
                required: false,
                default: None,
                array: false,
            },
        ]
    }

    fn indexes() -> Vec<IndexSchema> {
        vec![
            IndexSchema {
                key: "study_id_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["studyId".to_string()],
            },
            IndexSchema {
                key: "session_id_index".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["sessionId".to_string()],
            },
            IndexSchema {
                key: "study_session_composite".to_string(),
                index_type: IndexType::Key,
                attributes: vec!["studyId".to_string(), "sessionId".to_string()],
            },
        ]
    }

    fn permissions() -> Vec<Permission> {
        vec![
            Permission {
                role: "any".to_string(),
                permission: "read".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "create".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "update".to_string(),
            },
            Permission {
                role: "any".to_string(),
                permission: "delete".to_string(),
            },
        ]
    }
}

/// Main schema builder
pub struct SchemaBuilder {
    database_id: String,
    database_name: String,
}

impl SchemaBuilder {
    pub fn new(database_id: String, database_name: String) -> Self {
        Self {
            database_id,
            database_name,
        }
    }

    pub fn build_schema(&self) -> DatabaseSchema {
        DatabaseSchema {
            database_id: self.database_id.clone(),
            name: self.database_name.clone(),
            collections: vec![
                PracticeGoal::to_collection_schema(),
                Study::to_collection_schema(),
                PracticeSession::to_collection_schema(),
                StudySession::to_collection_schema(),
            ],
        }
    }

    pub fn build_platform_schema(&self) -> PlatformSchema {
        PlatformSchema {
            platforms: vec![
                Platform {
                    platform_type: PlatformType::iOS,
                    name: "iOS App".to_string(),
                    key: Some("com.jonyardley.Intrada".to_string()),
                    store_id: None,
                    hostname: None,
                },
                Platform {
                    platform_type: PlatformType::Web,
                    name: "Web App".to_string(),
                    key: None,
                    store_id: None,
                    hostname: Some("localhost".to_string()),
                },
            ],
        }
    }

    pub fn build_platform_commands(&self) -> Vec<String> {
        let platform_schema = self.build_platform_schema();
        let mut commands = Vec::new();

        for platform in &platform_schema.platforms {
            match platform.platform_type {
                PlatformType::iOS => {
                    if let Some(bundle_id) = &platform.key {
                        commands.push(format!(
                            "appwrite projects createPlatform --projectId intrada-dev --type apple-ios --name \"{}\" --key {}",
                            platform.name, bundle_id
                        ));
                    }
                }
                PlatformType::Android => {
                    if let Some(bundle_id) = &platform.key {
                        commands.push(format!(
                            "appwrite projects createPlatform --projectId intrada-dev --type android --name \"{}\" --key {}",
                            platform.name, bundle_id
                        ));
                    }
                }
                PlatformType::Web => {
                    if let Some(hostname) = &platform.hostname {
                        commands.push(format!(
                            "appwrite projects createPlatform --projectId intrada-dev --type web --name \"{}\" --hostname {}",
                            platform.name, hostname
                        ));
                    }
                }
                PlatformType::Flutter => {
                    // Flutter platforms require both iOS and Android bundles
                    if let Some(bundle_id) = &platform.key {
                        commands.push(format!(
                            "appwrite projects createPlatform --projectId intrada-dev --type apple-ios --name \"Flutter iOS\" --key {}",
                            bundle_id
                        ));
                        commands.push(format!(
                            "appwrite projects createPlatform --projectId intrada-dev --type android --name \"Flutter Android\" --key {}",
                            bundle_id
                        ));
                    }
                }
            }
        }

        commands
    }

    pub fn build_appwrite_functions(&self) -> Vec<String> {
        // Generate Appwrite CLI commands for collection creation
        let schema = self.build_schema();
        let mut commands = Vec::new();

        // Create database
        commands.push(format!(
            "appwrite databases create --databaseId {} --name \"{}\"",
            schema.database_id, schema.name
        ));

        // Create collections
        for collection in &schema.collections {
            commands.push(format!(
                "appwrite databases createCollection --databaseId {} --collectionId {} --name \"{}\"",
                schema.database_id,
                collection.collection_id,
                collection.name
            ));

            // Create attributes
            for attr in &collection.attributes {
                let attr_command = match &attr.attribute_type {
                    AttributeType::String { size } => {
                        format!(
                            "appwrite databases createStringAttribute --databaseId {} --collectionId {} --key {} --size {} --required {} --array {}",
                            schema.database_id,
                            collection.collection_id,
                            attr.key,
                            size.unwrap_or(255),
                            attr.required,
                            attr.array
                        )
                    }
                    AttributeType::Integer { min, max } => {
                        format!(
                            "appwrite databases createIntegerAttribute --databaseId {} --collectionId {} --key {} --required {} --array {} --min {} --max {}",
                            schema.database_id,
                            collection.collection_id,
                            attr.key,
                            attr.required,
                            attr.array,
                            min.unwrap_or(i64::MIN),
                            max.unwrap_or(i64::MAX)
                        )
                    }
                    AttributeType::Boolean => {
                        format!(
                            "appwrite databases createBooleanAttribute --databaseId {} --collectionId {} --key {} --required {} --array {}",
                            schema.database_id,
                            collection.collection_id,
                            attr.key,
                            attr.required,
                            attr.array
                        )
                    }
                    AttributeType::DateTime => {
                        format!(
                            "appwrite databases createDatetimeAttribute --databaseId {} --collectionId {} --key {} --required {} --array {}",
                            schema.database_id,
                            collection.collection_id,
                            attr.key,
                            attr.required,
                            attr.array
                        )
                    }
                    AttributeType::Enum { elements } => {
                        let elements_args = elements
                            .iter()
                            .map(|e| format!("--elements {}", e))
                            .collect::<Vec<_>>()
                            .join(" ");
                        format!(
                            "appwrite databases createEnumAttribute --databaseId {} --collectionId {} --key {} {} --required {} --array {}",
                            schema.database_id,
                            collection.collection_id,
                            attr.key,
                            elements_args,
                            attr.required,
                            attr.array
                        )
                    }
                    _ => continue,
                };
                commands.push(attr_command);
            }

            // Create indexes
            for index in &collection.indexes {
                let index_type = match index.index_type {
                    IndexType::Key => "key",
                    IndexType::Fulltext => "fulltext",
                    IndexType::Unique => "unique",
                };

                let attributes_args = index
                    .attributes
                    .iter()
                    .map(|attr| format!("--attributes {}", attr))
                    .collect::<Vec<_>>()
                    .join(" ");

                commands.push(format!(
                    "appwrite databases createIndex --databaseId {} --collectionId {} --key {} --type {} {}",
                    schema.database_id,
                    collection.collection_id,
                    index.key,
                    index_type,
                    attributes_args
                ));
            }

            // Update collection permissions
            if !collection.permissions.is_empty() {
                let permission_args = collection
                    .permissions
                    .iter()
                    .map(|p| format!("--permissions '{}(\"{}\")'", p.permission, p.role))
                    .collect::<Vec<_>>()
                    .join(" ");

                commands.push(format!(
                    "appwrite databases updateCollection --databaseId {} --collectionId {} --name \"{}\" {}",
                    schema.database_id,
                    collection.collection_id,
                    collection.name,
                    permission_args
                ));
            }
        }

        // Add platforms
        commands.extend(self.build_platform_commands());

        commands
    }
}

/// Schema validation utilities
pub mod validation {
    use super::*;

    pub fn validate_schema(schema: &DatabaseSchema) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        // Check for duplicate collection IDs
        let mut collection_ids = std::collections::HashSet::new();
        for collection in &schema.collections {
            if !collection_ids.insert(&collection.collection_id) {
                errors.push(format!(
                    "Duplicate collection ID: {}",
                    collection.collection_id
                ));
            }
        }

        // Validate each collection
        for collection in &schema.collections {
            if let Err(mut collection_errors) = validate_collection(collection) {
                errors.append(&mut collection_errors);
            }
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    fn validate_collection(collection: &CollectionSchema) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        // Check for duplicate attribute keys
        let mut attribute_keys = std::collections::HashSet::new();
        for attr in &collection.attributes {
            if !attribute_keys.insert(&attr.key) {
                errors.push(format!(
                    "Duplicate attribute key '{}' in collection '{}'",
                    attr.key, collection.name
                ));
            }
        }

        // Validate indexes reference existing attributes
        for index in &collection.indexes {
            for attr_key in &index.attributes {
                if !attribute_keys.contains(attr_key) {
                    errors.push(format!(
                        "Index '{}' references non-existent attribute '{}' in collection '{}'",
                        index.key, attr_key, collection.name
                    ));
                }
            }
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_schema_generation() {
        let builder = SchemaBuilder::new("intrada_db".to_string(), "Intrada Database".to_string());
        let schema = builder.build_schema();

        assert_eq!(schema.database_id, "intrada_db");
        assert_eq!(schema.collections.len(), 4);

        // Test that all expected collections are present
        let collection_names: Vec<_> = schema.collections.iter().map(|c| c.name.as_str()).collect();
        assert!(collection_names.contains(&"goals"));
        assert!(collection_names.contains(&"studies"));
        assert!(collection_names.contains(&"sessions"));
        assert!(collection_names.contains(&"study_sessions"));
    }

    #[test]
    fn test_practice_goal_schema() {
        let collection = PracticeGoal::to_collection_schema();
        assert_eq!(collection.name, "goals");
        assert_eq!(collection.collection_id, "goals");

        // Check required attributes exist
        let attr_keys: Vec<_> = collection
            .attributes
            .iter()
            .map(|a| a.key.as_str())
            .collect();
        assert!(attr_keys.contains(&"name"));
        assert!(attr_keys.contains(&"status"));
        assert!(attr_keys.contains(&"studyIds"));
    }

    #[test]
    fn test_schema_validation() {
        let builder = SchemaBuilder::new("test_db".to_string(), "Test Database".to_string());
        let schema = builder.build_schema();

        assert!(validation::validate_schema(&schema).is_ok());
    }

    #[test]
    fn test_appwrite_commands_generation() {
        let builder = SchemaBuilder::new("intrada_db".to_string(), "Intrada Database".to_string());
        let commands = builder.build_appwrite_functions();

        assert!(!commands.is_empty());
        assert!(commands[0].contains("appwrite databases create"));
        assert!(commands.iter().any(|c| c.contains("createCollection")));
        assert!(commands.iter().any(|c| c.contains("createStringAttribute")));
    }
}

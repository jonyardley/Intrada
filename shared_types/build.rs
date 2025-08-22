// This build script generates platform-specific type definitions from the shared Rust core
// It uses the facet type generation system to create data types for iOS (Swift), Android (Java), and Web (TypeScript)
// This complements the uniffi FFI bindings in shared/ which provide the runtime interface

use crux_core::type_generation::facet::{Config, TypeRegistry};
use shared::Chopin;
use std::path::PathBuf;

fn main() -> anyhow::Result<()> {
    println!("cargo:rerun-if-changed=../shared");

    let typegen = TypeRegistry::new().register_app::<Chopin>().build();

    let output_root = PathBuf::from("./generated");

    // Create the output directory if it doesn't exist
    std::fs::create_dir_all(&output_root)?;

    // Generate Swift types for iOS (data structures, events, etc.)
    typegen.swift(&Config::builder("SharedTypes", output_root.join("swift")).build())?;

    // Fix Package.swift to include Serde target
    fix_package_swift(&output_root.join("swift/SharedTypes/Package.swift"))?;

    // Add Request array support to SharedTypes.swift
    add_request_array_support(
        &output_root.join("swift/SharedTypes/Sources/SharedTypes/SharedTypes.swift"),
    )?;

    // Generate Java types for Android (currently disabled)
    // generator.java("com.jonyardley.intrada", output_root.join("java"))?;

    // Generate TypeScript types for Web (currently disabled)
    // generator.typescript("shared_types", output_root.join("typescript"))?;

    Ok(())
}

fn fix_package_swift(package_path: &PathBuf) -> anyhow::Result<()> {
    use std::fs;

    let correct_package_content = r#"// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "SharedTypes",
    products: [
        .library(
            name: "SharedTypes",
            targets: ["SharedTypes"]
        )
    ],
    targets: [
        .target(
            name: "Serde",
            dependencies: []
        ),
        .target(
            name: "SharedTypes",
            dependencies: ["Serde"]
        ),
    ]
)
"#;

    fs::write(package_path, correct_package_content)?;

    // Create Serde source directory and basic Serde.swift file
    let serde_sources_dir = package_path.parent().unwrap().join("Sources/Serde");
    fs::create_dir_all(&serde_sources_dir)?;

    // Create complete Serde.swift implementation
    let serde_swift_path = serde_sources_dir.join("Serde.swift");
    let serde_implementation = include_str!("serde_swift_template.swift");
    fs::write(&serde_swift_path, serde_implementation)?;

    Ok(())
}

fn add_request_array_support(shared_types_path: &PathBuf) -> anyhow::Result<()> {
    use std::fs;

    let mut content = fs::read_to_string(shared_types_path)?;

    // Add the array extension at the end of the file
    let array_extension = r#"

// MARK: - Array Extensions for Request

public extension Array where Element == Request {
    static func bincodeDeserialize(input: [UInt8]) throws -> [Request] {
        let deserializer = BincodeDeserializer(input: input)
        return try deserialize_vector_Request(deserializer: deserializer)
    }
}

func serialize_vector_Request<S: Serializer>(value: [Request], serializer: S) throws {
    try serializer.serialize_len(value: UInt64(value.count))
    for item in value {
        try item.serialize(serializer: serializer)
    }
}

func deserialize_vector_Request<D: Deserializer>(deserializer: D) throws -> [Request] {
    let length = try deserializer.deserialize_len()
    var obj: [Request] = []
    for _ in 0..<length {
        obj.append(try Request.deserialize(deserializer: deserializer))
    }
    return obj
}
"#;

    content.push_str(array_extension);
    fs::write(shared_types_path, content)?;

    Ok(())
}

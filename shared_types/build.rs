// This build script generates platform-specific type definitions from the shared Rust core
// It uses the facet type generation system to create data types for iOS (Swift), Android (Java), and Web (TypeScript)
// This complements the uniffi FFI bindings in shared/ which provide the runtime interface

use crux_core::type_generation::facet::TypeGen;
use shared::Chopin;
use std::path::PathBuf;

fn main() -> anyhow::Result<()> {
    println!("cargo:rerun-if-changed=../shared");

    let mut typegen = TypeGen::new();

    typegen.register_app::<Chopin>()?;

    let output_root = PathBuf::from("./generated");

    // Generate Swift types for iOS (data structures, events, etc.)
    typegen.swift("SharedTypes", output_root.join("swift"))?;

    // Generate Java types for Android (currently disabled)
    // typegen.java("com.jonyardley.intrada", output_root.join("java"))?;

    // Generate TypeScript types for Web (currently disabled)
    // typegen.typescript("shared_types", output_root.join("typescript"))?;

    Ok(())
}

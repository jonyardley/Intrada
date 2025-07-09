use crux_core::type_generation::facet::TypeGen;
use shared::Chopin;
use std::path::PathBuf;

fn main() -> anyhow::Result<()> {
    println!("cargo:rerun-if-changed=../shared");

    let mut typegen = TypeGen::new();

    typegen.register_app::<Chopin>()?;

    let output_root = PathBuf::from("./generated");

    typegen.swift("SharedTypes", output_root.join("swift"))?;

    // typegen.java("com.jonyardley.intrada", output_root.join("java"))?;

    // typegen.typescript("shared_types", output_root.join("typescript"))?;

    Ok(())
}

use crux_core::typegen::TypeGen;
use shared::{Chopin, GoalStatus};
use std::path::PathBuf;

fn main() -> anyhow::Result<()> {
    println!("cargo:rerun-if-changed=../shared");
    let mut gen = TypeGen::new();

    gen.register_type::<GoalStatus>()?;
    gen.register_app::<Chopin>()?;

    let output_root = PathBuf::from("./generated");
    gen.swift("SharedTypes", output_root.join("swift"))?;

    //gen.java("com.crux.example.simple_counter", output_root.join("java"))?;
    //gen.typescript("shared_types", output_root.join("typescript"))?;

    Ok(())
}

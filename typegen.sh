#!/usr/bin/env bash

set -eux

pushd shared
cargo swift package --name Shared --platforms ios
pushd generated
rm -rf headers sources *.swift *.h *.modulemap
popd
popd

cargo run --package shared --bin crux_cli --features cli -- \
    bindgen \
        --crate-name shared
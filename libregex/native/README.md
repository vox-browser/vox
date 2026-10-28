# Pinned native LibRegex dependency

The ten files listed in `manifest.json` are byte-exact copies from Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`. The source Rust backend is reused
unchanged, as upstream's C++ LibRegex wrappers do. `unicode.rs` supplies crate
wiring for the unchanged Unicode character wrappers; their C ABI calls reach
the existing translated V Unicode helpers and ICU.

The browser build script builds this dependency before invoking V. Before
running V tests in a fresh checkout, run `python3 tools/build_regex_backend.py`.
Concurrent builders share a locked, atomic output under
`Build/libregex/{darwin,linux,windows}/`, keeping host formats separate.
Use `--verify-only` to check the copied sources without building. The build
requires a Rust compiler supporting edition 2024 and does not read or link the
upstream checkout. `RUSTC` selects the compiler.

These native dependency assets do not claim the Rust parser, compiler or
instruction loop has been translated to V. The V C++ wrapper and HTML caller
translation use the pinned implementation rather than a replacement grammar.

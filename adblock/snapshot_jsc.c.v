module adblock

import os


#flag darwin -lz
#include "@DIR/snapshot.h"

fn C.vox_adblock_install_snapshot(voidptr, &u8, uint) int
fn C.vox_adblock_install_snapshot_file(voidptr, &char) int
fn C.vox_adblock_install_snapshot_metadata(voidptr, &u8, uint) int

const native_snapshot_bytes = $embed_file('engine.snapshot.bin')
const compressed_snapshot_metadata = $embed_file('engine.snapshot.json.gz')

// Explicit diagnostic input selection permits matched codec comparisons with
// one installed browser/helper identity. It never falls back after a bad input.
fn snapshot_asset_directory() ?string {
	value := os.getenv('VOX_ADBLOCK_ENGINE_ASSETS')
	if value == '' { return none }
	return value
}

fn warm_snapshot_sources() {
	_ = compressed_snapshot_metadata.data()
	if !os.is_file(bundled_snapshot_path()) { _ = native_snapshot_bytes.data() }
}

fn install_snapshot(context voidptr) ! {
	// Bundles keep the large payload in a reclaimable file-backed mapping.
	// Standalone tools/tests retain the same validated embedded fallback.
	path := if directory := snapshot_asset_directory() {
		os.join_path(directory, 'engine.snapshot.bin')
	} else { bundled_snapshot_path() }
	mut status := 0
	if os.is_file(path) || snapshot_asset_directory() != none {
		status = C.vox_adblock_install_snapshot_file(context, path.str)
	} else {
		mut snapshot := native_snapshot_bytes
		status = C.vox_adblock_install_snapshot(context, snapshot.data(), uint(snapshot.len))
	}
	if status != 0 {
		return error('Cannot restore bundled adblock snapshot: ${status}')
	}
	metadata := if directory := snapshot_asset_directory() {
		os.read_bytes(os.join_path(directory, 'engine.snapshot.json.gz'))!
	} else { compressed_snapshot_metadata.to_bytes() }
	metadata_status := C.vox_adblock_install_snapshot_metadata(context, metadata.data, uint(metadata.len))
	if metadata_status != 0 {
		return error('Cannot restore bundled adblock metadata: ${metadata_status}')
	}
}

fn bundled_snapshot_path() string {
	executable := current_executable_path() or { return '' }
	return os.join_path(os.dir(executable), '..', 'Resources', 'adblock.snapshot.bin')
}

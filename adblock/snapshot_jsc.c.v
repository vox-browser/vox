module adblock

import os


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

fn snapshot_resource_name(name string) string {
	return if name == 'engine.snapshot.bin' { 'adblock.snapshot.bin' } else { 'adblock.${name}' }
}

fn snapshot_resource_path(executable string, name string) string {
	return os.join_path(os.dir(executable), '..', 'Resources', snapshot_resource_name(name))
}

// A bundle owns the complete codec/data set. Once any packaged member exists,
// a missing member is an error rather than permission to mix checkout versions.
fn snapshot_asset_path_for_executable(executable string, directory ?string, name string) ?string {
	if selected := directory { return os.join_path(selected, name) }
	if executable == '' { return none }
	for member in ['engine.snapshot.bin', 'engine.snapshot.json.gz', 'engine.js.gz'] {
		if os.is_file(snapshot_resource_path(executable, member)) {
			return snapshot_resource_path(executable, name)
		}
	}
	return none
}

fn snapshot_asset_path(name string) ?string {
	executable := current_executable_path() or { '' }
	return snapshot_asset_path_for_executable(executable, snapshot_asset_directory(), name)
}

fn warm_snapshot_sources() {
	if snapshot_asset_path('engine.snapshot.json.gz') == none { _ = compressed_snapshot_metadata.data() }
	if snapshot_asset_path('engine.snapshot.bin') == none { _ = native_snapshot_bytes.data() }
}

fn install_snapshot(context voidptr) ! {
	// Bundles keep the large payload in a reclaimable file-backed mapping.
	// Standalone tools/tests retain the same validated embedded fallback.
	mut status := 0
	if path := snapshot_asset_path('engine.snapshot.bin') {
		status = C.vox_adblock_install_snapshot_file(context, path.str)
	} else {
		mut snapshot := native_snapshot_bytes
		status = C.vox_adblock_install_snapshot(context, snapshot.data(), uint(snapshot.len))
	}
	if status != 0 {
		return error('Cannot restore bundled adblock snapshot: ${status}')
	}
	metadata := if path := snapshot_asset_path('engine.snapshot.json.gz') {
		os.read_bytes(path)!
	} else { compressed_snapshot_metadata.to_bytes() }
	// Status 4 keeps the native installer's former inflate-failure code.
	json := gunzip_single_member(metadata) or {
		return error('Cannot restore bundled adblock metadata: 4')
	}
	metadata_status := C.vox_adblock_install_snapshot_metadata(context, json.data, uint(json.len))
	if metadata_status != 0 {
		return error('Cannot restore bundled adblock metadata: ${metadata_status}')
	}
}

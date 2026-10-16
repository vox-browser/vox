module adblock

import os


#flag darwin -lz
#include "@DIR/snapshot.h"

fn C.vox_adblock_install_snapshot(voidptr, &u8, usize) int
fn C.vox_adblock_install_snapshot_file(voidptr, &char) int
fn C.vox_adblock_install_snapshot_metadata(voidptr, &u8, usize) int

const native_snapshot_bytes = $embed_file('engine.snapshot.bin')
const compressed_snapshot_metadata = $embed_file('engine.snapshot.json.gz')

fn install_snapshot(context voidptr) ! {
	// Bundles keep the large payload in a reclaimable file-backed mapping.
	// Standalone tools/tests retain the same validated embedded fallback.
	path := os.join_path(os.dir(os.executable()), '..', 'Resources', 'adblock.snapshot.bin')
	mut status := 0
	if os.is_file(path) {
		status = C.vox_adblock_install_snapshot_file(context, path.str)
	} else {
		mut snapshot := native_snapshot_bytes
		status = C.vox_adblock_install_snapshot(context, snapshot.data(), usize(snapshot.len))
	}
	if status != 0 {
		return error('Cannot restore bundled adblock snapshot: ${status}')
	}
	metadata := compressed_snapshot_metadata.to_bytes()
	metadata_status := C.vox_adblock_install_snapshot_metadata(context, metadata.data, usize(metadata.len))
	if metadata_status != 0 {
		return error('Cannot restore bundled adblock metadata: ${metadata_status}')
	}
}

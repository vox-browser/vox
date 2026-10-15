module adblock

#flag darwin -lz
#include "@DIR/snapshot.h"

fn C.vox_adblock_install_snapshot(voidptr, &u8, usize) int
fn C.vox_adblock_install_snapshot_metadata(voidptr, &u8, usize) int

const native_snapshot_bytes = $embed_file('engine.snapshot.bin')
const compressed_snapshot_metadata = $embed_file('engine.snapshot.json.gz')

fn install_snapshot(context voidptr) ! {
	snapshot := native_snapshot_bytes.to_bytes()
	status := C.vox_adblock_install_snapshot(context, snapshot.data, usize(snapshot.len))
	if status != 0 {
		return error('Cannot restore bundled adblock snapshot: ${status}')
	}
	metadata := compressed_snapshot_metadata.to_bytes()
	metadata_status := C.vox_adblock_install_snapshot_metadata(context, metadata.data, usize(metadata.len))
	if metadata_status != 0 {
		return error('Cannot restore bundled adblock metadata: ${metadata_status}')
	}
}

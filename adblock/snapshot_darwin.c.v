module adblock

#flag darwin -lz
#include "@DIR/snapshot.h"

fn C.vox_adblock_install_snapshot(voidptr, &u8, usize) int

const compressed_snapshot_bytes = $embed_file('engine.snapshot.bin.gz')

fn install_snapshot(context voidptr) ! {
	compressed := compressed_snapshot_bytes.to_bytes()
	status := C.vox_adblock_install_snapshot(context, compressed.data, usize(compressed.len))
	if status != 0 {
		return error('Cannot restore bundled adblock snapshot: ${status}')
	}
}

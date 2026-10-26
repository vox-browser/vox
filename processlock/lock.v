module processlock

import crypto.sha256
import os

#include "@DIR/lock.h"

fn C.vox_profile_lock(&char) i32
fn C.vox_profile_unlock(i32)

pub struct Lock {
	fd i32 = -1
}

// Hold a stable sidecar inode across the entire read/modify/rename operation.
// Never unlink it on unlock: existing waiters must lock the same inode.
pub fn acquire(path string) !Lock {
	if path == '' { return Lock{} }
	os.mkdir_all(os.dir(path))!
	name := '${path}.lock'
	fd := C.vox_profile_lock(&char(name.str))
	if fd < 0 { return error('could not lock profile ${path}') }
	return Lock{ fd: fd }
}

pub fn (guard Lock) release() { C.vox_profile_unlock(guard.fd) }

// Keep profile fingerprints inline: refresh checks run in temporary arenas.
pub fn fingerprint(contents string) [32]u8 {
	digest := sha256.sum(contents.bytes())
	mut result := [32]u8{}
	for i in 0 .. 32 { result[i] = digest[i] }
	return result
}

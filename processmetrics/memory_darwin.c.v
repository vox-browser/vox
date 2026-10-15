module processmetrics

#include "memory_darwin.h"

fn C.vox_process_memory_bytes(&u64) int

pub fn memory_snapshot() MemorySnapshot {
	mut bytes := u64(0)
	status := C.vox_process_memory_bytes(&bytes)
	return MemorySnapshot{bytes: bytes, available: status == 0}
}

module processmetrics

import os

pub fn memory_snapshot() MemorySnapshot {
	statm := os.read_file('/proc/self/statm') or { return MemorySnapshot{} }
	return memory_snapshot_from_statm(statm, os.page_size())
}

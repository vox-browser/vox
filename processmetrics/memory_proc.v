module processmetrics

import strconv

// statm's second field is current resident pages, including shared pages.
// Use the kernel's page size rather than assuming 4 KiB on every architecture.
fn memory_snapshot_from_statm(statm string, page_size int) MemorySnapshot {
	fields := statm.fields()
	if fields.len < 2 || page_size <= 0 {
		return MemorySnapshot{}
	}
	resident := strconv.parse_uint(fields[1], 10, 64) or { return MemorySnapshot{} }
	if resident > ~u64(0) / u64(page_size) {
		return MemorySnapshot{}
	}
	return MemorySnapshot{ bytes: resident * u64(page_size), available: true }
}

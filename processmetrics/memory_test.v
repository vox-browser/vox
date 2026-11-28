module processmetrics

fn test_ram_label_formats_current_memory_and_unavailable_readings() {
	assert MemorySnapshot{}.ram_label() == 'RAM: unavailable'
	assert MemorySnapshot{ available: true }.ram_label() == 'RAM: 0.0 MB'
	assert MemorySnapshot{ bytes: 123_456_789, available: true }.ram_label() == 'RAM: 123.5 MB'
	assert MemorySnapshot{ bytes: 1_500_000_000, available: true }.ram_label() == 'RAM: 1.5 GB'
}

fn test_memory_snapshot_reads_the_running_process_footprint() {
	snapshot := memory_snapshot()
	$if darwin || linux {
		assert snapshot.available
		assert snapshot.bytes > 0
		assert !snapshot.ram_label().contains('unavailable')
	} $else {
		assert !snapshot.available
	}
}

fn test_memory_snapshot_uses_resident_pages_and_runtime_page_size() {
	// Virtual size and shared pages must not be added to resident memory.
	statm := '100000 1234 567 89 0 1000 0\n'
	assert memory_snapshot_from_statm(statm, 4096) == MemorySnapshot{
		bytes:     5_054_464
		available: true
	}
	assert memory_snapshot_from_statm(statm, 65536).bytes == 80_871_424
	assert memory_snapshot_from_statm('100\t2\n', 4096).bytes == 8192
	assert memory_snapshot_from_statm('100 0', 4096) == MemorySnapshot{ available: true }
}

fn test_memory_snapshot_rejects_invalid_proc_readings() {
	for statm in ['', '100', '100 invalid', '100 -1', '100 18446744073709551616',
		'100 18446744073709551615'] {
		assert !memory_snapshot_from_statm(statm, 4096).available
	}
	assert !memory_snapshot_from_statm('100 2', 0).available
	assert !memory_snapshot_from_statm('100 2', -1).available
}

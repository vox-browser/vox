module processmetrics

fn test_ram_label_formats_current_memory_and_unavailable_readings() {
	assert MemorySnapshot{}.ram_label() == 'RAM: unavailable'
	assert MemorySnapshot{available: true}.ram_label() == 'RAM: 0.0 MB'
	assert MemorySnapshot{bytes: 123_456_789, available: true}.ram_label() == 'RAM: 123.5 MB'
	assert MemorySnapshot{bytes: 1_500_000_000, available: true}.ram_label() == 'RAM: 1.5 GB'
}

fn test_memory_snapshot_reads_the_running_process_footprint() {
	snapshot := memory_snapshot()
	$if darwin {
		assert snapshot.available
		assert snapshot.bytes > 0
		assert !snapshot.ram_label().contains('unavailable')
	} $else {
		assert !snapshot.available
	}
}

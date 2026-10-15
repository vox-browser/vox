module main

fn test_memory_status_refreshes_once_per_second_across_idle_and_busy_frames() {
	mut status := BrowserMemoryStatus{}
	assert status.refresh_if_due(0)
	assert status.label.starts_with('RAM: ')
	assert status.next_sample_ns == 1_000_000_000
	first_label := status.label
	assert !status.refresh_if_due(16_000_000)
	assert !status.refresh_if_due(999_999_999)
	assert status.label == first_label
	assert status.refresh_if_due(1_000_000_000)
	assert status.next_sample_ns == 2_000_000_000
	// A delayed frame schedules from the current time without catching up.
	assert status.refresh_if_due(5_000_000_000)
	assert status.next_sample_ns == 6_000_000_000
}

module fileapi

fn test_source_file_reader_progress_timer_uses_exact_50ms_monotonic_threshold() {
	assert file_reader_enough_progress_time_passed(none, 0)
	previous := i64(100_000_000)
	assert !file_reader_enough_progress_time_passed(previous, previous - 1)
	assert !file_reader_enough_progress_time_passed(previous, previous)
	assert !file_reader_enough_progress_time_passed(previous, previous + 49_999_999)
	assert file_reader_enough_progress_time_passed(previous, previous + 50_000_000)
	assert file_reader_enough_progress_time_passed(previous, previous + 50_000_001)
}

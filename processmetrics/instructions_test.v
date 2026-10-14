module processmetrics

fn test_instruction_intervals_reject_unavailable_or_decreasing_counters() {
	start := InstructionSnapshot{ instructions: 100, available: true }
	end := InstructionSnapshot{ instructions: 175, available: true }
	assert end.since(start) or { panic('missing count') } == 75
	assert start.since(start) or { panic('missing zero interval') } == 0
	assert start.since(end) == none
	assert end.since(InstructionSnapshot{}) == none
	assert InstructionSnapshot{}.since(start) == none
}

fn test_process_instruction_counter_is_monotonic_when_supported() {
	first := instruction_snapshot()
	if !first.available {
		assert first.error_code != 0
		return
	}
	second := instruction_snapshot()
	assert second.available
	assert first.instructions > 0
	assert second.instructions > first.instructions
	assert second.since(first) or { panic('missing hardware interval') } > 0
}

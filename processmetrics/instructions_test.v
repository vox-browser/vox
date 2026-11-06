module processmetrics

import os

fn test_instruction_flag_observes_unset_empty_and_changed_values() {
	previous := os.getenv_opt('VOX_PROFILE_INSTRUCTIONS')
	defer {
		if value := previous { os.setenv('VOX_PROFILE_INSTRUCTIONS', value, true) }
		else { os.unsetenv('VOX_PROFILE_INSTRUCTIONS') }
	}
	os.unsetenv('VOX_PROFILE_INSTRUCTIONS')
	assert !instructions_enabled()
	os.setenv('VOX_PROFILE_INSTRUCTIONS', '', true)
	assert !instructions_enabled()
	os.setenv('VOX_PROFILE_INSTRUCTIONS', '1', true)
	assert instructions_enabled()
	os.setenv('VOX_PROFILE_INSTRUCTIONS', '0', true)
	assert instructions_enabled()
}

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

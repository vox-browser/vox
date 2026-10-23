module processmetrics

import json2

fn test_coalition_intervals_keep_exited_tasks_and_reject_changed_or_invalid_totals() {
	start := CoalitionInstructionSnapshot{
		coalition_id: 42
		instructions: 1000
		tasks_started: 2
		tasks_exited: 1
		available: true
	}
	end := CoalitionInstructionSnapshot{
		coalition_id: 42
		instructions: 5000
		tasks_started: 10
		tasks_exited: 9
		available: true
	}
	assert end.since(start) or { panic('missing coalition interval') } == 4000
	assert start.since(start) or { panic('missing zero interval') } == 0
	assert start.since(end) == none
	assert end.since(CoalitionInstructionSnapshot{}) == none
	assert CoalitionInstructionSnapshot{}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, coalition_id: 43}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, coalition_id: 0}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, tasks_started: 1, tasks_exited: 1}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, tasks_exited: 0}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, tasks_exited: 11}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, instructions: 0}.since(start) == none
	assert CoalitionInstructionSnapshot{...end, error_code: 5}.since(start) == none
}

fn test_coalition_record_preserves_stored_reading_and_escapes_labels() {
	reading := CoalitionInstructionSnapshot{
		coalition_id: 42
		instructions: 9_007_199_254_740_993
		tasks_started: 10
		tasks_exited: 9
		available: true
	}
	label := 'capture_"document"\nencoded'
	record := coalition_instruction_record(label, reading) or { panic('missing coalition record') }
	decoded := json2.decode[CoalitionInstructionCheckpoint](record) or { panic(err) }
	assert decoded.label == label
	assert decoded.coalition_id == reading.coalition_id
	assert decoded.instructions == reading.instructions
	assert decoded.tasks_started == reading.tasks_started
	assert decoded.tasks_exited == reading.tasks_exited
	assert !record.contains('\n')
	assert !record.contains('available') && !record.contains('error_code')
	assert coalition_instruction_record('missing', CoalitionInstructionSnapshot{}) == none
}

fn test_native_coalition_counter_is_monotonic_when_supported() {
	first := coalition_instruction_snapshot()
	if !first.available {
		assert first.error_code != 0
		return
	}
	second := coalition_instruction_snapshot()
	assert first.valid()
	assert second.valid()
	assert second.coalition_id == first.coalition_id
	assert second.tasks_started >= first.tasks_started
	assert second.tasks_exited >= first.tasks_exited
	assert second.instructions >= first.instructions
	assert second.since(first) or { panic('missing hardware coalition interval') } == second.instructions - first.instructions
	// This process may inherit a shared coalition. Advancing counters verify
	// the ABI, not browser exclusivity or instruction parity.
}

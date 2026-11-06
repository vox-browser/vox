module processmetrics

fn thread_instruction_worker_readings() (InstructionSnapshot, InstructionSnapshot) {
	return thread_instruction_snapshot(), thread_instruction_snapshot()
}

fn test_thread_instruction_snapshots_are_monotonic_on_each_calling_thread_or_unavailable() {
	first := thread_instruction_snapshot()
	second := thread_instruction_snapshot()
	if first.available {
		assert first.instructions > 0 && second.available && second.instructions > first.instructions
	} else { assert first.instructions == 0 && first.error_code != 0 }
	worker := spawn thread_instruction_worker_readings()
	a, b := worker.wait()
	if a.available { assert a.instructions > 0 && b.available && b.instructions > a.instructions }
	else { assert a.instructions == 0 && a.error_code != 0 }
	// Each thread has its own origin; worker and main readings are deliberately
	// not subtracted or ordered against each other.
}

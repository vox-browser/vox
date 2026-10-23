module processmetrics

import os

pub struct InstructionSnapshot {
pub:
	instructions u64
	available    bool
	error_code   int
}

pub fn instructions_enabled() bool {
	return os.getenv('VOX_PROFILE_INSTRUCTIONS') != ''
}

pub fn begin_instructions() InstructionSnapshot {
	if !instructions_enabled() { return InstructionSnapshot{} }
	return instruction_snapshot()
}

pub fn (end InstructionSnapshot) since(start InstructionSnapshot) ?u64 {
	if !start.available || !end.available || end.instructions < start.instructions {
		return none
	}
	return end.instructions - start.instructions
}

// Cumulative readings can be differenced in log order. Nested scope totals
// below are separate records and must not be added to these phase deltas.
pub fn instruction_checkpoint(label string) {
	if !instructions_enabled() { return }
	report_instruction_snapshot(label, instruction_snapshot())
}

// Preserve the exact sampled boundary when a caller records multiple counters.
pub fn report_instruction_snapshot(label string, reading InstructionSnapshot) {
	if !instructions_enabled() { return }
	if reading.available {
		eprintln('Vox instructions cumulative: ${label} ${reading.instructions}')
	} else {
		eprintln('Vox instructions unavailable: ${label} error=${reading.error_code}')
	}
}

pub fn report_instructions(label string, start InstructionSnapshot, end InstructionSnapshot) {
	if !instructions_enabled() { return }
	if count := end.since(start) {
		eprintln('Vox instructions scope: ${label} ${count}')
	} else {
		eprintln('Vox instructions unavailable: ${label} error=${end.error_code}')
	}
}

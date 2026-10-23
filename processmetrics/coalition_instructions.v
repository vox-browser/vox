module processmetrics

import json2

// A resource coalition includes completed tasks, but may also contain unrelated
// work. Its identity and task totals must be audited before comparing browsers.
pub struct CoalitionInstructionSnapshot {
pub:
	coalition_id  u64
	instructions  u64
	tasks_started u64
	tasks_exited  u64
	available     bool
	error_code    int
}

pub fn begin_coalition_instructions() CoalitionInstructionSnapshot {
	if !instructions_enabled() {
		return CoalitionInstructionSnapshot{}
	}
	return coalition_instruction_snapshot()
}

fn (reading CoalitionInstructionSnapshot) valid() bool {
	return reading.available && reading.error_code == 0 && reading.coalition_id > 0
		&& reading.instructions > 0 && reading.tasks_exited <= reading.tasks_started
}

pub fn (end CoalitionInstructionSnapshot) since(start CoalitionInstructionSnapshot) ?u64 {
	if !start.valid() || !end.valid() || start.coalition_id != end.coalition_id
		|| end.instructions < start.instructions || end.tasks_started < start.tasks_started
		|| end.tasks_exited < start.tasks_exited {
		return none
	}
	return end.instructions - start.instructions
}

struct CoalitionInstructionCheckpoint {
	label         string
	coalition_id  u64
	instructions  u64
	tasks_started u64
	tasks_exited  u64
}

fn coalition_instruction_record(label string, reading CoalitionInstructionSnapshot) ?string {
	if !reading.valid() {
		return none
	}
	return json2.encode(CoalitionInstructionCheckpoint{
		label: label
		coalition_id: reading.coalition_id
		instructions: reading.instructions
		tasks_started: reading.tasks_started
		tasks_exited: reading.tasks_exited
	})
}

// Report exactly the stored boundary reading, without sampling a second time.
pub fn report_coalition_instruction_snapshot(label string, reading CoalitionInstructionSnapshot) {
	if !instructions_enabled() {
		return
	}
	if record := coalition_instruction_record(label, reading) {
		eprintln('Vox coalition instructions: ${record}')
	} else {
		eprintln('Vox coalition instructions unavailable: ${label} error=${reading.error_code}')
	}
}

pub fn coalition_instruction_checkpoint(label string) {
	if !instructions_enabled() {
		return
	}
	report_coalition_instruction_snapshot(label, coalition_instruction_snapshot())
}

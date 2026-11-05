module processmetrics

$if !darwin {
	fn instruction_stage_main_thread() bool { return false }
	pub fn instruction_snapshot() InstructionSnapshot {
		return InstructionSnapshot{ error_code: -1 }
	}

	pub fn coalition_instruction_snapshot() CoalitionInstructionSnapshot {
		return CoalitionInstructionSnapshot{ error_code: -1 }
	}
}

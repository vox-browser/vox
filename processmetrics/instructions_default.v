module processmetrics

$if !darwin {
	pub fn instruction_snapshot() InstructionSnapshot {
		return InstructionSnapshot{ error_code: -1 }
	}
}

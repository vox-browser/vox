module processmetrics

#include "instruction_counter_darwin.h"

fn C.vox_process_instructions(&u64) int

pub fn instruction_snapshot() InstructionSnapshot {
	mut count := u64(0)
	status := C.vox_process_instructions(&count)
	return InstructionSnapshot{ instructions: count, available: status == 0, error_code: status }
}

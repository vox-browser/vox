module processmetrics

#include "instruction_counter_darwin.h"
#include <pthread.h>

fn C.vox_process_instructions(&u64) int
fn C.vox_coalition_instructions(&u64, &u64, &u64, &u64) int
fn C.pthread_main_np() int

fn instruction_stage_main_thread() bool {
	return C.pthread_main_np() != 0
}

pub fn instruction_snapshot() InstructionSnapshot {
	mut count := u64(0)
	status := C.vox_process_instructions(&count)
	return InstructionSnapshot{ instructions: count, available: status == 0, error_code: status }
}

pub fn coalition_instruction_snapshot() CoalitionInstructionSnapshot {
	mut coalition_id := u64(0)
	mut instructions := u64(0)
	mut tasks_started := u64(0)
	mut tasks_exited := u64(0)
	status := C.vox_coalition_instructions(&coalition_id, &instructions, &tasks_started, &tasks_exited)
	return CoalitionInstructionSnapshot{
		coalition_id: coalition_id
		instructions: instructions
		tasks_started: tasks_started
		tasks_exited: tasks_exited
		available: status == 0
		error_code: status
	}
}

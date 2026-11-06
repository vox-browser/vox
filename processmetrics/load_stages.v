module processmetrics

import os

#include "load_stage_log.h"
fn C.vox_load_stage_begin_log(i32, u64, u64, &char, uint)
fn C.vox_load_stage_end_log(i32, u64, u64)
fn C.vox_load_stage_unavailable_log(i32, u64, i32)
fn C.vox_thread_stage_begin_log(i32, u64, u64, &char, uint)
fn C.vox_thread_stage_end_log(i32, u64, u64)
fn C.vox_thread_stage_unavailable_log(i32, u64, i32)

const load_stage_diagnostics = os.getenv('VOX_DIAGNOSTIC_LOAD_STAGES') != ''
const thread_load_stage_diagnostics = os.getenv('VOX_DIAGNOSTIC_THREAD_LOAD_STAGES') != ''
__global load_stage_next_id u64
__global load_stage_current_is_javascript bool

pub struct InstructionStage {
	id u64
	previous_is_javascript bool
}

pub struct ThreadInstructionSubstage {
	id u64
	previous_is_javascript bool
}

// Fine-grained native stages need only the calling-thread stream. Polling
// proc_pid_rusage at every boundary is expensive enough to dominate small
// stages. Share identities with ordinary stages so the thread stream still
// nests exactly, while leaving the coarser process/coalition endpoints intact.
pub fn begin_thread_instruction_substage(label string) ThreadInstructionSubstage {
	if !load_stage_diagnostics || !thread_load_stage_diagnostics
		|| !instruction_stage_main_thread() || !instructions_enabled() {
		return ThreadInstructionSubstage{}
	}
	reading := thread_instruction_snapshot()
	if !reading.available {
		C.vox_thread_stage_unavailable_log(i32(os.getpid()), 0, i32(reading.error_code))
		return ThreadInstructionSubstage{}
	}
	load_stage_next_id++
	id := load_stage_next_id
	previous_is_javascript := load_stage_current_is_javascript
	load_stage_current_is_javascript = false
	C.vox_thread_stage_begin_log(i32(os.getpid()), id, reading.instructions, label.str, uint(label.len))
	return ThreadInstructionSubstage{id: id, previous_is_javascript: previous_is_javascript}
}

pub fn (stage ThreadInstructionSubstage) finish() {
	if stage.id == 0 { return }
	load_stage_current_is_javascript = stage.previous_is_javascript
	reading := thread_instruction_snapshot()
	if !reading.available {
		C.vox_thread_stage_unavailable_log(i32(os.getpid()), stage.id, i32(reading.error_code))
		return
	}
	C.vox_thread_stage_end_log(i32(os.getpid()), stage.id, reading.instructions)
}

// Main-thread nesting partitions process-counter intervals. Other threads'
// concurrent work remains in the process reading; this is not a thread counter.
pub fn begin_instruction_stage(label string) InstructionStage {
	if !load_stage_diagnostics || !instruction_stage_main_thread() || !instructions_enabled() {
		return InstructionStage{}
	}
	reading := instruction_snapshot()
	if !reading.available {
		C.vox_load_stage_unavailable_log(i32(os.getpid()), 0, i32(reading.error_code))
		return InstructionStage{}
	}
	load_stage_next_id++
	id := load_stage_next_id
	previous_is_javascript := load_stage_current_is_javascript
	load_stage_current_is_javascript = false
	C.vox_load_stage_begin_log(i32(os.getpid()), id, reading.instructions, label.str, uint(label.len))
	if thread_load_stage_diagnostics {
		thread_reading := thread_instruction_snapshot()
		if thread_reading.available {
			C.vox_thread_stage_begin_log(i32(os.getpid()), id, thread_reading.instructions, label.str, uint(label.len))
		} else { C.vox_thread_stage_unavailable_log(i32(os.getpid()), id, i32(thread_reading.error_code)) }
	}
	return InstructionStage{id: id, previous_is_javascript: previous_is_javascript}
}

pub fn (stage InstructionStage) finish() {
	if stage.id == 0 { return }
	load_stage_current_is_javascript = stage.previous_is_javascript
	if thread_load_stage_diagnostics {
		thread_reading := thread_instruction_snapshot()
		if thread_reading.available {
			C.vox_thread_stage_end_log(i32(os.getpid()), stage.id, thread_reading.instructions)
		} else { C.vox_thread_stage_unavailable_log(i32(os.getpid()), stage.id, i32(thread_reading.error_code)) }
	}
	reading := instruction_snapshot()
	if !reading.available {
		C.vox_load_stage_unavailable_log(i32(os.getpid()), stage.id, i32(reading.error_code))
		return
	}
	C.vox_load_stage_end_log(i32(os.getpid()), stage.id, reading.instructions)
}

// Coalesce nested engine calls while already in JS. An explicitly measured
// native child (style/layout/etc.) changes the active kind, so a JS callback
// from that child gets its own scope instead of being charged to native work.
pub fn begin_javascript_instruction_stage() InstructionStage {
	if !load_stage_diagnostics || !instruction_stage_main_thread() || !instructions_enabled() {
		return InstructionStage{}
	}
	if load_stage_current_is_javascript { return InstructionStage{} }
	stage := begin_instruction_stage('javascript_execution_and_bindings')
	if stage.id > 0 { load_stage_current_is_javascript = true }
	return stage
}

pub fn load_stages_enabled() bool {
	return load_stage_diagnostics && instructions_enabled()
}

// A scalar token crosses the native ABI without allocating a wrapper or
// maintaining a second identity stack. Native callers finish on the same
// thread in @finally, including when an Objective-C callback throws.
pub fn begin_native_instruction_stage(label &char) u64 {
	stage := begin_instruction_stage(unsafe { cstring_to_vstring(label) })
	return (stage.id << 1) | u64(stage.previous_is_javascript)
}

pub fn finish_native_instruction_stage(token u64) {
	stage := InstructionStage{id: token >> 1, previous_is_javascript: (token & 1) != 0}
	stage.finish()
}

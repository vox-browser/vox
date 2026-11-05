module processmetrics

import os

const load_stage_diagnostics = os.getenv('VOX_DIAGNOSTIC_LOAD_STAGES') != ''
__global load_stage_next_id u64
__global load_stage_current_is_javascript bool

pub struct InstructionStage {
	id u64
	previous_is_javascript bool
}

// Main-thread nesting partitions process-counter intervals. Other threads'
// concurrent work remains in the process reading; this is not a thread counter.
pub fn begin_instruction_stage(label string) InstructionStage {
	if !load_stage_diagnostics || !instruction_stage_main_thread() || !instructions_enabled() {
		return InstructionStage{}
	}
	reading := instruction_snapshot()
	if !reading.available {
		eprintln('Vox instruction stage unavailable: ${os.getpid()} begin ${label} error=${reading.error_code}')
		return InstructionStage{}
	}
	load_stage_next_id++
	id := load_stage_next_id
	previous_is_javascript := load_stage_current_is_javascript
	load_stage_current_is_javascript = false
	eprintln('Vox instruction stage begin: ${os.getpid()} ${id} ${reading.instructions} ${label}')
	return InstructionStage{id: id, previous_is_javascript: previous_is_javascript}
}

pub fn (stage InstructionStage) finish() {
	if stage.id == 0 { return }
	load_stage_current_is_javascript = stage.previous_is_javascript
	reading := instruction_snapshot()
	if !reading.available {
		eprintln('Vox instruction stage unavailable: ${os.getpid()} ${stage.id}')
		return
	}
	eprintln('Vox instruction stage end: ${os.getpid()} ${stage.id} ${reading.instructions}')
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

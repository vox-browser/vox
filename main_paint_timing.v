module main

import time
import processmetrics

// Native frame submission timing. This is not the web Performance API's FCP:
// it includes all document installation work and ends at the first submitted
// document frame, without waiting for screenshot capture or background refresh.
struct BrowserPaintTiming {
mut:
	navigation_start_ns       i64
	document_install_start_ns i64
	navigation_painted        bool
	navigation_instructions   processmetrics.InstructionSnapshot
	installation_instructions processmetrics.InstructionSnapshot
}

fn (mut timing BrowserPaintTiming) begin_navigation() {
	timing.navigation_start_ns = time.sys_mono_now()
	timing.navigation_painted = false
	timing.navigation_instructions = processmetrics.begin_instructions()
	coalition := processmetrics.begin_coalition_instructions()
	processmetrics.report_instruction_snapshot('navigation_started', timing.navigation_instructions)
	processmetrics.report_coalition_instruction_snapshot('navigation_started', coalition)
}

fn (mut timing BrowserPaintTiming) report_document_paint() {
	end_instructions := processmetrics.begin_instructions()
	now := time.sys_mono_now()
	if debug_timing_enabled() {
		if timing.document_install_start_ns > 0 {
			eprintln('Ladybird V timing: document_install_to_first_paint ${(now - timing.document_install_start_ns) / 1_000_000} ms')
		}
		if !timing.navigation_painted && timing.navigation_start_ns > 0 {
			eprintln('Ladybird V timing: navigation_to_first_document_paint ${(now - timing.navigation_start_ns) / 1_000_000} ms')
		}
	}
	processmetrics.report_instructions('document_install_to_first_paint', timing.installation_instructions, end_instructions)
	if !timing.navigation_painted && timing.navigation_start_ns > 0 {
		processmetrics.report_instructions('navigation_to_first_document_paint', timing.navigation_instructions, end_instructions)
	}
	timing.navigation_painted = true
}

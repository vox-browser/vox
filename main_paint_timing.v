module main

import time

// Native frame submission timing. This is not the web Performance API's FCP:
// it includes all document installation work and ends at the first submitted
// document frame, without waiting for screenshot capture or background refresh.
struct BrowserPaintTiming {
mut:
	navigation_start_ns       i64
	document_install_start_ns i64
	navigation_painted        bool
}

fn (mut timing BrowserPaintTiming) begin_navigation() {
	timing.navigation_start_ns = time.sys_mono_now()
	timing.navigation_painted = false
}

fn (mut timing BrowserPaintTiming) report_document_paint() {
	now := time.sys_mono_now()
	if debug_timing_enabled() {
		if timing.document_install_start_ns > 0 {
			eprintln('Ladybird V timing: document_install_to_first_paint ${(now - timing.document_install_start_ns) / 1_000_000} ms')
		}
		if !timing.navigation_painted && timing.navigation_start_ns > 0 {
			eprintln('Ladybird V timing: navigation_to_first_document_paint ${(now - timing.navigation_start_ns) / 1_000_000} ms')
		}
	}
	timing.navigation_painted = true
}

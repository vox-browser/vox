module dom

// document.open() reuses the Document and realm, but begins a new input stream.
// Readiness claims and queued parser work belong to that stream.
pub fn (document &Document) html_parser_stream_generation() u64 {
	return document.html_parser_stream_generation_
}

fn (mut document Document) reset_html_parser_stream() {
	document.html_parser_stream_generation_++
	document.parser = unsafe { nil }
	document.active_parser_was_aborted = false
	document.html_parser_end_state_target = unsafe { nil }
	document.html_parser_end_state_schedule_callback = unsafe { nil }
	document.pending_parsing_blocking_script = unsafe { nil }
	document.pending_parsing_blocking_svg_script = unsafe { nil }
	document.scripts_to_execute_when_parsing_has_finished.clear()
	document.scripts_to_execute_as_soon_as_possible.clear()
	document.scripts_to_execute_in_order_as_soon_as_possible.clear()
	document.fired_dom_content_loaded = false
	document.fired_load_event = false
	document.completely_loaded_time = false
	document.completely_loaded_deferred = false
	document.ready_for_post_load_tasks = false
	document.load_timing_info.dom_interactive_time = 0
	document.load_timing_info.dom_complete_time = 0
	document.load_timing_info.dom_content_loaded_event_start_time = 0
	document.load_timing_info.dom_content_loaded_event_end_time = 0
	document.load_timing_info.load_event_start_time = 0
	document.load_timing_info.load_event_end_time = 0
}

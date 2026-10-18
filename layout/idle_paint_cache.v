module layout

import dom

// The published vector owns every command needed to replay the current frame.
// Between recordings, phase buckets and the returned vector are only reusable
// storage. Release their backing arrays at the embedder's static idle boundary.
pub fn release_unused_display_list_caches(display_list &dom.DisplayList) {
	if display_list == unsafe { nil } || display_list.concrete_handle == unsafe { nil } {
		return
	}
	mut result := viewport_layout_result(display_list.concrete_handle)
	if voidptr(result.display_list) != voidptr(display_list) || result.needs_repaint {
		return
	}
	// The replay plan holds pointers into phase buckets. Drop the complete
	// scratch generation together; clear() would retain scanned backing storage.
	result.record_scratch = CompatibilityRecordScratch{}
	result.paint_phase_commands = [][]PaintCommand{}
	result.paint_phase_entry_valid = []bool{}
	result.paint_phase_command_count = 0
	result.paint_phase_cache_valid = false
}

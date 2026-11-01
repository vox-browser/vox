module css

import os

const disable_font_completion_coalescing = os.getenv('VOX_DISABLE_FONT_COMPLETION_COALESCING') != ''
const font_completion_coalescing_diagnostics = os.getenv('VOX_FONT_COMPLETION_COALESCING_DIAGNOSTICS') != ''

// A face can finish after the last rendering checkpoint made the environment
// clean. Its newly dirty style/layout belongs to the next rendering update,
// just like other pending environment work. Keep ready pending until that
// update also discovers any additional faces selected by the new layout.
fn (mut set FontFaceSet) wait_for_pending_document_rendering() bool {
	if disable_font_completion_coalescing { return false }
	computer := set.font_computer_ or { return false }
	document := computer.document_ or { return false }
	if document.layout_engine_handle() == unsafe { nil } || document.is_running_update_layout()
		|| !document.is_fully_active()
		|| (document.layout_is_up_to_date() && !document.needs_style_update_after_layout()) {
		return false
	}
	set.is_pending_on_the_environment = true
	set.is_stuck_on_the_environment = true
	if font_completion_coalescing_diagnostics {
		eprintln('Vox font completion: awaiting pending rendering environment')
	}
	return true
}

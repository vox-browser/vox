module layout

import dom
import os
import platform

const disable_early_text_font_requests = os.getenv('VOX_DISABLE_EARLY_TEXT_FONT_REQUESTS') != ''
const early_text_font_request_diagnostics = os.getenv('VOX_EARLY_TEXT_FONT_REQUEST_DIAGNOSTICS') != ''

// Resource planning can already have published the initial cascade. Start the
// text faces it selected before script/bootstrap work, without another style
// pass, temporary geometry or a broader font preload. Dirty styles keep their
// ordinary first-layout selection, including any intervening script changes.
pub fn request_fonts_for_existing_document_text(document &dom.Document) bool {
	if disable_early_text_font_requests || document == unsafe { nil }
		|| document.layout_root != unsafe { nil }
		|| document.needs_style_update_after_layout()
		|| document.has_pending_style_sheet_requests() {
		return false
	}
	root := document.document_element() or { return false }
	if root.el_computed_properties() == none || document.element_needs_style_update(root) {
		return false
	}
	mut font_policy := platform.begin_layout_font_policy_scope()
	defer { font_policy.finish() }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	request_fonts_for_computed_text(document)
	if early_text_font_request_diagnostics {
		eprintln('Vox early text fonts: requested faces from existing clean styles')
	}
	return true
}

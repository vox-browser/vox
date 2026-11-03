module layout

import css
import dom
import platform

// Use the ordinary style preparation and document arena, but leave geometry
// to the immediately following layout. The embedding can start a bounded set
// of computed image requests while that geometry is being constructed.
pub fn prepare_initial_resource_styles(document &dom.Document, width f64, height f64) {
	mut font_policy := platform.begin_layout_font_policy_scope()
	defer { font_policy.finish() }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	css.begin_selector_parse_cache()
	defer { css.end_selector_parse_cache() }
	mut owner := unsafe { &dom.Document(document) }
	previous := document.viewport_rect()
	owner.set_viewport_rect(dom.Rect{previous.x, previous.y, width, height})
	prepare_document_style_inputs(document)
	install_document_layout_hook(document)
	owner.update_style()
}

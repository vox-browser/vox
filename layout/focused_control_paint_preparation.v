module layout

import dom

// A geometry query can finish before a newly focused control has created its
// native editing owner and UA shadow tree. Paint-only shell adoption needs the
// same preparation as run_document_layout(), before updating layout again.
pub fn prepare_focused_text_controls_for_paint(document &dom.Document) {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	materialize_focused_text_control_models(document)
}

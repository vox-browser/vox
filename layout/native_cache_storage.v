module layout

import dom
import platform

// SVG image documents and other host borrowers can be visited while a
// different document's arena is entered. Their caches keep their own lifetime.
fn cache_uses_entered_document_storage(document &dom.Document) bool {
	owner := document.native_storage()
	return owner != unsafe { nil }
		&& voidptr(owner) == voidptr(platform.current_retained_arena())
}

fn block_paint_caches_use_entered_document_storage(state &LayoutState) bool {
	mut found := false
	for _, cache in state.block_layouts_ {
		if cache.inputs.len == 0 { continue }
		if !cache_uses_entered_document_storage(cache.inputs[0].node.document()) { return false }
		found = true
	}
	return found
}

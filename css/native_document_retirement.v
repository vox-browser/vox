module css

import dom

// Called only after the native browser closes this document's script runtime;
// history restoration constructs a new document. Keep live/adopted nodes and
// global font resources intact while releasing per-element resolved values.
pub fn discard_native_document_computed_styles(document &dom.Document) bool {
	if document.is_fully_active() { return false }
	document.as_node().for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.clear_layout_node_and_paintable()
		if mut element := node.as_element() { element.discard_native_computed_properties() }
		return .@continue
	})
	if document.style_computer != unsafe { nil }
		&& document.style_computer.css_handle != unsafe { nil } {
		mut computer := unsafe { &StyleComputer(document.style_computer.css_handle) }
		computer.cached_font_computation_context = none
		computer.cached_line_height_computation_context = none
		computer.cached_generic_computation_context = none
		computer.computed_property_page_interner_ = unsafe { nil }
		computer.has_result_cache_ = &HasResultCache{}
		computer.matching_rule_candidates_ = unsafe { nil }
	}
	return true
}

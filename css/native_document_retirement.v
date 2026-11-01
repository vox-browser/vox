module css

import dom

// Called only after the native browser closes this document's script runtime;
// history restoration constructs a new document. Keep live/adopted nodes and
// global font resources intact while releasing per-element resolved values.
pub fn discard_native_document_computed_styles(document &dom.Document) bool {
	if document.is_fully_active() { return false }
	discard_native_style_scope_caches(document.style_scope())
	// The registry also includes disconnected shadow roots. They can retain
	// the document's shared UA cache after their host leaves the DOM tree.
	for shadow_root in document.registered_shadow_roots() {
		discard_native_style_scope_caches(shadow_root.style_scope())
	}
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
		computer.deferred_hidden_styles_ = map[u64]bool{}
	}
	return true
}

fn discard_native_style_scope_caches(dom_scope &dom.StyleScope) {
	if dom_scope.css_handle == unsafe { nil } { return }
	mut scope := unsafe { &StyleScope(dom_scope.css_handle) }
	// Drop derived indices, preserving stylesheet and CSSOM identity. A later
	// style query on the inactive document rebuilds them from its live sheets.
	// Never mutate a cache object: constructed sheets may share it with another
	// scope, and the UA sheets themselves are process-wide resources.
	scope.rule_cache = none
	scope.author_rule_cache = none
	scope.user_rule_cache = none
	scope.user_agent_rule_cache = none
	scope.pseudo_class_rule_cache = map[PseudoClass]&RuleCache{}
	scope.style_invalidation_data = none
	scope.selector_insights = none
	scope.qualified_layer_names_in_order = []string{}
	scope.registered_counter_styles = map[string]CounterStyle{}
	scope.needs_counter_style_cache_update = true
	scope.has_size_container_queries = false
	scope.user_agent_only_shadow_cache_ = unsafe { nil }
	scope.adopted_user_agent_only_shadow_cache_ = unsafe { nil }
}

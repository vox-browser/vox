module layout

import css
import dom
import html

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
}

fn passthrough_resolve_full(retained RetainedFlowSubtree, mut builder TreeBuilderState) {
	for element in retained.elements {
		properties := css.computed_properties_for_element(element) or { panic('missing style') }
		resolve_layout_counters(mut builder, dom.AbstractElement.new(element, none), properties)
	}
}

fn passthrough_compare_full_rebuild(mut document dom.Document) {
	current := (document.record_display_list() or { panic('missing recording') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full recording') }).dump() == current
}

fn test_empty_retained_counter_passthrough_preserves_following_origins_and_avoids_per_node_resolution() {
	mut document := html.parse_document('<!doctype html><main><section id="stable">' + '<div><p>retained <strong>text</strong><span> tail</span></p></div>'.repeat(96) + '</section><p id="after" style="counter-increment:n">after</p></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	after := document.get_element_by_id('after')?
	mut rejected := map[u64]bool{}
	retained := reusable_clean_flow_subtree(stable, mut rejected)?
	assert retained.elements.len > 300
	assert retained_flow_has_no_counter_operations(retained.elements)
	mut fast := TreeBuilderState{}
	mut full := TreeBuilderState{}
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	resolve_retained_flow_counters(retained, mut fast)
	mut fast_bytes := usize(0)
	$if gcboehm ? { fast_bytes = C.GC_get_total_bytes() - before }
	assert fast.counter_tree_order_index == retained.elements.len
	assert fast.counter_sets.len == 0
	last_abstract := dom.AbstractElement.new(retained.elements.last(), none)
	assert fast.last_processed_key == abstract_element_counter_key(last_abstract)
	properties := css.computed_properties_for_element(after)?
	resolve_layout_counters(mut fast, dom.AbstractElement.new(after, none), properties)
	after_abstract := dom.AbstractElement.new(after, none)
	fast_result := css.counters_set_for_abstract_element(&after_abstract)?.dump()
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	passthrough_resolve_full(retained, mut full)
	mut full_bytes := usize(0)
	$if gcboehm ? { full_bytes = C.GC_get_total_bytes() - before }
	resolve_layout_counters(mut full, after_abstract, properties)
	assert full.counter_tree_order_index == fast.counter_tree_order_index
	assert full.last_processed_key == fast.last_processed_key
	assert css.counters_set_for_abstract_element(&after_abstract)?.dump() == fast_result
	$if gcboehm ? {
		// Value-only target queries also make the full empty-prefix traversal
		// allocation-free. Keep the original ratio guard when it allocates.
		assert (fast_bytes == 0 && full_bytes == 0) || (full_bytes > 0 && fast_bytes * 2 < full_bytes),
			'empty counter traversal allocated ${fast_bytes} bytes; full traversal allocated ${full_bytes}'
	}
	// An external counter consumer can install a set without changing style.
	// A later retained traversal must clear that stale descendant as well.
	mut last := dom.AbstractElement.new(retained.elements.last(), none)
	css.set_counters_set_for_abstract_element(mut last, css.counters_set_for_abstract_element(&after_abstract))
	assert last.counters_set() != none
	assert retained_flow_has_no_counter_operations(retained.elements)
	mut refreshed := TreeBuilderState{}
	resolve_retained_flow_counters(retained, mut refreshed)
	assert last.counters_set() == none
	assert retained_flow_has_no_counter_operations(retained.elements)
	assert refreshed.counter_tree_order_index == retained.elements.len
}

fn test_retained_empty_counter_branches_observe_new_incoming_scopes_and_later_counter_styles() {
	mut document := html.parse_document('<!doctype html><style>#after::before{content:counter(n)}</style><div id="before" style="display:none;counter-reset:n 7"></div><section id="stable"><p id="inside">retained <strong>branch</strong></p></section><p id="after" style="counter-increment:n"></p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut before := document.get_element_by_id('before')?
	stable := document.get_element_by_id('stable')?
	for style in ['display:block;counter-reset:n 7', 'display:none;counter-reset:n 7', 'display:block;counter-reset:n 12'] {
		handle := stable.as_node().unsafe_layout_node()?.real_layout_handle()
		before.set_attribute_value('style', style)
		document.update_layout(.debugging)
		assert stable.as_node().unsafe_layout_node()?.real_layout_handle() == handle
		passthrough_compare_full_rebuild(mut document)
	}
	mut inside := document.get_element_by_id('inside')?
	inside.set_attribute_value('style', 'counter-reset:n 23;counter-increment:n 2')
	// Exercise this TreeBuilder path after an actual tree invalidation. A
	// counter-only style mutation currently leaves the old tree in both the
	// pre-optimization and optimized engines.
	before.set_inner_html('<span>new preceding child</span>')!
	document.update_layout(.debugging)
	inside_abstract := dom.AbstractElement.new(inside, none)
	set := css.counters_set_for_abstract_element(&inside_abstract)?
	counter := set.last_counter_with_name('n')?
	value := counter.value or { panic('missing resolved counter value') }
	assert value == 25
	passthrough_compare_full_rebuild(mut document)
}

fn test_nonempty_retained_counter_passthrough_matches_full_resolution_and_keeps_dom_snapshots_independent() {
	mut document := html.parse_document('<!doctype html><main id="parent" style="counter-reset:n 5"><section id="stable"><p id="first">one <strong>two</strong></p><p id="last">three</p></section><p id="after" style="counter-increment:n">after</p></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	parent := document.get_element_by_id('parent')?
	stable := document.get_element_by_id('stable')?
	after := document.get_element_by_id('after')?
	first_element := document.get_element_by_id('first')?
	last_element := document.get_element_by_id('last')?
	first := dom.AbstractElement.new(first_element, none)
	last := dom.AbstractElement.new(last_element, none)
	mut rejected := map[u64]bool{}
	retained := reusable_clean_flow_subtree(stable, mut rejected)?
	assert retained_flow_has_no_counter_operations(retained.elements)
	assert !retained_flow_has_no_counter_operations([after])
	mut fast := TreeBuilderState{}
	parent_style := css.computed_properties_for_element(parent)?
	resolve_layout_counters(mut fast, dom.AbstractElement.new(parent, none), parent_style)
	resolve_retained_flow_counters(retained, mut fast)
	first_snapshot := css.counters_set_for_abstract_element(&first)?
	last_snapshot := css.counters_set_for_abstract_element(&last)?
	assert first_snapshot.dump() == last_snapshot.dump()
	assert first_snapshot.counters().data != last_snapshot.counters().data
	properties := css.computed_properties_for_element(after)?
	resolve_layout_counters(mut fast, dom.AbstractElement.new(after, none), properties)
	after_abstract := dom.AbstractElement.new(after, none)
	fast_result := css.counters_set_for_abstract_element(&after_abstract)?.dump()
	first_result := css.counters_set_for_abstract_element(&first)?.dump()
	last_result := css.counters_set_for_abstract_element(&last)?.dump()
	mut full := TreeBuilderState{}
	resolve_layout_counters(mut full, dom.AbstractElement.new(parent, none), parent_style)
	passthrough_resolve_full(retained, mut full)
	resolve_layout_counters(mut full, after_abstract, properties)
	assert full.counter_tree_order_index == fast.counter_tree_order_index
	assert css.counters_set_for_abstract_element(&after_abstract)?.dump() == fast_result
	assert css.counters_set_for_abstract_element(&first)?.dump() == first_result
	assert css.counters_set_for_abstract_element(&last)?.dump() == last_result
}

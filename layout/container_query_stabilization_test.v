module layout

import html

fn test_size_query_in_hidden_subtree_stabilizes_and_rechecks_when_shown() {
	mut document := html.parse_document('<!doctype html><style>
		#hidden { display: none }
		#container { container: card / inline-size; width: 400px }
		#target { width: 20px; height: 10px }
		@container card (width >= 300px) { #target { width: 50px } }
	</style><div id="hidden"><div id="container"><div id="target"></div></div></div>')
	mut hidden := document.get_element_by_id('hidden') or { panic('missing hidden wrapper') }
	container := document.get_element_by_id('container') or { panic('missing container') }
	target := document.get_element_by_id('target') or { panic('missing target') }

	_ = run_document_layout(document, 800, 600) or { panic('hidden layout did not stabilize') }
	assert document.layout_is_up_to_date()
	assert container.as_node().unsafe_layout_node() == none
	assert !document.needs_container_query_evaluation_after_layout(container)

	hidden.set_attribute_value('style', 'display: block')
	document.update_layout(.debugging)
	assert document.layout_is_up_to_date()
	assert container.client_width() == 400
	assert target.client_width() == 50
	assert !document.needs_container_query_evaluation_after_layout(container)
}

fn test_size_query_boxless_container_stabilizes_and_rechecks_when_box_is_created() {
	mut document := html.parse_document('<!doctype html><style>
		#container { display: contents; container: card / inline-size; width: 400px }
		#target { width: 20px; height: 10px }
		@container card (width >= 300px) { #target { width: 50px } }
	</style><div id="container"><div id="target"></div></div>')
	mut container := document.get_element_by_id('container') or { panic('missing container') }
	target := document.get_element_by_id('target') or { panic('missing target') }

	_ = run_document_layout(document, 800, 600) or { panic('boxless layout did not stabilize') }
	assert document.layout_is_up_to_date()
	assert container.as_node().unsafe_layout_node() == none
	assert target.client_width() == 20
	assert !document.needs_container_query_evaluation_after_layout(container)

	container.set_attribute_value('style', 'display: block')
	document.update_layout(.debugging)
	assert document.layout_is_up_to_date()
	assert container.client_width() == 400
	assert target.client_width() == 50
	assert !document.needs_container_query_evaluation_after_layout(container)
}

fn test_nested_size_queries_recheck_committed_geometry_after_outer_resize() {
	mut document := html.parse_document('<!doctype html><style>
		#outer { container: outer / inline-size; width: 400px }
		#inner { container: inner / inline-size; width: 100px }
		#target { width: 20px; height: 10px }
		@container outer (width >= 300px) { #inner { width: 320px } }
		@container inner (width >= 300px) { #target { width: 50px } }
	</style><div id="outer"><div id="inner"><div id="target"></div></div></div>')
	mut outer := document.get_element_by_id('outer') or { panic('missing outer container') }
	inner := document.get_element_by_id('inner') or { panic('missing inner container') }
	mut target := document.get_element_by_id('target') or { panic('missing target') }

	_ = run_document_layout(document, 800, 600) or { panic('nested layout did not stabilize') }
	assert document.layout_is_up_to_date()
	assert inner.client_width() == 320
	assert target.client_width() == 50
	assert !document.needs_container_query_evaluation_after_layout(outer)
	assert !document.needs_container_query_evaluation_after_layout(inner)

	outer.set_attribute_value('style', 'width: 200px')
	document.update_layout(.debugging)
	assert document.layout_is_up_to_date()
	assert inner.client_width() == 100
	assert target.client_width() == 20
	assert !document.needs_container_query_evaluation_after_layout(outer)
	assert !document.needs_container_query_evaluation_after_layout(inner)

	// Both inline-size containers grow in their block axis. Their unchanged
	// inline sizes must not trigger another dependent-style invalidation.
	scan_visits := document.style_invalidation_counters().size_query_container_scan_visits
	target.set_attribute_value('style', 'height: 30px')
	document.update_layout(.debugging)
	assert target.client_height() == 30
	assert inner.client_width() == 100
	assert document.style_invalidation_counters().size_query_container_scan_visits == scan_visits
}

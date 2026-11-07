module layout

import dom
import html

fn grid_track_cache_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn grid_track_cache_test_document(columns string, rows string) &dom.Document {
	mut document := html.parse_document('<!doctype html><body style="margin:0"><section id="grid" style="display:grid;width:300px;font-size:20px;gap:10px;grid-template-columns:${columns};grid-template-rows:${rows}"><div id="a">A</div><div id="b">B</div><div id="c">C</div></section></body>')
	_ = layout_document_typed_in_viewport(document, 400, 400)
	return document
}

fn test_computed_absolute_lengths_are_context_free_and_calculations_are_not() {
	// Computed track lists already resolve font and viewport units to pixels.
	for columns in ['80px 1fr', 'repeat(3, minmax(10px, 1fr))', '20% auto', 'repeat(auto-fill, 50px)',
		'min-content max-content', '2em 1fr', '10vw 1fr', 'minmax(1rem, 1fr) 20px'] {
		mut document := grid_track_cache_test_document(columns, 'auto')
		defer { document.finalize() }
		computed := grid_track_cache_test_node(document, 'grid').computed_values()
		assert grid_track_list_is_context_free(computed.grid_template_columns()), columns
	}
	for columns in ['calc(10px + 5%) 1fr', 'minmax(calc(1px + 1%), 1fr) 20px', 'repeat(2, calc(50% - 5px))'] {
		mut document := grid_track_cache_test_document(columns, 'auto')
		defer { document.finalize() }
		computed := grid_track_cache_test_node(document, 'grid').computed_values()
		assert !grid_track_list_is_context_free(computed.grid_template_columns()), columns
	}
}

fn test_cached_initial_tracks_match_the_resolver_and_are_detached_copies() {
	mut document := grid_track_cache_test_document('80px 20% 1fr', '30px auto')
	defer { document.finalize() }
	container := grid_track_cache_test_node(document, 'grid')
	computed := container.computed_values()
	available := CSSPixels.new(300)
	gap := CSSPixels.new(10)
	direct := resolve_grid_tracks(container, computed.grid_template_columns(), computed.grid_auto_columns(),
		available, gap, true, 0, 3)
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	mut first := resolve_grid_axis_tracks_in_state(mut state, container, true, available, gap, true, 0, 3)
	assert first == direct
	key := u64(voidptr(container))
	pool := state.measurement_chunk_pool_
	expected_entries := if disable_grid_track_resolution_reuse || computed.mutation_revision() == 0 { 0 } else { 1 }
	assert (pool.grid_track_resolutions_[key] or { []&GridTrackResolutionCache{} }).len == expected_entries
	// Sizing mutates the returned vector; later probes must start from the original tracks.
	first[0].base_size = CSSPixels.new(1)
	first[1].collapsed = true
	second := resolve_grid_axis_tracks_in_state(mut state, container, true, available, gap, true, 0, 3)
	assert second == direct
	// A different available size is a different question.
	narrow := resolve_grid_axis_tracks_in_state(mut state, container, true, CSSPixels.new(150), gap, true, 0, 3)
	assert narrow == resolve_grid_tracks(container, computed.grid_template_columns(), computed.grid_auto_columns(),
		CSSPixels.new(150), gap, true, 0, 3)
	rows := resolve_grid_axis_tracks_in_state(mut state, container, false, available, gap, false, 0, 2)
	assert rows == resolve_grid_tracks(container, computed.grid_template_rows(), computed.grid_auto_rows(),
		available, gap, false, 0, 2)
	state.release_measurement_chunk_pool()
	assert pool.closed && pool.grid_track_resolutions_.len == 0
}

fn test_calculated_tracks_and_poolless_states_bypass_the_cache() {
	mut document := grid_track_cache_test_document('calc(10px + 5%) 1fr', 'auto')
	defer { document.finalize() }
	container := grid_track_cache_test_node(document, 'grid')
	computed := container.computed_values()
	direct := resolve_grid_tracks(container, computed.grid_template_columns(), computed.grid_auto_columns(),
		CSSPixels.new(300), CSSPixels.new(10), true, 0, 3)
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	for _ in 0 .. 2 {
		assert resolve_grid_axis_tracks_in_state(mut state, container, true, CSSPixels.new(300),
			CSSPixels.new(10), true, 0, 3) == direct
	}
	assert state.measurement_chunk_pool_.grid_track_resolutions_.len == 0
	mut plain := LayoutState.new()
	assert resolve_grid_axis_tracks_in_state(mut plain, container, true, CSSPixels.new(300),
		CSSPixels.new(10), true, 0, 3) == direct
}

fn test_grid_layout_places_items_by_resolved_tracks_before_and_after_a_style_change() {
	mut document := grid_track_cache_test_document('80px 20% 1fr', '30px')
	defer { document.finalize() }
	expect := fn (document &dom.Document, xs []f64, widths []f64) {
		for index, id in ['a', 'b', 'c'] {
			rect := document.get_element_by_id(id) or { panic('missing item') }.get_bounding_client_rect()
			assert rect.x == xs[index], '${id} x ${rect.x}'
			assert rect.width == widths[index], '${id} width ${rect.width}'
		}
	}
	// 300px wide with two 10px gaps: 80px, 20% of 300px and the remaining 140px.
	expect(document, [0.0, 90, 160], [80.0, 60, 140])
	mut grid := document.get_element_by_id('grid') or { panic('missing grid') }
	grid.set_attribute_value('style', 'display:grid;width:300px;gap:10px;grid-template-columns:50px 1fr 50px;grid-template-rows:30px')
	document.update_layout(.debugging)
	expect(document, [0.0, 60, 250], [50.0, 180, 50])
}

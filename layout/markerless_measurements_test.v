module layout

import dom
import html

fn test_markerless_grid_measurement_owns_nested_list_geometry_after_scratch_release() {
	for position in ['inside', 'outside'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:1fr 2fr;width:240px"><ul style="margin:0;padding:0;list-style:none ${position}"><li id="item">Wrapping markerless text alpha beta gamma.<div>Nested block.</div></li><li>More text.</li></ul><p>Second track.</p></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		item := grid_measurement_test_node(document, 'item')
		assert item.is_list_item_box() && measurement_list_item_has_no_marker(item)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		assert !grid_measurement_test_compare(mut source, root, 240, 0, 500)
		gc_collect()
		assert grid_measurement_test_compare(mut source, root, 240, 0, 500) == (!disable_markerless_measurements && !disable_grid_measurement_reuse)
		assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
		assert grid_measurement_test_compare(mut source, root, 180, 0, 500) == (!disable_markerless_measurements && !disable_grid_measurement_reuse)
		source.release_measurement_chunk_pool()
	}
}

fn test_markerless_flex_measurement_matches_uncached_nested_list_geometry() {
	mut document := html.parse_document('<!doctype html><section id="flex" style="display:flex;width:240px;gap:7px;align-items:baseline"><ul style="list-style:none;margin:0;padding:0;flex:1"><li>Markerless wrapping text alpha beta gamma.</li><li><span>More text.</span></li></ul><p>Other item.</p></section>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := flex_measurement_test_node(document, 'flex')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	defer { source.release_measurement_chunk_pool() }
	assert !flex_measurement_test_compare(mut source, root, 240, 0, .normal, '')
	gc_collect()
	assert flex_measurement_test_compare(mut source, root, 240, 0, .normal, '') == (!disable_markerless_measurements && !disable_flex_measurement_reuse)
}

fn test_markerless_measurement_rejects_a_new_marker_and_preserves_across_pass_exclusion() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr"><ul style="list-style:none"><li id="item">Markerless text.</li></ul></section><ul><li id="marked">Visible marker.</li></ul>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	item := grid_measurement_test_node(document, 'item')
	mut list_item := item.as_list_item_box()?
	marked := grid_measurement_test_node(document, 'marked').as_list_item_box()?
	marker := marked.marker()?
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	assert collect_grid_measurement_inputs(root, mut inputs, mut rejected) == !disable_markerless_measurements
	if !disable_markerless_measurements {
		assert grid_measurement_inputs_are_current(inputs)
	}
	mut across := []RetainedInlineInput{}
	mut across_rejected := map[u64]bool{}
	assert !collect_retained_block_inputs(root, mut across, mut across_rejected)
	revision := item.computed_values().mutation_revision()
	list_item.set_marker(marker)
	assert item.computed_values().mutation_revision() == revision
	assert !measurement_list_item_has_no_marker(item)
	if !disable_markerless_measurements {
		assert !grid_measurement_inputs_are_current(inputs)
	}
	mut after := []RetainedInlineInput{}
	mut after_rejected := map[u64]bool{}
	assert !collect_grid_measurement_inputs(root, mut after, mut after_rejected)
	list_item.set_marker(none)
	assert measurement_list_item_has_no_marker(item)
	if !disable_markerless_measurements {
		assert grid_measurement_inputs_are_current(inputs)
	}
}

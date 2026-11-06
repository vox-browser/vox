module layout

import css
import dom
import html
import platform

fn same_pass_grid_prepare(mut state LayoutState, root &Node, width int, height int) &UsedValues {
	styled := root.as_node_with_style() or { panic('root style') }
	if state.try_get(styled) == none { return grid_measurement_test_prepare(mut state, root, width, height, 500) }
	parent := root.containing_block() or { panic('parent') }
	mut parent_values := state.get_mutable(unsafe { &NodeWithStyle(parent) })
	parent_values.set_content_width(CSSPixels.new(500))
	parent_values.set_content_height(CSSPixels.new(300))
	parent_values.set_has_definite_width(true)
	parent_values.set_has_definite_height(true)
	mut used := state.get_mutable(styled)
	used.set_containing_block_used_values(parent_values)
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(if height < 0 { -height } else { height }))
	used.set_has_definite_width(true)
	used.set_has_definite_height(height > 0)
	resolve_box_model_edges(root.computed_values(), mut used, 500)
	return used
}

fn same_pass_grid_compare(mut state LayoutState, root &Node, width int, height int,
	change string) bool {
	mut used := same_pass_grid_prepare(mut state, root, width, height)
	committed_grid_test_change(mut state, root, mut used, change)
	used.offset = css.CSSPixelPoint.from_values(17, 23)
	used.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	space := AvailableSpace.new(AvailableSize.make_definite(used.content_width()),
		if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
	actual := run_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
	assert used.offset == css.CSSPixelPoint.from_values(17, 23)
	assert (used.relative_inset_basis_width() or { panic('width basis') }) == CSSPixels.new(731)
	assert (used.relative_inset_basis_height() or { panic('height basis') }) == CSSPixels.new(919)
	mut retained := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(state, root)
	retained.finish()
	mut reused := false
	if cached := state.measurement_chunk_pool_.same_pass_grids_[u64(voidptr(root))] {
		reused = committed_grid_test_reused(state, cached)
		// Every writable consumer must detach from the owned snapshot.
		for entry in cached.values {
			if entry.values.line_boxes.len == 0 { continue }
			before := entry.values.line_boxes[0].fragments_[0].inline_length_
			mut writable := state.get_mutable(entry.node)
			writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
			assert entry.values.line_boxes[0].fragments_[0].inline_length_ == before
		}
	}
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('root style') })
	mut expected := grid_measurement_test_prepare(mut oracle, root, width, height, 500)
	committed_grid_test_change(mut oracle, root, mut expected, change)
	expected.offset = css.CSSPixelPoint.from_values(17, 23)
	expected.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .normal, space, false)
	assert geometry == grid_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_same_pass_grid_reuses_dirty_nested_geometry_and_preserves_caller_state() {
	for content in ['<p>Wrapping words alpha beta gamma 😀.</p><p>Other words.</p>',
		'<div style="display:grid;grid-template-columns:1fr 2fr"><p>Nested words 😀.</p><p>More text.</p></div><p>Other words.</p>',
		'<p style="position:relative">Unshifted relative words 😀.</p><p>Other words.</p>'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:[first] 1fr [second] 2fr [last];gap:7px">${content}</section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		mut dirty := unsafe { &Node(root) }
		dirty.set_needs_layout_update(true)
		for _ in 0 .. 3 { assert same_pass_grid_compare(mut state, root, 180, 0, '') == !disable_same_pass_grid_reuse }
		pool := state.measurement_chunk_pool_
		state.release_measurement_chunk_pool()
		assert pool.closed && pool.same_pass_grids_.len == 0 && pool.same_pass_grid_values_ == 0
	}
}

fn test_same_pass_grid_checks_every_incoming_basis_and_keeps_probe_entries_separate() {
	for change in ['', 'root-width', 'root-height', 'root-edges', 'parent-height', 'parent-definiteness', 'outer-width', 'outer-definiteness'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr;gap:7px"><p>Wrapping words alpha beta gamma.</p><p>Other words.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		// Exact indefinite numeric heights are part of this committed question.
		height := if change == '' { -93 } else { 0 }
		assert !same_pass_grid_compare(mut state, root, 180, height, change)
		assert same_pass_grid_compare(mut state, root, 180, height, change) == !disable_same_pass_grid_reuse
		assert state.measurement_chunk_pool_.grid_measurements_.len == 0
		assert state.measurement_chunk_pool_.grid_measurement_rejections_.len == 0
		state.release_measurement_chunk_pool()
	}
}

fn test_same_pass_grid_rejects_live_text_membership_style_font_and_environment_changes() {
	for change in ['text', 'membership', 'style', 'font', 'environment'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr;gap:7px"><p id="item">Wrapping words alpha beta gamma.</p><p>Other words.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		assert same_pass_grid_compare(mut state, root, 180, 0, '') == !disable_same_pass_grid_reuse
		if change == 'text' {
			mut text := grid_measurement_test_node(document, 'item').children()[0].as_text_node()?
			mut data := text.dom_node()?.as_character_data()?
			data.set_data('Changed wrapping text with extraordinary words.')
			text.invalidate_text_for_rendering()
		}
		if change == 'membership' {
			mut node := unsafe { &Node(root) }
			old := node.first_child()?
			node.remove_child(old)
		}
		if change == 'style' {
			mut element := document.create_element('section')!
			element.set_attribute_value('style', 'display:grid;grid-template-columns:1fr 2fr;gap:11px')
			mut styled := root.as_node_with_style()?
			styled.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		}
		if change == 'font' {
			mut computer := css.css_style_computer_for(document).font_computer()
			computer.did_load_font('SamePassGridFace')
		}
		if change == 'environment' { document.bump_style_environment_version() }
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		state.release_measurement_chunk_pool()
	}
}

fn test_same_pass_grid_preserves_running_clamp_and_shifted_descendant_algorithms() {
	for extra in ['max-lines:1;continue:collapse', 'position:relative;top:2px', 'float:left'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><p style="${extra}">Wrapping alpha beta gamma delta words.</p><p>Other words.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		assert !same_pass_grid_compare(mut state, root, 180, 0, '')
		assert state.measurement_chunk_pool_.same_pass_grids_.len == 0
		state.release_measurement_chunk_pool()
	}
}

fn test_same_pass_grid_owned_lines_survive_native_storage_and_pool_retirement() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><p>Wrapping words alpha beta gamma 😀.</p><p>Other words.</p></section></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	assert !same_pass_grid_compare(mut state, root, 180, 0, '')
	assert same_pass_grid_compare(mut state, root, 180, 0, '') == !disable_same_pass_grid_reuse
	// Restore without the helper's deliberately destructive COW write.
	mut used := same_pass_grid_prepare(mut state, root, 180, 0)
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = run_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
	mut retained := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(state, root)
	retained.finish()
	state.release_measurement_chunk_pool()
	gc_collect()
	assert geometry == grid_measurement_test_geometry(state, root)
}

fn test_same_pass_grid_snapshot_budget_preserves_uncached_geometry() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><p>Wrapping words alpha beta gamma.</p><p>Other words.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.same_pass_grid_values_ = same_pass_grid_value_limit
	assert !same_pass_grid_compare(mut state, root, 180, 0, '')
	assert !same_pass_grid_compare(mut state, root, 180, 0, '')
	assert state.measurement_chunk_pool_.same_pass_grids_.len == 0
	state.release_measurement_chunk_pool()
}

fn test_same_pass_grid_nested_reservations_cannot_overrun_the_shared_snapshot_budget() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><div id="nested" style="display:grid;grid-template-columns:1fr 2fr"><p>Nested words alpha beta.</p><p>More text.</p></div><p>Other words.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	assert collect_grid_measurement_inputs(root, mut inputs, mut rejected)
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.same_pass_grid_values_ = same_pass_grid_value_limit - inputs.len + 1
	assert !same_pass_grid_compare(mut state, root, 180, 0, '')
	pool := state.measurement_chunk_pool_
	assert pool.same_pass_grid_values_ <= same_pass_grid_value_limit
	assert u64(voidptr(root)) !in pool.same_pass_grids_
	if !disable_same_pass_grid_reuse {
		nested := grid_measurement_test_node(document, 'nested')
		assert u64(voidptr(nested)) in pool.same_pass_grids_
	}
	state.release_measurement_chunk_pool()
}

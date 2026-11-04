module layout

import css
import dom
import html
import platform

fn grid_measurement_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing '+id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn grid_measurement_test_prepare(mut probe LayoutState, root &Node, width int, height int,
	parent_width int) &UsedValues {
	styled := root.as_node_with_style() or { panic('missing style') }
	containing := root.containing_block() or { panic('missing containing block') }
	mut ancestor_state := LayoutState.new()
	parent_style := unsafe { &NodeWithStyle(containing) }
	mut parent := ancestor_state.get_mutable(parent_style)
	parent.set_content_width(CSSPixels.new(parent_width))
	parent.set_content_height(CSSPixels.new(300))
	parent.set_has_definite_width(true)
	parent.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut probe, mut ancestor_state, root)
	parent = probe.get_mutable(parent_style)
	mut used := probe.get_mutable(styled)
	used.set_containing_block_used_values(parent)
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(height))
	used.set_has_definite_width(true)
	used.set_has_definite_height(height > 0)
	resolve_box_model_edges(root.computed_values(), mut used, f64(parent_width))
	return used
}

// Scalar geometry and glyph payloads only: never format owner graphs.
fn grid_measurement_test_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width()} ${used.content_height()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset} ${used.margin_left} ${used.margin_right} ${used.margin_top} ${used.margin_bottom}'
			result << '${used.grid_template_columns()} ${used.grid_template_rows()} ${used.grid_column_line_names()} ${used.grid_row_line_names()} ${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()}'
			for line in used.line_boxes {
				result << '${line.width()} ${line.height()} ${line.baseline()}'
				for fragment in line.fragments_ {
					result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length()}'
					if run := fragment.glyph_run() {
						result << '${run.glyphs()} ${run.glyph_positions()} ${run.bounding_box()}'
					}
				}
			}
		}
	}
	for child in root.children() { result << grid_measurement_test_geometry(state, child) }
	return result
}

fn grid_measurement_test_compare(mut source LayoutState, root &Node, width int, height int,
	parent_width int) bool {
	return grid_measurement_test_compare_constraints(mut source, root, width, height,
		parent_width, .none)
}

fn grid_measurement_test_set_ancestor_constraints(mut state LayoutState, root &Node,
	constraint SizeConstraint) {
	mut ancestor := root.containing_block()
	for ancestor != none {
		box := ancestor or { break }
		mut values := state.get_mutable(unsafe { &NodeWithStyle(box) })
		values.width_constraint = constraint
		values.height_constraint = constraint
		ancestor = unsafe { &Node(box) }.containing_block()
	}
}

fn grid_measurement_test_compare_constraints(mut source LayoutState, root &Node, width int,
	height int, parent_width int, ancestor_constraint SizeConstraint) bool {
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
	mut probe := source.new_measurement_for_subtree(root.as_node_with_style() or { panic('style') })
	mut used := grid_measurement_test_prepare(mut probe, root, width, height, parent_width)
	grid_measurement_test_set_ancestor_constraints(mut probe, root, ancestor_constraint)
	used.offset = css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	used.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	actual := run_grid_formatting_context_internal(mut probe, root, mut used, .normal, space, false)
	assert used.offset == css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	assert (used.relative_inset_basis_width() or { panic('missing width basis') }) == CSSPixels.new(731)
	assert (used.relative_inset_basis_height() or { panic('missing height basis') }) == CSSPixels.new(919)
	mut retained := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(probe, root)
	retained.finish()
	mut reused := false
	if source.measurement_chunk_pool_ != unsafe { nil } {
		for entry in source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} } {
			for snapshot in entry.values {
				if snapshot.values.line_boxes.len == 0 { continue }
				if current := probe.try_get(snapshot.node) {
					if current.line_boxes.data == snapshot.values.line_boxes.data {
						reused = true
						// Writable callers must detach from retained buffers.
						mut writable := probe.get_mutable(snapshot.node)
						writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
						assert snapshot.values.line_boxes[0].fragments_[0].inline_length_ != CSSPixels.new(999)
					}
				}
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	// A separate unpooled oracle keeps every nested grid on the uncached path.
	mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('style') })
	mut expected := grid_measurement_test_prepare(mut oracle, root, width, height, parent_width)
	grid_measurement_test_set_ancestor_constraints(mut oracle, root, ancestor_constraint)
	expected.offset = css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	expected.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	result := run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected,
		.normal, space, false)
	assert actual == result
	assert geometry == grid_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_grid_measurement_reuses_owned_nested_geometry_after_scratch_retirement() {
	for rules in ['grid-template-columns:[start] minmax(0,1fr) [middle] 2fr [end];gap:7px',
		'grid-template-columns:repeat(auto-fit,minmax(60px,1fr));gap:3px;direction:rtl',
		'grid-template-columns:70px 1fr;align-items:baseline;grid-auto-flow:row dense'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:240px;${rules}"><div style="display:grid;grid-template-columns:1fr 1fr"><span>Nested wrapping words alpha beta gamma 😀.</span><span>More words.</span></div><div style="display:flex"><p>Flex content.</p><p>Other content.</p></div><p style="height:25%">Percentage item.</p></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut dirty_root := unsafe { &Node(root) }
		dirty_root.set_needs_layout_update(true)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for height in [0, 180] {
			assert !grid_measurement_test_compare(mut source, root, 240, height, 500)
			for _ in 0 .. 3 {
				assert grid_measurement_test_compare(mut source, root, 240, height, 500) == !disable_grid_measurement_reuse
			}
		}
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.grid_measurements_.len == 0 && pool.grid_measurement_rejections_.len == 0
	}
}

fn test_grid_measurement_invalidates_constraints_fonts_text_style_and_tree() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr 1fr;gap:7px"><p id="item">Original wrapping words alpha beta gamma.</p><p>Other content.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	assert grid_measurement_test_compare(mut source, root, 180, 0, 500) == !disable_grid_measurement_reuse
	assert !grid_measurement_test_compare(mut source, root, 181, 0, 500)
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 501)
	assert !grid_measurement_test_compare(mut source, root, 180, 181, 500)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedGridMeasurementFace')
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	document.bump_style_environment_version()
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	mut item := grid_measurement_test_node(document, 'item')
	mut text := item.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('Replacement text extraordinary words with different wrapping.')
	text.invalidate_text_for_rendering()
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	style_element := document.create_element('p')!
	mut styled := style_element
	styled.set_attribute_value('style', 'display:block;font-size:23px;grid-column:span 2')
	mut item_style := item.as_node_with_style()?
	item_style.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(styled, none)))
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	mut mutable_root := unsafe { &Node(root) }
	mutable_root.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node('new child').as_node(), 'new child')) })
	// Preserve unique indexes across both the measured subtree and its seeded
	// external ancestors, as a real full layout-tree rebuild does.
	mut tree_root := unsafe { &Node(root) }
	for {
		parent := tree_root.parent() or { break }
		tree_root = unsafe { &Node(parent) }
	}
	assign_layout_indexes(tree_root)
	recompute_containing_blocks(tree_root)
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	for width in [80, 100, 120, 140, 160, 180] {
		_ = grid_measurement_test_compare(mut source, root, width, 0, 500)
	}
	assert (source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }).len <= 4
}

fn test_grid_measurement_keeps_external_effects_and_specialized_layout_uncached() {
	for contents in ['<div style="position:absolute">Positioned.</div>',
		'<div style="position:relative">Relative.</div>', '<div style="float:left">Float.</div>',
		'<div style="display:grid;grid-template-columns:subgrid">Subgrid.</div>',
		'<svg width="20" height="20"><rect width="10" height="10"/></svg>',
		'<p style="max-lines:1;continue:collapse">Clamped content.</p>', '<input value="Control">'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr 1fr">${contents}<p>Other content.</p></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert !collect_grid_measurement_inputs(root, mut inputs, mut rejected)
	}
}

fn test_grid_measurement_keys_include_external_ancestor_bases_and_root_edges() {
	mut document := html.parse_document('<!doctype html><main id="parent"><section id="grid" style="display:grid;grid-template-columns:1fr 1fr"><p>Words.</p><p>More.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	root := grid_measurement_test_node(document, 'grid')
	styled_root := root.as_node_with_style() or { panic('missing grid style') }
	mut probe := LayoutState.new_for_subtree(styled_root)
	defer { probe.release_measurement() }
	mut used := grid_measurement_test_prepare(mut probe, root, 180, 0, 400)
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	key := grid_measurement_key(probe, root, used, space)
	used.padding_left = CSSPixels.new(3)
	assert key != grid_measurement_key(probe, root, used, space)
	used.padding_left = CSSPixels.new(0)
	assert key == grid_measurement_key(probe, root, used, space)
	used.height_constraint = .min_content
	assert key != grid_measurement_key(probe, root, used, space)
	used.height_constraint = .none
	parent := root.containing_block()?
	ancestor := unsafe { &Node(parent) }.containing_block()?
	mut external := probe.get_mutable(unsafe { &NodeWithStyle(ancestor) })
	external.set_content_width(external.content_width().plus(CSSPixels.new(1)))
	assert key != grid_measurement_key(probe, root, used, space)
}

fn test_grid_measurement_reuses_resolved_geometry_across_ancestor_intrinsic_questions() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;width:180px;grid-template-columns:minmax(0,1fr) 2fr;gap:7px"><div style="display:grid;grid-template-columns:1fr 1fr;max-width:90%"><p style="min-height:20%">Wrapping words alpha beta gamma.</p><p>More words.</p></div><p style="min-width:30%">Other content.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	assert collect_grid_measurement_inputs(root, mut inputs, mut rejected)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	assert !grid_measurement_test_compare_constraints(mut source, root, 180, 0, 500, .none)
	// Adding an intrinsic constraint changes effective definiteness and must
	// miss. Switching min to max preserves that basis and can reuse geometry.
	assert !grid_measurement_test_compare_constraints(mut source, root, 180, 0, 500, .min_content)
	for constraint in [SizeConstraint.max_content, .min_content, .max_content] {
		assert grid_measurement_test_compare_constraints(mut source, root, 180, 0, 500,
			constraint) == !disable_grid_measurement_reuse
	}
}

fn committed_grid_test_prepare(mut state LayoutState, root &Node, outer_height int) &UsedValues {
	used := grid_measurement_test_prepare(mut state, root, 180, 0, 500)
	parent := root.containing_block() or { panic('missing parent') }
	ancestor := unsafe { &Node(parent) }.containing_block() or { panic('missing ancestor') }
	mut outside := state.get_mutable(unsafe { &NodeWithStyle(ancestor) })
	outside.set_content_width(CSSPixels.new(900))
	outside.set_content_height(CSSPixels.new(outer_height))
	outside.set_has_definite_height(outer_height > 0)
	return used
}

fn committed_grid_test_reused(state &LayoutState, cached &GridMeasurementLayout) bool {
	for entry in cached.values {
		if entry.values.line_boxes.len == 0 { continue }
		if used := state.try_get(entry.node) {
			if used.line_boxes.data == entry.values.line_boxes.data { return true }
		}
	}
	return false
}

fn test_committed_grid_reuses_owned_measurement_across_unused_outer_heights() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr;gap:7px"><p>Wrapping words alpha beta gamma 😀.</p><p>Other words.</p></section></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	styled := root.as_node_with_style()?
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut producer := source.new_measurement_for_subtree(styled)
	mut measured := committed_grid_test_prepare(mut producer, root, 0)
	result := run_grid_formatting_context_internal(mut producer, root, mut measured, .normal, space, false)
	entries := source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }
	producer.release_measurement()
	gc_collect()
	mut used := committed_grid_test_prepare(mut source, root, 400)
	used.offset = css.CSSPixelPoint.from_values(11, 13)
	actual := run_grid_formatting_context(mut source, root, mut used, .normal, space)
	assert used.offset == css.CSSPixelPoint.from_values(11, 13)
	assert actual == result
	if !disable_grid_measurement_reuse {
		assert entries.len == 1 && entries[0].external_heights_independent
		assert committed_grid_test_reused(source, entries[0]) == !disable_committed_grid_measurement_reuse
	}
	mut snapshots := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(source, root)
	snapshots.finish()
	source.release_measurement_chunk_pool()
	gc_collect()
	assert geometry == grid_measurement_test_geometry(source, root)
	// Compare after pool/scratch retirement with an independent uncached state.
	mut oracle := LayoutState.new_for_subtree(styled)
	mut expected := committed_grid_test_prepare(mut oracle, root, 400)
	expected.offset = css.CSSPixelPoint.from_values(11, 13)
	assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .normal, space, false)
	assert geometry == grid_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	if !disable_grid_measurement_reuse {
		for entry in entries[0].values {
			if entry.values.line_boxes.len == 0 { continue }
			before := entry.values.line_boxes[0].fragments_[0].inline_length_
			mut writable := source.get_mutable(entry.node)
			writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
			assert entry.values.line_boxes[0].fragments_[0].inline_length_ == before
			break
		}
	}
}

fn committed_grid_test_change(mut state LayoutState, root &Node, mut used UsedValues, change string) {
	if change == 'root-width' { used.set_content_width(CSSPixels.new(181)) }
	if change == 'root-height' { used.set_content_height(CSSPixels.new(100)); used.set_has_definite_height(true) }
	if change == 'root-edges' { used.padding_left = CSSPixels.new(3) }
	parent := root.containing_block() or { panic('parent') }
	mut parent_values := state.get_mutable(unsafe { &NodeWithStyle(parent) })
	if change == 'parent-height' { parent_values.set_content_height(CSSPixels.new(301)) }
	if change == 'parent-definiteness' { parent_values.set_has_definite_height(false) }
	ancestor := unsafe { &Node(parent) }.containing_block() or { panic('ancestor') }
	mut outside := state.get_mutable(unsafe { &NodeWithStyle(ancestor) })
	if change == 'outer-width' { outside.set_content_width(CSSPixels.new(901)) }
	if change == 'outer-definiteness' { outside.set_has_definite_width(false) }
}

fn test_committed_grid_misses_preserve_cache_and_validate_inputs_and_consumed_bases() {
	for change in ['root-width', 'root-height', 'root-edges', 'parent-height', 'parent-definiteness',
		'outer-width', 'outer-definiteness', 'text', 'style', 'font', 'environment', 'intrinsic', 'width-only'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr;gap:7px"><p id="item">Wrapping words alpha beta gamma.</p><p>Other words.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		styled := root.as_node_with_style()?
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		mut producer := source.new_measurement_for_subtree(styled)
		mut measured := committed_grid_test_prepare(mut producer, root, 0)
		_ = run_grid_formatting_context_internal(mut producer, root, mut measured, .normal, space, false)
		producer.release_measurement()
		entries := source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }
		if change == 'text' {
			mut text := grid_measurement_test_node(document, 'item').children()[0].as_text_node()?
			mut data := text.dom_node()?.as_character_data()?
			data.set_data('Changed wrapping text with extraordinary words.')
			text.invalidate_text_for_rendering()
		}
		if change == 'style' {
			mut element := document.create_element('section')!
			element.set_attribute_value('style', 'display:grid;grid-template-columns:1fr 2fr;gap:11px')
			mut changed := unsafe { &NodeWithStyle(styled) }
			changed.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		}
		if change == 'font' {
			mut computer := css.css_style_computer_for(document).font_computer()
			computer.did_load_font('CommittedGridMeasurementFace')
		}
		if change == 'environment' { document.bump_style_environment_version() }
		mut used := committed_grid_test_prepare(mut source, root, 400)
		committed_grid_test_change(mut source, root, mut used, change)
		mode := if change == 'intrinsic' { LayoutMode.intrinsic_sizing } else { LayoutMode.normal }
		width_only := change == 'width-only'
		actual := run_grid_formatting_context_internal(mut source, root, mut used, mode, space, width_only)
		if !disable_grid_measurement_reuse { assert !committed_grid_test_reused(source, entries[0]) }
		current := source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }
		assert current.len == entries.len
		for i in 0 .. current.len { assert voidptr(current[i]) == voidptr(entries[i]) }
		mut oracle := LayoutState.new_for_subtree(styled)
		mut expected := committed_grid_test_prepare(mut oracle, root, 400)
		committed_grid_test_change(mut oracle, root, mut expected, change)
		assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, mode, space, width_only)
		assert grid_measurement_test_geometry(source, root) == grid_measurement_test_geometry(oracle, root)
		oracle.release_measurement()
		source.release_measurement_chunk_pool()
	}
}

fn test_committed_grid_preserves_outer_heights_for_dependent_subtrees() {
	for contents in ['<p style="height:25%">Percentage height.</p>',
		'<p style="min-height:25%">Percentage minimum.</p>', '<p style="max-height:25%">Percentage maximum.</p>',
		'<div style="display:grid;grid-template-rows:1fr"><p>Explicit rows.</p></div>',
		'<div style="display:grid;row-gap:10%"><p>Percentage gap.</p></div>',
		'<div style="display:flex;flex-direction:column"><p style="flex-basis:50%">Percentage basis.</p></div>',
		'<div style="display:flex"><p style="aspect-ratio:2">Flex aspect ratio.</p></div>'] {
		mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr">${contents}<p>Other content.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		styled := root.as_node_with_style()?
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert collect_grid_measurement_inputs(root, mut inputs, mut rejected)
		assert !grid_measurement_external_heights_are_unused(inputs)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		mut producer := source.new_measurement_for_subtree(styled)
		mut measured := committed_grid_test_prepare(mut producer, root, 0)
		_ = run_grid_formatting_context_internal(mut producer, root, mut measured, .normal, space, false)
		producer.release_measurement()
		entries := source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }
		mut used := committed_grid_test_prepare(mut source, root, 400)
		actual := run_grid_formatting_context_internal(mut source, root, mut used, .normal, space, false)
		if !disable_grid_measurement_reuse { assert !committed_grid_test_reused(source, entries[0]) }
		mut oracle := LayoutState.new_for_subtree(styled)
		mut expected := committed_grid_test_prepare(mut oracle, root, 400)
		assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .normal, space, false)
		assert grid_measurement_test_geometry(source, root) == grid_measurement_test_geometry(oracle, root)
		oracle.release_measurement()
		source.release_measurement_chunk_pool()
	}
}

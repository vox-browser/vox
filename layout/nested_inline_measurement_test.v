module layout

import css
import dom
import html
import platform

fn nested_measurement_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ' + id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn nested_measurement_prepare(mut probe LayoutState, root &Node, width AvailableSize,
	parent_width int) &UsedValues {
	containing := root.containing_block() or { panic('missing containing block') }
	mut ancestors := LayoutState.new()
	mut parent := ancestors.get_mutable(unsafe { &NodeWithStyle(containing) })
	parent.set_content_width(CSSPixels.new(parent_width))
	parent.set_content_height(CSSPixels.new(300))
	parent.set_has_definite_width(true)
	parent.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut probe, mut ancestors, root)
	mut used := probe.get_mutable(root.as_node_with_style() or { panic('style') })
	used.set_containing_block_used_values(probe.get_mutable(unsafe { &NodeWithStyle(containing) }))
	used.set_content_width(width.to_px_or_zero())
	used.set_has_definite_width(width.is_definite())
	used.offset = css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	resolve_box_model_edges(root.computed_values(), mut used, f64(parent_width))
	return used
}

fn nested_measurement_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width()} ${used.content_height()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset}'
			result << '${used.margin_left} ${used.margin_right} ${used.padding_left} ${used.padding_right} ${used.border_left} ${used.border_right} ${used.inline_end_static_position_rect()}'
			for line in used.line_boxes {
				result << '${line.width()} ${line.height()} ${line.baseline()}'
				for fragment in line.fragments_ {
					result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length()}'
					if run := fragment.glyph_run() {
						result << '${u64(voidptr(run.font()))} ${run.glyphs()} ${run.glyph_indices()} ${run.glyph_positions()} ${run.bounding_box()}'
					}
				}
			}
		}
	}
	for child in root.children() { result << nested_measurement_geometry(state, child) }
	return result
}

fn nested_measurement_compare(mut source LayoutState, root &Node, width AvailableSize,
	mode LayoutMode, width_only bool, parent_width int) bool {
	space := AvailableSpace.new(width, AvailableSize.make_indefinite())
	container := root.as_block_container() or { panic('container') }
	mut probe := source.new_measurement_for_subtree(root.as_node_with_style() or { panic('style') })
	mut used := nested_measurement_prepare(mut probe, root, width, parent_width)
	actual := run_inline_formatting_context_for_width(mut probe, container, mut used, mode,
		space, none, width_only)
	mut retained := platform.enter_retained_allocations()
	geometry := nested_measurement_geometry(probe, root)
	retained.finish()
	reused := used.line_boxes_are_shared_
	if reused && used.line_boxes.len > 0 && used.line_boxes[0].fragments_.len > 0 {
		mut writable := probe.get_mutable(root.as_node_with_style() or { panic('style') })
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
	}
	probe.release_measurement()
	gc_collect()
	// No pool in the independent oracle: nested probes cannot reuse the cache.
	mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('style') })
	mut expected := nested_measurement_prepare(mut oracle, root, width, parent_width)
	result := run_uncached_inline_formatting_context_for_width(mut oracle, container,
		mut expected, mode, space, none, width_only)
	assert actual == result
	assert geometry == nested_measurement_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_nested_inline_measurement_owns_lines_and_geometry_after_scratch_retirement() {
	for style in ['padding:3px 5%;border:1px solid;font:16px/22px Arial',
		'direction:rtl;text-align:justify;font:17px/24px Arial',
		'font:16px/22px Arial;white-space:pre-wrap;letter-spacing:1px'] {
		mut document := html.parse_document('<!doctype html><section><div id="text" style="${style}">Before <a style="padding:2%;border:1px solid"><span style="font-size:120%;vertical-align:20%">Nested 😀 אבג words alpha beta gamma</span> more text</a> after.</div></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := nested_measurement_node(document, 'text')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			for width in [AvailableSize.make_definite(CSSPixels.new(180)),
				AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
				width_only := !width.is_definite()
				assert !nested_measurement_compare(mut source, root, width, mode, width_only, 500)
				for _ in 0 .. 2 {
					assert nested_measurement_compare(mut source, root, width, mode, width_only, 500) == (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
				}
			}
		}
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.nested_inline_measurements_.len == 0
	}
}

fn test_nested_inline_measurement_invalidates_actual_inputs_and_outer_bases() {
	mut document := html.parse_document('<!doctype html><div id="text">Before <span id="span">Nested words alpha beta gamma.</span> after.</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := nested_measurement_node(document, 'text')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	width := AvailableSize.make_definite(CSSPixels.new(180))
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	assert nested_measurement_compare(mut source, root, width, .normal, false, 500) == (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 501)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedNestedMeasurementFace')
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	document.bump_style_environment_version()
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	document.set_font_rendering_policy(.chromium)
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	span := nested_measurement_node(document, 'span')
	mut text := span.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('Replacement extraordinary text 😀')
	text.invalidate_text_for_rendering()
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	mut element := document.get_element_by_id('span')?
	element.set_attribute_value('style', 'letter-spacing:3px;font-size:20px')
	mut styled_span := span.as_node_with_style()?
	styled_span.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	for size in [80, 100, 120, 140, 160, 180] {
		_ = nested_measurement_compare(mut source, root, AvailableSize.make_definite(CSSPixels.new(size)), .normal, false, 500)
	}
	entries := source.measurement_chunk_pool_.nested_inline_measurements_[u64(voidptr(root))] or { []&NestedInlineMeasurement{} }
	assert entries.len <= 4
}

fn test_nested_inline_measurement_invalidates_tree_and_keeps_committed_layout_uncached() {
	mut document := html.parse_document('<!doctype html><div id="text">Before <span id="span">Nested words</span> after</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := nested_measurement_node(document, 'text')
	mut source := LayoutState.new()
	width := AvailableSize.make_definite(CSSPixels.new(180))
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	mut committed := nested_measurement_prepare(mut source, root, width, 500)
	container := root.as_block_container() or { panic('container') }
	_ = run_inline_formatting_context_for_width(mut source, container,
		mut committed, .normal, AvailableSpace.new(width, AvailableSize.make_indefinite()), none, false)
	assert source.measurement_chunk_pool_.nested_inline_measurements_.len == 0
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	assert nested_measurement_compare(mut source, root, width, .normal, false, 500) == (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
	mut span := nested_measurement_node(document, 'span')
	span.append_child(unsafe {
		&Node(TextNode.new(document,
			document.create_text_node(' additional wrapping text 😀').as_node(), ' additional wrapping text 😀'))
	})
	mut tree_root := unsafe { &Node(root) }
	for {
		parent := tree_root.parent() or { break }
		tree_root = unsafe { &Node(parent) }
	}
	assign_layout_indexes(tree_root)
	recompute_containing_blocks(tree_root)
	assert !nested_measurement_compare(mut source, root, width, .normal, false, 500)
	assert nested_measurement_compare(mut source, root, width, .normal, false, 500) == (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
}

fn test_nested_inline_measurement_keeps_specialized_contexts_uncached() {
	for child in ['<span style="position:relative;left:2px">words</span>',
		'<span style="display:inline-block">words</span>', '<span style="float:left">words</span>',
		'<span>words<br>more</span>', '<span style="position:absolute">words</span>'] {
		mut document := html.parse_document('<!doctype html><div id="text">Before ${child} after</div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := nested_measurement_node(document, 'text')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		for _ in 0 .. 2 {
			assert !nested_measurement_compare(mut source, root, AvailableSize.make_definite(CSSPixels.new(180)), .normal, false, 500)
		}
		source.release_measurement_chunk_pool()
	}
}

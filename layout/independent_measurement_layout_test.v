module layout

import css
import dom
import html
import platform

fn independent_probe_fixture(style string, contents string) (&dom.Document, DocumentLayoutResult, &Node) {
	mut document := html.parse_document('<!doctype html><div style="width:300px;height:220px"><section id="probe" style="${style};font:16px/20px SerenitySans">${contents}</section></div>')
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 500, 400) or { panic('missing layout') }
	return document, result, independent_probe_find(result.root)
}

fn independent_probe_find(node &Node) &Node {
	if owner := node.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == 'probe' { return node }
		}
	}
	for child in node.children() {
		found := independent_probe_find(child)
		if found != unsafe { nil } { return found }
	}
	return unsafe { nil }
}

fn independent_probe_lines(lines []LineBox) []string {
	mut result := []string{}
	for line in lines {
		result << '${line.width().raw_value()} ${line.height().raw_value()} ${line.baseline().raw_value()}'
		for fragment in line.fragments_ {
			result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length().raw_value()}'
			if run := fragment.glyph_run() {
				result << '${u64(voidptr(run.font()))} ${run.glyphs()} ${run.glyph_indices()} ${run.glyph_positions()} ${run.bounding_box()}'
			}
		}
	}
	return result
}

// Keep owner graphs out of assertions. These are the geometry and line/glyph
// scalars consumed by grid/flex contribution and baseline callers.
fn independent_probe_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width().raw_value()} ${used.content_height().raw_value()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset}'
			result << '${used.margin_left.raw_value()} ${used.margin_right.raw_value()} ${used.margin_top.raw_value()} ${used.margin_bottom.raw_value()} ${used.padding_left.raw_value()} ${used.padding_top.raw_value()} ${used.border_left.raw_value()} ${used.border_top.raw_value()}'
			result << independent_probe_lines(used.line_boxes)
			result << '${used.grid_template_columns().map(it.raw_value())} ${used.grid_template_rows().map(it.raw_value())}'
		}
	}
	for child in root.children() { result << independent_probe_geometry(state, child) }
	return result
}

fn independent_probe_compare(mut source LayoutState, root &Node, width int, mode LayoutMode,
	available_height AvailableSize) bool {
	styled := root.as_node_with_style() or { panic('missing style') }
	node_key := u64(voidptr(root))
	before := source.measurement_chunk_pool_.independent_measurements_[node_key] or { []&IndependentMeasurementLayout{} }
	previous := if before.len == 0 { unsafe { nil } } else { voidptr(before.last()) }
	mut probe := source.new_measurement_for_subtree(styled)
	populate_intrinsic_containing_block_chain(mut probe, mut source, root)
	mut used := probe.get_mutable(styled)
	used.set_content_width(CSSPixels.new(width))
	used.set_has_definite_width(true)
	used.set_indefinite_content_height()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), available_height)
	actual := run_retaining_independent_formatting_context(mut probe, root, mut used, mode, space)
	mut retained := platform.enter_retained_allocations()
	geometry := independent_probe_geometry(probe, root)
	retained.finish()
	after := source.measurement_chunk_pool_.independent_measurements_[node_key] or { []&IndependentMeasurementLayout{} }
	reused := previous != unsafe { nil } && after.len == before.len && voidptr(after.last()) == previous
	// Mutating a consumer must detach the cache's shared fragment buffers.
	for child in root.children() {
		if child_style := child.as_node_with_style() {
			if child_used := probe.try_get(child_style) {
				if child_used.line_boxes.len > 0 && child_used.line_boxes[0].fragments_.len > 0 {
					mut writable := probe.get_mutable(child_style)
					writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
				}
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	populate_intrinsic_containing_block_chain(mut oracle, mut source, root)
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(CSSPixels.new(width))
	expected.set_has_definite_width(true)
	expected.set_indefinite_content_height()
	result := layout_uncached_independent_formatting_context(mut oracle, root, mut expected, mode, space)
	assert actual == result
	assert geometry == independent_probe_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_independent_measurement_reuses_flow_flex_and_grid_geometry_after_scratch_retires() {
	for style in ['display:flow-root', 'display:flex;gap:8px;align-items:stretch',
		'display:grid;grid-template-columns:1fr 2fr;gap:7px'] {
		mut document, layout, root := independent_probe_fixture(style,
			'<p>alpha beta gamma delta epsilon wrap several words</p><div><p>Second nested block with text</p></div>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		mut source := layout.state
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			for width in [160, 240] {
				assert !independent_probe_compare(mut source, root, width, mode, AvailableSize.make_indefinite())
				for _ in 0 .. 3 {
					assert independent_probe_compare(mut source, root, width, mode, AvailableSize.make_indefinite()) == !disable_independent_measurement_reuse
				}
			}
		}
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.independent_measurements_.len == 0
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
}

fn test_independent_measurement_rechecks_text_tree_style_fonts_and_containing_height() {
	mut document, layout, root := independent_probe_fixture('display:grid;grid-template-columns:1fr',
		'<p id="text">A paragraph with several words</p><div style="height:20%">percentage child</div>')
	defer { document.finalize() }
	mut source := layout.state
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSize.make_indefinite()
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	text_node := root.children()[0].children()[0].as_text_node()?
	mut data := text_node.dom_node()?.as_character_data()?
	data.set_data('Changed content with much longer words extraordinary and additional text')
	mut text := unsafe { &TextNode(text_node) }
	text.invalidate_text_for_rendering()
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	mut element := document.create_element('section')!
	element.set_attribute_value('style', 'display:grid;grid-template-columns:1fr;row-gap:13px;font:16px/20px SerenitySans')
	mut styled := root.as_node_with_style()?
	styled.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	mut font_computer := css.css_style_computer_for(document).font_computer()
	font_computer.did_load_font('UnrelatedProbeFont')
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	document.bump_style_environment_version()
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	containing := root.containing_block()?
	mut containing_values := source.get_mutable(unsafe { &NodeWithStyle(containing) })
	containing_values.set_content_height(CSSPixels.new(440))
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	mut mutable_root := unsafe { &Node(root) }
	extra := BlockContainer.new(document, none, root.computed_values())
	mutable_root.append_child(unsafe { &Node(extra) })
	assign_layout_indexes(layout.root)
	recompute_containing_blocks(layout.root)
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	for width in [70, 90, 110, 130, 150, 170] {
		_ = independent_probe_compare(mut source, root, width, .normal, space)
	}
	entries := source.measurement_chunk_pool_.independent_measurements_[u64(voidptr(root))] or { []&IndependentMeasurementLayout{} }
	assert entries.len <= 4
}

fn test_independent_measurement_excludes_external_and_specialized_dependencies() {
	for contents in ['<div style="float:left;width:40px;height:60px"></div><p>float</p>',
		'<div style="position:absolute;left:10%;top:20%">positioned</div>',
		'<ol><li>marker</li></ol>', '<p style="max-lines:1;continue:discard">clamped text</p>',
		'<div style="display:grid;grid-template-columns:subgrid">subgrid</div>',
		'<div style="columns:2">column text</div>'] {
		mut document, layout, root := independent_probe_fixture('display:flow-root', contents)
		defer { document.finalize() }
		mut source := layout.state
		source.enable_measurement_chunk_pool()
		for _ in 0 .. 2 { assert !independent_probe_compare(mut source, root, 180, .normal, AvailableSize.make_indefinite()) }
		entries := source.measurement_chunk_pool_.independent_measurements_[u64(voidptr(root))] or { []&IndependentMeasurementLayout{} }
		assert entries.len == 0
		source.release_measurement_chunk_pool()
	}
}

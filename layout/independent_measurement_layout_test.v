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
	mut probe := source.new_measurement_for_subtree(styled)
	populate_intrinsic_containing_block_chain(mut probe, mut source, root)
	mut used := probe.get_mutable(styled)
	used.set_content_width(CSSPixels.new(width))
	used.set_has_definite_width(true)
	used.set_indefinite_content_height()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), available_height)
	cached := completed_context_for_measurement(probe, root, used, mode, space)
	actual := run_retaining_independent_formatting_context(mut probe, root, mut used, mode, space)
	mut retained := platform.enter_retained_allocations()
	geometry := independent_probe_geometry(probe, root)
	retained.finish()
	mut reused := false
	if entry := cached {
		if used.line_boxes.len > 0 { reused = used.line_boxes.data == entry.lines.data }
		for child in entry.values {
			if child.values.line_boxes.len == 0 { continue }
			if values := probe.try_get(child.node) {
				reused = reused || values.line_boxes.data == child.values.line_boxes.data
			}
		}
	}
	assert reused == (cached != none && !disable_independent_measurement_reuse)
	// A writable consumer must detach the normal producer's retained fragments.
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

fn independent_probe_complete(mut source LayoutState, root &Node, width int) {
	styled := root.as_node_with_style() or { panic('missing style') }
	mut used := source.get_mutable(styled)
	used.set_content_width(CSSPixels.new(width))
	used.set_has_definite_width(true)
	used.set_content_height(CSSPixels.new(0))
	used.set_has_definite_height(false)
	used.clear_line_boxes()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
	_ = run_retaining_independent_formatting_context(mut source, root, mut used, .normal, space)
}

fn test_independent_measurement_reuses_completed_flow_flex_and_grid_after_probe_scratch_retires() {
	for style in ['display:flow-root', 'display:flex;gap:8px;align-items:stretch',
		'display:grid;grid-template-columns:1fr 2fr;gap:7px'] {
		mut document, layout, root := independent_probe_fixture(style,
			'<p>alpha beta gamma delta epsilon wrap several words</p><div><p>Second nested block with text</p></div>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		mut source := layout.state
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		independent_probe_complete(mut source, root, 300)
		for _ in 0 .. 4 {
			assert independent_probe_compare(mut source, root, 300, .normal, AvailableSize.make_indefinite()) == !disable_independent_measurement_reuse
		}
		// A dirty bit from this producing pass does not mean its inputs changed.
		mut mutable_root := unsafe { &Node(root) }
		mutable_root.set_needs_layout_update(true)
		assert independent_probe_compare(mut source, root, 300, .normal, AvailableSize.make_indefinite()) == !disable_independent_measurement_reuse
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			for width in [160, 240] {
				assert !independent_probe_compare(mut source, root, width, mode, AvailableSize.make_indefinite())
			}
		}
		assert !independent_probe_compare(mut source, root, 300, .normal, AvailableSize.make_definite(CSSPixels.new(400)))
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.source_state_ == unsafe { nil }
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
}

fn test_independent_measurement_rechecks_text_style_tree_and_containing_height() {
	mut document, layout, root := independent_probe_fixture('display:grid;grid-template-columns:1fr',
		'<p id="text">A paragraph with several words</p><div style="height:20%">percentage child</div>')
	defer { document.finalize() }
	mut source := layout.state
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSize.make_indefinite()
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	text_node := root.children()[0].children()[0].as_text_node()?
	mut data := text_node.dom_node()?.as_character_data()?
	data.set_data('Changed content with much longer words extraordinary and additional text')
	mut text := unsafe { &TextNode(text_node) }
	text.invalidate_text_for_rendering()
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	mut element := document.create_element('section')!
	element.set_attribute_value('style', 'display:grid;grid-template-columns:1fr;row-gap:13px;font:16px/20px SerenitySans')
	mut styled := root.as_node_with_style()?
	styled.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	containing := root.containing_block()?
	mut containing_values := source.get_mutable(unsafe { &NodeWithStyle(containing) })
	containing_values.set_content_height(CSSPixels.new(440))
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	document.bump_style_environment_version()
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	mut mutable_root := unsafe { &Node(root) }
	extra := BlockContainer.new(document, none, root.computed_values())
	mutable_root.append_child(unsafe { &Node(extra) })
	assign_layout_indexes(layout.root)
	recompute_containing_blocks(layout.root)
	assert !independent_probe_compare(mut source, root, 180, .normal, space)
	independent_probe_complete(mut source, root, 180)
	assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
}

fn test_independent_measurement_excludes_uncompleted_and_specialized_contexts() {
	for contents in [
		'<div style="float:left;width:40px;height:60px"></div><p>float</p>',
		'<div style="position:absolute;left:10%;top:20%">positioned</div>',
		'<ol><li>marker</li></ol>',
		'<p style="max-lines:1;continue:discard">clamped text</p>',
		'<div style="display:grid;grid-template-columns:subgrid">subgrid</div>',
		'<div style="columns:2">column text</div>',
	] {
		mut document, layout, root := independent_probe_fixture('display:flow-root', contents)
		defer { document.finalize() }
		mut source := layout.state
		source.enable_measurement_chunk_pool()
		for _ in 0 .. 2 {
			assert !independent_probe_compare(mut source, root, 180, .normal, AvailableSize.make_indefinite())
		}
		source.release_measurement_chunk_pool()
	}
	mut document, layout, root := independent_probe_fixture('display:flow-root', '<p>not completed</p>')
	defer { document.finalize() }
	mut source := layout.state
	source.block_layouts_ = map[u64]&RetainedBlockLayout{}
	source.enable_measurement_chunk_pool()
	assert !independent_probe_compare(mut source, root, 300, .normal, AvailableSize.make_indefinite())
	assert !independent_probe_compare(mut source, root, 300, .normal, AvailableSize.make_indefinite())
	source.release_measurement_chunk_pool()
}

fn test_independent_measurement_rechecks_selected_and_unrelated_font_completion() {
	$if macos {
		mut document, layout, root := independent_probe_fixture('display:flow-root',
			'<p style="font-family:LateIndependentProbe,monospace;font-size:18px;line-height:normal">Many words must wrap using the selected face and its current glyph advances.</p>')
		defer { document.finalize() }
		mut source := layout.state
		source.enable_measurement_chunk_pool()
		defer { source.release_measurement_chunk_pool() }
		space := AvailableSize.make_indefinite()
		independent_probe_complete(mut source, root, 180)
		assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
		mut face := css.FontFaceObject.construct_impl('LateIndependentProbe',
			css.FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), css.FontFaceDescriptors{})
		mut computer := css.css_style_computer_for(document)
		mut fonts := computer.font_face_set_
		fonts.add(face)!
		face.load()
		assert face.status() == .loaded
		assert !independent_probe_compare(mut source, root, 180, .normal, space)
		independent_probe_complete(mut source, root, 180)
		assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
		mut font_computer := computer.font_computer()
		font_computer.did_load_font('UnrelatedIndependentProbe')
		assert independent_probe_compare(mut source, root, 180, .normal, space) == !disable_independent_measurement_reuse
	}
}

fn test_independent_measurement_distinguishes_own_constraints_from_ancestor_probe_markers() {
	mut document := html.parse_document('<!doctype html><div style="width:300px"><section id="probe" style="display:grid;grid-template-columns:1fr;font:16px/20px SerenitySans"><p>Text wrapping inside a closed independent child.</p></section></div>')
	defer { document.finalize() }
	layout := run_document_layout(document, 500, 400) or { panic('missing layout') }
	root := independent_probe_find(layout.root)
	mut source := layout.state
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	independent_probe_complete(mut source, root, 180)
	parent := root.containing_block()?
	mut parent_values := source.get_mutable(unsafe { &NodeWithStyle(parent) })
	assert !parent_values.has_definite_height()
	for constraint in [SizeConstraint.min_content, .max_content] {
		parent_values.height_constraint = constraint
		assert independent_probe_compare(mut source, root, 180, .normal,
			AvailableSize.make_indefinite()) == !disable_independent_measurement_reuse
	}
	// A marker on an otherwise definite axis changes its effective
	// definiteness. That remains a real dependency and must reject replay.
	parent_values.width_constraint = .min_content
	assert !independent_probe_compare(mut source, root, 180, .normal,
		AvailableSize.make_indefinite())
	parent_values.width_constraint = .none
	styled := root.as_node_with_style()?
	mut probe := source.new_measurement_for_subtree(styled)
	defer { probe.release_measurement() }
	populate_intrinsic_containing_block_chain(mut probe, mut source, root)
	mut used := probe.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	used.set_has_definite_width(true)
	used.set_indefinite_content_height()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)),
		AvailableSize.make_indefinite())
	used.width_constraint = .min_content
	assert completed_context_for_measurement(probe, root, used, .normal, space) == none
	used.width_constraint = .none
	used.height_constraint = .max_content
	assert completed_context_for_measurement(probe, root, used, .normal, space) == none
}

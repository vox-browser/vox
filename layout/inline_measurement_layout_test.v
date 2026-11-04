module layout

import css
import dom
import html
import platform

fn measurement_inline_fixture(document &dom.Document, extra string) &BlockContainer {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	source := 'alpha beta gamma 😀 á אבג and more text to wrap across several lines'
	text := TextNode.new(document, document.create_text_node(source).as_node(), source)
	container.append_child(unsafe { &Node(text) })
	assign_layout_indexes(unsafe { &Node(container) })
	return container
}

fn measurement_inline_lines(lines []LineBox) []string {
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

fn measurement_inline_compare(mut source LayoutState, container &BlockContainer,
	space AvailableSpace, mode LayoutMode, width_only bool) bool {
	styled := unsafe { &NodeWithStyle(container) }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_content_width(space.width.to_px_or_zero())
	actual := run_inline_formatting_context_for_width(mut probe, container, mut used, mode,
		space, none, width_only)
	mut snapshots := platform.enter_retained_allocations()
	lines := measurement_inline_lines(used.line_boxes)
	snapshots.finish()
	inline_end := used.inline_end_static_position_rect()
	reused := used.line_boxes_are_shared_
	// A writable caller must detach the cache's fragments and glyph headers.
	if reused && used.line_boxes.len > 0 && used.line_boxes[0].fragments_.len > 0 {
		mut writable := probe.get_mutable(styled)
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := source.new_measurement_for_subtree(styled)
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(space.width.to_px_or_zero())
	result := run_uncached_inline_formatting_context_for_width(mut oracle, container, mut expected,
		mode, space, none, width_only)
	assert actual == result
	assert lines == measurement_inline_lines(expected.line_boxes)
	assert inline_end == expected.inline_end_static_position_rect()
	oracle.release_measurement()
	return reused
}

fn test_inline_measurement_reuses_owned_lines_after_producer_scratch_retires() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container := measurement_inline_fixture(document, '')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		for width in [AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_min_content(),
			AvailableSize.make_max_content()] {
			space := AvailableSpace.new(width, AvailableSize.make_indefinite())
			width_only := !width.is_definite()
			assert !measurement_inline_compare(mut source, container, space, mode, width_only)
			for _ in 0 .. 3 {
				reused := measurement_inline_compare(mut source, container, space, mode, width_only)
				assert reused == !disable_inline_measurement_reuse
			}
		}
	}
	pool := source.measurement_chunk_pool_
	source.release_measurement_chunk_pool()
	assert pool.closed && pool.inline_measurements_.len == 0
}

fn test_inline_measurement_invalidates_text_style_width_font_and_tree_inputs() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	mut container := measurement_inline_fixture(document, '')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	assert measurement_inline_compare(mut source, container, space, .normal, false) == !disable_inline_measurement_reuse
	mut text := container.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('Replacement text with a longer word: extraordinary')
	text.invalidate_text_for_rendering()
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	mut element := document.create_element('div')!
	element.set_attribute_value('style', 'display:block;font:23px/29px SerenitySans;letter-spacing:2px')
	container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	narrow := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(95)), AvailableSize.make_indefinite())
	assert !measurement_inline_compare(mut source, container, narrow, .normal, false)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedMeasurementFace')
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	document.bump_style_environment_version()
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	container.append_child(unsafe { &Node(TextNode.new(document,
		document.create_text_node(' additional child').as_node(), ' additional child')) })
	assign_layout_indexes(unsafe { &Node(container) })
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	for width in [80, 100, 120, 140, 160, 180] {
		_ = measurement_inline_compare(mut source, container,
			AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite()), .normal, false)
	}
	entries := source.measurement_chunk_pool_.inline_measurements_[u64(voidptr(container))] or { []&InlineMeasurementLayout{} }
	assert entries.len <= 4
}

fn test_inline_measurement_excludes_unpooled_committed_positioned_and_clamped_layout() {
	document := dom.Document.create(dom.url_about_blank())
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	for extra in ['', 'position:relative;left:2px', 'max-lines:1;continue:collapse', 'float:left'] {
		container := measurement_inline_fixture(document, extra)
		mut source := LayoutState.new()
		assert !measurement_inline_compare(mut source, container, space, .normal, false)
		source.enable_measurement_chunk_pool()
		if extra != '' {
			for _ in 0 .. 2 { assert !measurement_inline_compare(mut source, container, space, .normal, false) }
			assert source.measurement_chunk_pool_.inline_measurements_.len == 0
		}
		mut used := source.get_mutable(unsafe { &NodeWithStyle(container) })
		used.set_content_width(CSSPixels.new(180))
		_ = run_inline_formatting_context_for_width(mut source, container, mut used, .normal, space, none, false)
		assert source.measurement_chunk_pool_.inline_measurements_.len == 0
		source.release_measurement_chunk_pool()
	}
}

fn test_inline_measurement_does_not_cache_discarded_whitespace() {
	document := dom.Document.create(dom.url_about_blank())
	container := measurement_inline_fixture(document, '')
	mut text := container.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data(' \n\t ')
	text.invalidate_text_for_rendering()
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	for _ in 0 .. 3 {
		assert !measurement_inline_compare(mut source, container, space, .normal, false)
		assert source.measurement_chunk_pool_.inline_measurements_.len == 0
	}
}

fn test_committed_inline_consumes_measured_lines_with_document_ownership_and_copy_on_write() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container := measurement_inline_fixture(document, '')
	styled := unsafe { &NodeWithStyle(container) }
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut producer := state.new_measurement_for_subtree(styled)
	mut measured := producer.get_mutable(styled)
	measured.set_content_width(CSSPixels.new(180))
	result := run_inline_formatting_context_for_width(mut producer, container, mut measured,
		.normal, space, none, false)
	mut snapshots := platform.enter_retained_allocations()
	lines := measurement_inline_lines(measured.line_boxes)
	snapshots.finish()
	inline_end := measured.inline_end_static_position_rect()
	producer.release_measurement()
	gc_collect()
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	used.offset = css.CSSPixelPoint.from_values(11, 13)
	actual := run_inline_formatting_context(mut state, container, mut used, .normal, space)
	assert actual == result
	assert measurement_inline_lines(used.line_boxes) == lines
	assert used.inline_end_static_position_rect() == inline_end
	assert used.offset == css.CSSPixelPoint.from_values(11, 13)
	assert used.line_boxes_are_shared_ == (!disable_inline_measurement_reuse
		&& !disable_committed_inline_measurement_reuse)
	// The cache does not own its payload's lifetime. Releasing the pool and
	// collecting the producer must leave committed lines and glyphs usable.
	state.release_measurement_chunk_pool()
	gc_collect()
	assert measurement_inline_lines(used.line_boxes) == lines
	// Mutable line and fragment headers must detach from both retained caches.
	retained := state.inline_layouts_[u64(voidptr(container))] or { panic('missing committed layout') }
	mut writable := state.get_mutable(styled)
	assert !writable.line_boxes_are_shared_
	writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
	assert measurement_inline_lines(retained.lines) == lines
}

fn test_committed_inline_misses_never_populate_or_evict_measurements() {
	document := dom.Document.create(dom.url_about_blank())
	container := measurement_inline_fixture(document, '')
	styled := unsafe { &NodeWithStyle(container) }
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = measurement_inline_compare(mut state, container, space, .normal, false)
	key := u64(voidptr(container))
	entries := state.measurement_chunk_pool_.inline_measurements_[key] or { []&InlineMeasurementLayout{} }
	for width in [95, 110, 125, 140, 155, 170] {
		mut used := state.get_mutable(styled)
		used.set_content_width(CSSPixels.new(width))
		narrow := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
		_ = run_inline_formatting_context_for_width(mut state, container, mut used, .normal, narrow, none, false)
		assert !used.line_boxes_are_shared_
		current := state.measurement_chunk_pool_.inline_measurements_[key] or { []&InlineMeasurementLayout{} }
		assert current.len == entries.len
		for i in 0 .. current.len { assert voidptr(current[i]) == voidptr(entries[i]) }
	}
}

fn test_committed_inline_revalidates_measured_inputs_and_exact_geometry_question() {
	for change in ['text', 'style', 'font', 'environment', 'tree', 'height', 'intrinsic', 'width-only'] {
		mut document := dom.Document.create(dom.url_about_blank())
		mut container := measurement_inline_fixture(document, '')
		styled := unsafe { &NodeWithStyle(container) }
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		_ = measurement_inline_compare(mut state, container, space, .normal, false)
		match change {
			'text' {
				mut text := container.children()[0].as_text_node()?
				mut data := text.dom_node()?.as_character_data()?
				data.set_data('A changed text measurement')
				text.invalidate_text_for_rendering()
			}
			'style' {
				mut element := document.create_element('div')!
				element.set_attribute_value('style', 'display:block;font:23px/29px SerenitySans')
				container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
			}
			'font' {
				mut computer := css.css_style_computer_for(document).font_computer()
				computer.did_load_font('AnotherMeasurementFace')
			}
			'environment' { document.bump_style_environment_version() }
			'tree' {
				container.append_child(unsafe { &Node(TextNode.new(document,
					document.create_text_node(' extra').as_node(), ' extra')) })
				assign_layout_indexes(unsafe { &Node(container) })
			}
			else {}
		}
		mut used := state.get_mutable(styled)
		used.set_content_width(CSSPixels.new(180))
		if change == 'height' {
			used.set_content_height(CSSPixels.new(100))
			used.set_has_definite_height(true)
		}
		mode := if change == 'intrinsic' { LayoutMode.intrinsic_sizing } else { LayoutMode.normal }
		width_only := change == 'width-only'
		actual := run_inline_formatting_context_for_width(mut state, container, mut used, mode, space, none, width_only)
		assert !used.line_boxes_are_shared_
		lines := measurement_inline_lines(used.line_boxes)
		end := used.inline_end_static_position_rect()
		mut oracle := LayoutState.new()
		mut expected := oracle.get_mutable(styled)
		expected.set_content_width(CSSPixels.new(180))
		if change == 'height' {
			expected.set_content_height(CSSPixels.new(100))
			expected.set_has_definite_height(true)
		}
		result := run_uncached_inline_formatting_context_for_width(mut oracle, container, mut expected, mode, space, none, width_only)
		assert actual == result
		assert measurement_inline_lines(expected.line_boxes) == lines
		assert expected.inline_end_static_position_rect() == end
		state.release_measurement_chunk_pool()
	}
}

fn inline_tree_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing '+id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn inline_tree_test_prepare(mut state LayoutState, container &BlockContainer,
	space AvailableSpace, variant string) &UsedValues {
	root := unsafe { &Node(container) }
	parent := root.containing_block() or { panic('parent') }
	mut ancestors := LayoutState.new()
	mut parent_values := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	parent_values.set_content_width(CSSPixels.new(if variant == 'parent-width' { 501 } else { 500 }))
	parent_values.set_content_height(CSSPixels.new(300))
	parent_values.set_has_definite_width(true)
	parent_values.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	parent_values = state.get_mutable(unsafe { &NodeWithStyle(parent) })
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_containing_block_used_values(parent_values)
	used.set_content_width(space.width.to_px_or_zero())
	used.set_content_height(space.height.to_px_or_zero())
	used.set_has_definite_width(space.width.is_definite())
	used.set_has_definite_height(space.height.is_definite())
	used.offset = css.CSSPixelPoint.from_values(if variant == 'offset' { 21 } else { 11 }, 13)
	used.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	resolve_box_model_edges(root.computed_values(), mut used, parent_values.content_width().to_double())
	return used
}

fn inline_tree_test_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width()} ${used.content_height()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset}'
			result << '${used.margin_left} ${used.margin_right} ${used.margin_top} ${used.margin_bottom} ${used.padding_left} ${used.padding_right} ${used.padding_top} ${used.padding_bottom}'
			result << '${used.border_left} ${used.border_right} ${used.border_top} ${used.border_bottom} ${used.containing_line_box_fragment} ${used.inline_end_static_position_rect()}'
			result << '${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()}'
			result << measurement_inline_lines(used.line_boxes)
		} else { result << 'absent' }
	}
	for child in root.children() { result << inline_tree_test_geometry(state, child) }
	return result
}

fn inline_tree_test_compare(mut source LayoutState, container &BlockContainer,
	space AvailableSpace, mode LayoutMode, variant string) bool {
	root := unsafe { &Node(container) }
	styled := unsafe { &NodeWithStyle(container) }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := inline_tree_test_prepare(mut probe, container, space, variant)
	width_only := !space.width.is_definite()
	actual := run_inline_formatting_context_for_width(mut probe, container, mut used, mode,
		space, none, width_only)
	mut retained := platform.enter_retained_allocations()
	geometry := inline_tree_test_geometry(probe, root)
	retained.finish()
	reused := used.line_boxes_are_shared_
	if reused && used.line_boxes.len > 0 && used.line_boxes[0].fragments_.len > 0 {
		mut writable := probe.get_mutable(styled)
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
	}
	for entry in source.measurement_chunk_pool_.inline_measurements_[u64(voidptr(root))] or { []&InlineMeasurementLayout{} } {
		for saved in entry.values {
			if current := probe.try_get(saved.node) {
				mut writable := probe.get_mutable(saved.node)
				writable.offset = css.CSSPixelPoint.from_values(999, 999)
				assert saved.values.offset != writable.offset
				_ = current
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	mut expected := inline_tree_test_prepare(mut oracle, container, space, variant)
	result := run_uncached_inline_formatting_context_for_width(mut oracle, container, mut expected,
		mode, space, none, width_only)
	assert actual == result
	assert geometry == inline_tree_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_inline_tree_measurement_owns_styled_fragments_across_scratch_release() {
	for extra in ['direction:ltr', 'direction:rtl', 'white-space:pre-wrap'] {
		mut document := html.parse_document('<!doctype html><main><p id="lines" style="font:16px/20px SerenitySans;padding:2px 3%;${extra}">Before <strong style="padding:1px 2px;border:1px solid red;vertical-align:middle">bold <em style="font-size:13px">nested 😀 á אבג</em></strong> after words to wrap.</p></main>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		container := inline_tree_test_node(document, 'lines').as_block_container() or { panic('container') }
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			for width in [AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
				for height in [AvailableSize.make_indefinite(), AvailableSize.make_definite(CSSPixels.new(90))] {
					space := AvailableSpace.new(width, height)
					assert !inline_tree_test_compare(mut source, container, space, mode, '')
					for _ in 0 .. 3 {
						assert inline_tree_test_compare(mut source, container, space, mode, '') == (!disable_inline_measurement_reuse && !disable_inline_tree_measurement_reuse)
					}
				}
			}
		}
		source.release_measurement_chunk_pool()
	}
}

fn test_inline_tree_measurement_revalidates_styles_text_fonts_and_containing_bases() {
	for change in ['text', 'style', 'font', 'environment', 'tree', 'parent-width'] {
		mut document := html.parse_document('<!doctype html><main><p id="lines" style="font:16px/20px SerenitySans;padding:2px 3%">Before <span id="span" style="padding:2px">nested words to wrap</span> after.</p></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		container := inline_tree_test_node(document, 'lines').as_block_container() or { panic('container') }
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		assert !inline_tree_test_compare(mut source, container, space, .normal, '')
		assert inline_tree_test_compare(mut source, container, space, .normal, '') == (!disable_inline_measurement_reuse && !disable_inline_tree_measurement_reuse)
		assert inline_tree_test_compare(mut source, container, space, .normal, 'offset') == (!disable_inline_measurement_reuse && !disable_inline_tree_measurement_reuse)
		if change == 'text' {
			mut text := inline_tree_test_node(document, 'span').children()[0].as_text_node() or { panic('text') }
			mut data := text.dom_node()?.as_character_data() or { panic('data') }
			data.set_data('Changed text with extraordinary wrapping words.')
			text.invalidate_text_for_rendering()
		}
		if change == 'style' {
			mut element := document.create_element('span')!
			element.set_attribute_value('style', 'display:inline;font-size:23px;padding:4px')
			mut span := inline_tree_test_node(document, 'span').as_node_with_style() or { panic('span') }
			span.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		}
		if change == 'font' { mut computer := css.css_style_computer_for(document).font_computer(); computer.did_load_font('InlineTreeFace') }
		if change == 'environment' { document.bump_style_environment_version() }
		if change == 'tree' {
			mut span := inline_tree_test_node(document, 'span')
			span.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(' extra').as_node(), ' extra')) })
			mut top := unsafe { &Node(container) }
			for { parent := top.parent() or { break }; top = unsafe { &Node(parent) } }
			assign_layout_indexes(top)
			recompute_containing_blocks(top)
		}
		assert !inline_tree_test_compare(mut source, container, space, .normal, if change == 'parent-width' { change } else { '' })
		source.release_measurement_chunk_pool()
	}
}

fn test_inline_tree_measurement_keeps_atomic_positioned_break_and_clamp_cases_uncached() {
	for text in ['<span style="position:relative;left:2px">Shifted</span>', '<span style="display:inline-block">Atomic</span>', '<br>', '<img width="10" height="10">', '<svg width="10" height="10"><path d="M0 0H5V5Z"/></svg>'] {
		mut document := html.parse_document('<!doctype html><main><p id="lines">Before ${text} after.</p></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		container := inline_tree_test_node(document, 'lines').as_block_container() or { panic('container') }
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		for _ in 0 .. 2 { assert !inline_tree_test_compare(mut source, container, space, .normal, '') }
		source.release_measurement_chunk_pool()
	}
}

fn test_committed_inline_tree_consumes_owned_measurement_after_pool_retirement() {
	mut document := html.parse_document('<!doctype html><main><p id="lines">Before <strong>nested styled words 😀</strong> after words to wrap.</p></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	container := inline_tree_test_node(document, 'lines').as_block_container() or { panic('container') }
	root := unsafe { &Node(container) }
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !inline_tree_test_compare(mut source, container, space, .normal, '')
	mut used := inline_tree_test_prepare(mut source, container, space, '')
	actual := run_inline_formatting_context_for_width(mut source, container, mut used, .normal, space, none, false)
	assert used.line_boxes_are_shared_ == (!disable_inline_measurement_reuse && !disable_inline_tree_measurement_reuse && !disable_committed_inline_measurement_reuse)
	source.release_measurement_chunk_pool()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(unsafe { &NodeWithStyle(container) })
	mut expected := inline_tree_test_prepare(mut oracle, container, space, '')
	result := run_uncached_inline_formatting_context_for_width(mut oracle, container, mut expected, .normal, space, none, false)
	assert actual == result
	assert inline_tree_test_geometry(source, root) == inline_tree_test_geometry(oracle, root)
	oracle.release_measurement()
}

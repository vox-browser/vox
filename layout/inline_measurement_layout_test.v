module layout

import css
import dom
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

fn measurement_inline_values(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			containing := if parent := used.containing_block_used_values() { u64(voidptr(parent.node_)) } else { 0 }
			result << '${u64(voidptr(styled))} ${containing} ${used.content_width()} ${used.content_height()} ${used.offset}'
			result << '${used.margin_left} ${used.margin_right} ${used.margin_top} ${used.margin_bottom} ${used.border_left} ${used.border_right} ${used.border_top} ${used.border_bottom}'
			result << '${used.padding_left} ${used.padding_right} ${used.padding_top} ${used.padding_bottom} ${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()} ${used.inline_end_static_position_rect()}'
		} else { result << '${u64(voidptr(styled))} absent' }
	}
	for child in root.children() { result << measurement_inline_values(state, child) }
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
	values := measurement_inline_values(probe, unsafe { &Node(container) })
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
	assert values == measurement_inline_values(oracle, unsafe { &Node(container) })
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

fn measurement_nested_inline_fixture(document &dom.Document) (&BlockContainer, &InlineNode) {
	mut container := measurement_inline_fixture(document, '')
	mut element := document.create_element('span') or { panic(err) }
	element.set_attribute_value('style', 'display:inline;font:22px/26px SerenitySans;vertical-align:super;border:1px solid;padding:3px 5%;margin:2px')
	mut outer := InlineNode.new(document, element.as_node(),
		css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	source := ' nested text with wrapping and 😀 '
	outer.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(source).as_node(), source)) })
	mut inner_element := document.create_element('em') or { panic(err) }
	inner_element.set_attribute_value('style', 'display:inline;font:italic 12px/18px SerenitySans;letter-spacing:1px;padding:2px;border:2px solid')
	mut inner := InlineNode.new(document, inner_element.as_node(),
		css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(inner_element, none)))
	inner.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node('inner words').as_node(), 'inner words')) })
	outer.append_child(unsafe { &Node(inner) })
	container.append_child(unsafe { &Node(outer) })
	assign_layout_indexes(unsafe { &Node(container) })
	recompute_containing_blocks(unsafe { &Node(container) })
	return container, outer
}

fn test_inline_measurement_restores_nested_edges_and_containing_blocks_after_scratch_release() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, _ := measurement_nested_inline_fixture(document)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	defer { source.release_measurement_chunk_pool() }
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		for width in [AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_definite(CSSPixels.new(95)),
			AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
			space := AvailableSpace.new(width, AvailableSize.make_indefinite())
			width_only := !width.is_definite()
			assert !measurement_inline_compare(mut source, container, space, mode, width_only)
			for _ in 0 .. 3 {
				assert measurement_inline_compare(mut source, container, space, mode, width_only)
					== (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
			}
		}
	}
}

fn test_inline_measurement_nested_mutations_expire_geometry_and_positioned_content_stays_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	container, mut inline_node := measurement_nested_inline_fixture(document)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = measurement_inline_compare(mut source, container, space, .normal, false)
	assert measurement_inline_compare(mut source, container, space, .normal, false)
		== (!disable_inline_measurement_reuse && !disable_nested_inline_measurement_reuse)
	mut text := inline_node.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('different nested words')
	text.invalidate_text_for_rendering()
	assert !measurement_inline_compare(mut source, container, space, .normal, false)
	mut element := document.create_element('span')!
	for style in ['display:inline;font:28px/34px SerenitySans;border:3px solid;padding:4px',
		'display:inline;position:relative;left:7px'] {
		element.set_attribute_value('style', style)
		inline_node.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		assert !measurement_inline_compare(mut source, container, space, .normal, false)
	}
}

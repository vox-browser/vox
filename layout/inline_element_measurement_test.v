module layout

import css
import dom
import platform

fn inline_element_measurement_style(document &dom.Document, tag string, declarations string) &css.ComputedProperties {
	mut element := document.create_element(tag) or { panic(err) }
	element.set_attribute_value('style', declarations)
	return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

// A paragraph whose text runs through a padded, bordered link with emphasis
// inside it: a closed inline workspace with inline boxes, as in README text.
fn inline_element_measurement_fixture(document &dom.Document) (&BlockContainer, []&NodeWithStyle) {
	mut container := BlockContainer.new(document, none, inline_element_measurement_style(document,
		'p', 'display:block;font:16px/20px SerenitySans'))
	container.set_children_are_inline(true)
	before := 'Read the documentation in '
	container.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(before).as_node(), before)) })
	mut link := InlineNode.new(document, none, inline_element_measurement_style(document, 'a',
		'display:inline;font:16px/20px SerenitySans;padding:0 3px;margin-left:2px;border:1px solid'))
	inside := 'the getting started guide '
	link.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(inside).as_node(), inside)) })
	mut emphasis := InlineNode.new(document, none, inline_element_measurement_style(document, 'em',
		'display:inline;font:italic 16px/20px SerenitySans;margin-right:5px'))
	emphasized := 'before installing'
	emphasis.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(emphasized).as_node(), emphasized)) })
	link.append_child(unsafe { &Node(emphasis) })
	container.append_child(unsafe { &Node(link) })
	after := ' and building it from source on every supported platform.'
	container.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(after).as_node(), after)) })
	recompute_containing_blocks(unsafe { &Node(container) })
	assign_layout_indexes(unsafe { &Node(container) })
	return container, [unsafe { &NodeWithStyle(link) }, unsafe { &NodeWithStyle(emphasis) }]
}

fn inline_element_measurement_lines(lines []LineBox) []string {
	mut snapshots := platform.enter_retained_allocations()
	defer { snapshots.finish() }
	mut result := []string{}
	for line in lines {
		result << '${line.width().raw_value()} ${line.height().raw_value()} ${line.baseline().raw_value()}'
		for fragment in line.fragments_ {
			result << '${u64(voidptr(fragment.layout_node()))} ${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length().raw_value()}'
			if run := fragment.glyph_run() {
				result << '${run.glyphs()} ${run.glyph_positions()}'
			}
		}
	}
	return result
}

fn inline_element_measurement_values(state &LayoutState, boxes []&NodeWithStyle) []string {
	mut snapshots := platform.enter_retained_allocations()
	defer { snapshots.finish() }
	mut result := []string{}
	for box in boxes {
		used := state.try_get(box) or {
			result << 'missing'
			continue
		}
		result << '${used.margin_left.raw_value()} ${used.margin_right.raw_value()} ${used.padding_left.raw_value()} ${used.padding_right.raw_value()} ${used.border_left.raw_value()} ${used.border_right.raw_value()} ${used.content_width().raw_value()} ${used.content_height().raw_value()} ${used.offset}'
	}
	return result
}

fn inline_element_measurement_probe(mut source LayoutState, container &BlockContainer, boxes []&NodeWithStyle,
	space AvailableSpace) (bool, []string, []string) {
	styled := unsafe { &NodeWithStyle(container) }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_content_width(space.width.to_px_or_zero())
	_ = run_inline_formatting_context_for_width(mut probe, container, mut used, .normal, space, none, false)
	reused := used.line_boxes_are_shared_
	lines := inline_element_measurement_lines(used.line_boxes)
	values := inline_element_measurement_values(probe, boxes)
	probe.release_measurement()
	return reused, lines, values
}

fn test_measurement_reuses_lines_and_inline_box_values_of_a_paragraph_with_inline_elements() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, boxes := inline_element_measurement_fixture(document)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(170)), AvailableSize.make_indefinite())

	first_reused, first_lines, first_values := inline_element_measurement_probe(mut source, container, boxes, space)
	assert !first_reused
	assert first_lines.len > 4
	assert !first_values.contains('missing')
	// The producer's scratch has retired; a later probe at any ancestor level
	// asks the same question and receives the same lines and inline box values.
	for _ in 0 .. 2 {
		reused, lines, values := inline_element_measurement_probe(mut source, container, boxes, space)
		assert reused == !disable_inline_element_measurement_reuse
		assert lines == first_lines
		assert values == first_values
	}

	// The cached answer equals an uncached layout of the same question.
	styled := unsafe { &NodeWithStyle(container) }
	mut oracle := source.new_measurement_for_subtree(styled)
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(CSSPixels.new(170))
	_ = run_uncached_inline_formatting_context_for_width(mut oracle, container, mut expected, .normal,
		space, none, false)
	assert inline_element_measurement_lines(expected.line_boxes) == first_lines
	assert inline_element_measurement_values(oracle, boxes) == first_values
	oracle.release_measurement()

	// Another width is a different question.
	narrow := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(120)), AvailableSize.make_indefinite())
	narrow_reused, narrow_lines, _ := inline_element_measurement_probe(mut source, container, boxes, narrow)
	assert !narrow_reused
	assert narrow_lines != first_lines
}

fn test_inline_element_measurement_revalidates_a_restyled_inline_box() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, boxes := inline_element_measurement_fixture(document)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(170)), AvailableSize.make_indefinite())
	_, _, _ := inline_element_measurement_probe(mut source, container, boxes, space)
	// A new computed style for the link invalidates the cached answer.
	mut link := unsafe { &NodeWithStyle(boxes[0]) }
	link.set_computed_values(inline_element_measurement_style(document, 'a',
		'display:inline;font:16px/20px SerenitySans;padding:0 9px;border:2px solid'))
	reused, _, values := inline_element_measurement_probe(mut source, container, boxes, space)
	assert !reused
	assert values[0].starts_with('0 0 ${CSSPixels.new(9).raw_value()} ${CSSPixels.new(9).raw_value()} ${CSSPixels.new(2).raw_value()}')
}

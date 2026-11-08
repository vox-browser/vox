module layout

import css
import dom
import platform

fn principal_inline_style(document &dom.Document, tag string, declarations string) &css.ComputedProperties {
	mut element := document.create_element(tag) or { panic(err) }
	element.set_attribute_value('style', 'font:16px/20px SerenitySans;${declarations}')
	return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

fn principal_inline_fixture(document &dom.Document, list bool,
	position css.ListStylePosition) (&BlockContainer, ?&NodeWithStyle) {
	element := document.create_element(if list { 'li' } else { 'td' }) or { panic(err) }
	style := principal_inline_style(document, if list { 'li' } else { 'td' },
		if list { 'display:list-item;list-style-position:${position}' } else { 'display:table-cell;vertical-align:middle' })
	mut root := if list {
		unsafe { &BlockContainer(ListItemBox.new(document, element.as_node(), style)) }
	} else { BlockContainer.new(document, element.as_node(), style) }
	root.set_children_are_inline(true)
	mut marker := ?&NodeWithStyle(none)
	if list {
		mut box := ListItemMarkerBox.new(document,
			css.ListStyleType{kind: .string, name: '•'}, position, element,
			principal_inline_style(document, 'span', 'display:inline'))
		box.set_children_are_inline(true)
		box.append_child(unsafe { &Node(TextNode.new_generated(document, '•')) })
		mut marker_node := unsafe { &Node(box) }
		marker_node.set_generated_for(.marker, element)
		root.append_child(marker_node)
		mut item := unsafe { &ListItemBox(root) }
		item.set_marker(unsafe { &Node(box) })
		marker = unsafe { &NodeWithStyle(box) }
	}
	text := 'The principal inline content wraps across several narrow lines with '
	root.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(text).as_node(), text)) })
	mut link := InlineNode.new(document, none,
		principal_inline_style(document, 'a', 'display:inline;padding:0 3px;border:1px solid'))
	link_text := 'a padded link and trailing words.'
	link.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(link_text).as_node(), link_text)) })
	root.append_child(unsafe { &Node(link) })
	recompute_containing_blocks(unsafe { &Node(root) })
	assign_layout_indexes(unsafe { &Node(root) })
	return root, marker
}

fn principal_inline_line_snapshot(lines []LineBox) []string {
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut result := []string{}
	for line in lines {
		result << '${line.width().raw_value()} ${line.height().raw_value()} ${line.baseline().raw_value()}'
		for fragment in line.fragments_ {
			result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length().raw_value()}'
			if run := fragment.glyph_run() { result << '${run.glyphs()} ${run.glyph_positions()}' }
		}
	}
	return result
}

fn principal_inline_probe(mut source LayoutState, root &BlockContainer,
	marker ?&NodeWithStyle, marker_width int, space AvailableSpace,
	mode LayoutMode, cached bool) (bool, []string) {
	styled := unsafe { &NodeWithStyle(root) }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_content_width(space.width.to_px_or_zero())
	if node := marker {
		mut marker_used := probe.get_mutable(node)
		marker_used.set_content_width(CSSPixels.new(marker_width))
		marker_used.set_content_height(CSSPixels.new(8))
	}
	if cached {
		_ = run_inline_formatting_context_for_width(mut probe, root, mut used, mode, space, none, false)
	} else {
		_ = run_uncached_inline_formatting_context_for_width(mut probe, root, mut used, mode, space, none, false)
	}
	if node := marker {
		marker_used := probe.try_get(node) or { panic('marker values lost') }
		assert marker_used.content_width() == CSSPixels.new(marker_width)
	}
	reused := used.line_boxes_are_shared_
	lines := principal_inline_line_snapshot(used.line_boxes)
	probe.release_measurement()
	gc_collect()
	return reused, lines
}

fn test_disposable_principal_inline_roots_reuse_table_cells_and_outside_list_items() {
	for list in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_font_rendering_policy(.chromium)
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		root, marker := principal_inline_fixture(document, list, .outside)
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(170)), AvailableSize.make_indefinite())
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			if mode == .intrinsic_sizing {
				source.release_measurement_chunk_pool()
				source.enable_measurement_chunk_pool()
				source.measurement_chunk_pool_.scratch_enabled_ = true
			}
			first_shared, first := principal_inline_probe(mut source, root, marker, 9, space, mode, true)
			assert !first_shared
			second_shared, second := principal_inline_probe(mut source, root, marker, 31, space, mode, true)
			assert second_shared == (!disable_extended_inline_measurement_roots
				&& !disable_inline_measurement_reuse && !disable_inline_element_measurement_reuse)
			_, expected := principal_inline_probe(mut source, root, marker, 31, space, mode, false)
			assert first == second
			assert second == expected
		}
		narrow := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(120)), AvailableSize.make_indefinite())
		narrow_shared, narrow_actual := principal_inline_probe(mut source, root, marker, 31,
			narrow, .normal, true)
		_, narrow_expected := principal_inline_probe(mut source, root, marker, 31,
			narrow, .normal, false)
		assert !narrow_shared
		assert narrow_actual == narrow_expected
		// Cross-pass/committed ownership boundaries keep their original policy.
		assert !inline_measurement_root_is_closed(unsafe { &Node(root) }, none)
		source.release_measurement_chunk_pool()
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
}

fn test_inside_list_markers_keep_the_complete_inline_algorithm() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	root, _ := principal_inline_fixture(document, true, .inside)
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(170)), AvailableSize.make_indefinite())
	for _ in 0 .. 2 {
		// The complete inline algorithm sizes an inside marker itself.
		reused, actual := principal_inline_probe(mut source, root, none, 0, space, .normal, true)
		_, expected := principal_inline_probe(mut source, root, none, 0, space, .normal, false)
		assert !reused
		assert actual == expected
	}
	source.release_measurement_chunk_pool()
	owner.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_disposable_marker_text_reuse_revalidates_the_resolved_counter_string() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	_, marker := principal_inline_fixture(document, true, .outside)
	styled := marker or { panic('missing marker') }
	root := unsafe { &BlockContainer(styled) }
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(30)), AvailableSize.make_indefinite())
	first_shared, first := principal_inline_probe(mut source, root, none, 0, space, .normal, true)
	second_shared, second := principal_inline_probe(mut source, root, none, 0, space, .normal, true)
	assert !first_shared
	assert second_shared == (!disable_extended_inline_measurement_roots
		&& !disable_marker_inline_measurement_reuse && !disable_inline_measurement_reuse)
	assert first == second
	child := root.first_child() or { panic('missing marker text') }
	mut text := unsafe { &TextNode(child) }
	text.source_text_ = '123.'.clone()
	text.invalidate_text_for_rendering()
	changed_shared, changed := principal_inline_probe(mut source, root, none, 0, space, .normal, true)
	_, expected := principal_inline_probe(mut source, root, none, 0, space, .normal, false)
	assert !changed_shared
	assert changed != first
	assert changed == expected
	assert !inline_measurement_root_is_closed(unsafe { &Node(root) }, none)
	source.release_measurement_chunk_pool()
	owner.finish()
	document.finalize()
	document.release_native_storage()
}


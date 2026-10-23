module layout

import css
import dom
import html

fn uncached_inline_workspace_style(document &dom.Document, tag string, declarations string) &css.ComputedProperties {
	mut element := document.create_element(tag) or { panic(err) }
	element.set_attribute_value('style', declarations)
	return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

fn uncached_inline_workspace_fixture(document &dom.Document, source string, extra string) (&BlockContainer, &LayoutState, &UsedValues, &TextNode) {
	style := uncached_inline_workspace_style(document, 'div',
		'display:block;font:16px/20px SerenitySans;width:180px;${extra}')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text := TextNode.new_generated(document, source)
	container.append_child(unsafe { &Node(text) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	return container, state, used, text
}

fn uncached_inline_workspace_break(document &dom.Document, clear string) &BreakNode {
	style := uncached_inline_workspace_style(document, 'br', 'display:inline;clear:${clear}')
	element := document.create_element('br') or { panic(err) }
	return BreakNode.new(document, element.as_node(), style)
}

fn test_uncached_inline_workspace_accepts_generated_shadow_text_and_plain_breaks_without_caching() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut container, _, _, mut text := uncached_inline_workspace_fixture(document, 'generated', '')
	root := unsafe { &Node(container) }
	assert inline_layout_workspace_is_closed(root, true)
	mut inputs := []RetainedInlineInput{}
	assert !collect_retained_inline_inputs(root, true, mut inputs)
	text.is_generated_text_node_ = false
	text.set_is_in_ua_internal_shadow_tree(true)
	inputs.clear()
	assert inline_layout_workspace_is_closed(root, true)
	assert !collect_retained_inline_inputs(root, true, mut inputs)
	text.set_is_in_ua_internal_shadow_tree(false)
	container.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'none')) })
	inputs.clear()
	assert inline_layout_workspace_is_closed(root, true)
	assert !collect_retained_inline_inputs(root, true, mut inputs)
}

fn test_uncached_inline_workspace_rejects_external_geometry_and_text_split_dependencies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container, _, _, mut text := uncached_inline_workspace_fixture(document, 'text', '')
	root := unsafe { &Node(container) }
	text.first_letter_ = text
	assert !inline_layout_workspace_is_closed(root, true)
	text.first_letter_ = none
	text.source_range_length_ = 2
	assert !inline_layout_workspace_is_closed(root, true)
	text.source_range_length_ = none
	text.is_empty_editable_ = true
	assert !inline_layout_workspace_is_closed(root, true)
	text.is_empty_editable_ = false
	text.produces_line_box_fragment_when_empty_ = true
	assert !inline_layout_workspace_is_closed(root, true)
	text.produces_line_box_fragment_when_empty_ = false
	assert inline_layout_workspace_is_closed(root, true)
	for declarations in ['display:inline-block', 'display:inline;float:left',
		'display:inline;position:relative', 'display:inline;position:absolute'] {
		mut outer, _, _, _ := uncached_inline_workspace_fixture(document, 'outer', '')
		style := uncached_inline_workspace_style(document, 'span', declarations)
		child := InlineNode.new(document, none, style)
		outer.append_child(unsafe { &Node(child) })
		assert !inline_layout_workspace_is_closed(unsafe { &Node(outer) }, true), declarations
	}
	mut with_clear, _, _, _ := uncached_inline_workspace_fixture(document, 'clear', '')
	with_clear.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'both')) })
	assert !inline_layout_workspace_is_closed(unsafe { &Node(with_clear) }, true)
	mut continued, _, _, _ := uncached_inline_workspace_fixture(document, 'continued', '')
	style := uncached_inline_workspace_style(document, 'span', 'display:inline')
	mut continuation := InlineNode.new(document, none, style)
	continuation.continuation_of_node_ = unsafe { &NodeWithStyleAndBoxModelMetrics(continued) }
	continued.append_child(unsafe { &Node(continuation) })
	assert !inline_layout_workspace_is_closed(unsafe { &Node(continued) }, true)
	for declarations in ['writing-mode:vertical-rl', 'display:flex',
		'display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2'] {
		outer, _, _, _ := uncached_inline_workspace_fixture(document, 'excluded', declarations)
		assert !inline_layout_workspace_is_closed(unsafe { &Node(outer) }, true), declarations
	}
}

fn test_uncached_inline_workspace_matches_generated_unicode_breaks_and_ellipsis_without_cache_entries() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	for extra in ['', 'overflow-wrap:anywhere', 'white-space:pre-wrap',
		'white-space:nowrap;overflow:hidden;text-overflow:ellipsis'] {
		mut container, mut state, mut used, _ := uncached_inline_workspace_fixture(document,
			'Latin 😀 á אבג العربية longwordwithoutbreaks and trailing words  ', extra)
		container.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'none')) })
		container.append_child(unsafe { &Node(TextNode.new_generated(document, 'after break')) })
		assign_layout_indexes(unsafe { &Node(container) })
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		reference := run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, none)
		expected := inline_workspace_lines_fingerprint(used.line_boxes)
		assert expected.len > 1
		actual := run_inline_formatting_context(mut state, container, mut used, .normal, space)
		assert actual == reference
		assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
		assert state.inline_layouts_.len == 0
		assert state.previous_inline_layouts_.len == 0
	}
}

fn test_uncached_inline_workspace_publishes_text_caches_and_preserves_retired_lines() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, mut state, mut used, mut text := uncached_inline_workspace_fixture(document,
		'Unicode 😀 á אבג العربية text transforms and wraps repeatedly', 'text-transform:uppercase')
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	// The first pass creates the node's transformed text, font, chunks, UTF-16
	// units and Unicode segmenter while the new closed workspace is entered.
	_ = run_inline_formatting_context(mut state, container, mut used, .normal, space)
	old_lines := unsafe { used.line_boxes }
	// Declare the saved geometry as a borrower. The collector fallback can
	// otherwise reuse its private line vector on the next formatting pass.
	used.borrow_retained_line_boxes(old_lines)
	old_fingerprint := inline_workspace_lines_fingerprint(old_lines)
	old_rendered := text.text_for_rendering()
	old_units := text.cached_utf16_code_units_?
	old_units_copy := old_units.clone()
	old_chunks := text.cached_inline_chunks_?
	assert old_chunks.len > 0
	old_chunk_view := old_chunks[0].view
	old_font := old_chunks[0].font
	old_segmenter := text.line_segmenter()
	old_boundaries := old_segmenter.boundaries().clone()
	assert old_lines.len > 1
	for source in ['replacement 😀 á text needs different wrapping',
		'new אבג العربية content and a different trailing phrase', 'final text'] {
		text.source_text_ = source
		text.invalidate_text_for_rendering()
		_ = run_inline_formatting_context(mut state, container, mut used, .normal, space)
		expected := inline_workspace_lines_fingerprint(used.line_boxes)
		_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, none)
		assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
		assert state.inline_layouts_.len == 0
	}
	gc_collect()
	assert inline_workspace_lines_fingerprint(old_lines) == old_fingerprint
	assert old_units == old_units_copy
	assert old_chunks[0].view == old_chunk_view
	assert old_rendered.contains('UNICODE')
	assert old_font.point_size > 0
	assert old_segmenter.boundaries() == old_boundaries
}

fn test_uncached_inline_workspace_retires_generated_text_builder_allocations() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, mut state, mut used, _ := uncached_inline_workspace_fixture(document,
		'one two three four five six seven eight '.repeat(64), '')
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = run_inline_formatting_context(mut state, container, mut used, .normal, space)
	used.line_boxes = []LineBox{}
	before_reference := document.native_storage().arena.usage().used
	_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, none)
	reference_bytes := document.native_storage().arena.usage().used - before_reference
	expected := inline_workspace_lines_fingerprint(used.line_boxes)
	used.line_boxes = []LineBox{}
	before_owned := document.native_storage().arena.usage().used
	_ = run_inline_formatting_context(mut state, container, mut used, .normal, space)
	owned_bytes := document.native_storage().arena.usage().used - before_owned
	assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
	assert reference_bytes > 4096
	assert owned_bytes < reference_bytes * 9 / 10, 'owned=${owned_bytes} reference=${reference_bytes}'
	assert state.inline_layouts_.len == 0
}

fn test_native_uncached_inline_workspace_refreshes_generated_content_and_break_paint() {
	mut document := html.parse_document('<!doctype html><style>#stable{width:150px;font:16px/20px SerenitySans}#stable::before{content:attr(data-label)}#stable.changed{font:20px/24px SerenityMono;width:90px}</style><p id="stable" data-label="generated prefix ">Unicode 😀 á <br>different trailing text</p>')
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'stable')
	assert inline_layout_workspace_is_closed(root, true)
	mut inputs := []RetainedInlineInput{}
	assert !collect_retained_inline_inputs(root, true, mut inputs)
	previous := document_layout_result(document)?
	assert u64(voidptr(root)) !in previous.state.inline_layouts_
	old_commands := record_retained_display_list(mut document)?
	old_dump := old_commands.dump()
	mut stable := document.get_element_by_id('stable')?
	stable.set_attribute_value('data-label', 'changed generated prefix ')
	stable.set_attribute_value('class', 'changed')
	document.update_layout(.debugging)
	updated_commands := document.record_display_list()?
	updated_dump := updated_commands.dump()
	assert updated_dump != old_dump
	retained_inline_assert_full_layout(mut document)
	gc_collect()
	assert old_commands.dump() == old_dump
}

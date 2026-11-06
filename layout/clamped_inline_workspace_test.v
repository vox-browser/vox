module layout

import css
import dom
import platform

fn clamped_workspace_fingerprint(used &UsedValues) []string {
	mut values := inline_workspace_lines_fingerprint(used.line_boxes)
	values << '${used.has_line_clamp_point()} ${used.is_invisible_for_line_clamp()} ${used.inline_end_static_position_rect()}'
	for line in used.line_boxes {
		for fragment in line.fragments_ {
			values << '${fragment.is_fully_truncated()} ${fragment.block_ellipsis_text_ or { "" }}'
		}
	}
	return values
}

fn clamped_workspace_compare(container &BlockContainer, width int, already_consumed int) {
	root := unsafe { &Node(container) }
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(width))
	used.offset = css.CSSPixelPoint.from_values(17, 23)
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	context.line_clamp_line_count = already_consumed
	assert clamped_inline_workspace_is_closed(root, &context) == !retain_clamped_inline_allocations
	actual := run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	fingerprint := clamped_workspace_fingerprint(used)
	assert used.offset == css.CSSPixelPoint.from_values(17, 23)
	assert state.inline_layouts_.len == 0
	assert state.previous_inline_layouts_.len == 0
	gc_collect()
	mut oracle := LayoutState.new()
	mut expected := oracle.get_mutable(unsafe { &NodeWithStyle(container) })
	expected.set_content_width(CSSPixels.new(width))
	expected.offset = css.CSSPixelPoint.from_values(17, 23)
	mut expected_context := BlockFormattingContext.for_root(root, .normal, true)
	expected_context.line_clamp_line_count = already_consumed
	result := run_uncached_inline_formatting_context(mut oracle, container, mut expected,
		.normal, space, &expected_context)
	assert actual == result
	assert fingerprint == clamped_workspace_fingerprint(expected)
	assert context.line_clamp_line_count == expected_context.line_clamp_line_count
	assert context.line_clamp_reached_ == expected_context.line_clamp_reached_
	assert context.laying_out_invisible_clamped_content == expected_context.laying_out_invisible_clamped_content
	assert context.y_offset_of_current_block_container == expected_context.y_offset_of_current_block_container
	assert context.margin_state.current_collapsed_margin() == expected_context.margin_state.current_collapsed_margin()
	$if prealloc {
		if !retain_clamped_inline_allocations {
			assert clamped_inline_workspace_reported
			arena := root.document().native_storage().arena
			if used.line_boxes.len > 0 { assert arena.contains(voidptr(used.line_boxes.data)) }
			if rare := used.rare_ { assert arena.contains(voidptr(rare)) }
			for line in used.line_boxes {
				assert arena.contains(voidptr(line.fragments_.data))
				for fragment in line.fragments_ {
					if run := fragment.glyph_run() {
						assert arena.contains(voidptr(run))
						assert arena.contains(voidptr(run.glyphs_.data))
					}
					if ellipsis := fragment.block_ellipsis_text_ {
						if ellipsis.len > 0 { assert arena.contains(voidptr(ellipsis.str)) }
					}
				}
			}
		}
	}
}

fn test_clamped_inline_workspace_runs_full_algorithm_with_exact_geometry_and_running_counters() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	for rules in ['max-lines:1;continue:collapse', 'max-lines:2;continue:collapse',
		'display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3',
		'max-lines:2;continue:collapse;position:relative',
		'max-lines:2;continue:collapse;direction:rtl'] {
		container, _, _ := inline_workspace_fixture(document,
			'Latin 😀 á אבג العربية longwordwithoutbreaks and many more wrapping words alpha beta gamma delta epsilon', rules)
		for width in [90, 180, 320] {
			for consumed in [0, 1] { clamped_workspace_compare(container, width, consumed) }
		}
	}
}

fn test_clamped_inline_workspace_keeps_nested_spans_plain_breaks_and_generated_text_owned() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut container, _, _, _ := uncached_inline_workspace_fixture(document,
		'generated long text that wraps to many lines alpha beta gamma', 'max-lines:2;continue:collapse')
	style := uncached_inline_workspace_style(document, 'span', 'display:inline;font:18px/23px SerenitySans')
	mut nested := InlineNode.new(document, none, style)
	nested.append_child(unsafe { &Node(TextNode.new_generated(document, 'nested 😀 text more words')) })
	container.append_child(unsafe { &Node(nested) })
	container.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'none')) })
	container.append_child(unsafe { &Node(TextNode.new_generated(document, 'after break words')) })
	assign_layout_indexes(unsafe { &Node(container) })
	clamped_workspace_compare(container, 110, 0)
	clamped_workspace_compare(container, 250, 0)
}

fn test_clamped_inline_workspace_preserves_older_lines_and_shaped_text_after_live_mutations() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	container, mut state, mut used := inline_workspace_fixture(document,
		'original 😀 words alpha beta gamma delta epsilon zeta eta theta', 'max-lines:2;continue:collapse')
	root := unsafe { &Node(container) }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	old_lines := unsafe { used.line_boxes }
	used.borrow_retained_line_boxes(old_lines)
	old_fingerprint := inline_workspace_lines_fingerprint(old_lines)
	mut text := root.children()[0].as_text_node()?
	for source in ['replacement 😀 words with different wrapping alpha beta gamma', 'other אבג العربية content and more words'] {
		mut data := text.dom_node()?.as_character_data()?
		data.set_data(source)
		text.invalidate_text_for_rendering()
		context = BlockFormattingContext.for_root(root, .normal, true)
		_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
		gc_collect()
		assert inline_workspace_lines_fingerprint(old_lines) == old_fingerprint
		clamped_workspace_compare(container, 180, 0)
	}
}

fn test_clamped_inline_workspace_keeps_external_contexts_floats_and_shifted_or_split_trees_outside() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container, _, _, mut text := uncached_inline_workspace_fixture(document,
		'clamped text', 'max-lines:2;continue:collapse')
	root := unsafe { &Node(container) }
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	assert clamped_inline_workspace_is_closed(root, &context) == !retain_clamped_inline_allocations
	assert !clamped_inline_workspace_is_closed(root, none)
	context.root = none
	assert !clamped_inline_workspace_is_closed(root, &context)
	context.root = root
	context.laying_out_invisible_clamped_content = true
	assert !clamped_inline_workspace_is_closed(root, &context)
	context.laying_out_invisible_clamped_content = false
	text.source_range_length_ = 2
	assert !clamped_inline_workspace_is_closed(root, &context)
	text.source_range_length_ = none
	for extra in ['position:relative;top:2px', 'display:inline-block', 'float:left'] {
		mut outer, _, _, _ := uncached_inline_workspace_fixture(document, 'outer', 'max-lines:2;continue:collapse')
		style := uncached_inline_workspace_style(document, 'span', 'display:inline;${extra}')
		outer.append_child(unsafe { &Node(InlineNode.new(document, none, style)) })
		mut bfc := BlockFormattingContext.for_root(unsafe { &Node(outer) }, .normal, true)
		assert !clamped_inline_workspace_is_closed(unsafe { &Node(outer) }, &bfc)
	}
	mut clear, _, _, _ := uncached_inline_workspace_fixture(document, 'clear', 'max-lines:2;continue:collapse')
	clear.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'both')) })
	mut clear_context := BlockFormattingContext.for_root(unsafe { &Node(clear) }, .normal, true)
	assert !clamped_inline_workspace_is_closed(unsafe { &Node(clear) }, &clear_context)
}

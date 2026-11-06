module layout

import css
import dom
import platform

fn positioned_workspace_values(state &LayoutState, node &Node) []string {
	mut result := []string{}
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			if rare := used.rare_ { result << '${rare.static_position_rect_}' } else { result << 'none' }
			result << '${used.content_width()} ${used.content_height()} ${used.offset} ${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()}'
		} else { result << 'absent' }
	}
	for child in node.children() { result << positioned_workspace_values(state, child) }
	return result
}

fn positioned_workspace_absolute(document &dom.Document) &BlockContainer {
	style := uncached_inline_workspace_style(document, 'div', 'display:block;position:absolute;left:17px;top:11px;width:50px')
	mut box := BlockContainer.new(document, none, style)
	// This non-inline subtree is opaque to the inline iterator.
	floating := uncached_inline_workspace_style(document, 'div', 'display:block;float:left')
	mut child := BlockContainer.new(document, none, floating)
	child.append_child(unsafe { &Node(TextNode.new_generated(document, 'opaque contents')) })
	box.append_child(unsafe { &Node(child) })
	return box
}

fn positioned_workspace_compare(container &BlockContainer, width int) {
	root := unsafe { &Node(container) }
	assert positioned_inline_workspace_is_closed(root, true) == !retain_positioned_inline_allocations
	positioned_inline_workspace_reported = false
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(width))
	used.offset = css.CSSPixelPoint.from_values(17, 23)
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	actual := run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	lines := inline_workspace_lines_fingerprint(used.line_boxes)
	positions := positioned_workspace_values(state, root)
	end := used.inline_end_static_position_rect()
	assert state.inline_layouts_.len == 0
	assert used.offset == css.CSSPixelPoint.from_values(17, 23)
	$if prealloc {
		assert positioned_inline_workspace_reported == !retain_positioned_inline_allocations
		if !retain_positioned_inline_allocations {
			arena := root.document().native_storage().arena
			if used.line_boxes.len > 0 { assert arena.contains(voidptr(used.line_boxes.data)) }
			for line in used.line_boxes {
				if line.fragments_.len > 0 { assert arena.contains(voidptr(line.fragments_.data)) }
				if line.static_position_markers_.len > 0 { assert arena.contains(voidptr(line.static_position_markers_.data)) }
			}
		}
	}
	gc_collect()
	mut oracle := LayoutState.new()
	mut expected := oracle.get_mutable(unsafe { &NodeWithStyle(container) })
	expected.set_content_width(CSSPixels.new(width))
	expected.offset = css.CSSPixelPoint.from_values(17, 23)
	mut reference_context := BlockFormattingContext.for_root(root, .normal, true)
	assert actual == run_uncached_inline_formatting_context(mut oracle, container, mut expected,
		.normal, space, &reference_context)
	assert lines == inline_workspace_lines_fingerprint(expected.line_boxes)
	assert positions == positioned_workspace_values(oracle, root)
	assert end == expected.inline_end_static_position_rect()
	assert context.y_offset_of_current_block_container == reference_context.y_offset_of_current_block_container
	assert context.margin_state.current_collapsed_margin() == reference_context.margin_state.current_collapsed_margin()
}

fn test_positioned_inline_workspace_matches_full_static_positions_ltr_rtl_and_wrapping() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	for direction in ['ltr', 'rtl'] {
		mut container, _, _, _ := uncached_inline_workspace_fixture(document,
			'Latin 😀 á אבג العربية words alpha beta gamma delta epsilon', 'position:relative;direction:${direction}')
		container.append_child(unsafe { &Node(positioned_workspace_absolute(document)) })
		container.append_child(unsafe { &Node(TextNode.new_generated(document, ' final words')) })
		assign_layout_indexes(unsafe { &Node(container) })
		for width in [90, 180, 320] { positioned_workspace_compare(container, width) }
	}
}

fn test_positioned_inline_workspace_owns_removed_empty_line_markers_and_skips_absolute_subtrees() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	for text in ['', ' ', 'alpha beta gamma', 'alpha\n'] {
		mut container, _, _, _ := uncached_inline_workspace_fixture(document, text, 'white-space:pre-wrap')
		absolute := positioned_workspace_absolute(document)
		container.append_child(unsafe { &Node(absolute) })
		assign_layout_indexes(unsafe { &Node(container) })
		positioned_workspace_compare(container, 110)
	}
}

fn test_positioned_inline_workspace_preserves_nested_relative_metrics_and_plain_breaks() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut container, _, _, _ := uncached_inline_workspace_fixture(document,
		'generated outer words ', 'position:relative')
	style := uncached_inline_workspace_style(document, 'span', 'display:inline;position:relative;padding-left:3px;border-left:2px solid;margin-right:4px;font:18px/23px SerenitySans')
	mut nested := InlineNode.new(document, none, style)
	nested.append_child(unsafe { &Node(positioned_workspace_absolute(document)) })
	nested.append_child(unsafe { &Node(TextNode.new_generated(document, 'nested 😀 text and words')) })
	container.append_child(unsafe { &Node(nested) })
	container.append_child(unsafe { &Node(uncached_inline_workspace_break(document, 'none')) })
	container.append_child(unsafe { &Node(TextNode.new_generated(document, 'after break')) })
	assign_layout_indexes(unsafe { &Node(container) })
	positioned_workspace_compare(container, 110)
	positioned_workspace_compare(container, 250)
}

fn test_positioned_inline_workspace_preserves_borrowed_lines_and_markers_after_live_text_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut container, mut state, mut used, mut text := uncached_inline_workspace_fixture(document,
		'original 😀 words alpha beta gamma delta epsilon', 'position:relative')
	container.append_child(unsafe { &Node(positioned_workspace_absolute(document)) })
	assign_layout_indexes(unsafe { &Node(container) })
	root := unsafe { &Node(container) }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	old_lines := unsafe { used.line_boxes }
	used.borrow_retained_line_boxes(old_lines)
	old_fingerprint := inline_workspace_lines_fingerprint(old_lines)
	mut marker_counts := []int{}
	for line in old_lines { marker_counts << line.static_position_markers_.len }
	for source in ['replacement 😀 text with different wrapping', 'other אבג العربية words and trailing text'] {
		text.source_text_ = source
		text.invalidate_text_for_rendering()
		context = BlockFormattingContext.for_root(root, .normal, true)
		_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
		gc_collect()
		assert inline_workspace_lines_fingerprint(old_lines) == old_fingerprint
		for index, line in old_lines { assert line.static_position_markers_.len == marker_counts[index] }
		positioned_workspace_compare(container, 180)
	}
}

fn test_positioned_inline_workspace_rejects_shifted_floating_fixed_atomic_and_split_inputs() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for extra in ['position:relative;left:2px', 'position:fixed', 'display:inline-block', 'float:left'] {
		mut container, _, _, _ := uncached_inline_workspace_fixture(document, 'outer', '')
		style := uncached_inline_workspace_style(document, 'span', 'display:inline;${extra}')
		container.append_child(unsafe { &Node(InlineNode.new(document, none, style)) })
		assert !positioned_inline_workspace_is_closed(unsafe { &Node(container) }, true)
	}
	container, _, _, mut text := uncached_inline_workspace_fixture(document, 'split', 'position:relative')
	text.source_range_length_ = 2
	assert !positioned_inline_workspace_is_closed(unsafe { &Node(container) }, true)
	for extra in ['writing-mode:vertical-rl', 'max-lines:2;continue:collapse'] {
		outer, _, _, _ := uncached_inline_workspace_fixture(document, 'excluded', extra)
		assert !positioned_inline_workspace_is_closed(unsafe { &Node(outer) }, true)
	}
}

fn test_positioned_inline_workspace_retires_builder_storage_with_unchanged_static_rectangles() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut container, mut state, mut used, _ := uncached_inline_workspace_fixture(document,
		'one two three four five six seven eight '.repeat(64), 'position:relative')
	container.append_child(unsafe { &Node(positioned_workspace_absolute(document)) })
	assign_layout_indexes(unsafe { &Node(container) })
	root := unsafe { &Node(container) }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut context := BlockFormattingContext.for_root(root, .normal, true)
	_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, &context)
	context = BlockFormattingContext.for_root(root, .normal, true)
	_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	used.line_boxes = []LineBox{}
	context = BlockFormattingContext.for_root(root, .normal, true)
	before_reference := document.native_storage().arena.usage().used
	expected_result := run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, &context)
	reference_bytes := document.native_storage().arena.usage().used - before_reference
	expected_lines := inline_workspace_lines_fingerprint(used.line_boxes)
	expected_positions := positioned_workspace_values(state, root)
	used.line_boxes = []LineBox{}
	context = BlockFormattingContext.for_root(root, .normal, true)
	before_owned := document.native_storage().arena.usage().used
	actual := run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &context)
	owned_bytes := document.native_storage().arena.usage().used - before_owned
	assert actual == expected_result
	assert inline_workspace_lines_fingerprint(used.line_boxes) == expected_lines
	assert positioned_workspace_values(state, root) == expected_positions
	assert reference_bytes > 4096
	if !retain_positioned_inline_allocations { assert owned_bytes < reference_bytes * 9 / 10 }
}

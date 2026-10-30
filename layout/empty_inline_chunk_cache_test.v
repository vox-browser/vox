// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn (mut iterator InlineLevelIterator) emptycache_previous_enter_text_node(text_node &TextNode) {
	computed := text_node.Node.computed_values()
	white_space_collapse := computed.white_space_collapse()
	should_wrap_lines := computed.text_wrap_mode() == .wrap
	should_respect_linebreaks := white_space_collapse in [.preserve, .preserve_breaks, .break_spaces]
	mut chunks := []TextNodeChunk{}
	font_generation := css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
	if cached := text_node.cached_inline_chunks_ {
		// The cached chunks are immutable after construction; sharing their
		// backing array avoids copying it for each intrinsic-sizing pass. A font
		// load replaces the cascade, so chunks retaining the previous platform
		// fonts must be shaped again.
		if text_node.cached_font_environment_generation_ == font_generation {
			chunks = unsafe { cached }
		}
	}
	if chunks.len == 0 {
		mut chunk_iterator := TextNodeChunkIterator.new_with_direction(text_node, should_wrap_lines,
			should_respect_linebreaks, if iterator.is_unidirectional_left_to_right {
				TextDirectionMode.unidirectional_left_to_right
			} else {
				TextDirectionMode.per_code_point
			})
		for {
			chunk := chunk_iterator.next() or { break }
			chunks << chunk
		}
		// InlineLevelIterator::generate_next_item() synthesizes one empty chunk for
		// mutable form-control editing text and generated empty strings. The V DOM
		// does not materialize the closed UA shadow root, so TreeBuilder records the
		// former on its equivalent internal TextNode.
		if chunks.len == 0 && text_node.text_for_rendering().len == 0
			&& (text_node.retains_empty_generated_fragment_
				|| text_node.produces_line_box_fragment_when_empty_) {
			chunks << chunk_iterator.create_empty_chunk()
		}
		mut mutable_text_node := unsafe { &TextNode(text_node) }
		mutable_text_node.cached_inline_chunks_ = chunks
		mutable_text_node.cached_font_environment_generation_ = css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
		mutable_text_node.cached_intrinsic_text_shapes_.clear()
	}
	// Every retained chunk emits exactly one item, including whitespace and
	// forced line breaks. Reserve their known demand once instead of growing
	// and copying the wide item vector while emitting that text node.
	if chunks.len > 0 && iterator.items.len <= 2_147_483_647 - chunks.len {
		iterator.items.ensure_cap(iterator.items.len + chunks.len)
	}
	iterator.has_text_node_context = true
	iterator.text_node_context = InlineTextNodeContext{
		chunks:                     chunks
		should_collapse_whitespace: white_space_collapse in [.collapse, .preserve_breaks]
		should_wrap_lines:          should_wrap_lines
		should_respect_linebreaks:  should_respect_linebreaks
	}
}

fn emptycache_fixture(value string, declarations string) (&dom.Document, &BlockContainer, &TextNode) {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px SerenitySans;' + declarations)
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text := document.create_text_node(value)
	node := TextNode.new(document, text.as_node(), value)
	container.append_child(unsafe { &Node(node) })
	return document, container, node
}

fn emptycache_enter(text &TextNode, previous bool) InlineTextNodeContext {
	mut iterator := InlineLevelIterator{}
	if previous {
		iterator.emptycache_previous_enter_text_node(text)
	} else {
		iterator.enter_text_node(text)
	}
	assert iterator.has_text_node_context
	return iterator.text_node_context
}

fn emptycache_assert_same(actual InlineTextNodeContext, expected InlineTextNodeContext) {
	emptycache_assert_context(actual, expected, false)
}

fn emptycache_assert_context(actual InlineTextNodeContext, expected InlineTextNodeContext, rebuilt_fonts bool) {
	assert actual.should_collapse_whitespace == expected.should_collapse_whitespace
	assert actual.should_wrap_lines == expected.should_wrap_lines
	assert actual.should_respect_linebreaks == expected.should_respect_linebreaks
	assert actual.next_chunk_index == expected.next_chunk_index
	assert actual.last_known_direction == expected.last_known_direction
	assert actual.chunks.len == expected.chunks.len
	for index, a in actual.chunks {
		b := expected.chunks[index]
		assert a.view == b.view && a.start == b.start && a.length == b.length
		assert a.has_breaking_newline == b.has_breaking_newline
		assert a.has_breaking_tab == b.has_breaking_tab
		assert a.is_all_whitespace == b.is_all_whitespace
		assert a.can_break_after == b.can_break_after && a.text_type == b.text_type
		if rebuilt_fonts {
			// Rebuilding the chunk iterator constructs fresh platform Font owners.
			// Compare their face, public settings and metrics after invalidation;
			// a retained cache must still preserve pointer identity before it.
			assert a.font.family == b.font.family
			assert a.font.point_size == b.font.point_size
			assert a.font.weight == b.font.weight
			assert a.font.source_path == b.font.source_path
			assert a.font.is_invisible == b.font.is_invisible
			assert a.font.has_same_identity(b.font)
			assert a.font.pixel_metrics() == b.font.pixel_metrics()
		} else {
			assert voidptr(a.font) == voidptr(b.font)
		}
	}
}

fn emptycache_full_iterator(container &BlockContainer, mode LayoutMode) &InlineLevelIterator {
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(300))
	used.set_content_height(CSSPixels.new(100))
	return InlineLevelIterator.new(mut state, container, used, mode, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(300)), AvailableSize.make_definite(CSSPixels.new(100))), none)
}

fn test_empty_chunk_cache_valid_empty_skips_the_real_chunk_constructor() {
	_, _, mut text := emptycache_fixture('', '')
	initial := emptycache_enter(text, false)
	assert initial.chunks.len == 0 && text.cached_inline_chunks_ != none
	// This test-only removal is semantically harmless for an empty rendered
	// string. The actual constructor repopulates it, proving which path ran.
	text.cached_utf16_code_units_ = none
	actual := emptycache_enter(text, false)
	assert text.cached_utf16_code_units_ == none
	expected := emptycache_enter(text, true)
	assert text.cached_utf16_code_units_ != none
	emptycache_assert_same(actual, expected)
}

fn test_empty_chunk_cache_matches_previous_cold_and_warm_owned_results() {
	for declarations in ['', 'white-space-collapse:preserve', 'white-space-collapse:preserve-breaks',
		'white-space-collapse:break-spaces', 'text-wrap-mode:nowrap'] {
		for value in ['', ' ', '   ', 'one two', 'a\tb\nc\r\nd', 'Русский текст⁠⁠10',
			'á 👩‍👩‍👧‍👦 עברית'] {
			_, _, text := emptycache_fixture(value, declarations)
			expected := emptycache_enter(text, true)
			actual := emptycache_enter(text, false)
			emptycache_assert_same(actual, expected)
			for _ in 0 .. 3 { emptycache_assert_same(emptycache_enter(text, false), expected) }
		}
	}
}

fn test_empty_chunk_cache_unchanged_font_generation_reuses_chunks_and_publishes_final_generation() {
	for value in ['', 'one two'] {
		document, _, mut text := emptycache_fixture(value, '')
		_ = emptycache_enter(text, false)
		before := text.cached_font_environment_generation_
		text.cached_utf16_code_units_ = none
		mut computer := css.css_style_computer_for(document).font_computer()
		computer.did_load_font('SerenitySans')
		assert computer.environment_generation() != before
		actual := emptycache_enter(text, false)
		// The family was invalidated without changing its actual selected face.
		// Reusing chunks must not invoke the UTF-16/chunk constructor again.
		assert text.cached_utf16_code_units_ == none
		assert text.cached_font_environment_generation_ == computer.environment_generation()
		emptycache_assert_same(actual, emptycache_enter(text, true))
	}
}

fn test_empty_chunk_cache_text_invalidation_clears_empty_and_nonempty_results() {
	for initial in ['', 'before'] {
		_, _, mut text := emptycache_fixture(initial, '')
		_ = emptycache_enter(text, false)
		source := text.dom_node() or { panic('source') }
		mut data := source.as_character_data() or { panic('data') }
		for replacement in ['changed', ''] {
			data.replace_data_with_mutation_steps(0, data.data().len, replacement) or { panic(err) }
			text.invalidate_text_for_rendering()
			assert text.cached_inline_chunks_ == none
			actual := emptycache_enter(text, false)
			emptycache_assert_same(actual, emptycache_enter(text, true))
			assert actual.chunks.len == if replacement == '' { 0 } else { 1 }
		}
	}
}

fn test_empty_chunk_cache_editor_flag_transition_invalidates_a_valid_empty_result() {
	_, container, mut text := emptycache_fixture('', '')
	assert emptycache_full_iterator(container, .normal).items.len == 0
	text.is_empty_editable_ = true
	assert text.update_produces_line_box_fragment_when_empty_flag()
	assert text.cached_inline_chunks_ == none
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		items := emptycache_full_iterator(container, mode).items
		assert items.len == 1 && items[0].length_in_node == 0
	}
	text.is_empty_editable_ = false
	assert text.update_produces_line_box_fragment_when_empty_flag()
	assert emptycache_full_iterator(container, .normal).items.len == 0
}

fn test_empty_chunk_cache_keeps_generated_and_editable_synthetic_fragments() {
	for generated in [false, true] {
		_, container, mut text := emptycache_fixture('', 'white-space-collapse:preserve')
		text.retains_empty_generated_fragment_ = generated
		text.produces_line_box_fragment_when_empty_ = !generated
		for mode in [LayoutMode.normal, .intrinsic_sizing] {
			for _ in 0 .. 3 {
				items := emptycache_full_iterator(container, mode).items
				assert items.len == 1 && items[0].length_in_node == 0
				emptycache_assert_same(emptycache_enter(text, false), emptycache_enter(text, true))
			}
		}
	}
}

fn test_empty_chunk_cache_retained_chunks_survive_later_generation_and_collection() {
	for value in ['', 'one two', 'Русский текст⁠10', 'á😀'] {
		_, _, mut text := emptycache_fixture(value, '')
		retained := emptycache_enter(text, false)
		for _ in 0 .. 4 {
			_ = emptycache_enter(text, false)
			$if gcboehm ? {
				C.GC_gcollect()
			}
			emptycache_assert_same(retained, emptycache_enter(text, true))
		}
		text.invalidate_text_for_rendering()
		emptycache_assert_context(retained, emptycache_enter(text, false), true)
	}
}

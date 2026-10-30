module layout

import css
import dom
import platform

fn grapheme_cache_previous_iterator(text_node &TextNode, should_wrap_lines bool, should_respect_linebreaks bool, text_direction_mode TextDirectionMode) &TextNodeChunkIterator {
	view := text_node.text_for_rendering()
	mut mutable_text_node := unsafe { &TextNode(text_node) }
	// Rendered-text invalidation clears this cache. Chunk iterators and line
	// fragments only read its units, so repeated iterators can share them.
	code_units := if cached := text_node.cached_utf16_code_units_ {
		unsafe { cached }
	} else {
		units := utf16_code_units_for_line_box(view)
		mutable_text_node.cached_utf16_code_units_ = units
		units
	}
	font_cascade := text_node.Node.font_list()
	mut iterator := &TextNodeChunkIterator{
		text_node:              text_node
		should_wrap_lines_:     should_wrap_lines
		should_respect_breaks_: should_respect_linebreaks
		should_collapse_space_: text_node.Node.computed_values().white_space_collapse() in [
			.collapse,
			.preserve_breaks,
		]
		view:                   view
		code_units:             code_units
		grapheme_boundaries:    text_grapheme_boundaries(view)
		// No-wrap consumers still need grapheme, font and preserved-break
		// boundaries, but never query soft-wrap opportunities. In particular,
		// collecting innerText must not initialize the Unicode line segmenter.
		line_boundaries:        if should_wrap_lines {
			text_line_boundaries_from_segmenter(text_node.line_segmenter(), code_units.len)
		} else {
			[]bool{}
		}
		word_break:             text_node.Node.computed_values().word_break()
		text_direction_mode:    text_direction_mode
		font:                   text_node.font_for_rendering()
	}
	iterator.install_font_cascade(font_cascade)
	return iterator
}

fn (item &InlineLevelItem) grapheme_cache_previous_shaped_overflow(node &Node,
	boundaries []int, maximum_width CSSPixels,
	take_first_grapheme_when_none_fits bool) ?OverflowItemSplit {
	run := item.glyph_run or { return none }
	if run.text_type() == .rtl || run.glyphs_.len < 2 {
		return none
	}
	mut shaped_length := 0
	for glyph in run.glyphs_ {
		shaped_length += glyph.length_in_code_units
	}
	if shaped_length != item.length_in_node {
		return none
	}
	mut boundary_set := map[int]bool{}
	for boundary in boundaries {
		boundary_set[boundary] = true
	}
	leading_width := css_pixels_sum3(item.margin_start, item.border_start, item.padding_start)
	mut split_glyph_index := -1
	mut split_code_units := 0
	mut code_units := run.glyphs_[0].length_in_code_units
	for glyph_index := 1; glyph_index < run.glyphs_.len; glyph_index++ {
		glyph := run.glyphs_[glyph_index]
		if glyph.length_in_code_units == 0 {
			continue
		}
		offset := item.offset_in_node + code_units
		if boundary_set[offset] {
			prefix_width := CSSPixels.nearest_value_for(f64(glyph.position.x))
			if leading_width.plus(prefix_width).raw_value() > maximum_width.raw_value() {
				if split_glyph_index < 0 && take_first_grapheme_when_none_fits {
					split_glyph_index = glyph_index
					split_code_units = code_units
				}
				break
			}
			split_glyph_index = glyph_index
			split_code_units = code_units
		}
		code_units += glyph.length_in_code_units
	}
	if split_glyph_index < 0 {
		return none
	}

	split_x := run.glyphs_[split_glyph_index].position.x
	prefix_glyphs := run.glyphs_[..split_glyph_index].clone()
	mut remainder_glyphs := run.glyphs_[split_glyph_index..].clone()
	for index in 0 .. remainder_glyphs.len {
		remainder_glyphs[index].position.translate_by(-split_x, 0)
	}
	mut prefix_run := platform.GlyphRun.new_with_face(run.font(), run.text_type(), prefix_glyphs,
		run.face())
	mut remainder_run := platform.GlyphRun.new_with_face(run.font(), run.text_type(), remainder_glyphs,
		run.face())
	prefix_run.width_ = split_x
	remainder_run.width_ = run.width() - split_x
	prefix, remainder := overflow_split_items(item, node,
		item.offset_in_node + split_code_units, prefix_run, remainder_run, TrailingWhitespace{},
		TrailingWhitespace{})
	return OverflowItemSplit{prefix, remainder}
}

fn (item &InlineLevelItem) grapheme_cache_previous_overflow(maximum_width CSSPixels, take_first_grapheme_when_none_fits bool) ?(InlineLevelItem, InlineLevelItem) {
	node := item.node or { return none }
	text_node := node.as_text_node() or { return none }
	run := item.glyph_run or { return none }
	text := text_node.text_for_rendering()
	start := item.offset_in_node
	end := start + item.length_in_node
	if start < 0 || end <= start {
		return none
	}

	mut boundaries := []int{}
	for boundary in text_grapheme_boundaries(text) {
		if boundary > start && boundary < end {
			boundaries << boundary
		}
	}
	if boundaries.len == 0 {
		return none
	}
	if split := item.grapheme_cache_previous_shaped_overflow(node, boundaries, maximum_width,
		take_first_grapheme_when_none_fits) {
		return split.prefix, split.remainder
	}
	if run.text_type() == .rtl {
		return none
	}

	letter_spacing := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word_spacing := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	leading_width := css_pixels_sum3(item.margin_start, item.border_start, item.padding_start)
	mut split := -1
	for boundary in boundaries {
		prefix_text := utf16_substring_for_line_box(text, start, boundary - start)
		shaped := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, prefix_text,
			run.font(), run.text_type())
		prefix_width := CSSPixels.nearest_value_for(f64(shaped.glyph_run.width()))
		if leading_width.plus(prefix_width).raw_value() > maximum_width.raw_value() {
			break
		}
		split = boundary
	}
	if split < 0 {
		if !take_first_grapheme_when_none_fits {
			return none
		}
		split = boundaries[0]
	}

	prefix_text := utf16_substring_for_line_box(text, start, split - start)
	remainder_text := utf16_substring_for_line_box(text, split, end - split)
	prefix_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, prefix_text,
		run.font(), run.text_type())
	remainder_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
		remainder_text, run.font(), run.text_type())
	return overflow_split_items(item, node, split, prefix_shape.glyph_run,
		remainder_shape.glyph_run, trailing_whitespace_from_shaped_text(prefix_shape),
		trailing_whitespace_from_shaped_text(remainder_shape))
}

fn grapheme_cache_fixture(value string, declarations string, language string, generated bool) (&dom.Document, &BlockContainer, &TextNode) {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;${declarations}')
	element.set_attribute_value('lang', language)
	dom_text := document.create_text_node(value)
	mut element_node := element.as_node()
	element_node.append_child(dom_text.as_node()) or { panic(err) }
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut parent := BlockContainer.new(document, none, style)
	text := if generated {
		TextNode.new_generated(document, value)
	} else {
		TextNode.new(document, dom_text.as_node(), value)
	}
	parent.append_child(unsafe { &Node(text) })
	return document, parent, text
}

fn grapheme_cache_assert_chunk(a TextNodeChunk, b TextNodeChunk) {
	assert a.view == b.view && a.start == b.start && a.length == b.length
	assert a.has_breaking_newline == b.has_breaking_newline
	assert a.has_breaking_tab == b.has_breaking_tab
	assert a.is_all_whitespace == b.is_all_whitespace
	assert a.can_break_after == b.can_break_after && a.text_type == b.text_type
	assert a.font.has_same_identity(b.font)
	assert a.font.family == b.font.family && a.font.point_size == b.font.point_size
	assert a.font.weight == b.font.weight && a.font.source_path == b.font.source_path
	assert a.font.is_invisible == b.font.is_invisible
}

fn grapheme_cache_assert_iterators(mut actual TextNodeChunkIterator, mut expected TextNodeChunkIterator) {
	assert actual.view == expected.view
	assert actual.code_units == expected.code_units
	assert actual.grapheme_boundaries == expected.grapheme_boundaries
	assert actual.line_boundaries == expected.line_boundaries
	assert actual.word_break == expected.word_break
	assert actual.text_direction_mode == expected.text_direction_mode
	assert actual.should_wrap_lines_ == expected.should_wrap_lines_
	assert actual.should_respect_breaks_ == expected.should_respect_breaks_
	assert actual.should_collapse_space_ == expected.should_collapse_space_
	for {
		a := actual.next()
		b := expected.next()
		if chunk := a {
			grapheme_cache_assert_chunk(chunk, b or { panic('legacy exhausted') })
		} else {
			assert b == none
			break
		}
		assert actual.current_index == expected.current_index
		assert actual.grapheme_boundary_index == expected.grapheme_boundary_index
	}
}

fn test_full_node_grapheme_cache_matches_entire_previous_constructor_and_chunks() {
	inputs := ['', 'one   two', 'A\r\nB\tC\nD', 'Привет, мир!⁠⁠10',
		'ab áb 👩‍👩‍👧‍👦 🇦🇺 中文 אבג', '\u0600\nA', '\u0600\u2060',
		' \u0301A \u200dB \ufe0fC', '각 क्‍ष', 'A\u2028\u2029B',
		[u8(0xff), 0xed, 0xa0, 0x80, 0xf0, 0x9f, 0x41].bytestr()]
	for whitespace in ['collapse', 'preserve', 'preserve-breaks', 'break-spaces'] {
		for input in inputs {
			_, _, text := grapheme_cache_fixture(input, 'white-space-collapse:${whitespace}', '', false)
			assert text.cached_grapheme_boundaries_.len == 0
			for direction in [TextDirectionMode.per_code_point, .unidirectional_left_to_right] {
				for wrap in [false, true] {
					for respect in [false, true] {
						mut actual := TextNodeChunkIterator.new_with_direction(text, wrap, respect, direction)
						mut expected := grapheme_cache_previous_iterator(text, wrap, respect, direction)
						grapheme_cache_assert_iterators(mut actual, mut expected)
					}
				}
			}
			assert text.cached_grapheme_boundaries_ == text_grapheme_boundaries(text.text_for_rendering())
		}
	}
}

fn test_full_node_grapheme_cache_is_lazy_empty_valid_and_shared_across_wrap_modes() {
	for value in ['', 'ASCII text', 'Русский⁠⁠2', 'Á😀👩‍💻'] {
		_, _, text := grapheme_cache_fixture(value, '', '', true)
		_ = text.text_for_rendering()
		_ = collect_dom_rendered_text(text)
		assert text.cached_grapheme_boundaries_.len == 0
		first := TextNodeChunkIterator.new(text, false, false)
		assert first.grapheme_boundaries.len > 0
		for wrap in [true, false, true] {
			second := TextNodeChunkIterator.new(text, wrap, true)
			gc_collect()
			assert second.grapheme_boundaries == first.grapheme_boundaries
			assert voidptr(second.grapheme_boundaries.data) == voidptr(first.grapheme_boundaries.data)
			assert voidptr(text.cached_grapheme_boundaries_.data) == voidptr(first.grapheme_boundaries.data)
		}
		if value == '' {
			assert first.grapheme_boundaries == [0]
		}
	}
}

fn test_full_node_grapheme_cache_invalidation_detaches_retained_iterator_and_dom_updates() {
	_, _, mut text := grapheme_cache_fixture('Á😀B', '', '', false)
	mut retained := TextNodeChunkIterator.new(text, true, true)
	original := retained.grapheme_boundaries.clone()
	source := text.dom_node() or { panic('source') }
	mut data := source.as_character_data() or { panic('data') }
	for replacement in ['אבג 👩‍👩‍👧‍👦', '', 'а\u0483б⁠10',
		[u8(0xff), 0x41].bytestr()] {
		data.replace_data_with_mutation_steps(0, data.data().len, replacement) or { panic(err) }
		text.invalidate_text_for_rendering()
		assert text.cached_grapheme_boundaries_.len == 0
		mut actual := TextNodeChunkIterator.new(text, false, false)
		mut expected := grapheme_cache_previous_iterator(text, false, false, .per_code_point)
		assert voidptr(actual.grapheme_boundaries.data) != voidptr(retained.grapheme_boundaries.data)
		grapheme_cache_assert_iterators(mut actual, mut expected)
		for _ in 0 .. 3 { gc_collect() }
		assert retained.grapheme_boundaries == original
	}
	_, _, original_text := grapheme_cache_fixture('Á😀B', '', '', true)
	mut expected_retained := grapheme_cache_previous_iterator(original_text, true, true, .per_code_point)
	grapheme_cache_assert_iterators(mut retained, mut expected_retained)
}

fn test_full_node_grapheme_cache_font_generation_only_reuses_boundaries_and_rebuilds_context() {
	for input in ['', 'Русский⁠⁠2 Á👩‍💻', 'abc אבג'] {
		document, _, text := grapheme_cache_fixture(input, 'white-space-collapse:preserve', '', true)
		mut first := InlineLevelIterator{}
		first.enter_text_node(text)
		boundaries := unsafe { text.cached_grapheme_boundaries_ }
		before := text.cached_font_environment_generation_
		mut computer := css.css_style_computer_for(document).font_computer()
		computer.did_load_font('SerenitySans')
		assert computer.environment_generation() != before
		mut second := InlineLevelIterator{}
		second.enter_text_node(text)
		assert text.cached_font_environment_generation_ == computer.environment_generation()
		assert voidptr(boundaries.data) == voidptr(text.cached_grapheme_boundaries_.data)
		mut expected := grapheme_cache_previous_iterator(text, true, true, .per_code_point)
		mut expected_chunks := []TextNodeChunk{}
		for { expected_chunks << expected.next() or { break } }
		// Generated empty text deliberately synthesizes one empty chunk.
		if expected_chunks.len == 0 && input == '' {
			expected_chunks << expected.create_empty_chunk()
		}
		assert second.text_node_context.chunks.len == expected_chunks.len
		for i, chunk in second.text_node_context.chunks {
			grapheme_cache_assert_chunk(chunk, expected_chunks[i])
		}
	}
}

fn test_full_node_grapheme_cache_transforms_language_password_generated_and_ranges() {
	for generated in [false, true] {
		for transform in ['none', 'uppercase', 'lowercase', 'capitalize', 'math-auto'] {
			for language in ['', 'tr', 'el'] {
				_, _, mut text := grapheme_cache_fixture('I ı ß ΟΣ Á😀', 'text-transform:${transform}', language, generated)
				for start in [0, 1, 4] {
					text.source_range_start_ = start
					text.source_range_length_ = if start == 0 { none } else { ?int(3) }
					text.invalidate_text_for_rendering()
					mut actual := TextNodeChunkIterator.new(text, true, false)
					mut expected := grapheme_cache_previous_iterator(text, true, false, .per_code_point)
					grapheme_cache_assert_iterators(mut actual, mut expected)
				}
			}
		}
	}
	_, _, mut password := grapheme_cache_fixture('A😀á', 'text-transform:uppercase', '', false)
	source := password.dom_node() or { panic('password source') }
	mut dom_text := unsafe { &dom.Text(source) }
	for enabled in [false, true, false] {
		dom_text.set_is_password_input(enabled)
		password.invalidate_text_for_rendering()
		mut actual := TextNodeChunkIterator.new(password, true, false)
		mut expected := grapheme_cache_previous_iterator(password, true, false, .per_code_point)
		if enabled {
			assert actual.view == '●●●●'
		}
		grapheme_cache_assert_iterators(mut actual, mut expected)
	}
}

fn grapheme_cache_assert_item(actual InlineLevelItem, expected InlineLevelItem) {
	assert InlineLevelItem{ ...actual, glyph_run: none } == InlineLevelItem{ ...expected, glyph_run: none }
	mut a := actual.glyph_run or { panic('actual run') }
	mut b := expected.glyph_run or { panic('legacy run') }
	// Layout slices defer packed replay buffers until line publication. Compare
	// both completed runs rather than requiring the old eager allocation timing.
	a.refresh_replay_data()
	b.refresh_replay_data()
	assert a.font().has_same_identity(b.font())
	assert a.text_type() == b.text_type() && a.face() == b.face()
	assert a.width() == b.width() && a.space_width == b.space_width
	assert a.glyphs() == b.glyphs()
	assert a.glyph_indices() == b.glyph_indices()
	assert a.glyph_positions() == b.glyph_positions()
	assert a.bounding_box() == b.bounding_box()
}

fn grapheme_cache_split(item &InlineLevelItem, width CSSPixels, take_first bool, legacy bool) ?OverflowItemSplit {
	if legacy {
		prefix, remainder := item.grapheme_cache_previous_overflow(width, take_first) or { return none }
		return OverflowItemSplit{prefix, remainder}
	}
	prefix, remainder := item.split_for_overflow_break(width, take_first) or { return none }
	return OverflowItemSplit{prefix, remainder}
}

fn test_full_node_grapheme_cache_overflow_matches_old_full_context_and_glyph_ranges() {
	for value in ['abcádefghij', 'אבדגהוזחטיכלמנס', 'ab👩‍👩‍👧‍👦cdef',
		'🇦🇺🇷🇺abcdefgh', '\u0600abcdef', 'a\r\nbcdefgh'] {
		_, _, text := grapheme_cache_fixture(value, 'white-space:pre-wrap;overflow-wrap:anywhere', '', true)
		for direction in [platform.GlyphRunTextType.ltr, .rtl] {
			for start in [0, 1] {
				units := utf16_code_units_for_line_box(text.text_for_rendering())
				part := utf16_substring_for_line_box(text.text_for_rendering(), start, units.len - start)
				run := platform.shape_text_with_spacing(0, 0, 0, part, text.font_for_rendering(), direction).glyph_run
				item := InlineLevelItem{
					type_:                                     .text
					node:                                      unsafe { &Node(text) }
					glyph_run:                                 run
					offset_in_node:                            start
					length_in_node:                            units.len - start
					can_break_before:                          true
					preceded_by_unattached_inline_start_edges: true
					width:                                     CSSPixels.nearest_value_for(f64(run.width()))
					padding_start:                             CSSPixels.new(1)
					padding_end:                               CSSPixels.new(2)
					border_start:                              CSSPixels.new(3)
					border_end:                                CSSPixels.new(4)
					margin_start:                              CSSPixels.new(5)
					margin_end:                                CSSPixels.new(6)
				}
				for width in [0, 12, 40, 1000] {
					for take_first in [false, true] {
						actual := grapheme_cache_split(item, CSSPixels.new(width), take_first, false)
						expected := grapheme_cache_split(item, CSSPixels.new(width), take_first, true)
						if a := actual {
							b := expected or { panic('legacy split missing') }
							grapheme_cache_assert_item(a.prefix, b.prefix)
							grapheme_cache_assert_item(a.remainder, b.remainder)
							assert a.prefix.offset_in_node + a.prefix.length_in_node in text_grapheme_boundaries(text.text_for_rendering())
						} else {
							assert expected == none
						}
					}
				}
			}
		}
	}
}

// Compare to the old linear filter and map membership, including duplicate
// entries, absent endpoints, empty intervals and UTF-16 grapheme positions.
fn test_overflow_boundary_binary_lookup_matches_linear_filter_and_membership() {
	mut vectors := [[]int{}, [0], [0, 0, 1, 1, 4, 4, 8],
		text_grapheme_boundaries('Á😀👩‍👩‍👧‍👦🇦🇺B')]
	for mask in 0 .. 256 {
		mut boundaries := []int{}
		for index in 0 .. 8 {
			if mask & (1 << index) != 0 { boundaries << index }
		}
		vectors << boundaries
	}
	for boundaries in vectors {
		for start in -2 .. 26 {
			assert has_sorted_grapheme_boundary(boundaries, start) == (start in boundaries)
			for end in -2 .. 26 {
				mut expected := []int{}
				for boundary in boundaries {
					if boundary > start && boundary < end { expected << boundary }
				}
				actual := grapheme_boundaries_between(boundaries, start, end)
				assert actual == expected
			}
		}
	}
}

fn grapheme_cache_inner_boundary_view(text &TextNode) []int {
	boundaries := text.grapheme_boundaries_for_rendered_text()
	view := grapheme_boundaries_between(boundaries, 0, boundaries.last())
	assert view.len > 0
	expected_view := boundaries[1..boundaries.len - 1]
	assert voidptr(view.data) == voidptr(expected_view.data)
	return view
}

fn test_overflow_boundary_slice_retains_cached_vector_after_text_invalidation() {
	_, _, mut text := grapheme_cache_fixture('Á😀👩‍💻B', '', '', false)
	view := grapheme_cache_inner_boundary_view(text)
	expected := view.clone()
	source := text.dom_node() or { panic('source') }
	mut data := source.as_character_data() or { panic('data') }
	for replacement in ['אבג', '', 'áb😀c'] {
		data.replace_data_with_mutation_steps(0, data.data().len, replacement) or { panic(err) }
		text.invalidate_text_for_rendering()
		current := text.grapheme_boundaries_for_rendered_text()
		assert current == text_grapheme_boundaries(text.text_for_rendering())
		for _ in 0 .. 3 { gc_collect() }
		assert view == expected
	}
}

fn test_overflow_boundary_lookup_matches_every_successive_shaped_split() {
	for value in ['abcdefghijklmno'.repeat(4), 'Á😀👩‍💻ab🇦🇺cdef',
		'office affine ffi fi fl', 'abc אבג def'] {
		_, _, text := grapheme_cache_fixture(value, 'white-space:pre-wrap;overflow-wrap:anywhere', '', true)
		units := utf16_code_units_for_line_box(text.text_for_rendering())
		run := platform.shape_text_with_spacing(0, 0, 0, text.text_for_rendering(),
			text.font_for_rendering(), .ltr).glyph_run
		for width in [0, 12, 40] {
			mut item := InlineLevelItem{
				type_:          .text
				node:           unsafe { &Node(text) }
				glyph_run:      run
				length_in_node: units.len
				width:          CSSPixels.nearest_value_for(f64(run.width()))
				padding_start:  CSSPixels.new(1)
				padding_end:    CSSPixels.new(2)
				border_start:   CSSPixels.new(3)
				border_end:     CSSPixels.new(4)
				margin_start:   CSSPixels.new(5)
				margin_end:     CSSPixels.new(6)
			}
			mut splits := 0
			for {
				actual := grapheme_cache_split(item, CSSPixels.new(width), true, false)
				expected := grapheme_cache_split(item, CSSPixels.new(width), true, true)
				if a := actual {
					b := expected or { panic('legacy split missing') }
					grapheme_cache_assert_item(a.prefix, b.prefix)
					grapheme_cache_assert_item(a.remainder, b.remainder)
					assert a.prefix.length_in_node > 0
					assert a.remainder.offset_in_node > item.offset_in_node
					assert a.remainder.offset_in_node + a.remainder.length_in_node == units.len
					item = a.remainder
					splits++
					assert splits < units.len
				} else {
					assert expected == none
					break
				}
			}
			assert splits > 0
		}
	}
}

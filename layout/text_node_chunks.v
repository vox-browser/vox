// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform

// TextNode::Chunk and TextNode::ChunkIterator split rendered text at font,
// bidi, whitespace, preserved-break and soft-wrap boundaries. Offsets and
// lengths are UTF-16 code units, matching DOM Range and LineBoxFragment.
pub struct TextNodeChunk {
pub:
	view                 string
	font                 &platform.Font = unsafe { nil }
	start                int
	length               int
	has_breaking_newline bool
	has_breaking_tab     bool
	is_all_whitespace    bool
	can_break_after      bool
	text_type            platform.GlyphRunTextType
}

@[heap]
pub struct TextNodeChunkIterator {
	text_node              &TextNode = unsafe { nil }
	should_wrap_lines_     bool
	should_respect_breaks_ bool
	should_collapse_space_ bool
	view                   string
	code_units             []u16
	grapheme_boundaries    []int
	line_boundaries        map[int]bool
	word_break             css.WordBreak
	font                   &platform.Font = unsafe { nil }
	font_cascade_fonts     []&platform.Font
	font_cascade_ranges    [][]css.UnicodeRange
	last_resort_font       ?&platform.Font
pub mut:
	current_index            int
	peek_queue               []TextNodeChunk
	last_non_whitespace_font ?&platform.Font
}

fn text_node_chunk_platform_font(font css.PlatformFont) &platform.Font {
	return &platform.Font{
		family: font.typeface.family_name
		point_size: font.point_size / 0.75
		weight: int(font.variations.weight)
	}
}

pub fn TextNodeChunkIterator.new(text_node &TextNode, should_wrap_lines bool, should_respect_linebreaks bool) &TextNodeChunkIterator {
	view := text_node.text_for_rendering()
	font_cascade := text_node.Node.computed_values().font_list()
	mut font_cascade_fonts := []&platform.Font{cap: font_cascade.fonts.len}
	mut font_cascade_ranges := [][]css.UnicodeRange{cap: font_cascade.fonts.len}
	for entry in font_cascade.fonts {
		font_cascade_fonts << text_node_chunk_platform_font(entry.font)
		font_cascade_ranges << entry.unicode_ranges.clone()
	}
	mut last_resort_font := ?&platform.Font(none)
	if font := font_cascade.last_resort_font {
		last_resort_font = text_node_chunk_platform_font(font)
	}
	return &TextNodeChunkIterator{
		text_node: text_node
		should_wrap_lines_: should_wrap_lines
		should_respect_breaks_: should_respect_linebreaks
		should_collapse_space_: text_node.Node.computed_values().white_space_collapse() in [
			.collapse,
			.preserve_breaks,
		]
		view: view
		code_units: utf16_code_units_for_line_box(view)
		grapheme_boundaries: text_grapheme_boundaries(view)
		line_boundaries: text_line_boundaries(view)
		word_break: text_node.Node.computed_values().word_break()
		font: text_node.font_for_rendering()
		font_cascade_fonts: font_cascade_fonts
		font_cascade_ranges: font_cascade_ranges
		last_resort_font: last_resort_font
	}
}

pub fn (iterator &TextNodeChunkIterator) should_wrap_lines() bool {
	return iterator.should_wrap_lines_
}

pub fn (iterator &TextNodeChunkIterator) should_respect_linebreaks() bool {
	return iterator.should_respect_breaks_
}

pub fn (iterator &TextNodeChunkIterator) should_collapse_whitespace() bool {
	return iterator.should_collapse_space_
}

pub fn (mut iterator TextNodeChunkIterator) next() ?TextNodeChunk {
	if iterator.peek_queue.len > 0 {
		chunk := iterator.peek_queue[0]
		iterator.peek_queue.delete(0)
		return chunk
	}
	return iterator.next_without_peek()
}

pub fn (mut iterator TextNodeChunkIterator) peek(count int) ?TextNodeChunk {
	for iterator.peek_queue.len <= count {
		next := iterator.next_without_peek() or { return none }
		iterator.peek_queue << next
	}
	return iterator.peek_queue[count]
}

pub fn (iterator &TextNodeChunkIterator) create_empty_chunk() TextNodeChunk {
	return TextNodeChunk{
		font: iterator.font
		is_all_whitespace: true
		text_type: .common
	}
}

fn (iterator &TextNodeChunkIterator) next_grapheme_boundary() int {
	for boundary in iterator.grapheme_boundaries {
		if boundary > iterator.current_index {
			return boundary
		}
	}
	return iterator.code_units.len
}

fn (iterator &TextNodeChunkIterator) is_at_line_break_opportunity() bool {
	if !iterator.should_wrap_lines_ {
		return false
	}
	if iterator.word_break == .break_all {
		if iterator.current_index > 0 && iterator.current_index < iterator.code_units.len {
			previous := code_point_before_utf16(iterator.code_units, iterator.current_index)
			current := code_point_at_utf16(iterator.code_units, iterator.current_index)
			if is_typographic_letter_unit(previous) && is_typographic_letter_unit(current) {
				return true
			}
		}
	}
	if iterator.word_break == .keep_all {
		if iterator.current_index > 0 && iterator.current_index < iterator.code_units.len {
			previous := code_point_before_utf16(iterator.code_units, iterator.current_index)
			current := code_point_at_utf16(iterator.code_units, iterator.current_index)
			if is_keep_all_unit(previous) && is_keep_all_unit(current) {
				return false
			}
		}
	}
	return iterator.current_index in iterator.line_boundaries
}

fn (iterator &TextNodeChunkIterator) font_for_code_point(code_point u32) &platform.Font {
	for index, font in iterator.font_cascade_fonts {
		ranges := iterator.font_cascade_ranges[index]
		if ranges.len == 0 {
			return font
		}
		for range_ in ranges {
			if range_.start <= code_point && code_point <= range_.end {
				return font
			}
		}
	}
	return iterator.last_resort_font or { iterator.font }
}

pub fn (iterator &TextNodeChunkIterator) font_for_space(at_index int) &platform.Font {
	if font := iterator.last_non_whitespace_font {
		if !font.is_emoji_font() {
			return font
		}
	}

	mut index := at_index
	for index < iterator.code_units.len {
		code_point := code_point_at_utf16(iterator.code_units, index)
		if !is_interword_space(code_point) && code_point != u32(`\t`)
			&& code_point != u32(`\n`) {
			font := iterator.font_for_code_point(code_point)
			if !font.is_emoji_font() {
				return font
			}
			break
		}
		index += utf16_code_point_length(code_point)
	}

	for font in iterator.font_cascade_fonts {
		if !font.is_emoji_font() {
			return font
		}
	}
	if font := iterator.last_resort_font {
		if !font.is_emoji_font() {
			return font
		}
	}
	return iterator.font
}

fn (mut iterator TextNodeChunkIterator) next_without_peek() ?TextNodeChunk {
	if iterator.current_index >= iterator.code_units.len {
		return none
	}
	mut code_point := code_point_at_utf16(iterator.code_units, iterator.current_index)
	mut can_break_at_current_position := iterator.is_at_line_break_opportunity()
	start_of_chunk := iterator.current_index
	font := if is_interword_space(code_point) {
		iterator.font_for_space(iterator.current_index)
	} else {
		iterator.font_for_code_point(code_point)
	}
	text_type := text_type_for_code_point(code_point)
	mut broken_on_tab := false

	for iterator.current_index < iterator.code_units.len {
		code_point = code_point_at_utf16(iterator.code_units, iterator.current_index)
		expected_font := if is_interword_space(code_point) {
			iterator.font_for_space(iterator.current_index)
		} else {
			iterator.font_for_code_point(code_point)
		}
		if voidptr(font) != voidptr(expected_font) {
			if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, can_break_at_current_position, font, text_type) {
				return chunk
			}
		}
		if code_point == u32(`\t`) {
			if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, font, text_type) {
				return chunk
			}
			broken_on_tab = true
			for iterator.current_index < iterator.code_units.len
				&& code_point_at_utf16(iterator.code_units, iterator.current_index) == u32(`\t`) {
				iterator.current_index = iterator.next_grapheme_boundary()
			}
			can_break_at_current_position = iterator.is_at_line_break_opportunity()
		}

		if iterator.should_respect_breaks_ && code_point == u32(`\n`) {
			if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, font, text_type) {
				return chunk
			}
			iterator.current_index = iterator.next_grapheme_boundary()
			return iterator.try_commit_chunk(start_of_chunk, iterator.current_index, true, broken_on_tab, false, font, text_type)
		}

		if iterator.is_collapsible(code_point) && iterator.current_index > 0
			&& iterator.is_collapsible(code_point_before_utf16(iterator.code_units, iterator.current_index)) {
			result := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, font, text_type)
			for iterator.current_index < iterator.code_units.len
				&& iterator.is_collapsible(code_point_at_utf16(iterator.code_units, iterator.current_index)) {
				iterator.current_index = iterator.next_grapheme_boundary()
			}
			if chunk := result {
				return chunk
			}
			return iterator.next_without_peek()
		}

		if iterator.should_wrap_lines_ {
			if text_type != text_type_for_code_point(code_point) {
				if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, can_break_at_current_position, font, text_type) {
					return chunk
				}
			}
			if is_ascii_space_code_point(code_point) {
				if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, font, text_type) {
					return chunk
				}
				iterator.current_index = iterator.next_grapheme_boundary()
				can_break_at_current_position = iterator.is_at_line_break_opportunity()
				space_font := iterator.font_for_space(iterator.current_index)
				if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, space_font, text_type) {
					return chunk
				}
				continue
			}
			if can_break_at_current_position {
				if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, true, font, text_type) {
					return chunk
				}
			}
		}

		iterator.current_index = iterator.next_grapheme_boundary()
		can_break_at_current_position = iterator.is_at_line_break_opportunity()
	}

	if start_of_chunk != iterator.code_units.len {
		return iterator.try_commit_chunk(start_of_chunk, iterator.code_units.len, false, broken_on_tab, false, font, text_type)
	}
	return none
}

fn (iterator &TextNodeChunkIterator) is_collapsible(code_point u32) bool {
	return iterator.should_collapse_space_ && is_ascii_space_code_point(code_point)
}

fn (mut iterator TextNodeChunkIterator) try_commit_chunk(start int, end int, has_breaking_newline bool, has_breaking_tab bool, can_break_after bool, font &platform.Font, text_type platform.GlyphRunTextType) ?TextNodeChunk {
	length := end - start
	if length <= 0 {
		return none
	}
	view := utf16_substring_for_line_box(iterator.view, start, length)
	is_all_whitespace := string_is_ascii_whitespace(view)
	if !is_all_whitespace {
		iterator.last_non_whitespace_font = font
	}
	return TextNodeChunk{
		view: view
		font: font
		start: start
		length: length
		has_breaking_newline: has_breaking_newline
		has_breaking_tab: has_breaking_tab
		is_all_whitespace: is_all_whitespace
		can_break_after: can_break_after
		text_type: text_type
	}
}

fn text_grapheme_boundaries(text string) []int {
	mut boundaries := []int{cap: text.runes().len + 1}
	boundaries << 0
	mut offset := 0
	for grapheme in text.graphemes() {
		offset += utf16_code_units_for_line_box(grapheme).len
		boundaries << offset
	}
	return boundaries
}

fn text_line_boundaries(text string) map[int]bool {
	units := utf16_code_units_for_line_box(text)
	mut boundaries := map[int]bool{}
	mut index := 0
	for index < units.len {
		code_point := code_point_at_utf16(units, index)
		step := utf16_code_point_length(code_point)
		next := index + step
		if is_ascii_space_code_point(code_point) || code_point == u32(`-`) || code_point == 0x200b
			|| code_point == u32(`\n`) {
			boundaries[next] = true
		}
		if next < units.len && is_cjk_code_point(code_point)
			&& is_cjk_code_point(code_point_at_utf16(units, next)) {
			boundaries[next] = true
		}
		index = next
	}
	return boundaries
}

fn text_type_for_code_point(code_point u32) platform.GlyphRunTextType {
	if is_interword_space(code_point) {
		return .context_dependent
	}
	if (code_point >= 0x0590 && code_point <= 0x08ff)
		|| (code_point >= 0xfb1d && code_point <= 0xfdff)
		|| (code_point >= 0xfe70 && code_point <= 0xfeff) {
		return .rtl
	}
	if (code_point >= u32(`A`) && code_point <= u32(`Z`)) || (code_point >= u32(`a`)
		&& code_point <= u32(`z`)) || code_point >= 0x80 {
		return .ltr
	}
	if is_ascii_space_code_point(code_point) || (code_point >= u32(`0`) && code_point <= u32(`9`)) {
		return .context_dependent
	}
	return .common
}

fn is_interword_space(code_point u32) bool {
	return code_point == 0x0020 || code_point == 0x00a0
}

fn is_typographic_letter_unit(code_point u32) bool {
	return (code_point >= u32(`0`) && code_point <= u32(`9`))
		|| (code_point >= u32(`A`) && code_point <= u32(`Z`))
		|| (code_point >= u32(`a`) && code_point <= u32(`z`))
		|| is_cjk_code_point(code_point)
}

fn is_keep_all_unit(code_point u32) bool {
	return is_typographic_letter_unit(code_point) || code_point >= 0x80
}

fn is_cjk_code_point(code_point u32) bool {
	return (code_point >= 0x2e80 && code_point <= 0x9fff)
		|| (code_point >= 0xac00 && code_point <= 0xd7af)
		|| (code_point >= 0xf900 && code_point <= 0xfaff)
}

fn is_ascii_space_code_point(code_point u32) bool {
	return code_point in [u32(0x09), 0x0a, 0x0b, 0x0c, 0x0d, 0x20]
}

fn string_is_ascii_whitespace(text string) bool {
	if text == '' {
		return false
	}
	for character in text.runes() {
		if !is_ascii_space_code_point(u32(character)) {
			return false
		}
	}
	return true
}

fn utf16_code_point_length(code_point u32) int {
	return if code_point > 0xffff { 2 } else { 1 }
}

fn code_point_at_utf16(units []u16, index int) u32 {
	if index < 0 || index >= units.len {
		return 0
	}
	first := units[index]
	if first >= 0xd800 && first <= 0xdbff && index + 1 < units.len {
		second := units[index + 1]
		if second >= 0xdc00 && second <= 0xdfff {
			return 0x10000 + ((u32(first) - 0xd800) << 10) + (u32(second) - 0xdc00)
		}
	}
	return u32(first)
}

fn code_point_before_utf16(units []u16, index int) u32 {
	if index <= 0 || units.len == 0 {
		return 0
	}
	mut previous := index - 1
	if units[previous] >= 0xdc00 && units[previous] <= 0xdfff && previous > 0
		&& units[previous - 1] >= 0xd800 && units[previous - 1] <= 0xdbff {
		previous--
	}
	return code_point_at_utf16(units, previous)
}

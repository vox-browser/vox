// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import platform
import math

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

enum TextDirectionMode {
	per_code_point
	unidirectional_left_to_right
}

// Invisible fallbacks and synthesized caps need derived fonts. Ordinary text
// retains no empty map or map backing storage.
@[heap]
struct InvisibleFontSelectionStorage {
mut:
	values map[string]&platform.Font
}

@[heap]
pub struct TextNodeChunkIterator {
	text_node              &TextNode = unsafe { nil }
	should_wrap_lines_     bool
	should_respect_breaks_ bool
	should_collapse_space_ bool
	// Blink collapses spaces across element boundaries and removes them at
	// line starts in non-wrapping text too, which needs separate space items.
	splits_unwrapped_spaces_ bool
	view                   string
	code_units             []u16
	grapheme_boundaries    []int
	line_boundaries        []bool
	word_break             css.WordBreak
	text_direction_mode    TextDirectionMode
	font                   &platform.Font = unsafe { nil }
	font_variant_caps      css.FontVariantCaps
mut:
	font_cascade_list      &css.FontCascadeList = unsafe { nil }
	font_cascade_fonts     []&platform.Font
	font_cascade_ranges    [][]css.UnicodeRange
	last_resort_font       ?&platform.Font
	selected_font_storage_ &InvisibleFontSelectionStorage = unsafe { nil }
	retain_selected_fonts_ bool
pub mut:
	current_index            int
	grapheme_boundary_index  int = 1
	peek_queue               []TextNodeChunk
	last_non_whitespace_font ?&platform.Font
}

fn text_node_chunk_platform_font(font &css.PlatformFont) &platform.Font {
	return font.font_for_rendering()
}

fn text_node_chunk_invisible_font(font &platform.Font) &platform.Font {
	return &platform.Font{
		family:       font.family.clone()
		point_size: font.point_size
		weight: font.weight
		source_path:  font.source_path.clone()
		is_invisible: true
		font_rendering_policy: font.font_rendering_policy
		synthesize_ascii_caps: font.synthesize_ascii_caps
		system_face_override: font.system_face_override
	}
}

fn (mut iterator TextNodeChunkIterator) install_font_cascade(font_cascade &css.FontCascadeList) {
	iterator.font_cascade_list = font_cascade
	iterator.font_cascade_fonts = []&platform.Font{cap: font_cascade.fonts.len}
	iterator.font_cascade_ranges = [][]css.UnicodeRange{cap: font_cascade.fonts.len}
	for index in 0 .. font_cascade.fonts.len {
		iterator.font_cascade_fonts << text_node_chunk_platform_font(&font_cascade.fonts[index].font)
		iterator.font_cascade_ranges << font_cascade.fonts[index].unicode_ranges.clone()
	}
	iterator.last_resort_font = none
	if font_cascade.last_resort_font != unsafe { nil } {
		last_resort := text_node_chunk_platform_font(font_cascade.last_resort_font)
		// FontCascadeList retains its last-resort font by reference. Reuse the
		// matching translated cascade object as well, so a missing glyph followed
		// by covered glyphs from that same face stays one shaped fragment.
		for font in iterator.font_cascade_fonts {
			if font.has_same_identity(last_resort) {
				iterator.last_resort_font = font
				return
			}
		}
		iterator.last_resort_font = last_resort
	}
}

pub fn TextNodeChunkIterator.new(text_node &TextNode, should_wrap_lines bool, should_respect_linebreaks bool) &TextNodeChunkIterator {
	return TextNodeChunkIterator.new_with_direction(text_node, should_wrap_lines,
		should_respect_linebreaks, .per_code_point)
}

fn TextNodeChunkIterator.new_with_direction(text_node &TextNode, should_wrap_lines bool, should_respect_linebreaks bool, text_direction_mode TextDirectionMode) &TextNodeChunkIterator {
	view := text_node.text_for_rendering()
	mut mutable_text_node := unsafe { &TextNode(text_node) }
	// Rendered-text invalidation clears this cache. Chunk iterators and line
	// fragments only read its units, so repeated iterators can share them.
	code_units := if cached := text_node.cached_utf16_code_units_ {
		unsafe { cached }
	} else {
		use_document := cache_uses_entered_document_storage(text_node.Node.document())
		mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		persistent := platform.enter_persistent_if(!use_document)
		units := utf16_code_units_for_line_box(view)
		mutable_text_node.cached_utf16_code_units_ = units
		platform.leave_persistent(persistent)
		retained.finish()
		units
	}
	mut line_boundaries := if should_wrap_lines {
		text_line_boundaries_from_segmenter(text_node.line_segmenter(), code_units.len)
	} else {
		[]bool{}
	}
	font_cascade, rendering_font := chunk_iterator_rendering_fonts(text_node)
	if text_node.Node.document().font_rendering_policy() == .chromium {
		apply_chromium_ascii_line_breaks(code_units, mut line_boundaries)
	}
	mut iterator := &TextNodeChunkIterator{
		text_node: text_node
		should_wrap_lines_: should_wrap_lines
		should_respect_breaks_: should_respect_linebreaks
		should_collapse_space_: text_node.Node.computed_values().white_space_collapse() in [
			.collapse,
			.preserve_breaks,
		]
		splits_unwrapped_spaces_: !should_wrap_lines
			&& text_node.Node.document().font_rendering_policy() == .chromium
		view: view
		code_units: code_units
		grapheme_boundaries: text_node.grapheme_boundaries_for_rendered_text()
		// No-wrap consumers still need grapheme, font and preserved-break
		// boundaries, but never query soft-wrap opportunities. In particular,
		// collecting innerText must not initialize the Unicode line segmenter.
		line_boundaries: line_boundaries
		word_break: text_node.Node.computed_values().word_break()
		text_direction_mode: text_direction_mode
		font: rendering_font
		font_variant_caps: text_node.Node.computed_values().font_variant_caps()
	}
	iterator.install_font_cascade(font_cascade)
	return iterator
}

// Cache only this node's complete rendered text. Fragment and first-letter
// substring segmentation continues to use text_grapheme_boundaries directly.
// Consumers only read this vector; rendered-text invalidation replaces it.
fn (node &TextNode) grapheme_boundaries_for_rendered_text() []int {
	text := node.text_for_rendering()
	if node.cached_grapheme_boundaries_.len > 0 {
		return unsafe { node.cached_grapheme_boundaries_ }
	}
	use_document := cache_uses_entered_document_storage(node.Node.document())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	persistent := platform.enter_persistent_if(!use_document)
	boundaries := text_grapheme_boundaries(text)
	platform.leave_persistent(persistent)
	retained.finish()
	mut mutable_node := unsafe { &TextNode(node) }
	mutable_node.cached_grapheme_boundaries_ = boundaries
	return boundaries
}

fn (iterator &TextNodeChunkIterator) current_text_type() platform.GlyphRunTextType {
	if iterator.text_direction_mode == .unidirectional_left_to_right {
		return .ltr
	}
	return text_type_for_code_point(code_point_at_utf16(iterator.code_units,
		iterator.current_index))
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

fn (mut iterator TextNodeChunkIterator) next_grapheme_boundary() int {
	for iterator.grapheme_boundary_index < iterator.grapheme_boundaries.len
		&& iterator.grapheme_boundaries[iterator.grapheme_boundary_index] <= iterator.current_index {
		iterator.grapheme_boundary_index++
	}
	if iterator.grapheme_boundary_index < iterator.grapheme_boundaries.len {
		return iterator.grapheme_boundaries[iterator.grapheme_boundary_index]
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
	return iterator.current_index >= 0 && iterator.current_index < iterator.line_boundaries.len
		&& iterator.line_boundaries[iterator.current_index]
}

fn (mut iterator TextNodeChunkIterator) font_for_code_point(code_point u32) &platform.Font {
	if iterator.font_cascade_list == unsafe { nil } && iterator.font_cascade_fonts.len == 0 {
		return iterator.synthetic_caps_font_for(iterator.font, code_point)
	}
	mut selected := iterator.last_resort_font or { iterator.font }
	mut selected_index := iterator.font_cascade_fonts.len
	for index, font in iterator.font_cascade_fonts {
		ranges := iterator.font_cascade_ranges[index]
		if ranges.len == 0 && font.contains_glyph(code_point) {
			selected = font
			selected_index = index
			break
		}
		for range_ in ranges {
			if range_.start <= code_point && code_point <= range_.end
				&& font.contains_glyph(code_point) {
				selected = font
				selected_index = index
				break
			}
		}
		if selected_index == index {
			break
		}
	}
	if selected_index == iterator.font_cascade_fonts.len {
		if fallback := iterator.system_fallback_font(code_point) {
			return fallback
		}
	}
	// An empty pending list cannot load a face or make this fallback invisible.
	// Keep the full generation check for cascades with pending author faces.
	if iterator.font_cascade_list == unsafe { nil }
		|| iterator.font_cascade_list.pending_faces.len == 0 {
		return iterator.synthetic_caps_font_for(selected, code_point)
	}
	font_computer := css.css_style_computer_for(iterator.text_node.Node.document()).font_computer()
	font_generation := font_computer.environment_generation()
	fallback_is_invisible := iterator.fallback_visibility_for_code_point(code_point, selected_index)
	if font_computer.environment_generation() != font_generation {
		// A synchronously loaded URL-backed face invalidates the old cascade.
		// Rebuild it before shaping this code point so the first layout uses the
		// author font rather than retaining fallback metrics until another pass.
		mut computed_values := unsafe { &css.ComputedProperties(iterator.text_node.Node.computed_values()) }
		use_document := iterator.retain_selected_fonts_ && iterator.text_node != unsafe { nil }
			&& cache_uses_entered_document_storage(iterator.text_node.Node.document())
		mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		persistent := platform.enter_persistent_if(iterator.retain_selected_fonts_ && !use_document)
		updated := computed_values.computed_font_list(font_computer)
		platform.leave_persistent(persistent)
		retained.finish()
		iterator.install_font_cascade(updated)
		return iterator.font_for_code_point(code_point)
	}
	if !fallback_is_invisible {
		return iterator.synthetic_caps_font_for(selected, code_point)
	}
	return iterator.synthetic_caps_font_for(iterator.invisible_font_for(selected), code_point)
}

fn (mut iterator TextNodeChunkIterator) synthetic_caps_font_for(selected &platform.Font, code_point u32) &platform.Font {
	if selected.font_rendering_policy != .chromium { return selected }
	variant := iterator.font_variant_caps
	if variant !in [.small_caps, .all_small_caps] { return selected }
	needs_cap := (code_point >= u32(`a`) && code_point <= u32(`z`))
		|| (variant == .all_small_caps && code_point < 128)
	if !needs_cap { return selected }
	key := 'caps:${selected.family}|${selected.source_path}|${selected.point_size}|${selected.weight}|${selected.is_invisible}'
	if iterator.selected_font_storage_ != unsafe { nil } {
		if font := iterator.selected_font_storage_.values[key] { return font }
	}
	if selected.has_gsub_feature('smcp') { return selected }
	uppercase := if code_point >= u32(`a`) && code_point <= u32(`z`) { code_point - 32 } else { code_point }
	if !selected.contains_glyph(uppercase) { return selected }
	use_document := iterator.retain_selected_fonts_ && iterator.text_node != unsafe { nil }
		&& cache_uses_entered_document_storage(iterator.text_node.Node.document())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	persistent := platform.enter_persistent_if(iterator.retain_selected_fonts_ && !use_document)
	font := &platform.Font{
		family: selected.family.clone()
		point_size: f32(math.round(f64(selected.point_size * 0.7)))
		weight: selected.weight
		source_path: selected.source_path.clone()
		is_invisible: selected.is_invisible
		font_rendering_policy: selected.font_rendering_policy
		synthesize_ascii_caps: true
	}
	platform.leave_persistent(persistent)
	retained.finish()
	if iterator.selected_font_storage_ == unsafe { nil } {
		iterator.selected_font_storage_ = &InvisibleFontSelectionStorage{values: map[string]&platform.Font{}}
	}
	iterator.selected_font_storage_.values[key] = font
	return font
}

fn (iterator &TextNodeChunkIterator) uses_chromium_font_rendering() bool {
	base := if iterator.font_cascade_fonts.len > 0 { iterator.font_cascade_fonts[0] } else { iterator.font }
	return base != unsafe { nil } && base.font_rendering_policy == .chromium
}

// No face in the CSS cascade covers this code point. Use the platform's
// language-aware system fallback, based on the cascade's primary face.
fn (iterator &TextNodeChunkIterator) system_fallback_font(code_point u32) ?&platform.Font {
	if code_point < 0x80 {
		return none
	}
	base := if iterator.font_cascade_fonts.len > 0 { iterator.font_cascade_fonts[0] } else { iterator.font }
	if base == unsafe { nil } {
		return none
	}
	mut language := ''
	if dom_text := iterator.text_node.dom_node_ {
		if parent_element := dom_text.parent_or_shadow_host_element() {
			language = parent_element.lang() or { '' }
		}
	}
	return platform.system_fallback_font(code_point, language, base)
}

fn (iterator &TextNodeChunkIterator) cached_invisible_font(key string) ?&platform.Font {
	if iterator.selected_font_storage_ == unsafe { nil } {
		return none
	}
	return iterator.selected_font_storage_.values[key] or { return none }
}

fn (mut iterator TextNodeChunkIterator) invisible_font_for(selected &platform.Font) &platform.Font {
	key := '${selected.family}|${selected.source_path}|${selected.point_size}|${selected.weight}|invisible'
	if font := iterator.cached_invisible_font(key) {
		return font
	}
	use_document := iterator.retain_selected_fonts_ && iterator.text_node != unsafe { nil }
		&& cache_uses_entered_document_storage(iterator.text_node.Node.document())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	persistent := platform.enter_persistent_if(iterator.retain_selected_fonts_ && !use_document)
	font := text_node_chunk_invisible_font(selected)
	platform.leave_persistent(persistent)
	retained.finish()
	if iterator.selected_font_storage_ == unsafe { nil } {
		iterator.selected_font_storage_ = &InvisibleFontSelectionStorage{
			values: map[string]&platform.Font{}
		}
	}
	iterator.selected_font_storage_.values[key] = font
	return font
}

pub fn (mut iterator TextNodeChunkIterator) font_for_space(at_index int, space_code_point u32) &platform.Font {
	// Blink selects a space's font by coverage like any other character, so a
	// space after fallback CJK text uses the primary font.
	if iterator.uses_chromium_font_rendering() {
		return iterator.font_for_code_point(space_code_point)
	}
	if font := iterator.last_non_whitespace_font {
		if !font.synthesize_ascii_caps && !font.is_emoji_font() && font.contains_glyph(space_code_point) {
			return font
		}
	}

	mut index := at_index
	for index < iterator.code_units.len {
		code_point := code_point_at_utf16(iterator.code_units, index)
		if !is_interword_space(code_point) && code_point != u32(`\t`)
			&& code_point != u32(`\n`) {
			font := iterator.font_for_code_point(code_point)
			if !font.synthesize_ascii_caps && !font.is_emoji_font() && font.contains_glyph(space_code_point) {
				return font
			}
			break
		}
		index += utf16_code_point_length(code_point)
	}

	return iterator.font_for_code_point(space_code_point)
}

fn (mut iterator TextNodeChunkIterator) next_without_peek() ?TextNodeChunk {
	if iterator.current_index >= iterator.code_units.len {
		return none
	}
	mut code_point := code_point_at_utf16(iterator.code_units, iterator.current_index)
	mut can_break_at_current_position := iterator.is_at_line_break_opportunity()
	start_of_chunk := iterator.current_index
	font := if is_interword_space(code_point) {
		iterator.font_for_space(iterator.current_index, code_point)
	} else {
		iterator.font_for_code_point(code_point)
	}
	text_type := iterator.current_text_type()
	mut broken_on_tab := false

	for iterator.current_index < iterator.code_units.len {
		code_point = code_point_at_utf16(iterator.code_units, iterator.current_index)
		expected_font := if is_interword_space(code_point) {
			iterator.font_for_space(iterator.current_index, code_point)
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
			if text_type != iterator.current_text_type() {
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
				space_font := iterator.font_for_space(iterator.current_index, code_point)
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
		} else if iterator.splits_unwrapped_spaces_ && iterator.is_collapsible(code_point) {
			if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, font, text_type) {
				return chunk
			}
			iterator.current_index = iterator.next_grapheme_boundary()
			space_font := iterator.font_for_space(iterator.current_index, code_point)
			if chunk := iterator.try_commit_chunk(start_of_chunk, iterator.current_index, false, broken_on_tab, false, space_font, text_type) {
				return chunk
			}
			continue
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
	view := if iterator.view.is_ascii() {
		utf16_substring_for_line_box(iterator.view, start, length)
	} else {
		utf16_substring_from_code_units_for_line_box(iterator.code_units, start, length)
	}
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
	if text.is_ascii() {
		mut boundaries := []int{cap: text.len + 1}
		boundaries << 0
		for index in 0 .. text.len {
			// UAX #29 GB3 keeps CRLF in a single extended grapheme cluster.
			if text[index] == `\r` && index + 1 < text.len && text[index + 1] == `\n` {
				continue
			}
			boundaries << index + 1
		}
		return boundaries
	}
	// Latin and non-combining Cyrillic text with common punctuation has one
	// grapheme per code point. Avoid the substantially more expensive general
	// UAX #29 tables for this common case, while retaining the full segmenter
	// for combining marks, joiners, emoji, and complex scripts.
	code_points := text.runes()
	mut has_only_simple_graphemes := true
	for code_point in code_points {
		if code_point >= 0x80
			&& !(code_point >= 0xa0 && code_point <= 0x2ff)
			// U+0483..0489 are combining marks and stay on the general path.
			&& !(code_point >= 0x400 && code_point <= 0x482)
			&& !(code_point >= 0x48a && code_point <= 0x52f)
			&& !(code_point >= 0x2000 && code_point <= 0x200b)
			&& !(code_point >= 0x2010 && code_point <= 0x2029)
			&& code_point != 0x2060 {
			has_only_simple_graphemes = false
			break
		}
	}
	if has_only_simple_graphemes {
		mut boundaries := []int{cap: code_points.len + 1}
		boundaries << 0
		mut offset := 0
		for index, code_point in code_points {
			offset += if code_point > 0xffff { 2 } else { 1 }
			if code_point == `\r` && index + 1 < code_points.len && code_points[index + 1] == `\n` {
				continue
			}
			boundaries << offset
		}
		return boundaries
	}
	return general_text_grapheme_boundaries(code_points)
}

fn text_line_boundaries(text string) []bool {
	if ascii_segmenter := dom.Segmenter.try_create_for_ascii_line(text) {
		return text_line_boundaries_from_segmenter(ascii_segmenter, text.len)
	}
	units := utf16_code_units_for_line_box(text)
	return text_line_boundaries_from_code_units(units)
}

fn text_line_boundaries_from_segmenter(segmenter &dom.Segmenter, length int) []bool {
	mut boundaries := []bool{len: length + 1}
	for boundary in segmenter.boundaries() {
		if boundary >= 0 && boundary <= length {
			boundaries[boundary] = true
		}
	}
	return boundaries
}

fn text_line_boundaries_from_code_units(units []u16) []bool {
	mut boundaries := []bool{len: units.len + 1}
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
	if code_point < 0x80 {
		if (code_point >= u32(`A`) && code_point <= u32(`Z`))
			|| (code_point >= u32(`a`) && code_point <= u32(`z`)) {
			return .ltr
		}
		if code_point in u32(0x09) .. u32(0x0e)
			|| code_point in u32(0x1c) .. u32(0x21)
			|| code_point in [u32(`#`), u32(`$`), u32(`%`), u32(`+`), u32(`,`), u32(`-`), u32(`.`),
				u32(`/`), u32(`:`)]
			|| code_point in u32(`0`) .. u32(`:`) {
			return .context_dependent
		}
		return .common
	}
	match dom.unicode_bidirectional_class(code_point) {
		.white_space_neutral, .block_separator, .segment_separator, .common_number_separator,
		.dir_non_spacing_mark, .arabic_number, .european_number, .european_number_separator,
		.european_number_terminator {
			return .context_dependent
		}
		.boundary_neutral, .other_neutral, .first_strong_isolate, .pop_directional_format,
		.pop_directional_isolate {
			return .common
		}
		.left_to_right, .left_to_right_embedding, .left_to_right_isolate, .left_to_right_override {
			return .ltr
		}
		.right_to_left, .right_to_left_arabic, .right_to_left_embedding, .right_to_left_isolate,
		.right_to_left_override {
			return .rtl
		}
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
	for character in text.bytes() {
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

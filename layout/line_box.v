// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform
import strings

pub struct LineBoxFragmentCoordinate {
pub mut:
	line_box_index int
	fragment_index int
}

pub struct LineBoxFragment {
pub:
	layout_node_ &Node = unsafe { nil }
	glyph_run_   ?&platform.GlyphRun
pub mut:
	start_                   int
	length_in_code_units_    int
	inline_offset_           CSSPixels
	block_offset_            CSSPixels
	inline_length_           CSSPixels
	block_length_            CSSPixels
	border_box_top_          CSSPixels
	baseline_                CSSPixels
	direction_               css.Direction = .ltr
	writing_mode_            css.WritingMode = .horizontal_tb
	insert_position_         f32
	current_insert_direction css.Direction = .ltr
	has_trailing_whitespace_ bool
}

pub fn LineBoxFragment.new(layout_node &Node, start int, length_in_code_units int, inline_offset CSSPixels, block_offset CSSPixels, inline_length CSSPixels, block_length CSSPixels, border_box_top CSSPixels, direction css.Direction, writing_mode css.WritingMode, glyph_run ?&platform.GlyphRun) LineBoxFragment {
	mut fragment := LineBoxFragment{
		layout_node_: layout_node
		start_: start
		length_in_code_units_: length_in_code_units
		inline_offset_: inline_offset
		block_offset_: block_offset
		inline_length_: inline_length
		block_length_: block_length
		border_box_top_: border_box_top
		direction_: direction
		writing_mode_: writing_mode
		glyph_run_: glyph_run
	}
	if run := glyph_run {
		fragment.current_insert_direction = fragment.resolve_glyph_run_direction(run.text_type())
		if direction == .rtl {
			fragment.insert_position_ = f32(inline_length.to_double())
		}
	}
	return fragment
}

pub fn (fragment &LineBoxFragment) layout_node() &Node {
	return fragment.layout_node_
}

pub fn (fragment &LineBoxFragment) start() int {
	return fragment.start_
}

pub fn (fragment &LineBoxFragment) length_in_code_units() int {
	return fragment.length_in_code_units_
}

pub fn (fragment &LineBoxFragment) offset() css.CSSPixelPoint {
	if fragment.writing_mode_ != .horizontal_tb {
		return css.CSSPixelPoint.new(fragment.block_offset_, fragment.inline_offset_)
	}
	return css.CSSPixelPoint.new(fragment.inline_offset_, fragment.block_offset_)
}

pub fn (fragment &LineBoxFragment) inline_offset() CSSPixels {
	return fragment.inline_offset_
}

pub fn (fragment &LineBoxFragment) block_offset() CSSPixels {
	return fragment.block_offset_
}

pub fn (mut fragment LineBoxFragment) set_inline_offset(value CSSPixels) {
	fragment.inline_offset_ = value
}

pub fn (mut fragment LineBoxFragment) set_block_offset(value CSSPixels) {
	fragment.block_offset_ = value
}

pub fn (mut fragment LineBoxFragment) set_baseline(value CSSPixels) {
	fragment.baseline_ = value
}

pub fn (fragment &LineBoxFragment) baseline() CSSPixels {
	return fragment.baseline_
}

pub fn (fragment &LineBoxFragment) size() css.CSSPixelSize {
	if fragment.writing_mode_ != .horizontal_tb {
		return css.CSSPixelSize.new(fragment.block_length_, fragment.inline_length_)
	}
	return css.CSSPixelSize.new(fragment.inline_length_, fragment.block_length_)
}

pub fn (fragment &LineBoxFragment) width() CSSPixels {
	return fragment.size().width()
}

pub fn (fragment &LineBoxFragment) height() CSSPixels {
	return fragment.size().height()
}

pub fn (fragment &LineBoxFragment) inline_length() CSSPixels {
	return fragment.inline_length_
}

pub fn (fragment &LineBoxFragment) block_length() CSSPixels {
	return fragment.block_length_
}

pub fn (mut fragment LineBoxFragment) set_inline_length(value CSSPixels) {
	fragment.inline_length_ = value
}

pub fn (mut fragment LineBoxFragment) set_block_length(value CSSPixels) {
	fragment.block_length_ = value
}

pub fn (fragment &LineBoxFragment) border_box_top() CSSPixels {
	return fragment.border_box_top_
}

pub fn (fragment &LineBoxFragment) text() ?string {
	text_node := fragment.layout_node_.as_text_node() or { return none }
	value := text_node.text_for_rendering()
	if value.is_ascii() {
		return utf16_substring_for_line_box(value, fragment.start_, fragment.length_in_code_units_)
	}
	if units := text_node.cached_utf16_code_units_ {
		return utf16_substring_from_code_units_for_line_box(units, fragment.start_, fragment.length_in_code_units_)
	}
	return utf16_substring_for_line_box(value, fragment.start_, fragment.length_in_code_units_)
}

fn (fragment &LineBoxFragment) code_unit_at(relative_index int) ?u16 {
	if relative_index < 0 || relative_index >= fragment.length_in_code_units_ {
		return none
	}
	text_node := fragment.layout_node_.as_text_node() or { return none }
	absolute_index := fragment.start_ + relative_index
	value := text_node.text_for_rendering()
	if value.is_ascii() {
		if absolute_index < 0 || absolute_index >= value.len {
			return none
		}
		return u16(value[absolute_index])
	}
	if units := text_node.cached_utf16_code_units_ {
		if absolute_index < 0 || absolute_index >= units.len {
			return none
		}
		return units[absolute_index]
	}
	units := utf16_code_units_for_line_box(value)
	if absolute_index < 0 || absolute_index >= units.len {
		return none
	}
	return units[absolute_index]
}

pub fn (fragment &LineBoxFragment) ends_in_whitespace() bool {
	if fragment.length_in_code_units_ == 0 {
		return false
	}
	last := fragment.code_unit_at(fragment.length_in_code_units_ - 1) or { return false }
	return is_ascii_space_code_unit(last)
}

pub fn (fragment &LineBoxFragment) is_justifiable_whitespace() bool {
	if fragment.length_in_code_units_ != 1 {
		return false
	}
	return fragment.code_unit_at(0) or { return false } == u16(` `)
}

pub fn (fragment &LineBoxFragment) is_atomic_inline() bool {
	return fragment.layout_node_.is_atomic_inline()
}

pub fn (fragment &LineBoxFragment) glyph_run() ?&platform.GlyphRun {
	return fragment.glyph_run_
}

pub fn (fragment &LineBoxFragment) writing_mode() css.WritingMode {
	return fragment.writing_mode_
}

pub fn (fragment &LineBoxFragment) has_trailing_whitespace() bool {
	return fragment.has_trailing_whitespace_
}

pub fn (mut fragment LineBoxFragment) set_has_trailing_whitespace(value bool) {
	fragment.has_trailing_whitespace_ = value
}

fn (fragment &LineBoxFragment) resolve_glyph_run_direction(text_type platform.GlyphRunTextType) css.Direction {
	return match text_type {
		.common, .context_dependent, .end_padding { fragment.direction_ }
		.ltr { css.Direction.ltr }
		.rtl { css.Direction.rtl }
	}
}

pub fn (mut fragment LineBoxFragment) append_glyph_run(glyph_run &platform.GlyphRun, run_width CSSPixels) {
	match fragment.direction_ {
		.ltr { fragment.append_glyph_run_ltr(glyph_run, run_width) }
		.rtl { fragment.append_glyph_run_rtl(glyph_run, run_width) }
	}
}

fn (mut fragment LineBoxFragment) append_glyph_run_ltr(glyph_run &platform.GlyphRun, run_width CSSPixels) {
	run_direction := fragment.resolve_glyph_run_direction(glyph_run.text_type())
	inline_offset := f32(fragment.inline_length_.to_double())
	if fragment.current_insert_direction != run_direction {
		if run_direction == .rtl {
			fragment.insert_position_ = inline_offset
		}
		fragment.current_insert_direction = run_direction
	}
	mut destination := fragment.glyph_run_ or { return }
	destination.invalidate_replay_data()
	match run_direction {
		.ltr {
			for source_glyph in glyph_run.glyphs_ {
				mut glyph := source_glyph
				glyph.position.translate_by(inline_offset, 0)
				destination.glyphs_ << glyph
			}
		}
		.rtl {
			for i in 0 .. destination.glyphs_.len {
				if destination.glyphs_[i].position.x >= fragment.insert_position_ {
					destination.glyphs_[i].position.translate_by(f32(run_width.to_double()), 0)
				}
			}
			for source_glyph in glyph_run.glyphs_ {
				mut glyph := source_glyph
				glyph.position.translate_by(fragment.insert_position_, 0)
				destination.glyphs_ << glyph
			}
		}
	}
	fragment.inline_length_ = fragment.inline_length_.plus(run_width)
}

fn (mut fragment LineBoxFragment) append_glyph_run_rtl(glyph_run &platform.GlyphRun, run_width CSSPixels) {
	run_direction := fragment.resolve_glyph_run_direction(glyph_run.text_type())
	run_offset := f32(run_width.to_double())
	if fragment.current_insert_direction != run_direction {
		if run_direction == .ltr {
			fragment.insert_position_ = 0
		}
		fragment.current_insert_direction = run_direction
	}
	mut destination := fragment.glyph_run_ or { return }
	destination.invalidate_replay_data()
	match run_direction {
		.ltr {
			for i in 0 .. destination.glyphs_.len {
				if destination.glyphs_[i].position.x >= fragment.insert_position_ {
					destination.glyphs_[i].position.translate_by(run_offset, 0)
				}
			}
			for source_glyph in glyph_run.glyphs_ {
				mut glyph := source_glyph
				glyph.position.translate_by(fragment.insert_position_, 0)
				destination.glyphs_ << glyph
			}
		}
		.rtl {
			if glyph_run.text_type() != .end_padding {
				for i in 0 .. destination.glyphs_.len {
					destination.glyphs_[i].position.translate_by(run_offset, 0)
				}
			}
			for glyph in glyph_run.glyphs_ {
				destination.glyphs_ << glyph
			}
		}
	}
	fragment.inline_length_ = fragment.inline_length_.plus(run_width)
	fragment.insert_position_ += run_offset
}

pub struct LineBox {
pub mut:
	fragments_                []LineBoxFragment
	inline_length_            CSSPixels
	block_length_             CSSPixels
	bottom_                   CSSPixels
	baseline_                 CSSPixels
	direction_                css.Direction = .ltr
	writing_mode_             css.WritingMode = .horizontal_tb
	original_available_width_ AvailableSize = AvailableSize.make_indefinite()
	has_break_                bool
	has_forced_break_         bool
}

pub fn LineBox.new(direction css.Direction, writing_mode css.WritingMode) LineBox {
	return LineBox{
		direction_: direction
		writing_mode_: writing_mode
	}
}

pub fn (line &LineBox) width() CSSPixels {
	if line.writing_mode_ != .horizontal_tb {
		return line.block_length_
	}
	return line.inline_length_
}

pub fn (line &LineBox) height() CSSPixels {
	if line.writing_mode_ != .horizontal_tb {
		return line.inline_length_
	}
	return line.block_length_
}

pub fn (line &LineBox) bottom() CSSPixels {
	if line.writing_mode_ != .horizontal_tb {
		return line.inline_length_
	}
	return line.bottom_
}

pub fn (line &LineBox) inline_length() CSSPixels {
	return line.inline_length_
}

pub fn (line &LineBox) block_length() CSSPixels {
	return line.block_length_
}

pub fn (line &LineBox) baseline() CSSPixels {
	return line.baseline_
}

pub fn (mut line LineBox) add_fragment(layout_node &Node, start int, length int, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels, content_width CSSPixels, content_height CSSPixels, border_box_top CSSPixels, border_box_bottom CSSPixels, glyph_run ?&platform.GlyphRun) {
	text_align_is_justify := layout_node.computed_values().text_align() == .justify
	mut did_merge := false
	if run := glyph_run {
		if !text_align_is_justify && line.fragments_.len > 0 {
			mut last := &line.fragments_[line.fragments_.len - 1]
			if layout_nodes_same(last.layout_node_, layout_node)
				&& last.start_ + last.length_in_code_units_ == start {
				if last_run := last.glyph_run_ {
					// The temporary V font model can select the bundled emoji
					// HarfBuzz face behind the same CSS Font object. Glyph IDs from
					// different faces cannot share one retained replay run.
					if voidptr(last_run.font()) == voidptr(run.font())
						&& last_run.face() == run.face() {
						last.length_in_code_units_ += length
						last.append_glyph_run(run, content_width)
						did_merge = true
					}
				}
			}
		}
	}
	if !did_merge {
		inline_offset := line.inline_length_.plus(leading_margin).plus(leading_size)
		line.fragments_ << LineBoxFragment.new(layout_node, start, length, inline_offset, CSSPixels.new(0), content_width, content_height, border_box_top, line.direction_, line.writing_mode_, glyph_run)
	}
	line.inline_length_ =
		line.inline_length_.plus(leading_margin).plus(leading_size).plus(content_width).plus(trailing_size).plus(trailing_margin)
	block_extent := content_height.plus(border_box_top).plus(border_box_bottom)
	if block_extent.raw_value() > line.block_length_.raw_value() {
		line.block_length_ = block_extent
	}
}

pub fn (line &LineBox) fragments() []LineBoxFragment {
	return line.fragments_
}

enum RemoveTrailingWhitespace {
	yes
	no
}

fn (mut line LineBox) calculate_or_trim_trailing_whitespace(should_remove RemoveTrailingWhitespace) CSSPixels {
	mut whitespace_width := CSSPixels.new(0)
	mut trailing_whitespace_width := CSSPixels.new(0)
	mut fragment_index := line.fragments_.len
	for {
		if fragment_index == 0 {
			return whitespace_width
		}
		fragment_index--
		mut last_fragment := &line.fragments_[fragment_index]
		if dom_node := last_fragment.layout_node_.dom_node() {
			if cursor_position := dom_node.document().cursor_position() {
				if cursor_node := cursor_position.node() {
					if voidptr(cursor_node) == voidptr(dom_node) {
						return whitespace_width
					}
				}
			}
		}
		white_space_collapse := last_fragment.layout_node_.computed_values().white_space_collapse()
		if white_space_collapse !in [.collapse, .preserve_breaks] {
			return whitespace_width
		}
		if !last_fragment.is_justifiable_whitespace() {
			break
		}
		whitespace_width = whitespace_width.plus(last_fragment.inline_length_)
		trailing_whitespace_width = trailing_whitespace_width.plus(last_fragment.inline_length_)
		if should_remove == .yes {
			line.inline_length_ = line.inline_length_.minus(last_fragment.inline_length_)
			line.fragments_.delete(fragment_index)
		}
	}

	mut last_fragment := &line.fragments_[fragment_index]
	if last_fragment.layout_node_.as_text_node() == none {
		if should_remove == .yes && trailing_whitespace_width.raw_value() > 0 {
			last_fragment.set_has_trailing_whitespace(true)
		}
		return whitespace_width
	}
	mut last_text_length := last_fragment.length_in_code_units_
	for last_text_length > 0 {
		last_text_length--
		last_character := last_fragment.code_unit_at(last_text_length) or { break }
		if !is_ascii_space_code_unit(last_character) {
			break
		}
		mut last_character_width :=
			CSSPixels.nearest_value_for(last_fragment.layout_node_.first_available_font().glyph_width(last_character))
		if run := last_fragment.glyph_run_ {
			last_character_width =
				CSSPixels.nearest_value_for(run.font().glyph_width(last_character))
		}
		last_character_width = last_character_width.plus(resolved_text_spacing_for_node(last_fragment.layout_node_, .letter_spacing))
		whitespace_width = whitespace_width.plus(last_character_width)
		trailing_whitespace_width = trailing_whitespace_width.plus(last_character_width)
		if should_remove == .yes {
			last_fragment.length_in_code_units_--
			last_fragment.inline_length_ = last_fragment.inline_length_.minus(last_character_width)
			line.inline_length_ = line.inline_length_.minus(last_character_width)
		}
	}
	if should_remove == .yes
		&& (trailing_whitespace_width.raw_value() > 0 || !last_fragment.has_trailing_whitespace_) {
		last_fragment.has_trailing_whitespace_ = trailing_whitespace_width.raw_value() > 0
	}
	return whitespace_width
}

pub fn (line &LineBox) get_trailing_whitespace_width() CSSPixels {
	mut mutable_line := unsafe { &LineBox(line) }
	return mutable_line.calculate_or_trim_trailing_whitespace(.no)
}

pub fn (mut line LineBox) trim_trailing_whitespace() {
	line.calculate_or_trim_trailing_whitespace(.yes)
}

pub fn (line &LineBox) is_empty_or_ends_in_whitespace() bool {
	if line.fragments_.len == 0 {
		return true
	}
	return line.fragments_[line.fragments_.len - 1].ends_in_whitespace()
}

pub fn (line &LineBox) is_empty() bool {
	return line.fragments_.len == 0 && !line.has_break_
}

pub fn (line &LineBox) original_available_width() AvailableSize {
	return line.original_available_width_
}

fn is_ascii_space_code_unit(code_unit u16) bool {
	return code_unit in [u16(0x09), 0x0a, 0x0b, 0x0c, 0x0d, 0x20]
}

fn utf16_code_units_for_line_box(value string) []u16 {
	if value.is_ascii() {
		mut code_units := []u16{len: value.len}
		for index in 0 .. value.len {
			code_units[index] = u16(value[index])
		}
		return code_units
	}
	mut code_units := []u16{cap: value.len}
	for character in value.runes() {
		code_point := u32(character)
		if code_point <= 0xffff {
			code_units << u16(code_point)
			continue
		}
		scalar := code_point - 0x10000
		code_units << u16(0xd800 + (scalar >> 10))
		code_units << u16(0xdc00 + (scalar & 0x3ff))
	}
	return code_units
}

fn string_from_utf16_code_units_for_line_box(code_units []u16) string {
	mut all_ascii := true
	for code_unit in code_units {
		if code_unit > 0x7f {
			all_ascii = false
			break
		}
	}
	if all_ascii {
		mut bytes := []u8{len: code_units.len}
		for index, code_unit in code_units {
			bytes[index] = u8(code_unit)
		}
		return bytes.bytestr()
	}
	mut builder := strings.new_builder(code_units.len)
	mut index := 0
	for index < code_units.len {
		code_unit := code_units[index]
		if code_unit >= 0xd800 && code_unit <= 0xdbff && index + 1 < code_units.len {
			next := code_units[index + 1]
			if next >= 0xdc00 && next <= 0xdfff {
				high := u32(code_unit) - 0xd800
				low := u32(next) - 0xdc00
				builder.write_rune(rune(0x10000 + (high << 10) + low))
				index += 2
				continue
			}
		}
		builder.write_rune(rune(code_unit))
		index++
	}
	return builder.str()
}

fn utf16_substring_for_line_box(value string, start int, length int) string {
	if value.is_ascii() {
		safe_start := if start < 0 {
			0
		} else if start > value.len {
			value.len
		} else {
			start
		}
		requested_end := safe_start + if length < 0 { 0 } else { length }
		safe_end := if requested_end > value.len { value.len } else { requested_end }
		return value[safe_start..safe_end]
	}
	units := utf16_code_units_for_line_box(value)
	return utf16_substring_from_code_units_for_line_box(units, start, length)
}

fn utf16_substring_from_code_units_for_line_box(units []u16, start int, length int) string {
	safe_start := if start < 0 {
		0
	} else if start > units.len {
		units.len
	} else {
		start
	}
	requested_end := safe_start + if length < 0 { 0 } else { length }
	safe_end := if requested_end > units.len { units.len } else { requested_end }
	return string_from_utf16_code_units_for_line_box(units[safe_start..safe_end])
}

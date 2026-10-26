// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform
import strings

// The advance of trailing whitespace recorded during shaping. Keeping this
// beside the fragment makes line-end trimming exact even after runs merge.
pub struct TrailingWhitespace {
pub:
	length_in_code_units int
	inline_size          CSSPixels
}

pub struct LineBoxFragmentCoordinate {
pub mut:
	line_box_index int
	fragment_index int
}

pub struct LineBoxFragment {
pub:
	layout_node_         &Node = unsafe { nil }
	style_source_        &Node = unsafe { nil }
	glyph_run_           ?&platform.GlyphRun
	block_ellipsis_text_ ?string
	is_block_ellipsis_   bool
pub mut:
	start_                           int
	length_in_code_units_            int
	inline_offset_                   CSSPixels
	block_offset_                    CSSPixels
	inline_length_                   CSSPixels
	block_length_                    CSSPixels
	border_box_top_                  CSSPixels
	baseline_                        CSSPixels
	direction_                       css.Direction = .ltr
	writing_mode_                    css.WritingMode = .horizontal_tb
	insert_position_                 f32
	current_insert_direction         css.Direction = .ltr
	has_trailing_whitespace_         bool
	trailing_whitespace_             TrailingWhitespace
	has_soft_wrap_opportunity_after_ bool
	is_fully_truncated_              bool
	// A Blink-compatible text run retains its fractional advance between words.
	// The exposed box width still uses CSSPixels, rounded once for the run.
	precise_inline_length_           ?f64
	// Contiguous fragments of one text node form a single Blink text item even
	// where fallback fonts or line-break opportunities split them, and the item
	// is rounded up once. A fragment records its unsnapped width, the item's
	// unsnapped width before it, its snapped offset from the item's start, and
	// the part of that offset finer than 1/64 px, which its glyphs carry.
	chains_item_     bool
	item_width_      f64
	item_prefix_     f64
	item_offset_     CSSPixels
	glyph_remainder_ f32
}

pub fn LineBoxFragment.new(layout_node &Node, start int, length_in_code_units int, inline_offset CSSPixels, block_offset CSSPixels, inline_length CSSPixels, block_length CSSPixels, border_box_top CSSPixels, direction css.Direction, writing_mode css.WritingMode, glyph_run ?&platform.GlyphRun) LineBoxFragment {
	mut fragment := LineBoxFragment{
		layout_node_: layout_node
		style_source_: layout_node
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
		if direction == .ltr && fragment.current_insert_direction == .ltr
			&& run.font().font_rendering_policy == .chromium
			&& inline_length == shaped_inline_width(run, 0)
			&& run.glyphs_.len > 0 && run.glyphs_[0].position.x == 0 {
			fragment.precise_inline_length_ = f64(run.width())
		}
		if direction == .ltr && fragment.current_insert_direction == .ltr
			&& run.font().font_rendering_policy == .chromium
			&& inline_length == shaped_inline_width(run, 0) {
			fragment.chains_item_ = true
			fragment.item_width_ = f64(run.width())
		}
		if direction == .rtl {
			fragment.insert_position_ = f32(inline_length.to_double())
		}
	}
	return fragment
}

pub fn LineBoxFragment.new_block_ellipsis(layout_node &Node, style_source &Node, text string, start int, inline_offset CSSPixels, block_offset CSSPixels, inline_length CSSPixels, block_length CSSPixels, baseline CSSPixels, direction css.Direction, writing_mode css.WritingMode, glyph_run ?&platform.GlyphRun) LineBoxFragment {
	return LineBoxFragment{
		layout_node_: layout_node
		style_source_: style_source
		block_ellipsis_text_: text
		start_: start
		length_in_code_units_: utf16_length_for_line_box(text)
		inline_offset_: inline_offset
		block_offset_: block_offset
		inline_length_: inline_length
		block_length_: block_length
		baseline_: baseline
		direction_: direction
		writing_mode_: writing_mode
		glyph_run_: glyph_run
		current_insert_direction: direction
		is_block_ellipsis_: true
	}
}

pub fn (fragment &LineBoxFragment) layout_node() &Node {
	return fragment.layout_node_
}

pub fn (fragment &LineBoxFragment) style_source() &Node {
	return fragment.style_source_
}

pub fn (fragment &LineBoxFragment) start() int {
	return fragment.start_
}

// Source UTF-16 position for DOM ranges, selection and caret projections.
// Shaping and fragment.text() continue to index the rendered slice locally.
pub fn (fragment &LineBoxFragment) source_start() int {
	if text := fragment.layout_node_.as_text_node() {
		return text.source_offset_for_rendered_text_offset(fragment.start_, .start)
	}
	return fragment.start_
}

pub fn (fragment &LineBoxFragment) source_end() int {
	if text := fragment.layout_node_.as_text_node() {
		return text.source_offset_for_rendered_text_offset(fragment.start_ +
			fragment.length_in_code_units_, .end)
	}
	return fragment.start_ + fragment.length_in_code_units_
}

fn (fragment &LineBoxFragment) source_offset_for_local_rendered(offset int) int {
	if text := fragment.layout_node_.as_text_node() {
		return text.source_offset_for_rendered_text_offset(fragment.start_ + offset, .end)
	}
	return fragment.start_ + offset
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
	fragment.precise_inline_length_ = none
	fragment.chains_item_ = false
}

pub fn (mut fragment LineBoxFragment) set_block_length(value CSSPixels) {
	fragment.block_length_ = value
}

pub fn (fragment &LineBoxFragment) border_box_top() CSSPixels {
	return fragment.border_box_top_
}

pub fn (fragment &LineBoxFragment) text() ?string {
	if text := fragment.block_ellipsis_text_ {
		return text
	}
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

pub fn (fragment &LineBoxFragment) is_block_ellipsis() bool {
	return fragment.is_block_ellipsis_
}

fn (fragment &LineBoxFragment) code_unit_at(relative_index int) ?u16 {
	if relative_index < 0 || relative_index >= fragment.length_in_code_units_ {
		return none
	}
	text_node := fragment.layout_node_.as_text_node() or { return none }
	absolute_index := fragment.start_ + relative_index
	value := text_node.text_for_rendering()
	// Chunk iteration already decodes the rendered text, including ASCII.
	// Read that immutable cache before scanning the entire string again.
	if units := text_node.cached_utf16_code_units_ {
		if absolute_index < 0 || absolute_index >= units.len {
			return none
		}
		return units[absolute_index]
	}
	if value.is_ascii() {
		if absolute_index < 0 || absolute_index >= value.len {
			return none
		}
		return u16(value[absolute_index])
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

pub fn (fragment &LineBoxFragment) has_soft_wrap_opportunity_after() bool {
	return fragment.has_soft_wrap_opportunity_after_
}

pub fn (mut fragment LineBoxFragment) set_has_soft_wrap_opportunity_after(value bool) {
	fragment.has_soft_wrap_opportunity_after_ = value
}

pub fn (fragment &LineBoxFragment) is_fully_truncated() bool {
	return fragment.is_fully_truncated_
}

pub fn (mut fragment LineBoxFragment) set_fully_truncated(value bool) {
	fragment.is_fully_truncated_ = value
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
	mut inline_offset := f32(fragment.inline_length_.to_double())
	// The unsnapped offset of a continued item: each glyph position is the
	// exact sum converted to float once, as Blink converts its 16.16 sums.
	mut precise_offset := ?f64(none)
	if precise := fragment.precise_inline_length_ {
		if fragment.current_insert_direction == .ltr && run_direction == .ltr
			&& run_width == shaped_inline_width(glyph_run, 0)
			&& glyph_run.glyphs_.len > 0 && glyph_run.glyphs_[0].position.x == 0 {
			inline_offset = f32(precise) + fragment.glyph_remainder_
			precise_offset = precise + f64(fragment.glyph_remainder_)
			fragment.precise_inline_length_ = precise + f64(glyph_run.width())
		} else {
			fragment.precise_inline_length_ = none
		}
	}
	if fragment.chains_item_ {
		if fragment.precise_inline_length_ != none {
			fragment.item_width_ += f64(glyph_run.width())
		} else {
			fragment.chains_item_ = false
		}
	}
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
			start := destination.glyphs_.len
			destination.glyphs_ << glyph_run.glyphs_
			for i in start .. destination.glyphs_.len {
				if offset := precise_offset {
					destination.glyphs_[i].position.x = f32(offset + f64(destination.glyphs_[i].position.x))
				} else {
					destination.glyphs_[i].position.translate_by(inline_offset, 0)
				}
			}
		}
		.rtl {
			for i in 0 .. destination.glyphs_.len {
				if destination.glyphs_[i].position.x >= fragment.insert_position_ {
					destination.glyphs_[i].position.translate_by(f32(run_width.to_double()), 0)
				}
			}
			start := destination.glyphs_.len
			destination.glyphs_ << glyph_run.glyphs_
			for i in start .. destination.glyphs_.len {
				destination.glyphs_[i].position.translate_by(fragment.insert_position_, 0)
			}
		}
	}
	fragment.inline_length_ = fragment.inline_length_.plus(run_width)
	if precise := fragment.precise_inline_length_ {
		fragment.inline_length_ = inline_advance_to_css_pixels(fragment.item_prefix_ + precise,
			destination.font()).minus(fragment.item_offset_)
	}
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
			start := destination.glyphs_.len
			destination.glyphs_ << glyph_run.glyphs_
			for i in start .. destination.glyphs_.len {
				destination.glyphs_[i].position.translate_by(fragment.insert_position_, 0)
			}
		}
		.rtl {
			if glyph_run.text_type() != .end_padding {
				for i in 0 .. destination.glyphs_.len {
					destination.glyphs_[i].position.translate_by(run_offset, 0)
				}
			}
			destination.glyphs_ << glyph_run.glyphs_
		}
	}
	fragment.inline_length_ = fragment.inline_length_.plus(run_width)
	fragment.insert_position_ += run_offset
}

// A zero-size placeholder recorded at an out-of-flow box's position in the
// inline flow. Offsets are logical until the line is finalized.
pub struct StaticPositionMarker {
pub mut:
	box                         &Box = unsafe { nil }
	inline_offset               CSSPixels
	block_offset                CSSPixels
	writing_mode                css.WritingMode
	preceded_by_in_flow_content bool
}

pub fn (marker &StaticPositionMarker) offset() css.CSSPixelPoint {
	if marker.writing_mode != .horizontal_tb {
		return css.CSSPixelPoint.new(marker.block_offset, marker.inline_offset)
	}
	return css.CSSPixelPoint.new(marker.inline_offset, marker.block_offset)
}

pub struct LineBox {
pub mut:
	fragments_                           []LineBoxFragment
	inline_length_                       CSSPixels
	inline_length_before_block_ellipsis_ ?CSSPixels
	block_length_                        CSSPixels
	bottom_                              CSSPixels
	baseline_                            CSSPixels
	direction_                           css.Direction = .ltr
	writing_mode_                        css.WritingMode = .horizontal_tb
	original_available_width_            AvailableSize = AvailableSize.make_indefinite()
	has_break_                           bool
	has_forced_break_                    bool
	has_block_level_box_                 bool
	static_position_markers_             []StaticPositionMarker
	block_level_box_bottom_margin_       CSSPixels
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
	line.add_fragment_with_trailing_whitespace(layout_node, start, length, leading_size, trailing_size, leading_margin, trailing_margin, content_width, content_height, border_box_top, border_box_bottom, glyph_run, TrailingWhitespace{})
}

pub fn (mut line LineBox) add_fragment_with_trailing_whitespace(layout_node &Node, start int, length int, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels, content_width CSSPixels, content_height CSSPixels, border_box_top CSSPixels, border_box_bottom CSSPixels, glyph_run ?&platform.GlyphRun, trailing_whitespace TrailingWhitespace) {
	text_align_is_justify := layout_node.computed_values().text_align() == .justify
	mut did_merge := false
	mut added_width := content_width
	if run := glyph_run {
		if !text_align_is_justify && line.fragments_.len > 0 {
			mut last := &line.fragments_[line.fragments_.len - 1]
			if !last.has_soft_wrap_opportunity_after()
				&& layout_nodes_same(last.layout_node_, layout_node)
				&& last.start_ + last.length_in_code_units_ == start {
				if last_run := last.glyph_run_ {
					// The temporary V font model can select the bundled emoji
					// HarfBuzz face behind the same CSS Font object. Glyph IDs from
					// different faces cannot share one retained replay run.
					if voidptr(last_run.font()) == voidptr(run.font())
						&& last_run.face() == run.face() {
						last.length_in_code_units_ += length
						previous_width := last.inline_length_
						last.append_glyph_run(run, content_width)
						added_width = last.inline_length_.minus(previous_width)
						if trailing_whitespace.length_in_code_units == length {
							last.trailing_whitespace_ = TrailingWhitespace{
								length_in_code_units: last.trailing_whitespace_.length_in_code_units + trailing_whitespace.length_in_code_units
								inline_size: last.trailing_whitespace_.inline_size.plus(trailing_whitespace.inline_size)
							}
						} else {
							last.trailing_whitespace_ = trailing_whitespace
						}
						did_merge = true
					}
				}
			}
		}
	}
	if !did_merge {
		mut inline_offset := line.inline_length_.plus(leading_margin).plus(leading_size)
		mut fragment_width := content_width
		mut fragment_run := glyph_run
		mut item_prefix := 0.0
		mut item_offset := CSSPixels.new(0)
		mut remainder := f32(0)
		if run := glyph_run {
			if leading_margin.raw_value() == 0 && leading_size.raw_value() == 0
				&& !text_align_is_justify && content_width == shaped_inline_width(run, 0) {
				if last := line.chained_text_item(layout_node, start, run) {
					// Continue the previous fragment's text item at its unsnapped end.
					origin := last.inline_offset_.minus(last.item_offset_)
					item_prefix = last.item_prefix_ + last.item_width_
					item_offset = CSSPixels.nearest_value_for(item_prefix)
					inline_offset = origin.plus(item_offset)
					end := origin.plus(inline_advance_to_css_pixels(item_prefix + f64(run.width()),
						run.font()))
					fragment_width = end.minus(inline_offset)
					added_width = end.minus(line.inline_length_)
					remainder = f32(item_prefix - item_offset.to_double())
					if remainder != 0 {
						mut glyphs := run.glyphs().clone()
						for mut glyph in glyphs {
							glyph.position.translate_by(remainder, 0)
						}
						fragment_run = platform.GlyphRun.new_with_face(run.font(), run.text_type(),
							glyphs, run.face())
					}
				}
			}
		}
		mut fragment := LineBoxFragment.new(layout_node, start, length, inline_offset, CSSPixels.new(0), fragment_width, content_height, border_box_top, line.direction_, line.writing_mode_, fragment_run)
		if item_offset.raw_value() != 0 || item_prefix != 0 {
			if run := glyph_run {
				fragment.chains_item_ = true
				fragment.item_width_ = f64(run.width())
				fragment.item_prefix_ = item_prefix
				fragment.item_offset_ = item_offset
				fragment.glyph_remainder_ = remainder
				fragment.precise_inline_length_ = if run.glyphs_.len > 0
					&& run.glyphs_[0].position.x == 0 { ?f64(f64(run.width())) } else { none }
			}
		}
		fragment.trailing_whitespace_ = trailing_whitespace
		line.fragments_ << fragment
	}
	line.inline_length_ =
		line.inline_length_.plus(leading_margin).plus(leading_size).plus(added_width).plus(trailing_size).plus(trailing_margin)
	block_extent := content_height.plus(border_box_top).plus(border_box_bottom)
	if block_extent.raw_value() > line.block_length_.raw_value() {
		line.block_length_ = block_extent
	}
}

// The previous fragment whose Blink text item a Chromium-policy chunk of
// `layout_node` starting at `start` continues, if any.
fn (line &LineBox) chained_text_item(layout_node &Node, start int, run &platform.GlyphRun) ?LineBoxFragment {
	if line.direction_ != .ltr || line.fragments_.len == 0 || run.text_type() == .rtl
		|| run.font().font_rendering_policy != .chromium {
		return none
	}
	last := line.fragments_[line.fragments_.len - 1]
	if last.chains_item_ && layout_nodes_same(last.layout_node_, layout_node)
		&& chromium_text_item_continues(layout_node, last.start_ + last.length_in_code_units_, start)
		&& last.inline_offset_.plus(last.inline_length_) == line.inline_length_ {
		return last
	}
	return none
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
			line.clamp_static_position_markers_to_inline_length()
		}
	}

	mut last_fragment := &line.fragments_[fragment_index]
	if last_fragment.layout_node_.as_text_node() == none {
		if should_remove == .yes && trailing_whitespace_width.raw_value() > 0 {
			last_fragment.set_has_trailing_whitespace(true)
		}
		return whitespace_width
	}
	// Subtract exactly the advance retained by shaping, including letter- and
	// word-spacing and any shaping-specific adjustment.
	fragment_trailing_whitespace := last_fragment.trailing_whitespace_
	mut trailing_size := fragment_trailing_whitespace.inline_size
	trimmed_advance := last_fragment.trailing_whitespace_advance(fragment_trailing_whitespace)
	if trimmed_width := last_fragment.chromium_width_without_trailing_advance(trimmed_advance) {
		trailing_size = last_fragment.inline_length_.minus(trimmed_width)
	}
	whitespace_width = whitespace_width.plus(trailing_size)
	trailing_whitespace_width = trailing_whitespace_width.plus(trailing_size)
	if should_remove == .yes {
		last_fragment.length_in_code_units_ -= fragment_trailing_whitespace.length_in_code_units
		last_fragment.inline_length_ = last_fragment.inline_length_.minus(trailing_size)
		if advance := trimmed_advance {
			if precise := last_fragment.precise_inline_length_ {
				last_fragment.precise_inline_length_ = precise - advance
			}
			if last_fragment.chains_item_ {
				last_fragment.item_width_ -= advance
			}
		}
		last_fragment.trailing_whitespace_ = TrailingWhitespace{}
		line.inline_length_ = line.inline_length_.minus(trailing_size)
		line.clamp_static_position_markers_to_inline_length()
	}
	if should_remove == .yes
		&& (trailing_whitespace_width.raw_value() > 0 || !last_fragment.has_trailing_whitespace_) {
		last_fragment.has_trailing_whitespace_ = trailing_whitespace_width.raw_value() > 0
	}
	return whitespace_width
}

// The unsnapped advance of the glyphs that shape the fragment's trailing
// whitespace, when its glyph run ends with exactly those code units.
fn (fragment &LineBoxFragment) trailing_whitespace_advance(trailing TrailingWhitespace) ?f64 {
	run := fragment.glyph_run_ or { return none }
	if trailing.length_in_code_units <= 0 {
		return none
	}
	mut remaining := trailing.length_in_code_units
	mut advance := 0.0
	mut index := run.glyphs_.len - 1
	for remaining > 0 && index >= 0 {
		advance += f64(run.glyphs_[index].advance)
		remaining -= run.glyphs_[index].length_in_code_units
		index--
	}
	return if remaining == 0 { advance } else { none }
}

// Blink removes trailing spaces from a text item's shape result and snaps the
// remaining advance up to a LayoutUnit again, instead of subtracting the
// separately snapped width of the spaces.
fn (fragment &LineBoxFragment) chromium_width_without_trailing_advance(advance ?f64) ?CSSPixels {
	trimmed := advance or { return none }
	run := fragment.glyph_run_ or { return none }
	if run.font().font_rendering_policy != .chromium || fragment.direction_ != .ltr {
		return none
	}
	precise := fragment.precise_inline_length_ or { return none }
	if fragment.chains_item_ {
		origin := fragment.inline_offset_.minus(fragment.item_offset_)
		end := origin.plus(inline_advance_to_css_pixels(fragment.item_prefix_ +
			fragment.item_width_ - trimmed, run.font()))
		return end.minus(fragment.inline_offset_)
	}
	return inline_advance_to_css_pixels(precise - trimmed, run.font())
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

pub fn (line &LineBox) ends_in_preserved_whitespace() bool {
	if line.fragments_.len == 0 {
		return false
	}
	last := line.fragments_[line.fragments_.len - 1]
	if !last.ends_in_whitespace() {
		return false
	}
	collapse := last.layout_node_.computed_values().white_space_collapse()
	return collapse != .collapse && collapse != .preserve_breaks
}

pub fn (line &LineBox) is_empty() bool {
	return line.fragments_.len == 0 && !line.has_break_
}

pub fn (line &LineBox) has_forced_break() bool {
	return line.has_forced_break_
}

// Inline box start edges count like content: a line box holding an inline
// element with non-zero margin, border, or padding is not a zero-height line
// box (CSS 2 9.4.2), so a block-level abspos after such an edge belongs below
// this line rather than at its top.
pub fn (mut line LineBox) add_static_position_marker(box &Box, preceded_by_inline_box_start_edges bool) {
	line.static_position_markers_ << StaticPositionMarker{
		box: unsafe { box }
		inline_offset: line.inline_length_
		writing_mode: line.writing_mode_
		preceded_by_in_flow_content: line.fragments_.len > 0 || preceded_by_inline_box_start_edges
	}
}

pub fn (line &LineBox) static_position_markers() []StaticPositionMarker {
	return line.static_position_markers_
}

fn (mut line LineBox) clamp_static_position_markers_to_inline_length() {
	for mut marker in line.static_position_markers_ {
		if marker.inline_offset.raw_value() > line.inline_length_.raw_value() {
			marker.inline_offset = line.inline_length_
		}
	}
}

pub fn (line &LineBox) has_block_level_box() bool {
	return line.has_block_level_box_
}

pub fn (line &LineBox) block_level_box_bottom_margin() CSSPixels {
	return line.block_level_box_bottom_margin_
}

pub fn (line &LineBox) original_available_width() AvailableSize {
	return line.original_available_width_
}

fn is_ascii_space_code_unit(code_unit u16) bool {
	return code_unit in [u16(0x09), 0x0a, 0x0b, 0x0c, 0x0d, 0x20]
}

// Count offsets without materializing code units. The iterator uses the same
// decoder as string.runes(), including one replacement rune per invalid byte.
fn utf16_length_for_line_box(value string) int {
	if value.is_ascii() {
		return value.len
	}
	mut length := 0
	for character in value.runes_iterator() {
		length += if u32(character) > 0xffff { 2 } else { 1 }
	}
	return length
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

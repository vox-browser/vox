// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform

pub struct InlineFormattingResult {
pub:
	automatic_content_width  CSSPixels
	automatic_content_height CSSPixels
}

fn calculate_inline_static_position_rect(box &Box, containing_block_used_values &UsedValues) StaticPositionRect {
	box_node := unsafe { &Node(box) }
	mut position_x := CSSPixels.new(0)
	mut position_y := CSSPixels.new(0)
	if sibling := box_node.previous_sibling() {
		mut found := false
		mut last_offset := css.CSSPixelPoint{}
		mut last_width := CSSPixels.new(0)
		mut last_height := CSSPixels.new(0)
		for line_box in containing_block_used_values.line_boxes {
			for fragment in line_box.fragments_ {
				if fragment.layout_node() == sibling {
					found = true
					last_offset = fragment.offset()
					last_width = fragment.width()
					last_height = fragment.height()
				}
			}
		}
		if found {
			if box.computed_values().display_before_box_type_transformation().is_block_outside() {
				position_y = last_offset.y().plus(last_height)
			} else {
				position_x = last_offset.x().plus(last_width)
				position_y = last_offset.y()
			}
		}
	}
	return StaticPositionRect{
		rect: css.CSSPixelRect.new(position_x.to_double(), position_y.to_double(), 0, 0)
	}
}

// InlineFormattingContext::run() and generate_line_boxes(). Float placement is
// shared with BlockFormattingContext; without intruding floats the available
// width at every block offset is the supplied inline available size.
pub fn run_inline_formatting_context(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace) InlineFormattingResult {
	return run_inline_formatting_context_internal(mut state, containing_block, mut
		containing_block_used_values, layout_mode, available_space, none)
}

fn (mut bfc BlockFormattingContext) run_inline_formatting_context_with_floats(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace) InlineFormattingResult {
	return run_inline_formatting_context_internal(mut state, containing_block, mut
		containing_block_used_values, layout_mode, available_space, bfc)
}

fn run_inline_formatting_context_internal(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) InlineFormattingResult {
	containing_block_used_values.line_boxes.clear()
	direction := containing_block.computed_values().direction()
	writing_mode := containing_block.computed_values().writing_mode()
	mut iterator := InlineLevelIterator.new(mut state, containing_block,
		containing_block_used_values, layout_mode, available_space, parent_block_context)
	mut line_builder := LineBuilder.new_with_block_context(mut state, containing_block,
		containing_block_used_values, available_space.width, direction, writing_mode,
		parent_block_context)
	mut leading_margin_from_collapsible_whitespace := CSSPixels.new(0)
	mut leading_border_from_collapsible_whitespace := CSSPixels.new(0)
	mut leading_padding_from_collapsible_whitespace := CSSPixels.new(0)
	mut absolute_boxes := []&Box{}
	mut vertical_float_clearance := CSSPixels.new(0)

	for {
		mut item := iterator.next() or { break }
		if item.is_collapsible_whitespace && (containing_block_used_values.line_boxes.len == 0
			|| containing_block_used_values.line_boxes.last().is_empty_or_ends_in_whitespace()) {
			if node := item.node {
				if node.computed_values().text_wrap_mode() == .wrap {
					next_width := iterator.next_non_whitespace_sequence_width()
					if next_width.raw_value() > 0 {
						line_builder.break_if_needed(next_width)
					}
				}
			}
			leading_margin_from_collapsible_whitespace =
				leading_margin_from_collapsible_whitespace.plus(item.margin_start)
			leading_border_from_collapsible_whitespace =
				leading_border_from_collapsible_whitespace.plus(item.border_start)
			leading_padding_from_collapsible_whitespace =
				leading_padding_from_collapsible_whitespace.plus(item.padding_start)
			continue
		}

		item.margin_start = item.margin_start.plus(leading_margin_from_collapsible_whitespace)
		leading_margin_from_collapsible_whitespace = CSSPixels.new(0)
		item.border_start = item.border_start.plus(leading_border_from_collapsible_whitespace)
		leading_border_from_collapsible_whitespace = CSSPixels.new(0)
		item.padding_start = item.padding_start.plus(leading_padding_from_collapsible_whitespace)
		leading_padding_from_collapsible_whitespace = CSSPixels.new(0)

		match item.type_ {
			.forced_break {
				line_builder.break_line(.yes, none)
				if node := item.node {
					if context := parent_block_context {
						mut mutable_context := unsafe { &BlockFormattingContext(context) }
						clear := node.computed_values().clear()
						clearance := mutable_context.clearance_y(clear,
							node.computed_values().direction(),
							containing_block_used_values.cumulative_offset().y(),
							vertical_float_clearance)
						if clear_applies_to_float(clear, .left, node.computed_values().direction()) {
							mutable_context.left_floats.current_boxes.clear()
						}
						if clear_applies_to_float(clear, .right, node.computed_values().direction()) {
							mutable_context.right_floats.current_boxes.clear()
						}
						if clearance.raw_value() > vertical_float_clearance.raw_value() {
							vertical_float_clearance = clearance
							line_builder.did_introduce_clearance(clearance)
							mutable_context.margin_state.reset()
						}
					}
				}
			}
			.element {
				node := item.node or { continue }
				box := node.as_box() or { continue }
				if containing_block.computed_values().text_wrap_mode() == .wrap {
					mut minimum_space := item.border_box_width()
					if item.margin_start.raw_value() < 0 {
						minimum_space = minimum_space.plus(item.margin_start)
					}
					if item.margin_end.raw_value() < 0 {
						minimum_space = minimum_space.plus(item.margin_end)
					}
					line_builder.break_if_needed(minimum_space)
				}
				line_builder.append_box(box, item.border_start.plus(item.padding_start),
					item.padding_end.plus(item.border_end), item.margin_start, item.margin_end)
			}
			.absolutely_positioned_element {
				node := item.node or { continue }
				if box := node.as_box() {
					absolute_boxes << box
				}
			}
			.floating_element {
				node := item.node or { continue }
				if context := parent_block_context {
					mut mutable_context := unsafe { &BlockFormattingContext(context) }
					clear := node.computed_values().clear()
					clearance := mutable_context.clearance_y(clear,
						node.computed_values().direction(),
						containing_block_used_values.cumulative_offset().y(),
						line_builder.current_block_offset_value())
					if clearance.raw_value() > line_builder.current_block_offset_value().raw_value() {
						vertical_float_clearance = css_pixels_max(vertical_float_clearance,
							clearance)
						line_builder.did_introduce_clearance(clearance)
					}
					containing_styled := unsafe { &Node(containing_block) }.as_node_with_style() or {
						continue
					}
					container_height := if available_space.height.is_definite() {
						?CSSPixels(available_space.height.to_px_or_zero())
					} else {
						?CSSPixels(none)
					}
					mutable_context.layout_floating_box(mut state, node, containing_styled,
						available_space.width.to_px_or_zero(), container_height,
						line_builder.current_block_offset_value(), line_builder)
					line_builder.recalculate_available_space()
				}
			}
			.text {
				node := item.node or { continue }
				text_node := node.as_text_node() or { continue }
				if text_node.Node.computed_values().text_wrap_mode() == .wrap {
					is_whitespace := item.is_all_whitespace
					mut next_width := CSSPixels.new(0)
					if is_whitespace {
						next_width = iterator.next_non_whitespace_sequence_width()
					}
					if is_whitespace && next_width.raw_value() > 0
						&& line_builder.break_if_needed(item.border_box_width().plus(next_width)) {
						line_builder.set_trailing_whitespace_on_previous_line()
						continue
					}
					if item.can_break_before && !is_whitespace {
						line_builder.break_if_needed(item.border_box_width())
					}
				}
				glyph_run := item.glyph_run or { continue }
				line_builder.append_text_chunk(text_node, item.offset_in_node, item.length_in_node,
					item.border_start.plus(item.padding_start),
					item.padding_end.plus(item.border_end), item.margin_start, item.margin_end,
					item.width, text_node.Node.computed_values().line_height(), glyph_run)
			}
		}
	}

	for index in 0 .. containing_block_used_values.line_boxes.len {
		containing_block_used_values.line_boxes[index].trim_trailing_whitespace()
	}
	apply_text_overflow_ellipsis(containing_block, mut containing_block_used_values.line_boxes)
	line_builder.remove_last_line_if_empty()
	if containing_block.computed_values().text_align() == .justify {
		line_count := containing_block_used_values.line_boxes.len
		for index in 0 .. line_count {
			apply_justification_to_line(containing_block.computed_values().text_justify(), mut
				containing_block_used_values.line_boxes[index], index == line_count - 1)
		}
	}
	for line_index in 0 .. containing_block_used_values.line_boxes.len {
		mut line_box := &containing_block_used_values.line_boxes[line_index]
		for fragment_index in 0 .. line_box.fragments_.len {
			fragment := line_box.fragments_[fragment_index]
			if fragment.layout_node_.is_inline_block() {
				if styled := fragment.layout_node_.as_node_with_style() {
					mut box_state := state.get_mutable(styled)
					box_state.set_content_offset(fragment.offset())
				}
			}
		}
	}
	// LibWeb records atomic inline offsets before vertical alignment updates the
	// fragments. Static-position coordinate conversion relies on that ordering.
	line_builder.update_last_line()
	if layout_mode == .normal {
		for box in absolute_boxes {
			styled := unsafe { &Node(box) }.as_node_with_style() or { continue }
			mut box_state := state.get_mutable(styled)
			box_state.set_static_position_rect(calculate_inline_static_position_rect(box,
				containing_block_used_values))
		}
	}

	mut content_width := CSSPixels.new(0)
	mut content_height := CSSPixels.new(0)
	for line_box in containing_block_used_values.line_boxes {
		content_width = css_pixels_max(content_width, line_box.width())
		content_height = content_height.plus(line_box.height())
	}
	return InlineFormattingResult{
		automatic_content_width:  content_width
		automatic_content_height: content_height
	}
}

// https://drafts.csswg.org/css-overflow-4/#text-overflow
fn apply_text_overflow_ellipsis(containing_block &BlockContainer, mut line_boxes []LineBox) {
	block_node := unsafe { &Node(containing_block) }
	block_values := if block_node.is_anonymous() {
		block := block_node.non_anonymous_containing_block() or { return }
		block.computed_values()
	} else {
		containing_block.computed_values()
	}
	if block_values.text_overflow() != .ellipsis || block_values.overflow_x() == .visible {
		return
	}

	ellipsis_code_point := u32(0x2026)
	for line_index in 0 .. line_boxes.len {
		mut line_box := unsafe { &line_boxes[line_index] }
		if !line_box.original_available_width().is_definite() {
			continue
		}
		available_width := line_box.original_available_width().to_px_or_zero()
		if line_box.inline_length().raw_value() <= available_width.raw_value()
			|| line_box.fragments_.len == 0 {
			continue
		}

		mut line_has_visible_content := false
		for fragment_index in 0 .. line_box.fragments_.len {
			mut fragment := &line_box.fragments_[fragment_index]
			fragment_start := fragment.inline_offset()
			fragment_end := fragment_start.plus(fragment.inline_length())
			if fragment_end.raw_value() <= available_width.raw_value() {
				line_has_visible_content = true
				continue
			}

			run_pointer := fragment.glyph_run() or {
				// Hiding an overflowing atomic inline to make room for the ellipsis is
				// not implemented upstream either; continue to the next text fragment.
				continue
			}
			font := run_pointer.font()
			ellipsis_width := font.glyph_width(ellipsis_code_point)
			available_in_fragment := f32(available_width.minus(fragment_start).to_double())
			max_text_width := available_in_fragment - ellipsis_width
			mut keep_count := 0
			mut last_kept_end := f32(0)
			mut glyph_block_offset := f32(0)
			for glyph in run_pointer.glyphs_ {
				glyph_end := glyph.position.x + glyph.advance
				if glyph_end > max_text_width && (keep_count > 0 || line_has_visible_content) {
					break
				}
				keep_count++
				last_kept_end = glyph_end
				glyph_block_offset = glyph.position.y
			}

			mut run := unsafe { &platform.GlyphRun(run_pointer) }
			run.invalidate_replay_data()
			run.glyphs_ = run.glyphs_[..keep_count].clone()
			ellipsis_run := platform.shape_text(0, 0, '…', font, .common)
			if ellipsis_run.glyphs_.len > 0 {
				mut ellipsis_glyph := ellipsis_run.glyphs_[0]
				ellipsis_glyph.code_point = ellipsis_code_point
				ellipsis_glyph.position = platform.GlyphPosition{
					x: last_kept_end
					y: glyph_block_offset
				}
				ellipsis_glyph.advance = ellipsis_width
				ellipsis_glyph.length_in_code_units = 1
				run.glyphs_ << ellipsis_glyph
			}
			run.width_ = last_kept_end + ellipsis_width
			fragment.set_inline_length(CSSPixels.nearest_value_for(f64(run.width_)))

			if fragment_index + 1 < line_box.fragments_.len {
				line_box.fragments_.delete_many(fragment_index + 1,
					line_box.fragments_.len - fragment_index - 1)
			}
			line_box.inline_length_ = available_width
			break
		}
	}
}

fn apply_justification_to_line(text_justify css.TextJustify, mut line_box LineBox, is_last_line bool) {
	if text_justify == .none_ || is_last_line || line_box.has_forced_break_ {
		return
	}
	mut excess :=
		line_box.original_available_width().to_px_or_zero().minus(line_box.inline_length())
	mut whitespace_count := 0
	for fragment in line_box.fragments_ {
		if fragment.is_justifiable_whitespace() {
			whitespace_count++
			excess = excess.plus(fragment.inline_length())
		}
	}
	if whitespace_count == 0 {
		return
	}
	// C++'s CSSPixels / integral overload produces a CSSPixelFraction whose
	// conversion back to CSSPixels divides raw fixed-point values, truncating
	// the remainder rather than rounding through floating point.
	justified_space_width := CSSPixels.from_raw(excess.raw_value() / whitespace_count)
	mut running_diff := CSSPixels.new(0)
	for index in 0 .. line_box.fragments_.len {
		mut fragment := &line_box.fragments_[index]
		fragment.set_inline_offset(fragment.inline_offset().plus(running_diff))
		if fragment.is_justifiable_whitespace()
			&& fragment.inline_length().raw_value() != justified_space_width.raw_value() {
			running_diff = running_diff.plus(justified_space_width.minus(fragment.inline_length()))
			fragment.set_inline_length(justified_space_width)
		}
	}
}

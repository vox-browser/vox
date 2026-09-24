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
	return run_inline_formatting_context_internal(mut state, containing_block, mut containing_block_used_values, layout_mode, available_space, none)
}

fn (mut bfc BlockFormattingContext) run_inline_formatting_context_with_floats(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace) InlineFormattingResult {
	return run_inline_formatting_context_internal(mut state, containing_block, mut containing_block_used_values, layout_mode, available_space, bfc)
}

fn run_inline_formatting_context_internal(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) InlineFormattingResult {
	containing_block_used_values.line_boxes.clear()
	direction := containing_block.computed_values().direction()
	writing_mode := containing_block.computed_values().writing_mode()
	mut iterator := InlineLevelIterator.new(mut state, containing_block, containing_block_used_values, layout_mode, available_space, parent_block_context)
	mut line_builder := LineBuilder.new_with_block_context(mut state, containing_block, containing_block_used_values, available_space.width, direction, writing_mode, parent_block_context)
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
						clearance := mutable_context.clearance_y(clear, node.computed_values().direction(), containing_block_used_values.cumulative_offset().y(), vertical_float_clearance)
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
					line_builder.note_soft_wrap_opportunity()
					line_builder.break_if_needed(minimum_space)
				}
				line_builder.append_box(box, item.border_start.plus(item.padding_start), item.padding_end.plus(item.border_end), item.margin_start, item.margin_end)
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
					clearance := mutable_context.clearance_y(clear, node.computed_values().direction(), containing_block_used_values.cumulative_offset().y(), line_builder.current_block_offset_value())
					if clearance.raw_value() > line_builder.current_block_offset_value().raw_value() {
						vertical_float_clearance = css_pixels_max(vertical_float_clearance, clearance)
						line_builder.did_introduce_clearance(clearance)
					}
					containing_styled := unsafe { &Node(containing_block) }.as_node_with_style() or {
						continue
					}
					mut container_height := ?CSSPixels(none)
					if available_space.height.is_definite() {
						container_height = available_space.height.to_px_or_zero()
					}
					mutable_context.layout_floating_box(mut state, node, containing_styled, available_space.width.to_px_or_zero(), container_height, line_builder.current_block_offset_value(), line_builder)
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
					if is_whitespace && next_width.raw_value() > 0 {
						line_builder.note_soft_wrap_opportunity()
						if line_builder.break_if_needed(item.border_box_width().plus(next_width)) {
							line_builder.set_trailing_whitespace_on_previous_line()
							continue
						}
					}
					if item.can_break_before && !is_whitespace {
						line_builder.note_soft_wrap_opportunity()
						line_builder.break_if_needed(item.border_box_width())
					}
				}
				glyph_run := item.glyph_run or { continue }
				line_builder.append_text_chunk_with_trailing_whitespace(text_node, item.offset_in_node, item.length_in_node, item.border_start.plus(item.padding_start), item.padding_end.plus(item.border_end), item.margin_start, item.margin_end, item.width, text_node.Node.computed_values().line_height(), glyph_run, item.trailing_whitespace)
			}
		}
	}

	for index in 0 .. containing_block_used_values.line_boxes.len {
		containing_block_used_values.line_boxes[index].trim_trailing_whitespace()
	}
	apply_text_overflow_ellipsis(containing_block, mut containing_block_used_values.line_boxes)
	line_builder.remove_last_line_if_empty()
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
	apply_line_clamp(containing_block, mut containing_block_used_values, mut state, layout_mode, available_space, parent_block_context)
	if containing_block.computed_values().text_align() == .justify {
		line_count := containing_block_used_values.line_boxes.len
		for index in 0 .. line_count {
			is_last_line := index == line_count - 1
				&& containing_block_used_values.line_boxes[index].inline_length_before_block_ellipsis_ == none
			apply_justification_to_line(containing_block.computed_values().text_justify(), mut containing_block_used_values.line_boxes[index], is_last_line)
		}
	}
	// Rust InlineContent finalization publishes both the packed glyph replay
	// data and conservative CSS-pixel bounds after ellipsis, clamping, merging,
	// and justification have made their last changes to the line fragments.
	for line_index in 0 .. containing_block_used_values.line_boxes.len {
		mut line_box := &containing_block_used_values.line_boxes[line_index]
		for fragment_index in 0 .. line_box.fragments_.len {
			if run_pointer := line_box.fragments_[fragment_index].glyph_run() {
				mut run := unsafe { &platform.GlyphRun(run_pointer) }
				run.refresh_replay_data()
			}
		}
	}
	if layout_mode == .normal {
		for box in absolute_boxes {
			styled := unsafe { &Node(box) }.as_node_with_style() or { continue }
			mut box_state := state.get_mutable(styled)
			box_state.set_static_position_rect(calculate_inline_static_position_rect(box, containing_block_used_values))
		}
	}

	mut content_width := CSSPixels.new(0)
	mut content_height := CSSPixels.new(0)
	for line_box in containing_block_used_values.line_boxes {
		content_width = css_pixels_max(content_width, line_box.width())
		content_height = content_height.plus(line_box.height())
	}
	return InlineFormattingResult{
		automatic_content_width: content_width
		automatic_content_height: content_height
	}
}

fn line_clamp_is_active(computed &css.ComputedProperties) bool {
	if computed.continue_value() == .collapse {
		return true
	}
	return computed.continue_value() == .webkit_legacy
		&& computed.display_before_box_type_transformation().is_webkit_box_inside()
		&& computed.webkit_box_orient() == .vertical
}

fn line_clamp_subtree_contains_line(node &Node) bool {
	if node.is_text_node() {
		text := node.as_text_node() or { return false }
		return text.text_for_rendering().trim_space().len > 0
	}
	if node.is_break_node() || node.is_atomic_inline()
		|| (node.is_anonymous() && node.children_are_inline()) {
		return true
	}
	if node.is_floating() || node.is_absolutely_positioned() {
		return false
	}
	if styled := node.as_node_with_style() {
		if creates_block_formatting_context(styled) || !node.display().is_flow_inside() {
			return false
		}
	}
	for child in node.children() {
		if line_clamp_subtree_contains_line(child) {
			return true
		}
	}
	return false
}

fn (bfc &BlockFormattingContext) line_clamp_has_future_content(anchor &Node) bool {
	root := bfc.root or { return false }
	mut node := anchor
	for !layout_nodes_same(node, root) {
		mut sibling := node.next_sibling()
		for sibling != none {
			candidate := sibling or { break }
			if !candidate.is_absolutely_positioned() && !candidate.is_floating()
				&& line_clamp_subtree_contains_line(candidate) {
				return true
			}
			sibling = candidate.next_sibling()
		}
		node = node.parent() or { break }
	}
	return false
}

fn (mut bfc BlockFormattingContext) apply_line_clamp_to_lines(containing_block &BlockContainer,
	mut used UsedValues, mut state LayoutState) {
	maximum := bfc.max_lines or { return }
	if maximum <= 0 {
		bfc.line_clamp_reached_ = used.line_boxes.len > 0
		if root := bfc.root {
			if styled := root.as_node_with_style() {
				mut root_used := state.get_mutable(styled)
				root_used.set_has_line_clamp_point(bfc.line_clamp_reached_)
			}
		}
		for line in used.line_boxes {
			for fragment in line.fragments_ {
				mark_line_clamp_fragment_invisible(mut state, fragment)
			}
		}
		used.line_boxes.clear()
		return
	}
	if bfc.line_clamp_reached() {
		for line in used.line_boxes {
			for fragment in line.fragments_ {
				mark_line_clamp_fragment_invisible(mut state, fragment)
			}
		}
		used.line_boxes.clear()
		return
	}
	for line_index in 0 .. used.line_boxes.len {
		bfc.line_clamp_line_count++
		if bfc.line_clamp_line_count != maximum {
			continue
		}
		line := used.line_boxes[line_index]
		anchor := if line.fragments_.len > 0 {
			line.fragments_.last().layout_node()
		} else {
			unsafe { &Node(containing_block) }
		}
		has_immediate_continuation := line_index + 1 < used.line_boxes.len
		if !has_immediate_continuation && !bfc.line_clamp_has_future_content(anchor) {
			continue
		}
		bfc.line_clamp_reached_ = true
		if root := bfc.root {
			if styled := root.as_node_with_style() {
				mut root_used := state.get_mutable(styled)
				root_used.set_has_line_clamp_point(true)
			}
		}
		for hidden_line_index := line_index + 1; hidden_line_index < used.line_boxes.len; hidden_line_index++ {
			for fragment in used.line_boxes[hidden_line_index].fragments_ {
				mark_line_clamp_fragment_invisible(mut state, fragment)
			}
		}
		used.line_boxes = used.line_boxes[..line_index + 1].clone()
		apply_block_ellipsis(containing_block, mut used, mut state)
		return
	}
}

fn automatic_line_clamp_limit(containing_block &BlockContainer, used &UsedValues,
	available_space AvailableSpace) ?CSSPixels {
	if available_space.height.is_definite() {
		return available_space.height.to_px_or_zero()
	}
	node := unsafe { &Node(containing_block) }
	computed := containing_block.computed_values()
	max_height := computed.size_value(.max_height)
	if max_height.is_auto() || max_height.is_none() {
		return none
	}
	mut percentage_basis := CSSPixels.new(0)
	if max_height.contains_percentage() {
		containing := used.containing_block_used_values() or { return none }
		if !containing.has_definite_height() {
			return none
		}
		percentage_basis = containing.content_height()
	}
	mut limit := resolve_layout_content_size(node, max_height, percentage_basis, used, false) or { return none }
	min_height := computed.size_value(.min_height)
	if !min_height.is_auto() && !min_height.is_none() {
		if minimum := resolve_layout_content_size(node, min_height, percentage_basis, used, false) {
			limit = css_pixels_max(limit, minimum)
		}
	}
	return limit
}

fn mark_line_clamp_fragment_invisible(mut state LayoutState, fragment &LineBoxFragment) {
	if !fragment.is_atomic_inline() {
		return
	}
	styled := fragment.layout_node().as_node_with_style() or { return }
	mut used := state.get_mutable(styled)
	used.set_invisible_for_line_clamp(true)
}

fn truncate_line_for_block_ellipsis(mut state LayoutState, mut line LineBox,
	available_for_content CSSPixels) CSSPixels {
	mut retained := CSSPixels.new(0)
	mut truncate_following := false
	for index in 0 .. line.fragments_.len {
		mut fragment := &line.fragments_[index]
		if truncate_following || fragment.inline_offset().raw_value() >= available_for_content.raw_value() {
			fragment.set_fully_truncated(true)
			mark_line_clamp_fragment_invisible(mut state, fragment)
			truncate_following = true
			continue
		}
		fragment_end := fragment.inline_offset().plus(fragment.inline_length())
		if fragment_end.raw_value() <= available_for_content.raw_value() {
			retained = css_pixels_max(retained, fragment_end)
			continue
		}
		run_pointer := fragment.glyph_run() or {
			fragment.set_fully_truncated(true)
			mark_line_clamp_fragment_invisible(mut state, fragment)
			truncate_following = true
			continue
		}
		available := available_for_content.minus(fragment.inline_offset())
		mut keep_count := 0
		mut kept_code_units := 0
		mut kept_width := f32(0)
		for glyph in run_pointer.glyphs_ {
			glyph_end := glyph.position.x + glyph.advance
			if glyph_end > f32(available.to_double()) {
				break
			}
			keep_count++
			kept_code_units += glyph.length_in_code_units
			kept_width = glyph_end
		}
		if keep_count == 0 {
			fragment.set_fully_truncated(true)
			mark_line_clamp_fragment_invisible(mut state, fragment)
		} else {
			mut run := unsafe { &platform.GlyphRun(run_pointer) }
			run.invalidate_replay_data()
			run.glyphs_ = run.glyphs_[..keep_count].clone()
			run.width_ = kept_width
			fragment.length_in_code_units_ = kept_code_units
			fragment.set_inline_length(CSSPixels.nearest_value_for(f64(kept_width)))
			retained = fragment.inline_offset().plus(fragment.inline_length())
		}
		truncate_following = true
	}
	return retained
}

fn block_ellipsis_font(style_source &Node, ellipsis string) &platform.Font {
	units := utf16_code_units_for_line_box(ellipsis)
	if units.len == 0 {
		return style_source.first_available_font()
	}
	code_point := code_point_at_utf16(units, 0)
	cascade := style_source.font_list()
	for index, entry in cascade.fonts {
		mut covers_code_point := entry.unicode_ranges.len == 0
		for range_ in entry.unicode_ranges {
			if range_.start <= code_point && code_point <= range_.end {
				covers_code_point = true
				break
			}
		}
		if !covers_code_point {
			continue
		}
		font := text_node_chunk_platform_font(entry.font)
		if font.contains_glyph(code_point) {
			if cascade.fallback_is_invisible_for_code_point_through(code_point, index) {
				return text_node_chunk_invisible_font(font)
			}
			return font
		}
	}
	if cascade.last_resort_font != unsafe { nil } {
		font := text_node_chunk_platform_font(*cascade.last_resort_font)
		if cascade.fallback_is_invisible_for_code_point_through(code_point, cascade.fonts.len) {
			return text_node_chunk_invisible_font(font)
		}
		return font
	}
	return style_source.first_available_font()
}

fn apply_block_ellipsis(containing_block &BlockContainer, mut used UsedValues,
	mut state LayoutState) {
	if used.line_boxes.len == 0 {
		return
	}
	ellipsis := match containing_block.computed_values().block_ellipsis().type_ {
		.no_ellipsis {
			return
		}
		.auto_ { '…' }
		.string { containing_block.computed_values().block_ellipsis().text() }
	}
	if ellipsis.len == 0 {
		return
	}
	mut line := &used.line_boxes[used.line_boxes.len - 1]
	line.inline_length_before_block_ellipsis_ = line.inline_length()
	line.trim_trailing_whitespace()
	style_source := unsafe { &Node(containing_block) }
	font := block_ellipsis_font(style_source, ellipsis)
	letter_spacing := resolved_text_spacing_for_node(style_source, .letter_spacing)
	word_spacing := resolved_text_spacing_for_node(style_source, .word_spacing)
	run := platform.shape_text_with_spacing(0, f32(letter_spacing.to_double()), f32(word_spacing.to_double()), ellipsis, font, .common).glyph_run
	units := utf16_code_units_for_line_box(ellipsis)
	first_code_point := if units.len > 0 { code_point_at_utf16(units, 0) } else { u32(0) }
	retained_run := if first_code_point != 0 && font.contains_glyph(first_code_point) {
		?&platform.GlyphRun(run)
	} else {
		?&platform.GlyphRun(none)
	}
	ellipsis_width := CSSPixels.nearest_value_for(f64(run.width()))
	available_width := if line.original_available_width().is_definite() {
		line.original_available_width().to_px_or_zero()
	} else {
		line.inline_length().plus(ellipsis_width)
	}
	available_for_content := css_pixels_max(CSSPixels.new(0), available_width.minus(ellipsis_width))
	mut retained := line.inline_length()
	mut displaced_at_soft_wrap := false
	if line.inline_length().raw_value() > available_for_content.raw_value() {
		for index := line.fragments_.len - 1; index >= 0; index-- {
			fragment := line.fragments_[index]
			fragment_end := fragment.inline_offset().plus(fragment.inline_length())
			if fragment.has_soft_wrap_opportunity_after()
				&& fragment_end.raw_value() <= available_for_content.raw_value() {
				retained = fragment_end
				for displaced_index := index + 1; displaced_index < line.fragments_.len; displaced_index++ {
					mut displaced := &line.fragments_[displaced_index]
					displaced.set_fully_truncated(true)
					mark_line_clamp_fragment_invisible(mut state, displaced)
				}
				displaced_at_soft_wrap = true
				break
			}
		}
	}
	if line.inline_length().raw_value() > available_for_content.raw_value()
		&& !displaced_at_soft_wrap {
		retained = truncate_line_for_block_ellipsis(mut state, mut line, available_for_content)
	}
	mut block_offset := line.bottom().minus(line.block_length())
	mut block_length := containing_block.computed_values().line_height()
	mut baseline := font_baseline_for_line_height(font.pixel_metrics(), block_length)
	for index := line.fragments_.len - 1; index >= 0; index-- {
		fragment := line.fragments_[index]
		if fragment.is_fully_truncated() {
			continue
		}
		block_offset = fragment.block_offset()
		block_length = fragment.block_length()
		baseline = fragment.baseline()
		break
	}
	mut ellipsis_offset := retained
	if line.direction_ == .rtl {
		mut ellipsis_precedes_content := true
		for index := line.fragments_.len - 1; index >= 0; index-- {
			if line.fragments_[index].is_fully_truncated() {
				continue
			}
			ellipsis_precedes_content = line.fragments_[index].current_insert_direction != .ltr
			break
		}
		if ellipsis_precedes_content {
			for index in 0 .. line.fragments_.len {
				if !line.fragments_[index].is_fully_truncated() {
					line.fragments_[index].set_inline_offset(line.fragments_[index].inline_offset().plus(ellipsis_width))
				}
			}
			ellipsis_offset = CSSPixels.new(0)
		}
	}
	mut ellipsis_layout_node := style_source.first_child() or { style_source }
	mut ellipsis_start := 0
	if line.fragments_.len > 0 {
		mut boundary_index := 0
		for index := line.fragments_.len - 1; index >= 0; index-- {
			boundary_index = index
			if !line.fragments_[index].is_fully_truncated() {
				break
			}
		}
		boundary := line.fragments_[boundary_index]
		ellipsis_layout_node = boundary.layout_node_
		ellipsis_start = if boundary.is_fully_truncated() {
			boundary.start_
		} else {
			boundary.start_ + boundary.length_in_code_units_
		}
	}
	line.fragments_ << LineBoxFragment.new_block_ellipsis(ellipsis_layout_node, style_source, ellipsis, ellipsis_start, ellipsis_offset, block_offset, ellipsis_width, block_length, baseline, line.direction_, line.writing_mode_, retained_run)
	line.inline_length_ = retained.plus(ellipsis_width)
}

fn apply_line_clamp(containing_block &BlockContainer, mut used UsedValues,
	mut state LayoutState, layout_mode LayoutMode, available_space AvailableSpace,
	parent_block_context ?&BlockFormattingContext) {
	if layout_mode == .intrinsic_sizing || !line_clamp_is_active(containing_block.computed_values()) {
		if context := parent_block_context {
			mut mutable_context := unsafe { &BlockFormattingContext(context) }
			if mutable_context.has_line_clamp() {
				mutable_context.apply_line_clamp_to_lines(containing_block, mut used, mut state)
			}
		}
		return
	}
	if context := parent_block_context {
		mut mutable_context := unsafe { &BlockFormattingContext(context) }
		if mutable_context.has_line_clamp() && mutable_context.max_lines != none {
			mutable_context.apply_line_clamp_to_lines(containing_block, mut used, mut state)
			return
		}
	}
	mut maximum := containing_block.computed_values().max_lines() or { -1 }
	if maximum < 0 {
		limit := automatic_line_clamp_limit(containing_block, used, available_space) or { return }
		if used.line_boxes.len == 0 || used.line_boxes.last().bottom().raw_value() <= limit.raw_value() {
			return
		}
		maximum = 0
		for line in used.line_boxes {
			if line.bottom().raw_value() > limit.raw_value() {
				break
			}
			maximum++
		}
	}
	if maximum >= used.line_boxes.len {
		return
	}
	used.set_has_line_clamp_point(true)
	for line_index := maximum; line_index < used.line_boxes.len; line_index++ {
		for fragment in used.line_boxes[line_index].fragments_ {
			mark_line_clamp_fragment_invisible(mut state, fragment)
		}
	}
	used.line_boxes = used.line_boxes[..maximum].clone()
	if maximum > 0 {
		apply_block_ellipsis(containing_block, mut used, mut state)
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

			for later_index := fragment_index + 1; later_index < line_box.fragments_.len; later_index++ {
				line_box.fragments_[later_index].set_fully_truncated(true)
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
		if !fragment.is_fully_truncated() && fragment.is_justifiable_whitespace() {
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
		if fragment.is_fully_truncated() {
			continue
		}
		fragment.set_inline_offset(fragment.inline_offset().plus(running_diff))
		if fragment.is_justifiable_whitespace()
			&& fragment.inline_length().raw_value() != justified_space_width.raw_value() {
			running_diff = running_diff.plus(justified_space_width.minus(fragment.inline_length()))
			fragment.set_inline_length(justified_space_width)
		}
	}
}

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

// A block-level abspos box starts below a line holding in-flow content and at
// the marker's line position otherwise; an inline-level one starts at its
// marker.
fn static_position_from_line_markers(box &Box, line_box &LineBox, containing_block_inline_size CSSPixels) ?StaticPositionRect {
	for marker in line_box.static_position_markers_ {
		if voidptr(marker.box) != voidptr(box) {
			continue
		}
		if box.computed_values().display_before_box_type_transformation().is_block_outside() {
			block_position := if marker.preceded_by_in_flow_content {
				line_box.bottom()
			} else {
				marker.offset().y()
			}
			return StaticPositionRect{
				rect: css.CSSPixelRect{
					y: block_position
					width: containing_block_inline_size
				}
			}
		}
		offset := marker.offset()
		return StaticPositionRect{
			rect: css.CSSPixelRect{
				x: offset.x()
				y: offset.y()
			}
		}
	}
	return none
}

fn calculate_inline_end_static_position_rect(containing_block &BlockContainer, containing_block_used_values &UsedValues) StaticPositionRect {
	to_physical_position := fn (writing_mode css.WritingMode, inline_position CSSPixels, block_position CSSPixels) css.CSSPixelPoint {
		if writing_mode != .horizontal_tb {
			return css.CSSPixelPoint.new(block_position, inline_position)
		}
		return css.CSSPixelPoint.new(inline_position, block_position)
	}
	writing_mode := containing_block.computed_values().writing_mode()
	if containing_block_used_values.line_boxes.len == 0 {
		return StaticPositionRect{
			rect: css.CSSPixelRect.new(0, 0, 0, 0)
		}
	}
	mut line_boxes_bottom := CSSPixels.new(0)
	for index in 0 .. containing_block_used_values.line_boxes.len {
		line_box := unsafe { &containing_block_used_values.line_boxes[index] }
		line_boxes_bottom = css_pixels_max(line_boxes_bottom, line_box.bottom())
	}
	// Read the last line and fragment in place: copies of them would be moved to
	// the heap by current V.
	last_line_box := unsafe { &containing_block_used_values.line_boxes[containing_block_used_values.line_boxes.len - 1] }
	if last_line_box.has_forced_break() || last_line_box.fragments_.len == 0 {
		position := to_physical_position(writing_mode, CSSPixels.new(0), line_boxes_bottom)
		return StaticPositionRect{
			rect: css.CSSPixelRect{
				x: position.x()
				y: position.y()
			}
		}
	}
	last_fragment := unsafe { &last_line_box.fragments_[last_line_box.fragments_.len - 1] }
	mut direction := containing_block.computed_values().direction()
	containing_node := unsafe { &Node(containing_block) }
	if containing_node.is_anonymous() {
		if parent := containing_node.parent() {
			direction = parent.computed_values().direction()
		}
	}
	inline_position := if direction == .rtl {
		last_fragment.inline_offset()
	} else {
		css_pixels_max(last_fragment.inline_offset().plus(last_fragment.inline_length()),
			last_line_box.inline_length())
	}
	position := to_physical_position(last_fragment.writing_mode(), inline_position,
		last_fragment.block_offset())
	return StaticPositionRect{
		rect: css.CSSPixelRect{
			x: position.x()
			y: position.y()
		}
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

fn run_uncached_inline_formatting_context(mut state LayoutState, containing_block &BlockContainer, mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) InlineFormattingResult {
	return run_inline_formatting_context_for_width(mut state, containing_block,
		mut containing_block_used_values, layout_mode, available_space, parent_block_context, false)
}

// Only a disposable intrinsic probe may omit vertical geometry. A closed
// horizontal subtree has no float, atomic, positioned, or clamped descendant
// whose width depends on its block position. Published APIs retain full lines.
fn intrinsic_inline_width_is_independent(node &Node) bool {
	style := node.computed_values()
	if style.writing_mode() != .horizontal_tb || style.direction() != .ltr
		|| style.text_align() == .justify || style.text_overflow() == .ellipsis {
		return false
	}
	for child in node.children() {
		if !intrinsic_inline_width_is_independent(child) { return false }
	}
	return true
}

fn measure_disposable_inline_width(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, space AvailableSpace) CSSPixels {
	root := unsafe { &Node(containing_block) }
	if (!space.width.is_min_content() && !space.width.is_max_content())
		|| !inline_layout_workspace_is_closed(root, true)
		|| !intrinsic_inline_width_is_independent(root) {
		return run_inline_formatting_context(mut state, containing_block, mut used,
			.intrinsic_sizing, space).automatic_content_width
	}
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	return run_inline_formatting_context_for_width(mut state, containing_block, mut used,
		.intrinsic_sizing, space, none, true).automatic_content_width
}

fn run_inline_formatting_context_for_width(mut state LayoutState, containing_block &BlockContainer,
	mut containing_block_used_values UsedValues, layout_mode LayoutMode, available_space AvailableSpace,
	parent_block_context ?&BlockFormattingContext, width_only bool) InlineFormattingResult {
	containing_block_used_values.clear_line_boxes()
	if inline_context_has_only_discarded_text(containing_block) {
		containing_block_used_values.set_inline_end_static_position_rect(StaticPositionRect{})
		return InlineFormattingResult{}
	}
	direction := containing_block.computed_values().direction()
	writing_mode := containing_block.computed_values().writing_mode()
	mut item_buffers := acquire_inline_item_buffers(unsafe { &Node(containing_block) }.document())
	mut iterator := new_inline_iterator_with_item_storage(mut state, containing_block, containing_block_used_values, layout_mode, available_space, parent_block_context, item_buffers.arena)
	// This iterator's item records are consumed by value. Published line
	// fragments retain their own node and glyph references, so the temporary
	// outer item buffer has no owner after this formatting run completes.
	defer {
		if item_buffers.arena == unsafe { nil } { unsafe { iterator.items.free() } }
		item_buffers.finish()
	}
	mut line_builder := LineBuilder.new_with_block_context(mut state, containing_block, containing_block_used_values, available_space.width, direction, writing_mode, parent_block_context)
	line_builder.intrinsic_width_only = width_only
	mut leading_margin_from_collapsible_whitespace := CSSPixels.new(0)
	mut leading_border_from_collapsible_whitespace := CSSPixels.new(0)
	mut leading_padding_from_collapsible_whitespace := CSSPixels.new(0)
	mut absolute_boxes := []&Box{}
	mut vertical_float_clearance := CSSPixels.new(0)
	mut previous_text_item_allows_overflow_break_after := false

	for {
		mut item := iterator.next() or { break }
		can_break_after_previous_overflow_item := previous_text_item_allows_overflow_break_after
		previous_text_item_allows_overflow_break_after = false
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
			if node := item.node {
				if node.document().font_rendering_policy() == .chromium {
					line_builder.append_inline_end_edges(item.border_end.plus(item.padding_end),
						item.margin_end)
				}
			}
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
			.block_level_box {
				node := item.node or { continue }
				box := node.as_box() or { continue }
				// Inline start-edge box-model metrics cannot attach to the block;
				// retain them for the next inline item after the interruption.
				leading_margin_from_collapsible_whitespace =
					leading_margin_from_collapsible_whitespace.plus(item.margin_start)
				leading_border_from_collapsible_whitespace =
					leading_border_from_collapsible_whitespace.plus(item.border_start)
				leading_padding_from_collapsible_whitespace =
					leading_padding_from_collapsible_whitespace.plus(item.padding_start)
				line_builder.finish_current_line_before_block_level_box()
				if context := parent_block_context {
					mut mutable_context := unsafe { &BlockFormattingContext(context) }
					mutable_context.layout_interrupting_block_inside_inline_context(mut state, box,
						containing_block, available_space, mut line_builder)
				}
			}
			.absolutely_positioned_element {
				node := item.node or { continue }
				if box := node.as_box() {
					// Enclosing inline boxes' start edges arrive either still unattached
					// in the iterator or restashed onto this item from a skipped
					// collapsible whitespace chunk.
					preceded_by_inline_box_start_edges := item.preceded_by_unattached_inline_start_edges
						|| item.margin_start.raw_value() != 0 || item.border_start.raw_value() != 0
						|| item.padding_start.raw_value() != 0
					line_builder.append_static_position_marker(box, preceded_by_inline_box_start_edges)
					absolute_boxes << box
				}
			}
			.floating_element {
				node := item.node or { continue }
				if context := parent_block_context {
					mut mutable_context := unsafe { &BlockFormattingContext(context) }
					line_builder.commit_pending_margin_before_float()
					clear := node.computed_values().clear()
					clearance := mutable_context.clearance_y(clear, node.computed_values().direction(), containing_block_used_values.cumulative_offset().y(), line_builder.current_block_offset_value())
					mut float_block_offset := line_builder.current_block_offset_value()
					if clearance.raw_value() > line_builder.current_block_offset_value().raw_value() {
						if node.document().font_rendering_policy() == .chromium {
							// CSS 2.1 9.5.1 constrains a float by earlier line boxes only.
							// Blink moves just the cleared float, so following inline
							// content can still share lines beside the earlier floats.
							float_block_offset = clearance
						} else {
							vertical_float_clearance = css_pixels_max(vertical_float_clearance, clearance)
							line_builder.did_introduce_clearance(clearance)
							float_block_offset = line_builder.current_block_offset_value()
						}
					}
					containing_styled := unsafe { &Node(containing_block) }.as_node_with_style() or {
						continue
					}
					mut container_height := ?CSSPixels(none)
					if available_space.height.is_definite() {
						container_height = available_space.height.to_px_or_zero()
					}
					mutable_context.layout_floating_box(mut state, node, containing_styled, available_space.width.to_px_or_zero(), container_height, float_block_offset, line_builder)
					line_builder.recalculate_available_space()
				}
			}
			.text {
				node := item.node or { continue }
				text_node := node.as_text_node() or { continue }
				style := text_node.Node.computed_values()
				if style.text_wrap_mode() == .wrap {
					is_whitespace := item.is_all_whitespace
					mut next_width := CSSPixels.new(0)
					if is_whitespace {
						next_width = iterator.next_non_whitespace_sequence_width()
					}
					if is_whitespace && next_width.raw_value() > 0 {
						line_builder.note_soft_wrap_opportunity()
						sequence_width := if node.document().font_rendering_policy() == .chromium {
							line_builder.projected_text_sequence_width_for_line_break(item,
								iterator.next_non_whitespace_sequence_items())
						} else { item.border_box_width().plus(next_width) }
						remaining := line_builder.remaining_width_for_overflow_break() or { CSSPixels.new(0) }
						can_hyphenate := available_space.width.is_definite()
							&& sequence_width.raw_value() > remaining.raw_value()
							&& iterator.next_word_can_hyphenate(remaining.minus(item.border_box_width()))
						broke_line := if can_hyphenate {
							false
						} else if iterator.next_non_whitespace_text_allows_overflow_break() {
							line_builder.break_if_needed_before_overflow_breakable_item(sequence_width)
						} else {
							line_builder.break_if_needed(sequence_width)
						}
						if broke_line {
							line_builder.set_trailing_whitespace_on_previous_line()
							continue
						}
					}
					overflow_break_allowed := !is_whitespace
						&& overflow_break_applies_to_style(style, available_space.width)
					can_break_before_item := item.can_break_before
						|| (can_break_after_previous_overflow_item && !overflow_break_allowed)
						|| (containing_block_used_values.line_boxes.len > 0
						&& containing_block_used_values.line_boxes.last().ends_in_preserved_whitespace())
					if !is_whitespace && style.hyphens() == .auto_ {
						break_automatically_hyphenated_item(mut line_builder, mut item,
							iterator.next_glued_text_items())
					}
					if can_break_before_item && !is_whitespace {
						glued := if node.document().font_rendering_policy() == .chromium {
							iterator.next_glued_text_items()
						} else {
							[]InlineLevelItem{}
						}
						projected_width := line_builder.projected_text_sequence_width_for_line_break(item, glued)
						line_builder.note_soft_wrap_opportunity()
						if overflow_break_allowed {
							line_builder.break_if_needed_before_overflow_breakable_item(projected_width)
						} else {
							line_builder.break_if_needed(projected_width)
						}
					}
					if overflow_break_allowed {
						break_overflowing_text_item(mut line_builder, mut item)
						previous_text_item_allows_overflow_break_after = true
					}
				}
				line_builder.append_text_item(item, style.line_height())
			}
		}
	}

	if !unsafe { &Node(containing_block) }.is_list_item_marker_box() {
	for index in 0 .. containing_block_used_values.line_boxes.len {
		containing_block_used_values.line_boxes[index].trim_trailing_whitespace()
	}
	}
	if width_only {
		line_builder.remove_last_line_if_empty()
		mut content_width := line_builder.intrinsic_completed_width
		for line_box in containing_block_used_values.line_boxes {
			content_width = css_pixels_max(content_width, line_box.width())
		}
		return InlineFormattingResult{ automatic_content_width: content_width }
	}
	apply_text_overflow_ellipsis(containing_block, mut containing_block_used_values.line_boxes)
	// Upstream finalizes the last line and resolves static positions before it
	// removes a trailing empty line. Keep the finalized markers of such a line.
	mut removed_marker_lines := []LineBox{}
	if containing_block_used_values.line_boxes.len > 0
		&& containing_block_used_values.line_boxes.last().is_empty()
		&& containing_block_used_values.line_boxes.last().static_position_markers_.len > 0 {
		line_builder.update_last_line()
		removed_marker_lines << containing_block_used_values.line_boxes.last()
	}
	line_builder.remove_last_line_if_empty()
	// Final text and baseline alignment must reach atomic inline used values:
	// escaping abspos descendants convert their static position through them.
	line_builder.update_last_line()
	for line_index in 0 .. containing_block_used_values.line_boxes.len {
		mut line_box := &containing_block_used_values.line_boxes[line_index]
		for fragment_index in 0 .. line_box.fragments_.len {
			fragment := line_box.fragments_[fragment_index]
			if fragment.layout_node_.is_inline_block() || fragment.layout_node_.is_list_item_marker_box() {
				if styled := fragment.layout_node_.as_node_with_style() {
					mut box_state := state.get_mutable(styled)
					if fragment.layout_node_.is_list_item_marker_box() {
						box_state.set_containing_block_used_values(containing_block_used_values)
					}
					box_state.set_content_offset(fragment.offset())
				}
			}
		}
	}
	containing_block_used_values.set_inline_end_static_position_rect(calculate_inline_end_static_position_rect(containing_block,
		containing_block_used_values))
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
		containing_direction := containing_block.computed_values().direction()
		containing_block_inline_size := containing_block_used_values.content_width()
		for box in absolute_boxes {
			styled := unsafe { &Node(box) }.as_node_with_style() or { continue }
			mut box_state := state.get_mutable(styled)
			mut static_position_rect := StaticPositionRect{}
			mut found_marker := false
			for line_box in containing_block_used_values.line_boxes {
				if position := static_position_from_line_markers(box, line_box,
					containing_block_inline_size) {
					static_position_rect = position
					found_marker = true
					break
				}
			}
			if !found_marker {
				for line_box in removed_marker_lines {
					if position := static_position_from_line_markers(box, line_box,
						containing_block_inline_size) {
						static_position_rect = position
						break
					}
				}
			}
			if containing_direction == .rtl {
				if writing_mode == .horizontal_tb {
					static_position_rect.horizontal_alignment = .end
				} else {
					static_position_rect.vertical_alignment = .end
				}
			}
			box_state.set_static_position_rect(static_position_rect)
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

fn break_overflowing_text_item(mut line_builder LineBuilder, mut item InlineLevelItem) {
	for {
		remaining_width := line_builder.remaining_width_for_overflow_break() or { return }
		if line_builder.projected_text_sequence_width(item, []).raw_value() <= remaining_width.raw_value() {
			return
		}
		line_is_empty := line_builder.current_line_is_empty()
		if line_is_empty && line_builder.current_line_has_no_space_left_by_floats() {
			line_builder.break_line(.no, none)
			continue
		}
		prefix, remainder := item.split_for_overflow_break(remaining_width, line_is_empty) or {
			if line_is_empty {
				return
			}
			line_builder.note_soft_wrap_opportunity()
			line_builder.break_line(.no, item.border_box_width())
			continue
		}
		item = remainder
		line_builder.append_text_item(prefix, (prefix.node or { return }).computed_values().line_height())
		line_builder.note_soft_wrap_opportunity()
		line_builder.break_line(.no, none)
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
	mut node := unsafe { anchor }
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
	used.ensure_mutable_line_boxes()
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

fn block_ellipsis_font_for_code_point(cascade &css.FontCascadeList, code_point u32) &platform.Font {
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
		font := text_node_chunk_platform_font(&cascade.fonts[index].font)
		if font.contains_glyph(code_point) {
			if cascade.fallback_is_invisible_for_code_point_through(code_point, index) {
				return text_node_chunk_invisible_font(font)
			}
			return font
		}
	}
	if cascade.last_resort_font != unsafe { nil } {
		mut font := text_node_chunk_platform_font(cascade.last_resort_font)
		// FontCascadeList may use the same concrete face as both an authored
		// entry and its last resort. Preserve that handle identity just like the
		// text chunker so adjacent literal text and a block ellipsis remain one
		// replayable shaped run even when the face has no glyph for the ellipsis.
		for index in 0 .. cascade.fonts.len {
			candidate := text_node_chunk_platform_font(&cascade.fonts[index].font)
			if candidate.has_same_identity(font) {
				font = candidate
				break
			}
		}
		if cascade.fallback_is_invisible_for_code_point_through(code_point, cascade.fonts.len) {
			return text_node_chunk_invisible_font(font)
		}
		return font
	}
	return text_node_chunk_platform_font(&cascade.fonts[0].font)
}

fn block_ellipsis_font(style_source &Node, ellipsis string) &platform.Font {
	units := utf16_code_units_for_line_box(ellipsis)
	if units.len == 0 {
		return style_source.first_available_font()
	}
	return block_ellipsis_font_for_code_point(style_source.font_list(), code_point_at_utf16(units,
		0))
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
	used.ensure_mutable_line_boxes()
	mut line := &used.line_boxes[used.line_boxes.len - 1]
	line.inline_length_before_block_ellipsis_ = line.inline_length()
	line.trim_trailing_whitespace()
	style_source := unsafe { &Node(containing_block) }
	font := block_ellipsis_font(style_source, ellipsis)
	letter_spacing := resolved_text_spacing_for_shaping(style_source, .letter_spacing)
	word_spacing := resolved_text_spacing_for_shaping(style_source, .word_spacing)
	run := platform.shape_text_with_spacing(0, f32(letter_spacing), f32(word_spacing), ellipsis, font, .common).glyph_run
	ellipsis_width := shaped_inline_width(run, 0)
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
	line.fragments_ << LineBoxFragment.new_block_ellipsis(ellipsis_layout_node, style_source, ellipsis, ellipsis_start, ellipsis_offset, block_offset, ellipsis_width, block_length, baseline, line.direction_, line.writing_mode_, ?&platform.GlyphRun(run))
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
			line_box.clamp_static_position_markers_to_inline_length()
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
			diff := justified_space_width.minus(fragment.inline_length())
			running_diff = running_diff.plus(diff)
			// This compares against the fragment's already shifted offset,
			// matching upstream's ordering.
			for mut marker in line_box.static_position_markers_ {
				if marker.inline_offset.raw_value() > fragment.inline_offset().raw_value() {
					marker.inline_offset = marker.inline_offset.plus(diff)
				}
			}
			fragment.set_inline_length(justified_space_width)
		}
	}
}

// Blink measures the whole unbreakable sequence at a soft wrap opportunity,
// including following text items that begin without one, such as the
// `&nbsp;` and `[Reply]` text nodes after 4chan's thread status icon.
fn (iterator &InlineLevelIterator) next_glued_text_items() []InlineLevelItem {
	mut end := iterator.next_item_index
	for end < iterator.items.len {
		item := iterator.items[end]
		if item.type_ != .text || item.can_break_before || item.is_all_whitespace {
			break
		}
		end++
	}
	return iterator.items[iterator.next_item_index..end]
}

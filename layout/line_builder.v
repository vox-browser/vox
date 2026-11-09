// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import math
import platform

pub enum ForcedLineBreak {
	no
	yes
}

struct LineRelativeAlignedSubtreeRoot {
	root      &Node = unsafe { nil }
	alignment css.VerticalAlign
}

struct LineRelativeAlignedSubtree {
	root      &Node = unsafe { nil }
	alignment css.VerticalAlign
mut:
	block_start CSSPixels
	block_end   CSSPixels
	shift       CSSPixels
}

// LineBuilder owns line creation, overflow breaks, indentation, fragment
// alignment and baseline geometry. Float intrusion is supplied as the
// available width; when float layout is absent this is the containing width.
@[heap]
pub struct LineBuilder {
mut:
	layout_state                     &LayoutState = unsafe { nil }
	containing_block                 &BlockContainer = unsafe { nil }
	containing_block_used_values     &UsedValues = unsafe { nil }
	available_width_for_current_line AvailableSize = AvailableSize.make_indefinite()
	available_width                  AvailableSize = AvailableSize.make_indefinite()
	current_block_offset             CSSPixels
	max_height_on_current_line       CSSPixels
	text_indent                      CSSPixels
	text_indent_hanging              bool
	text_indent_each_line            bool
	direction                        css.Direction = .ltr
	writing_mode                     css.WritingMode = .horizontal_tb
	last_line_needs_update           bool
	should_advance_to_last_line_box_block_end bool
	parent_block_context             ?&BlockFormattingContext
	containing_block_root_offset     CSSPixelPoint
	current_line_inline_offset       CSSPixels
	current_line_committed_pending_margin bool
	pending_margin_follows_block_level_box bool
	intrinsic_width_only bool
	intrinsic_completed_width CSSPixels
}

pub fn LineBuilder.new(mut layout_state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, available_width AvailableSize, direction css.Direction, writing_mode css.WritingMode) &LineBuilder {
	return LineBuilder.new_with_block_context(mut layout_state, containing_block, containing_block_used_values, available_width, direction, writing_mode, none)
}

fn LineBuilder.new_with_block_context(mut layout_state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, available_width AvailableSize, direction css.Direction, writing_mode css.WritingMode, parent_block_context ?&BlockFormattingContext) &LineBuilder {
	computed := containing_block.computed_values()
	indent := computed.text_indent()
	mut text_indent := CSSPixels.new(0)
	// An absolute zero has no font, viewport or container dependency. Keep
	// the existing context and font-metric path for every other indent.
	if !indent.length_percentage.is_length()
		|| !indent.length_percentage.length().is_absolute()
		|| indent.length_percentage.length().raw_value() != 0 {
		mut context :=
			css.LengthResolutionContext.for_document(unsafe { &Node(containing_block) }.document())
		font_size := computed.font_size()
		font_metrics := layout_font_metrics_for_node(unsafe { &Node(containing_block) })
		context.font_metrics.font_size = font_size
		context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(font_metrics.x_height))
		context.font_metrics.cap_height = font_size.scaled(0.75)
		context.font_metrics.zero_advance =
			CSSPixels.nearest_value_for(f64(font_metrics.advance_of_ascii_zero))
		context.font_metrics.line_height = computed.line_height()
		text_indent = indent.length_percentage.to_px(context, containing_block_used_values.content_width())
	}
	mut builder := &LineBuilder{
		layout_state: layout_state
		containing_block: containing_block
		containing_block_used_values: containing_block_used_values
		available_width: available_width
		text_indent: text_indent
		text_indent_hanging: indent.hanging
		text_indent_each_line: indent.each_line
		direction: direction
		writing_mode: writing_mode
		parent_block_context: parent_block_context
		containing_block_root_offset: containing_block_used_values.cumulative_offset()
	}
	builder.begin_new_line(false, true, .no)
	return builder
}

pub fn (mut builder LineBuilder) break_line(forced_break ForcedLineBreak, next_item_width ?CSSPixels) {
	mut last_line_box := builder.ensure_last_line_box()
	last_line_box.has_break_ = true
	last_line_box.has_forced_break_ = forced_break == .yes
	builder.last_line_needs_update = true
	builder.update_last_line()
	mut break_count := 0
	for {
		builder.append_new_line_box()
		builder.begin_new_line(true, break_count == 0, forced_break)
		break_count++
		current_line_height := css_pixels_max(builder.max_height_on_current_line,
			builder.containing_block.computed_values().line_height())
		if !builder.any_floats_intrude_in_block_range(builder.current_block_offset,
			builder.current_block_offset.plus(current_line_height)) {
			break
		}
		if !builder.can_fit_new_line_at_block_offset(builder.current_block_offset,
			builder.containing_block.computed_values().line_height()) {
			continue
		}
		if width := next_item_width {
			if builder.available_width_for_current_line.is_less_than_px(width) {
				continue
			}
		}
		break
	}
}

// A disposable width probe needs only the current line and its predecessor:
// the caller can still mark the predecessor's trailing whitespace after a
// break. Retire older lines through the same trimming path as finalization,
// and reuse their fragment storage instead of retaining every word's line.
fn (mut builder LineBuilder) append_new_line_box() {
	mut used := builder.containing_block_used_values
	if !builder.intrinsic_width_only || used.line_boxes.len < 2 {
		used.line_boxes << LineBox.new(builder.direction, builder.writing_mode)
		return
	}
	assert used.line_boxes.len == 2
	used.line_boxes[0].trim_trailing_whitespace()
	builder.intrinsic_completed_width = css_pixels_max(builder.intrinsic_completed_width,
		used.line_boxes[0].width())
	// Transfer this buffer to the replacement line; neither retained line may
	// keep an alias after the two assignments below.
	mut fragments := unsafe { used.line_boxes[0].fragments_ }
	fragments.clear()
	used.line_boxes[0] = used.line_boxes[1]
	used.line_boxes[1] = LineBox{
		direction_: builder.direction
		writing_mode_: builder.writing_mode
		fragments_: fragments
	}
}

// End the current inline line before an in-flow block child. The line is a
// forced-break boundary for alignment and justification, but an already-empty
// line does not acquire a strut merely because a block follows it.
fn (mut builder LineBuilder) finish_current_line_before_block_level_box() {
	if builder.containing_block_used_values.line_boxes.len == 0
		|| builder.containing_block_used_values.line_boxes.last().is_empty() {
		return
	}
	mut last_line := builder.ensure_last_line_box()
	last_line.has_break_ = true
	last_line.has_forced_break_ = true
	builder.last_line_needs_update = true
	builder.update_last_line()
	builder.containing_block_used_values.line_boxes << LineBox.new(builder.direction,
		builder.writing_mode)
	builder.begin_new_line(true, true, .yes)
}

// Represent an interrupting block as the sole fragment on a zero-height line.
// Its own used values carry the actual geometry; the line's bottom advances the
// following inline content past the block and its collapsed flow position.
fn (mut builder LineBuilder) append_block_level_box(box &Box, block_bottom CSSPixels, block_bottom_margin CSSPixels) {
	styled := unsafe { &Node(box) }.as_node_with_style() or { return }
	mut box_state := builder.layout_state.get_mutable(styled)
	mut line_box := builder.ensure_last_line_box()
	if line_box.fragments_.len != 0 {
		return
	}
	is_horizontal := builder.writing_mode == .horizontal_tb
	inline_offset := if is_horizontal { box_state.offset.x() } else { box_state.offset.y() }
	block_offset := if is_horizontal { box_state.offset.y() } else { box_state.offset.x() }
	inline_length := if is_horizontal { box_state.content_width() } else { box_state.content_height() }
	block_length := if is_horizontal { box_state.content_height() } else { box_state.content_width() }
	line_box.fragments_ << LineBoxFragment.new(unsafe { &Node(box) }, 0, 0, inline_offset,
		block_offset, inline_length, block_length, box_state.border_box_top(), builder.direction,
		builder.writing_mode, none)
	line_box.inline_length_ = if is_horizontal {
		box_state.margin_box_width()
	} else {
		box_state.margin_box_height()
	}
	line_box.block_length_ = CSSPixels.new(0)
	line_box.bottom_ = block_bottom
	line_box.baseline_ = CSSPixels.new(0)
	line_box.font_box_baseline_ = none
	line_box.has_block_level_box_ = true
	line_box.block_level_box_bottom_margin_ = block_bottom_margin
	line_box.has_break_ = true
	line_box.has_forced_break_ = true
	box_state.containing_line_box_fragment = LineBoxFragmentCoordinate{
		line_box_index: builder.containing_block_used_values.line_boxes.len - 1
		fragment_index: 0
	}
	// Markers recorded on this line never go through update_last_line(), so
	// anchor them at the flow position where the interrupting block starts.
	for mut marker in line_box.static_position_markers_ {
		marker.block_offset = marker.block_offset.plus(builder.current_block_offset)
	}
	builder.pending_margin_follows_block_level_box = true
	builder.current_block_offset = block_bottom
	builder.max_height_on_current_line = CSSPixels.new(0)
	builder.last_line_needs_update = false
	builder.should_advance_to_last_line_box_block_end = false
	builder.containing_block_used_values.line_boxes << LineBox.new(builder.direction,
		builder.writing_mode)
	builder.begin_new_line(false, true, .no)
}

// LineBuilder::did_introduce_clearance(). A forced break with `clear` grows
// the preceding line through the clearance edge and starts the new line there.
fn (mut builder LineBuilder) did_introduce_clearance(clearance CSSPixels) {
	if clearance.raw_value() <= builder.current_block_offset.raw_value() {
		return
	}
	line_count := builder.containing_block_used_values.line_boxes.len
	if line_count > 1 {
		builder.containing_block_used_values.line_boxes[line_count - 2].bottom_ = clearance
	}
	builder.current_block_offset = clearance
	builder.recalculate_available_space()
}

fn (mut builder LineBuilder) begin_new_line(increment_y bool, is_first_break_in_sequence bool, forced_break ForcedLineBreak) {
	if increment_y {
		if is_first_break_in_sequence {
			if builder.should_advance_to_last_line_box_block_end
				&& builder.containing_block_used_values.line_boxes.len > 1 {
				previous_index := builder.containing_block_used_values.line_boxes.len - 2
				builder.current_block_offset = builder.containing_block_used_values.line_boxes[previous_index].bottom_
			} else {
				line_height := builder.containing_block.computed_values().line_height()
				increment := css_pixels_max(builder.max_height_on_current_line, line_height)
				builder.current_block_offset = builder.current_block_offset.plus(increment)
			}
		} else {
			// Consecutive breaks are squeezing past intruding floats. A band's
			// intrusions are constant, so the next possible fit begins at its next
			// boundary rather than at the following CSS pixel.
			if context := builder.parent_block_context {
				root_y := builder.containing_block_root_offset.y().plus(builder.current_block_offset)
				if boundary := context.next_float_band_start_after(root_y) {
					builder.current_block_offset = boundary.minus(builder.containing_block_root_offset.y())
				} else {
					line_height := builder.containing_block.computed_values().line_height()
					builder.current_block_offset = builder.current_block_offset.plus(css_pixels_max(builder.max_height_on_current_line,
						line_height))
				}
			} else {
				builder.current_block_offset = builder.current_block_offset.plus(builder.containing_block.computed_values().line_height())
			}
		}
	}
	builder.recalculate_available_space()
	mut line_box := builder.ensure_last_line_box()
	line_box.original_available_width_ = builder.available_width_for_current_line
	builder.max_height_on_current_line = CSSPixels.new(0)
	builder.last_line_needs_update = true
	builder.should_advance_to_last_line_box_block_end = false
	mut should_indent := builder.containing_block_used_values.line_boxes.len <= 1
		|| (builder.text_indent_each_line && forced_break == .yes)
	if builder.text_indent_hanging {
		should_indent = !should_indent
	}
	if should_indent {
		line_box.inline_length_ = line_box.inline_length_.plus(builder.text_indent)
	}
	builder.current_line_committed_pending_margin = false
}

fn (mut builder LineBuilder) ensure_last_line_box() &LineBox {
	if builder.containing_block_used_values.line_boxes.len == 0 {
		builder.containing_block_used_values.line_boxes << LineBox.new(builder.direction, builder.writing_mode)
	}
	last_index := builder.containing_block_used_values.line_boxes.len - 1
	mut line := &builder.containing_block_used_values.line_boxes[last_index]
	line.intrinsic_width_only_ = builder.intrinsic_width_only
	return line
}

// A dropped collapsible space can carry the end edges of the inline boxes it
// closes; those edges still occupy the line.
fn (mut builder LineBuilder) append_inline_end_edges(trailing_size CSSPixels, trailing_margin CSSPixels) {
	if trailing_size.raw_value() == 0 && trailing_margin.raw_value() == 0 {
		return
	}
	mut line_box := builder.ensure_last_line_box()
	line_box.inline_length_ = line_box.inline_length_.plus(trailing_size).plus(trailing_margin)
	builder.last_line_needs_update = true
}

pub fn (mut builder LineBuilder) append_box(box &Box, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels) {
	builder.prepare_to_append_inline_content()
	styled := unsafe { &NodeWithStyle(box) }
	mut box_state := builder.layout_state.get_mutable(styled)
	mut line_box := builder.ensure_last_line_box()
	line_box.add_fragment(unsafe { &Node(box) }, 0, 0, leading_size, trailing_size, leading_margin, trailing_margin, box_state.content_width(), box_state.content_height(), box_state.border_box_top(), box_state.border_box_bottom(), none)
	builder.max_height_on_current_line = css_pixels_max(builder.max_height_on_current_line, box_state.margin_box_height())
	box_state.containing_line_box_fragment = LineBoxFragmentCoordinate{
		line_box_index: builder.containing_block_used_values.line_boxes.len - 1
		fragment_index: line_box.fragments_.len - 1
	}
}

pub fn (mut builder LineBuilder) append_text_chunk(text_node &TextNode, offset_in_node int, length_in_node int, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels, content_width CSSPixels, content_height CSSPixels, glyph_run &platform.GlyphRun) {
	builder.append_text_chunk_with_trailing_whitespace(text_node, offset_in_node, length_in_node, leading_size, trailing_size, leading_margin, trailing_margin, content_width, content_height, glyph_run, TrailingWhitespace{})
}

pub fn (mut builder LineBuilder) append_text_chunk_with_trailing_whitespace(text_node &TextNode, offset_in_node int, length_in_node int, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels, content_width CSSPixels, content_height CSSPixels, glyph_run &platform.GlyphRun, trailing_whitespace TrailingWhitespace) {
	builder.prepare_to_append_inline_content()
	mut line_box := builder.ensure_last_line_box()
	line_box.add_fragment_with_trailing_whitespace(unsafe { &Node(text_node) }, offset_in_node, length_in_node, leading_size, trailing_size, leading_margin, trailing_margin, content_width, content_height, CSSPixels.new(0), CSSPixels.new(0), glyph_run, trailing_whitespace)
	builder.max_height_on_current_line = css_pixels_max(builder.max_height_on_current_line, line_box.block_length())
}

// The BFC keeps a block's trailing margin pending so it may collapse with what
// follows. Inline content commits that margin exactly once for its line.
fn (mut builder LineBuilder) prepare_to_append_inline_content() {
	if builder.current_line_committed_pending_margin {
		return
	}
	line_box := builder.ensure_last_line_box()
	if line_box.has_block_level_box() {
		return
	}
	if context := builder.parent_block_context {
		mut mutable_context := unsafe { &BlockFormattingContext(context) }
		margin_before_line := mutable_context.commit_pending_margin_before_inline_content()
		if margin_before_line.raw_value() != 0 {
			builder.current_block_offset = builder.current_block_offset.plus(margin_before_line)
			builder.recalculate_available_space()
		}
	}
	builder.current_line_committed_pending_margin = true
	builder.pending_margin_follows_block_level_box = false
}

fn (mut builder LineBuilder) commit_pending_margin_before_float() {
	// Ordinary floats do not consume pending collapsible margins. A margin left
	// by an interrupting block must be consumed so the float and inline content
	// that share the next line start at the same block offset.
	if builder.pending_margin_follows_block_level_box {
		builder.prepare_to_append_inline_content()
	}
}

pub fn (mut builder LineBuilder) break_if_needed(next_item_width CSSPixels) bool {
	if builder.should_break(next_item_width) {
		builder.break_line(.no, next_item_width)
		return true
	}
	return false
}

pub fn (mut builder LineBuilder) current_line_is_empty() bool {
	return builder.containing_block_used_values.line_boxes.len == 0
		|| builder.ensure_last_line_box().is_empty()
}

fn (mut builder LineBuilder) remaining_width_on_current_line() ?CSSPixels {
	if !builder.available_width_for_current_line.is_definite() {
		return none
	}
	return builder.available_width_to_fit().minus(builder.ensure_last_line_box().width())
}

// Chromium accepts content that overflows the line by one LayoutUnit (1/64
// CSS pixel): LineBreaker::AvailableWidthToFit() adds that epsilon to the
// available width, absorbing rounding in summed glyph advances. A 4chan
// teaser line measuring 150.015625px therefore stays on a 150px line.
fn (builder &LineBuilder) available_width_to_fit() CSSPixels {
	available := builder.available_width_for_current_line.to_px_or_zero()
	if unsafe { &Node(builder.containing_block) }.document().font_rendering_policy() != .chromium {
		return available
	}
	return available.plus(CSSPixels.smallest_positive_value())
}

pub fn (mut builder LineBuilder) remaining_width_for_overflow_break() ?CSSPixels {
	if builder.available_width_for_current_line.is_definite() {
		return builder.remaining_width_on_current_line()
	}
	if builder.available_width_for_current_line.is_min_content() {
		return CSSPixels.new(0)
	}
	return none
}

pub fn (mut builder LineBuilder) break_if_needed_before_overflow_breakable_item(next_item_width CSSPixels) bool {
	if builder.current_line_is_empty() || !builder.should_break(next_item_width) {
		return false
	}
	builder.break_line(.no, none)
	return true
}

pub fn (mut builder LineBuilder) current_line_has_no_space_left_by_floats() bool {
	remaining := builder.remaining_width_on_current_line() or { return false }
	if remaining.raw_value() > 0 {
		return false
	}
	line_height := builder.containing_block.computed_values().line_height()
	block_end := builder.current_block_offset.plus(css_pixels_max(builder.max_height_on_current_line,
		line_height))
	return builder.any_floats_intrude_in_block_range(builder.current_block_offset, block_end)
}

pub fn (mut builder LineBuilder) append_text_item(item &InlineLevelItem, content_height CSSPixels) {
	text_node := (item.node or { return }).as_text_node() or { return }
	glyph_run := item.glyph_run or { return }
	if item.length_in_node == 0 && text_node.Node.is_generated_for_pseudo_element() {
		// An empty generated string retains a degenerate fragment at the inline
		// box's insertion point. Its opening edges still advance the line, while
		// the ancestor's used values supply the fragment's painted box geometry.
		opening_advance := item.margin_start.plus(item.border_start).plus(item.padding_start)
		builder.append_text_chunk_with_trailing_whitespace(text_node, item.offset_in_node,
			item.length_in_node, CSSPixels.new(0), opening_advance, CSSPixels.new(0),
			CSSPixels.new(0), item.width, CSSPixels.new(0), glyph_run, item.trailing_whitespace)
		builder.append_inline_end_edges(item.padding_end.plus(item.border_end), item.margin_end)
		return
	}
	builder.append_text_chunk_with_trailing_whitespace(text_node, item.offset_in_node,
		item.length_in_node, item.border_start.plus(item.padding_start),
		item.padding_end.plus(item.border_end), item.margin_start, item.margin_end, item.width,
		content_height, glyph_run, item.trailing_whitespace)
}

pub fn (mut builder LineBuilder) note_soft_wrap_opportunity() {
	context := builder.parent_block_context or { return }
	if !context.has_line_clamp() {
		return
	}
	if builder.containing_block_used_values.line_boxes.len == 0 {
		return
	}
	mut line := builder.ensure_last_line_box()
	for index := line.fragments_.len - 1; index >= 0; index-- {
		if !line.fragments_[index].is_justifiable_whitespace() {
			line.fragments_[index].set_has_soft_wrap_opportunity_after(true)
			return
		}
	}
}

fn (mut builder LineBuilder) should_break(next_item_width CSSPixels) bool {
	if builder.available_width_for_current_line.is_max_content()
		|| builder.available_width_for_current_line.is_indefinite() {
		return false
	}
	line_boxes := builder.containing_block_used_values.line_boxes
	if line_boxes.len == 0 || line_boxes.last().is_empty() {
		line_height := builder.containing_block.computed_values().line_height()
		if !builder.any_floats_intrude_in_block_range(builder.current_block_offset,
			builder.current_block_offset.plus(line_height)) {
			return false
		}
	}
	current_line_width := builder.ensure_last_line_box().width()
	if builder.available_width_for_current_line.is_definite() {
		return builder.available_width_to_fit().raw_value() < current_line_width.plus(next_item_width).raw_value()
	}
	return builder.available_width_for_current_line.is_less_than_px(current_line_width.plus(next_item_width))
}

// Direct text in the block container belongs to an anonymous inline box. The
// container's vertical-align positions the container in its parent formatting
// context and does not apply to that anonymous inline box, whose initial value
// is baseline because vertical-align is not inherited.
fn (builder &LineBuilder) fragment_uses_container_alignment(fragment &LineBoxFragment) bool {
	if !fragment.layout_node_.is_text_node() {
		return false
	}
	parent := fragment.layout_node_.parent() or { return false }
	return layout_nodes_same(parent, unsafe { &Node(builder.containing_block) })
}

fn line_relative_alignment(node &Node) ?css.VerticalAlign {
	computed := node.computed_values()
	if computed.vertical_align_length_percentage() != none {
		return none
	}
	alignment := computed.vertical_align()
	if alignment == .top || alignment == .bottom {
		return alignment
	}
	return none
}

fn fragment_alignment_style_source(fragment &LineBoxFragment) &Node {
	if fragment.layout_node_.is_text_node() {
		return fragment.layout_node_.parent() or { fragment.style_source_ }
	}
	return fragment.style_source_
}

// A top- or bottom-aligned subtree contains its root and every descendant
// inline subtree that is not itself aligned to the line box.
fn (builder &LineBuilder) line_relative_aligned_subtree_root(style_source &Node) ?LineRelativeAlignedSubtreeRoot {
	if builder.writing_mode != .horizontal_tb {
		return none
	}
	containing_block := unsafe { &Node(builder.containing_block) }
	mut node := unsafe { style_source }
	for !layout_nodes_same(node, containing_block) {
		if alignment := line_relative_alignment(node) {
			return LineRelativeAlignedSubtreeRoot{
				root:      node
				alignment: alignment
			}
		}
		parent := node.parent() or { break }
		if !layout_nodes_same(parent, containing_block) && !parent.is_inline_node() {
			break
		}
		node = parent
	}
	return none
}

fn aligned_subtree_index(subtrees []LineRelativeAlignedSubtree, root &Node) int {
	for index, subtree in subtrees {
		if layout_nodes_same(subtree.root, root) {
			return index
		}
	}
	return -1
}

fn (builder &LineBuilder) inline_box_alignment_delta(node &Node, line_box_baseline CSSPixels, container_font_metrics platform.FontPixelMetrics, container_font_size CSSPixels) CSSPixels {
	computed := node.computed_values()
	font_metrics := layout_font_metrics_for_node(node)
	baseline := font_baseline_for_line_height(font_metrics, computed.line_height())
	styled := node.as_node_with_style() or { return CSSPixels.new(0) }
	box_state := builder.layout_state.try_get(styled) or { return CSSPixels.new(0) }
	box_top := box_state.border_box_top()
	box_bottom := box_state.border_box_bottom()
	alphabetic := builder.current_block_offset.plus(line_box_baseline).minus(baseline).plus(box_top)
	mut aligned := alphabetic
	if vertical_align := computed.vertical_align_length_percentage() {
		aligned = alphabetic.minus(vertical_align.to_px(layout_length_resolution_context(node),
			computed.line_height()))
	} else {
		match computed.vertical_align() {
			.middle {
				parent_metrics := if parent := node.parent() {
					layout_font_metrics_for_node(parent)
				} else { container_font_metrics }
				aligned = builder.current_block_offset.plus(line_box_baseline).plus(middle_alignment_offset(
					node, box_top, box_bottom, computed.line_height(), parent_metrics.x_height))
			}
			.sub {
				aligned = alphabetic.plus(CSSPixels.from_raw(container_font_size.raw_value() / 5))
			}
			.super_ {
				aligned = alphabetic.minus(CSSPixels.from_raw(container_font_size.raw_value() / 3))
			}
			.text_top {
				parent_metrics := if parent := node.parent() {
					layout_font_metrics_for_node(parent)
				} else {
					container_font_metrics
				}
				aligned = builder.current_block_offset.plus(line_box_baseline).minus(CSSPixels.nearest_value_for(f64(parent_metrics.ascent))).plus(box_top)
			}
			.text_bottom {
				parent_metrics := if parent := node.parent() {
					layout_font_metrics_for_node(parent)
				} else {
					container_font_metrics
				}
				aligned = builder.current_block_offset.plus(line_box_baseline).plus(CSSPixels.nearest_value_for(f64(parent_metrics.descent))).minus(computed.line_height()).minus(box_bottom)
			}
			else {}
		}
	}
	return aligned.minus(alphabetic)
}

// A middle-aligned inline participates at its aligned top, rather than at its
// face's unshifted baseline. Keep that face baseline on the fragment for paint.
fn (builder &LineBuilder) chromium_middle_baseline_shift(fragment &LineBoxFragment,
	baseline CSSPixels, container_font_metrics platform.FontPixelMetrics,
	container_font_size CSSPixels) CSSPixels {
	if builder.fragment_uses_container_alignment(fragment) { return CSSPixels.new(0) }
	source := fragment_alignment_style_source(fragment)
	computed := source.computed_values()
	mut shift := CSSPixels.new(0)
	if fragment.layout_node_.is_text_node() && computed.vertical_align() == .middle
		&& computed.vertical_align_length_percentage() == none {
		parent_metrics := if parent := source.parent() {
			layout_font_metrics_for_node(parent)
		} else { container_font_metrics }
		shift = baseline.plus(middle_alignment_offset(fragment.layout_node_, CSSPixels.new(0),
			CSSPixels.new(0), computed.line_height(), parent_metrics.x_height))
	}
	mut ancestor := source.parent()
	containing_block := unsafe { &Node(builder.containing_block) }
	for {
		current := ancestor or { break }
		if layout_nodes_same(current, containing_block) || !current.is_inline_node()
			|| line_relative_alignment(current) != none { break }
		style := current.computed_values()
		if style.vertical_align() == .middle && style.vertical_align_length_percentage() == none {
			shift = shift.plus(builder.inline_box_alignment_delta(current, CSSPixels.new(0),
				container_font_metrics, container_font_size))
		}
		ancestor = current.parent()
	}
	return shift
}

pub fn (mut builder LineBuilder) update_last_line() {
	if builder.intrinsic_width_only {
		builder.last_line_needs_update = false
		return
	}
	if !builder.last_line_needs_update {
		return
	}
	builder.last_line_needs_update = false
	if builder.containing_block_used_values.line_boxes.len == 0 {
		return
	}
	mut line_box := builder.ensure_last_line_box()
	computed := builder.containing_block.computed_values()
	current_line_height := css_pixels_max(builder.max_height_on_current_line,
		computed.line_height())
	mut start_inline_offset := builder.current_line_inline_offset
	if context := builder.parent_block_context {
		if builder.available_width.is_definite() {
			left, _, _ := context.float_boundaries_at(builder.current_block_offset,
				current_line_height, builder.available_width.to_px_or_zero(), builder.direction,
				builder.containing_block_root_offset)
			start_inline_offset = left
		}
	}
	mut inline_offset := start_inline_offset
	mut block_offset := CSSPixels.new(0)
	// Blink removes a line's trailing collapsible spaces before aligning it
	// (CSS Text 3 §4.1.3); the inline formatting context trims them later.
	mut aligned_inline_length := line_box.inline_length()
	if unsafe { &Node(builder.containing_block) }.document().font_rendering_policy() == .chromium {
		aligned_inline_length = aligned_inline_length.minus(line_box.get_trailing_whitespace_width())
	}
	excess_inline_space :=
		builder.available_width_for_current_line.to_px_or_zero().minus(aligned_inline_length)
	// Keep block progression logical here. The inline available size does
	// not position a vertical line on the physical x axis; projection handles
	// the writing mode after line metrics have been finalized.
	if excess_inline_space.raw_value() > 0 {
		match computed.text_align() {
			.center, .libweb_center, .libweb_inherit_or_center {
				// CSSPixels / an integral divisor produces a CSSPixelFraction which
				// truncates when converted back to CSSPixels.
				inline_offset =
					inline_offset.plus(CSSPixels.from_raw(excess_inline_space.raw_value() / 2))
			}
			.start {
				if computed.direction() == .rtl {
					inline_offset = inline_offset.plus(excess_inline_space)
				}
			}
			.end_ {
				if computed.direction() == .ltr {
					inline_offset = inline_offset.plus(excess_inline_space)
				}
			}
			.right, .libweb_right {
				inline_offset = inline_offset.plus(excess_inline_space)
			}
			else {}
		}
	} else if excess_inline_space.raw_value() < 0 && computed.direction() == .rtl {
		// Overflowing lines ignore text-align and stay aligned to inline-start.
		inline_offset = inline_offset.plus(excess_inline_space)
	}

	container_font_size := computed.font_size()
	container_font_metrics :=
		layout_font_metrics_for_node(unsafe { &Node(builder.containing_block) })
	// Quirks documents omit the block's zero-width inline strut. Actual
	// text and atomic inline boxes still supply their own line metrics.
	// https://quirks.spec.whatwg.org/#the-blocks-ignore-line-height-quirk
	document := unsafe { &Node(builder.containing_block) }.document()
	omit_strut := (line_box.fragments_.len > 0 || !line_box.has_forced_break())
		&& document.font_rendering_policy() == .chromium
		&& (document.in_quirks_mode() || document.in_limited_quirks_mode())
	strut_height := if omit_strut { CSSPixels.new(0) } else { computed.line_height() }
	strut_baseline := if omit_strut { CSSPixels.new(0) } else {
		font_baseline_for_line_height(container_font_metrics, strut_height)
	}
	mut line_box_baseline := strut_baseline
	// Blink always places the root inline box's strut on the line's baseline, so
	// a protruding aligned box grows the line box and the next line follows it.
	mut should_align_strut_to_line_box_baseline :=
		unsafe { &Node(builder.containing_block) }.document().font_rendering_policy() == .chromium
	mut has_line_relative_aligned_subtree := false
	for fragment in line_box.fragments_ {
		if builder.line_relative_aligned_subtree_root(fragment_alignment_style_source(fragment)) != none {
			has_line_relative_aligned_subtree = true
			break
		}
	}
	for index in 0 .. line_box.fragments_.len {
		mut fragment := &line_box.fragments_[index]
		fragment_computed := fragment.layout_node_.computed_values()
		uses_container_alignment := builder.fragment_uses_container_alignment(fragment)
		mut fragment_baseline := CSSPixels.new(0)
		// The fragment's own box keeps its primary-font baseline; a fallback face
		// with line-height: normal can raise the line's baseline above it.
		mut used_font_baseline := CSSPixels.new(0)
		if fragment.layout_node_.is_text_node() {
			primary_metrics := layout_font_metrics_for_node(fragment.layout_node_)
			fragment_baseline = font_baseline_for_line_height(primary_metrics, fragment_computed.line_height())
			if primary_metrics.floor_inline_leading && fragment_computed.line_height_is_normal() {
				if run := fragment.glyph_run() {
					used := layout_inline_font_metrics(fragment.layout_node_, run.font())
					used_font_baseline = CSSPixels.nearest_value_for(f64(used.ascent)).plus(inline_half_leading(CSSPixels.nearest_value_for(f64(used.line_gap)), used))
				}
			}
		} else {
			fragment_baseline = layout_box_baseline_for_inline(builder.layout_state, fragment.layout_node_)
		}
		fragment.set_baseline(fragment_baseline)
		if builder.line_relative_aligned_subtree_root(fragment_alignment_style_source(fragment)) != none {
			continue
		}
		if !uses_container_alignment {
			if vertical_align := fragment_computed.vertical_align_length_percentage() {
				fragment_baseline = fragment_baseline.plus(vertical_align.to_px(layout_length_resolution_context(fragment.layout_node_), fragment_computed.line_height()))
			} else if fragment.layout_node_.document().font_rendering_policy() == .chromium
				&& fragment_computed.vertical_align() in [.text_top, .text_bottom] {
				// Text and atomic inline boxes meet the parent's text edges.
				// An atomic box's internal baseline must not raise the strut
				// when that baseline does not participate in alignment.
				alignment_source := fragment_alignment_style_source(fragment)
				parent_metrics := if parent := alignment_source.parent() {
					layout_font_metrics_for_node(parent)
				} else {
					container_font_metrics
				}
				fragment_baseline = if fragment_computed.vertical_align() == .text_top {
					CSSPixels.nearest_value_for(f64(parent_metrics.ascent))
				} else {
					fragment.height().minus(CSSPixels.nearest_value_for(f64(parent_metrics.descent)))
				}
				used_font_baseline = CSSPixels.new(0)
			}
		}
		if fragment_baseline.raw_value() > line_box_baseline.raw_value()
			&& !fragment.layout_node_.is_text_node()
			&& fragment_computed.vertical_align_length_percentage() == none {
			display := fragment_computed.display()
			should_align_strut_to_line_box_baseline = should_align_strut_to_line_box_baseline
				|| has_line_relative_aligned_subtree
				|| ((display.is_inline_block()
					|| (display.is_inline_outside() && display.is_flex_inside()))
					&& fragment_computed.vertical_align() == .baseline)
		}
		if used_font_baseline.raw_value() > 0 {
			used_font_baseline = used_font_baseline.plus(fragment_baseline.minus(fragment.baseline()))
		}
		mut contribution := fragment_baseline
		if document.font_rendering_policy() == .chromium {
			shift := builder.chromium_middle_baseline_shift(fragment, fragment_baseline,
				container_font_metrics, container_font_size)
			contribution = contribution.minus(shift)
			if used_font_baseline.raw_value() > 0 { used_font_baseline = used_font_baseline.minus(shift) }
		}
		line_box_baseline = css_pixels_max(css_pixels_max(line_box_baseline, contribution),
			used_font_baseline)
	}

	strut_top := builder.current_block_offset
	mut uppermost_box_top := strut_top
	mut lowermost_box_bottom := if should_align_strut_to_line_box_baseline {
		builder.current_block_offset.plus(line_box_baseline).plus(strut_height.minus(strut_baseline))
	} else {
		builder.current_block_offset.plus(strut_height)
	}
	mut first_unshifted_text_baseline := ?CSSPixels(none)
	mut aligned_subtrees := []LineRelativeAlignedSubtree{}
	current_block_offset := builder.current_block_offset
	for index in 0 .. line_box.fragments_.len {
		mut fragment := &line_box.fragments_[index]
		uses_container_alignment := builder.fragment_uses_container_alignment(fragment)
		fragment_inline_offset := inline_offset.plus(fragment.inline_offset())
		mut effective_box_top_offset := fragment.border_box_top()
		mut effective_box_bottom_offset := fragment.border_box_top()
		if fragment.is_atomic_inline() {
			if styled := fragment.layout_node_.as_node_with_style() {
				fragment_box_state := builder.layout_state.get(styled)
				effective_box_top_offset = fragment_box_state.margin_box_top()
				effective_box_bottom_offset = fragment_box_state.margin_box_bottom()
			}
		}
		alphabetic_baseline :=
			builder.current_block_offset.plus(line_box_baseline).minus(fragment.baseline()).plus(effective_box_top_offset)
		mut fragment_block_offset := alphabetic_baseline
		fragment_computed := fragment.layout_node_.computed_values()
		alignment_style_source := fragment_alignment_style_source(fragment)
		aligned_subtree := builder.line_relative_aligned_subtree_root(alignment_style_source)
		mut alignment := if uses_container_alignment {
			css.VerticalAlign.baseline
		} else {
			fragment_computed.vertical_align()
		}
		if subtree := aligned_subtree {
			if layout_nodes_same(subtree.root, alignment_style_source) {
				alignment = .baseline
			}
		}
		match alignment {
			.top {
				fragment_block_offset = builder.current_block_offset.plus(effective_box_top_offset)
			}
			.middle {
				parent_metrics := if parent := alignment_style_source.parent() {
					layout_font_metrics_for_node(parent)
				} else { container_font_metrics }
				fragment_block_offset =
					builder.current_block_offset.plus(line_box_baseline).plus(middle_alignment_offset(
						fragment.layout_node_, effective_box_top_offset, effective_box_bottom_offset,
						fragment.height(), parent_metrics.x_height))
			}
			.sub {
				fragment_block_offset =
					alphabetic_baseline.plus(CSSPixels.from_raw(container_font_size.raw_value() / 5))
			}
			.super_ {
				fragment_block_offset =
					alphabetic_baseline.minus(CSSPixels.from_raw(container_font_size.raw_value() / 3))
			}
			.text_top {
				parent_font_metrics := if parent := alignment_style_source.parent() {
					layout_font_metrics_for_node(parent)
				} else {
					container_font_metrics
				}
				fragment_block_offset = builder.current_block_offset.plus(line_box_baseline).minus(CSSPixels.nearest_value_for(f64(parent_font_metrics.ascent))).plus(
					effective_box_top_offset)
			}
			.text_bottom {
				parent_font_metrics := if parent := alignment_style_source.parent() {
					layout_font_metrics_for_node(parent)
				} else {
					container_font_metrics
				}
				fragment_block_offset = builder.current_block_offset.plus(line_box_baseline).plus(CSSPixels.nearest_value_for(f64(parent_font_metrics.descent))).minus(
					fragment.height()).minus(effective_box_bottom_offset)
			}
			else {}
		}
		if !uses_container_alignment {
			if vertical_align := fragment_computed.vertical_align_length_percentage() {
				vertical_align_amount := vertical_align.to_px(layout_length_resolution_context(fragment.layout_node_), fragment_computed.line_height())
				fragment_block_offset = alphabetic_baseline.minus(vertical_align_amount)
			}
		}
		own_alignment_is_line_relative := line_relative_alignment(alignment_style_source) != none
		if !own_alignment_is_line_relative {
			mut ancestor := alignment_style_source.parent()
			containing_block := unsafe { &Node(builder.containing_block) }
			for {
				current := ancestor or { break }
				if layout_nodes_same(current, containing_block) || !current.is_inline_node() {
					break
				}
				if line_relative_alignment(current) != none {
					break
				}
				ancestor_computed := current.computed_values()
				if ancestor_computed.vertical_align_length_percentage() == none
					&& ancestor_computed.vertical_align() == .baseline {
					ancestor = current.parent()
					continue
				}
				fragment_block_offset = fragment_block_offset.plus(builder.inline_box_alignment_delta(current,
					line_box_baseline, container_font_metrics, container_font_size))
				ancestor = current.parent()
			}
		}
		fragment_is_unshifted := fragment_block_offset == alphabetic_baseline
		fragment.set_inline_offset(fragment_inline_offset)
		fragment.set_block_offset((if fragment.layout_node_.document().font_rendering_policy() == .chromium {
			fragment_block_offset
		} else { css.css_pixels_floor(fragment_block_offset) }).plus(block_offset))
		mut top_of_inline_box := CSSPixels.new(0)
		mut bottom_of_inline_box := CSSPixels.new(0)
		if fragment.is_atomic_inline() {
			if styled := fragment.layout_node_.as_node_with_style() {
				fragment_box_state := builder.layout_state.get(styled)
				top_of_inline_box =
					fragment.block_offset().minus(fragment_box_state.margin_box_top())
				bottom_of_inline_box =
					fragment.block_offset().plus(fragment_box_state.content_height()).plus(fragment_box_state.margin_box_bottom())
			}
		} else {
			font_metrics := layout_font_metrics_for_node(fragment.layout_node_)
			typographic_height := CSSPixels.nearest_value_for(f64(font_metrics.ascent + font_metrics.descent))
			leading := fragment_computed.line_height().minus(typographic_height)
			half_leading := inline_half_leading(leading, font_metrics)
			end_leading := if font_metrics.floor_inline_leading { leading.minus(half_leading) } else { half_leading }
			ascent := CSSPixels.nearest_value_for(f64(font_metrics.ascent))
			descent := CSSPixels.nearest_value_for(f64(font_metrics.descent))
			top_of_inline_box =
				fragment.block_offset().plus(fragment.baseline()).minus(ascent).minus(half_leading)
			bottom_of_inline_box =
				fragment.block_offset().plus(fragment.baseline()).plus(descent).plus(end_leading)
			// With line-height: normal, Blink's inline box also includes the
			// fonts its text actually uses, each with half its line gap on
			// either side, so a taller fallback face grows the line.
			if font_metrics.floor_inline_leading && fragment_computed.line_height_is_normal() {
				if run := fragment.glyph_run() {
					used := layout_inline_font_metrics(fragment.layout_node_, run.font())
					used_half_gap := inline_half_leading(CSSPixels.nearest_value_for(f64(used.line_gap)), used)
					used_end_gap := CSSPixels.nearest_value_for(f64(used.line_gap)).minus(used_half_gap)
					baseline := fragment.block_offset().plus(fragment.baseline())
					top_of_inline_box = css_pixels_min(top_of_inline_box,
						baseline.minus(CSSPixels.nearest_value_for(f64(used.ascent))).minus(used_half_gap))
					bottom_of_inline_box = css_pixels_max(bottom_of_inline_box,
						baseline.plus(CSSPixels.nearest_value_for(f64(used.descent))).plus(used_end_gap))
				}
			}
		}
		if !uses_container_alignment {
			if vertical_align := fragment_computed.vertical_align_length_percentage() {
				bottom_of_inline_box = bottom_of_inline_box.plus(vertical_align.to_px(layout_length_resolution_context(fragment.layout_node_), fragment_computed.line_height()))
			}
		}
		if subtree := aligned_subtree {
			subtree_index := aligned_subtree_index(aligned_subtrees, subtree.root)
			if subtree_index >= 0 {
				aligned_subtrees[subtree_index].block_start = css_pixels_min(aligned_subtrees[subtree_index].block_start,
					top_of_inline_box)
				aligned_subtrees[subtree_index].block_end = css_pixels_max(aligned_subtrees[subtree_index].block_end,
					bottom_of_inline_box)
			} else {
				aligned_subtrees << LineRelativeAlignedSubtree{
					root:        subtree.root
					alignment:   subtree.alignment
					block_start: top_of_inline_box
					block_end:   bottom_of_inline_box
				}
			}
		} else {
			uppermost_box_top = css_pixels_min(uppermost_box_top, top_of_inline_box)
			lowermost_box_bottom = css_pixels_max(lowermost_box_bottom, bottom_of_inline_box)
		}

		// Text is initially aligned using its computed line height so that it
		// contributes the right bounds to the line box. Anchor its paint box to
		// the selected font's normal metrics afterwards, matching upstream's
		// horizontal-writing-mode fragment geometry.
		if fragment.layout_node_.is_text_node() && builder.writing_mode == .horizontal_tb {
			font_metrics := layout_font_metrics_for_node(fragment.layout_node_)
			font_box_height := normal_line_height_for_font_metrics(font_metrics)
			font_baseline := font_baseline_for_line_height(font_metrics, font_box_height)
			fragment.set_block_offset(fragment.block_offset().plus(fragment.baseline()).minus(font_baseline))
			fragment.set_baseline(font_baseline)
			fragment.set_block_length(font_box_height)
		}
		if first_unshifted_text_baseline == none && fragment_is_unshifted
			&& fragment.layout_node_.is_text_node() && !fragment.is_fully_truncated_ {
			first_unshifted_text_baseline = fragment.block_offset().plus(fragment.baseline()).minus(current_block_offset)
		}
	}
	mut maximum_top_subtree_height := CSSPixels.new(0)
	mut maximum_bottom_subtree_height := CSSPixels.new(0)
	for subtree in aligned_subtrees {
		height := subtree.block_end.minus(subtree.block_start)
		if subtree.alignment == .top {
			maximum_top_subtree_height = css_pixels_max(maximum_top_subtree_height, height)
		} else {
			maximum_bottom_subtree_height = css_pixels_max(maximum_bottom_subtree_height,
				height)
		}
	}
	lowermost_box_bottom = css_pixels_max(lowermost_box_bottom,
		uppermost_box_top.plus(maximum_top_subtree_height))
	uppermost_box_top = css_pixels_min(uppermost_box_top,
		lowermost_box_bottom.minus(maximum_bottom_subtree_height))
	normal_subtree_shift := if has_line_relative_aligned_subtree {
		builder.current_block_offset.minus(uppermost_box_top)
	} else {
		CSSPixels.new(0)
	}
	for index in 0 .. aligned_subtrees.len {
		aligned_subtrees[index].shift = if aligned_subtrees[index].alignment == .top {
			builder.current_block_offset.minus(aligned_subtrees[index].block_start)
		} else {
			builder.current_block_offset.plus(lowermost_box_bottom.minus(uppermost_box_top)).minus(
				aligned_subtrees[index].block_end)
		}
	}
	if has_line_relative_aligned_subtree {
		for index in 0 .. line_box.fragments_.len {
			mut shift := normal_subtree_shift
			if subtree := builder.line_relative_aligned_subtree_root(fragment_alignment_style_source(&line_box.fragments_[index])) {
				subtree_index := aligned_subtree_index(aligned_subtrees, subtree.root)
				if subtree_index >= 0 {
					shift = aligned_subtrees[subtree_index].shift
				}
			}
			line_box.fragments_[index].block_offset_ = line_box.fragments_[index].block_offset_.plus(shift)
		}
	}
	for mut marker in line_box.static_position_markers_ {
		mut shift := normal_subtree_shift
		marker_node := unsafe { &Node(marker.box) }
		if parent := marker_node.parent() {
			if subtree := builder.line_relative_aligned_subtree_root(parent) {
				subtree_index := aligned_subtree_index(aligned_subtrees, subtree.root)
				if subtree_index >= 0 {
					shift = aligned_subtrees[subtree_index].shift
				}
			}
		}
		marker.inline_offset = marker.inline_offset.plus(inline_offset)
		marker.block_offset = marker.block_offset.plus(block_offset).plus(builder.current_block_offset).plus(
			shift)
	}
	line_box.block_length_ = lowermost_box_bottom.minus(uppermost_box_top)
	line_box.bottom_ = builder.current_block_offset.plus(line_box.block_length_)
	line_box.baseline_ = (first_unshifted_text_baseline or {
		line_box_baseline.plus(block_offset)
	}).plus(normal_subtree_shift)
	line_box.font_box_baseline_ = builder.current_block_offset.plus(line_box.baseline_)
	builder.should_advance_to_last_line_box_block_end = should_align_strut_to_line_box_baseline
}

pub fn (mut builder LineBuilder) remove_last_line_if_empty() {
	for builder.containing_block_used_values.line_boxes.len > 0
		&& builder.containing_block_used_values.line_boxes.last().is_empty() {
		last_index := builder.containing_block_used_values.line_boxes.len - 1
		builder.containing_block_used_values.line_boxes.delete(last_index)
		builder.last_line_needs_update = false
	}
}

pub fn (mut builder LineBuilder) recalculate_available_space() {
	builder.available_width_for_current_line = builder.available_width
	builder.current_line_inline_offset = CSSPixels.new(0)
	if context := builder.parent_block_context {
		if builder.available_width.is_definite() {
			line_height := css_pixels_max(builder.max_height_on_current_line,
				builder.containing_block.computed_values().line_height())
			left, right, _ := context.float_boundaries_at(builder.current_block_offset,
				line_height, builder.available_width.to_px_or_zero(), builder.direction,
				builder.containing_block_root_offset)
			width := right.minus(left)
			builder.available_width_for_current_line = AvailableSize.make_definite(if width.raw_value() > 0 {
				width
			} else {
				CSSPixels.new(0)
			})
			builder.current_line_inline_offset = left
		}
	}
	if builder.containing_block_used_values.line_boxes.len > 0 {
		mut line_box := builder.ensure_last_line_box()
		line_box.original_available_width_ = builder.available_width_for_current_line
	}
}

pub fn (mut builder LineBuilder) append_static_position_marker(box &Box, preceded_by_inline_box_start_edges bool) {
	mut line_box := builder.ensure_last_line_box()
	line_box.add_static_position_marker(box, preceded_by_inline_box_start_edges)
}

fn (builder &LineBuilder) any_floats_intrude_in_block_range(block_start CSSPixels, block_end CSSPixels) bool {
	if !builder.available_width.is_definite() {
		return false
	}
	context := builder.parent_block_context or { return false }
	left, right, _ := context.float_boundaries_at(block_start, block_end.minus(block_start),
		builder.available_width.to_px_or_zero(), builder.direction,
		builder.containing_block_root_offset)
	return left.raw_value() > 0
		|| right.raw_value() < builder.available_width.to_px_or_zero().raw_value()
}

fn (builder &LineBuilder) can_fit_new_line_at_block_offset(block_offset CSSPixels, line_height CSSPixels) bool {
	if !builder.available_width.is_definite() {
		return true
	}
	context := builder.parent_block_context or { return true }
	left, right, _ := context.float_boundaries_at(block_offset, line_height,
		builder.available_width.to_px_or_zero(), builder.direction,
		builder.containing_block_root_offset)
	return right.minus(left).raw_value() > 0
}

pub fn (mut builder LineBuilder) set_trailing_whitespace_on_previous_line() {
	line_count := builder.containing_block_used_values.line_boxes.len
	if line_count < 2 {
		return
	}
	mut previous := &builder.containing_block_used_values.line_boxes[line_count - 2]
	if previous.fragments_.len == 0 {
		return
	}
	previous.fragments_[previous.fragments_.len - 1].set_has_trailing_whitespace(true)
}

pub fn (builder &LineBuilder) current_block_offset_value() CSSPixels {
	return builder.current_block_offset
}

// LineBuilder::y_for_float_to_be_inserted_here(). A float that cannot fit
// beside already-generated inline content starts below the current line. New
// floats also cannot be placed above the most recently inserted float.
fn (builder &LineBuilder) y_for_float_to_be_inserted_here(box_state &UsedValues, block_context &BlockFormattingContext) CSSPixels {
	mut candidate := builder.current_block_offset
	if builder.containing_block_used_values.line_boxes.len > 0 {
		line := builder.containing_block_used_values.line_boxes.last()
		line_width := line.width().minus(line.get_trailing_whitespace_width())
		if line_width.raw_value() > 0 && builder.available_width_for_current_line.is_definite()
			&& line_width.plus(box_state.margin_box_width()).raw_value() > builder.available_width_for_current_line.to_px_or_zero().raw_value() {
			candidate = candidate.plus(line.height())
		}
	}
	if block_context.floating_boxes.len > 0 {
		last_float := block_context.floating_boxes.last()
		last_float_top := last_float.top.minus(builder.containing_block_root_offset.y())
		candidate = css_pixels_max(candidate, last_float_top)
	}
	return candidate
}

fn layout_font_metrics_for_node(node &Node) platform.FontPixelMetrics {
	if text := node.as_text_node() {
		return layout_inline_font_metrics(node, text.font_for_rendering())
	}
	return layout_inline_font_metrics(node, node.first_available_font())
}

fn layout_inline_font_metrics(node &Node, font &platform.Font) platform.FontPixelMetrics {
	document := node.document()
	return font.inline_metrics_at_scale(document.display_device_pixel_ratio() / document.layout_coordinate_scale())
}

fn inline_half_leading(leading CSSPixels, metrics platform.FontPixelMetrics) CSSPixels {
	half := CSSPixels.from_raw(leading.raw_value() / 2)
	if !metrics.floor_inline_leading { return half }
	scale := metrics.inline_leading_scale
	return CSSPixels.nearest_value_for(math.floor(half.to_double() * scale) / scale)
}

fn middle_alignment_offset(node &Node, top CSSPixels, bottom CSSPixels, height CSSPixels,
	x_height f32) CSSPixels {
	if node.document().font_rendering_policy() == .chromium {
		// Blink rounds half the parent's x-height, independently of the box's
		// half-height. Rounding the complete sum loses one CSSPixel quantum.
		// LayoutUnit::FromFloatRound uses roundf (ties away from zero),
		// whereas LibWeb CSSPixels uses ties-to-even rounding.
		half_x_height := CSSPixels.from_raw(int(math.round(f64(x_height) * 32)))
		// Blink derives the shift from (ascent - descent) / 2 before
		// subtracting ascent. With odd subpixels that floors the resulting
		// negative half-height instead of truncating it toward zero.
		half_height := int(math.floor(f64(top.minus(bottom).minus(height).raw_value()) / 2))
		return CSSPixels.from_raw(half_height)
			.minus(half_x_height)
	}
	return CSSPixels.from_raw(top.minus(bottom).minus(height)
		.minus(CSSPixels.nearest_value_for(f64(x_height))).raw_value() / 2)
}

// ComputedValues stores font-relative lengths in their typed form. Resolve
// them with the actual font selected for this layout node, matching
// StyleComputer's font-metric resolution in upstream (notably `ch` for text
// spacing and tab-size).
fn resolve_font_dependent_length_for_node(node &Node, length css.Length) CSSPixels {
	if length.is_absolute() {
		return length.absolute_length_to_px()
	}
	mut context := css.LengthResolutionContext.for_document(node.document())
	computed := node.computed_values()
	metrics := layout_font_metrics_for_node(node)
	font_size := CSSPixels.nearest_value_for(computed.resolved_font_size_px())
	context.font_metrics.font_size = font_size
	context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(metrics.x_height))
	context.font_metrics.cap_height = font_size.scaled(0.75)
	context.font_metrics.zero_advance =
		CSSPixels.nearest_value_for(f64(metrics.advance_of_ascii_zero))
	context.font_metrics.line_height = computed.line_height()
	return length.to_px(context)
}

fn resolved_text_spacing_for_node(node &Node, property_id css.PropertyID) CSSPixels {
	return resolve_font_dependent_length_for_node(node, computed_text_spacing_length(node.computed_values(), property_id))
}

fn font_baseline_for_line_height(font_metrics platform.FontPixelMetrics, line_height CSSPixels) CSSPixels {
	ascent := CSSPixels.nearest_value_for(f64(font_metrics.ascent))
	typographic_height :=
		CSSPixels.nearest_value_for(f64(font_metrics.ascent + font_metrics.descent))
	half_leading := inline_half_leading(line_height.minus(typographic_height), font_metrics)
	return ascent.plus(half_leading)
}

fn normal_line_height_for_font_metrics(font_metrics platform.FontPixelMetrics) CSSPixels {
	if font_metrics.floor_inline_leading && font_metrics.inline_leading_scale != 1 {
		return CSSPixels.nearest_value_for(f64(font_metrics.ascent + font_metrics.descent + font_metrics.line_gap))
	}
	gap := if font_metrics.floor_inline_leading { int(font_metrics.line_gap) } else { 0 }
	return CSSPixels.new(int(math.round_to_even(f64(font_metrics.ascent))) + int(math.round_to_even(f64(font_metrics.descent))) + gap)
}

fn css_pixels_min(a CSSPixels, b CSSPixels) CSSPixels {
	return if a.raw_value() < b.raw_value() { a } else { b }
}

fn css_pixels_max(a CSSPixels, b CSSPixels) CSSPixels {
	return if a.raw_value() > b.raw_value() { a } else { b }
}

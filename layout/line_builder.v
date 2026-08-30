// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform

pub enum ForcedLineBreak {
	no
	yes
}

// LineBuilder owns line creation, overflow breaks, indentation, fragment
// alignment and baseline geometry. Float intrusion is supplied as the
// available width; when float layout is absent this is the containing width.
@[heap]
pub struct LineBuilder {
mut:
	layout_state                     &LayoutState    = unsafe { nil }
	containing_block                 &BlockContainer = unsafe { nil }
	containing_block_used_values     &UsedValues     = unsafe { nil }
	available_width_for_current_line AvailableSize   = AvailableSize.make_indefinite()
	available_width                  AvailableSize   = AvailableSize.make_indefinite()
	current_block_offset             CSSPixels
	max_height_on_current_line       CSSPixels
	text_indent                      CSSPixels
	text_indent_hanging              bool
	text_indent_each_line            bool
	direction                        css.Direction   = .ltr
	writing_mode                     css.WritingMode = .horizontal_tb
	last_line_needs_update           bool
	parent_block_context             ?&BlockFormattingContext
	containing_block_root_offset     CSSPixelPoint
	current_line_inline_offset       CSSPixels
	next_float_bottom                ?CSSPixels
}

pub fn LineBuilder.new(mut layout_state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, available_width AvailableSize, direction css.Direction, writing_mode css.WritingMode) &LineBuilder {
	return LineBuilder.new_with_block_context(mut layout_state, containing_block,
		containing_block_used_values, available_width, direction, writing_mode, none)
}

fn LineBuilder.new_with_block_context(mut layout_state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, available_width AvailableSize, direction css.Direction, writing_mode css.WritingMode, parent_block_context ?&BlockFormattingContext) &LineBuilder {
	computed := containing_block.computed_values()
	indent := computed.text_indent()
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
	mut builder := &LineBuilder{
		layout_state:                 layout_state
		containing_block:             containing_block
		containing_block_used_values: containing_block_used_values
		available_width:              available_width
		text_indent:                  indent.length_percentage.to_px(context,
			containing_block_used_values.content_width())
		text_indent_hanging:          indent.hanging
		text_indent_each_line:        indent.each_line
		direction:                    direction
		writing_mode:                 writing_mode
		parent_block_context:         parent_block_context
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
		builder.containing_block_used_values.line_boxes << LineBox.new(builder.direction,
			builder.writing_mode)
		builder.begin_new_line(true, break_count == 0, forced_break)
		break_count++
		if !builder.any_floats_intrude_at_block_offset(builder.current_block_offset) {
			break
		}
		if !builder.can_fit_new_line_at_block_offset(builder.current_block_offset) {
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
			line_height := builder.containing_block.computed_values().line_height()
			increment := css_pixels_max(builder.max_height_on_current_line, line_height)
			builder.current_block_offset = builder.current_block_offset.plus(increment)
		} else {
			// Consecutive breaks are squeezing past intruding floats. Scan one CSS
			// pixel at a time until a complete line-height fits, exactly like
			// LineBuilder::begin_new_line().
			mut candidate := builder.current_block_offset.plus(CSSPixels.new(1))
			for !builder.can_fit_new_line_at_block_offset(candidate) {
				candidate = candidate.plus(CSSPixels.new(1))
			}
			builder.current_block_offset = candidate
		}
	}
	builder.recalculate_available_space()
	mut line_box := builder.ensure_last_line_box()
	line_box.original_available_width_ = builder.available_width_for_current_line
	builder.max_height_on_current_line = CSSPixels.new(0)
	builder.last_line_needs_update = true
	mut should_indent := builder.containing_block_used_values.line_boxes.len <= 1
		|| (builder.text_indent_each_line && forced_break == .yes)
	if builder.text_indent_hanging {
		should_indent = !should_indent
	}
	if should_indent {
		line_box.inline_length_ = line_box.inline_length_.plus(builder.text_indent)
	}
}

fn (mut builder LineBuilder) ensure_last_line_box() &LineBox {
	if builder.containing_block_used_values.line_boxes.len == 0 {
		builder.containing_block_used_values.line_boxes << LineBox.new(builder.direction,
			builder.writing_mode)
	}
	last_index := builder.containing_block_used_values.line_boxes.len - 1
	return &builder.containing_block_used_values.line_boxes[last_index]
}

pub fn (mut builder LineBuilder) append_box(box &Box, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels) {
	styled := unsafe { &NodeWithStyle(box) }
	mut box_state := builder.layout_state.get_mutable(styled)
	mut line_box := builder.ensure_last_line_box()
	line_box.add_fragment(unsafe { &Node(box) }, 0, 0, leading_size, trailing_size, leading_margin,
		trailing_margin, box_state.content_width(), box_state.content_height(),
		box_state.border_box_top(), box_state.border_box_bottom(), none)
	builder.max_height_on_current_line = css_pixels_max(builder.max_height_on_current_line,
		box_state.margin_box_height())
	box_state.containing_line_box_fragment = LineBoxFragmentCoordinate{
		line_box_index: builder.containing_block_used_values.line_boxes.len - 1
		fragment_index: line_box.fragments_.len - 1
	}
}

pub fn (mut builder LineBuilder) append_text_chunk(text_node &TextNode, offset_in_node int, length_in_node int, leading_size CSSPixels, trailing_size CSSPixels, leading_margin CSSPixels, trailing_margin CSSPixels, content_width CSSPixels, content_height CSSPixels, glyph_run &platform.GlyphRun) {
	mut line_box := builder.ensure_last_line_box()
	line_box.add_fragment(unsafe { &Node(text_node) }, offset_in_node, length_in_node,
		leading_size, trailing_size, leading_margin, trailing_margin, content_width,
		content_height, CSSPixels.new(0), CSSPixels.new(0), glyph_run)
	builder.max_height_on_current_line = css_pixels_max(builder.max_height_on_current_line,
		line_box.block_length())
}

pub fn (mut builder LineBuilder) break_if_needed(next_item_width CSSPixels) bool {
	if builder.should_break(next_item_width) {
		builder.break_line(.no, next_item_width)
		return true
	}
	return false
}

fn (mut builder LineBuilder) should_break(next_item_width CSSPixels) bool {
	if builder.available_width_for_current_line.is_max_content()
		|| builder.available_width_for_current_line.is_indefinite() {
		return false
	}
	line_boxes := builder.containing_block_used_values.line_boxes
	if line_boxes.len == 0 || line_boxes.last().is_empty() {
		if !builder.any_floats_intrude_at_block_offset(builder.current_block_offset) {
			return false
		}
		line_height := builder.containing_block.computed_values().line_height()
		if !builder.any_floats_intrude_at_block_offset(builder.current_block_offset.plus(line_height)) {
			return false
		}
	}
	current_line_width := builder.ensure_last_line_box().width()
	return builder.available_width_for_current_line.is_less_than_px(current_line_width.plus(next_item_width))
}

pub fn (mut builder LineBuilder) update_last_line() {
	if !builder.last_line_needs_update {
		return
	}
	builder.last_line_needs_update = false
	if builder.containing_block_used_values.line_boxes.len == 0 {
		return
	}
	mut line_box := builder.ensure_last_line_box()
	computed := builder.containing_block.computed_values()
	mut inline_offset := builder.current_line_inline_offset
	mut block_offset := CSSPixels.new(0)
	excess_inline_space :=
		builder.available_width_for_current_line.to_px_or_zero().minus(line_box.inline_length())
	if builder.writing_mode != .horizontal_tb {
		block_offset =
			builder.available_width_for_current_line.to_px_or_zero().minus(line_box.block_length())
	}
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
	}

	container_font_size := computed.font_size()
	container_font_metrics :=
		layout_font_metrics_for_node(unsafe { &Node(builder.containing_block) })
	strut_baseline := font_baseline_for_line_height(container_font_metrics, computed.line_height())
	mut line_box_baseline := strut_baseline
	for index in 0 .. line_box.fragments_.len {
		mut fragment := &line_box.fragments_[index]
		fragment_computed := fragment.layout_node_.computed_values()
		mut fragment_baseline := CSSPixels.new(0)
		if fragment.layout_node_.is_text_node() {
			fragment_baseline = font_baseline_for_line_height(layout_font_metrics_for_node(fragment.layout_node_),
				fragment_computed.line_height())
		} else {
			fragment_baseline = layout_box_baseline(builder.layout_state, fragment.layout_node_)
		}
		fragment.set_baseline(fragment_baseline)
		if vertical_align := fragment_computed.vertical_align_length_percentage() {
			if vertical_align.is_length() {
				fragment_baseline =
					fragment_baseline.plus(vertical_align.length().to_px(layout_length_resolution_context(fragment.layout_node_)))
			} else if vertical_align.is_percentage() {
				fragment_baseline =
					fragment_baseline.plus(fragment_computed.line_height().scaled(vertical_align.percentage().as_fraction()))
			}
		}
		line_box_baseline = css_pixels_max(line_box_baseline, fragment_baseline)
	}

	strut_top := builder.current_block_offset
	mut uppermost_box_top := strut_top
	mut lowermost_box_bottom := builder.current_block_offset.plus(computed.line_height())
	for index in 0 .. line_box.fragments_.len {
		mut fragment := &line_box.fragments_[index]
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
		match fragment_computed.vertical_align() {
			.top {
				fragment_block_offset = builder.current_block_offset.plus(effective_box_top_offset)
			}
			.middle {
				x_height := CSSPixels.nearest_value_for(f64(container_font_metrics.x_height))
				fragment_block_offset =
					builder.current_block_offset.plus(line_box_baseline).plus(CSSPixels.from_raw(effective_box_top_offset.minus(effective_box_bottom_offset).minus(x_height).minus(fragment.height()).raw_value() / 2))
			}
			.sub {
				fragment_block_offset =
					alphabetic_baseline.plus(CSSPixels.from_raw(container_font_size.raw_value() / 5))
			}
			.super_ {
				fragment_block_offset =
					alphabetic_baseline.minus(CSSPixels.from_raw(container_font_size.raw_value() / 3))
			}
			else {}
		}
		if vertical_align := fragment_computed.vertical_align_length_percentage() {
			if vertical_align.is_length() {
				vertical_align_amount :=
					vertical_align.length().to_px(layout_length_resolution_context(fragment.layout_node_))
				fragment_block_offset = alphabetic_baseline.minus(vertical_align_amount)
			} else if vertical_align.is_percentage() {
				vertical_align_amount :=
					computed.line_height().scaled(vertical_align.percentage().as_fraction())
				fragment_block_offset = alphabetic_baseline.minus(vertical_align_amount)
			}
		}
		fragment.set_inline_offset(fragment_inline_offset)
		fragment.set_block_offset(css.css_pixels_floor(fragment_block_offset).plus(block_offset))
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
			typographic_height := CSSPixels.nearest_value_for(f64(font_metrics.ascent +
				font_metrics.descent))
			leading := fragment_computed.line_height().minus(typographic_height)
			half_leading := CSSPixels.from_raw(leading.raw_value() / 2)
			ascent := CSSPixels.nearest_value_for(f64(font_metrics.ascent))
			descent := CSSPixels.nearest_value_for(f64(font_metrics.descent))
			top_of_inline_box =
				fragment.block_offset().plus(fragment.baseline()).minus(ascent).minus(half_leading)
			bottom_of_inline_box =
				fragment.block_offset().plus(fragment.baseline()).plus(descent).plus(half_leading)
		}
		if vertical_align := fragment_computed.vertical_align_length_percentage() {
			if vertical_align.is_length() {
				bottom_of_inline_box =
					bottom_of_inline_box.plus(vertical_align.length().to_px(layout_length_resolution_context(fragment.layout_node_)))
			} else if vertical_align.is_percentage() {
				bottom_of_inline_box =
					bottom_of_inline_box.plus(computed.line_height().scaled(vertical_align.percentage().as_fraction()))
			}
		}
		uppermost_box_top = css_pixels_min(uppermost_box_top, top_of_inline_box)
		lowermost_box_bottom = css_pixels_max(lowermost_box_bottom, bottom_of_inline_box)
	}
	line_box.block_length_ = lowermost_box_bottom.minus(uppermost_box_top)
	line_box.bottom_ = builder.current_block_offset.plus(line_box.block_length_)
	line_box.baseline_ = line_box_baseline
}

pub fn (mut builder LineBuilder) remove_last_line_if_empty() {
	line_boxes := builder.containing_block_used_values.line_boxes
	if line_boxes.len > 0 && line_boxes.last().is_empty() {
		builder.containing_block_used_values.line_boxes.delete(line_boxes.len - 1)
		builder.last_line_needs_update = false
	}
}

pub fn (mut builder LineBuilder) recalculate_available_space() {
	builder.available_width_for_current_line = builder.available_width
	builder.current_line_inline_offset = CSSPixels.new(0)
	builder.next_float_bottom = none
	if context := builder.parent_block_context {
		if builder.available_width.is_definite() {
			left, right, next_bottom := context.float_boundaries_at(builder.current_block_offset,
				CSSPixels.new(1), builder.available_width.to_px_or_zero(), builder.direction,
				builder.containing_block_root_offset)
			width := right.minus(left)
			builder.available_width_for_current_line = AvailableSize.make_definite(if width.raw_value() > 0 {
				width
			} else {
				CSSPixels.new(0)
			})
			builder.current_line_inline_offset = left
			if !next_bottom.might_be_saturated() {
				builder.next_float_bottom = next_bottom
			}
		}
	}
	if builder.containing_block_used_values.line_boxes.len > 0 {
		mut line_box := builder.ensure_last_line_box()
		line_box.original_available_width_ = builder.available_width_for_current_line
	}
}

fn (builder &LineBuilder) float_edges_at_block_offset(block_offset CSSPixels) (CSSPixels, CSSPixels) {
	available_width := builder.available_width.to_px_or_zero()
	context := builder.parent_block_context or { return CSSPixels.new(0), available_width }

	left, right, _ := context.float_boundaries_at(block_offset, CSSPixels.new(1), available_width,
		builder.direction, builder.containing_block_root_offset)
	return left, right
}

fn (builder &LineBuilder) any_floats_intrude_at_block_offset(block_offset CSSPixels) bool {
	if !builder.available_width.is_definite() {
		return false
	}
	left, right := builder.float_edges_at_block_offset(block_offset)
	return left.raw_value() > 0
		|| right.raw_value() < builder.available_width.to_px_or_zero().raw_value()
}

fn (builder &LineBuilder) can_fit_new_line_at_block_offset(block_offset CSSPixels) bool {
	if !builder.available_width.is_definite() {
		return true
	}
	line_height := builder.containing_block.computed_values().line_height()
	bottom_offset := block_offset.plus(line_height).minus(CSSPixels.new(1))
	top_left, top_right := builder.float_edges_at_block_offset(block_offset)
	bottom_left, bottom_right := builder.float_edges_at_block_offset(bottom_offset)
	if top_left.raw_value() > bottom_right.raw_value() {
		return false
	}
	if bottom_left.raw_value() > top_right.raw_value() {
		return false
	}
	return true
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
		return text.font_for_rendering().pixel_metrics()
	}
	computed := node.computed_values()
	font := platform.Font{
		family:     'sans-serif'
		point_size: f32(computed.resolved_font_size_px())
		weight:     int(computed.font_weight())
	}
	return font.pixel_metrics()
}

// ComputedValues stores font-relative lengths in their typed form. Resolve
// them with the actual font selected for this layout node, matching
// StyleComputer's font-metric resolution in upstream (notably `ch` for text
// spacing and tab-size).
fn resolve_font_dependent_length_for_node(node &Node, length css.Length) CSSPixels {
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
	return resolve_font_dependent_length_for_node(node, node.computed_values().length(property_id))
}

fn font_baseline_for_line_height(font_metrics platform.FontPixelMetrics, line_height CSSPixels) CSSPixels {
	ascent := CSSPixels.nearest_value_for(f64(font_metrics.ascent))
	typographic_height :=
		CSSPixels.nearest_value_for(f64(font_metrics.ascent + font_metrics.descent))
	half_leading := CSSPixels.from_raw(line_height.minus(typographic_height).raw_value() / 2)
	return ascent.plus(half_leading)
}

fn css_pixels_min(a CSSPixels, b CSSPixels) CSSPixels {
	return if a.raw_value() < b.raw_value() { a } else { b }
}

fn css_pixels_max(a CSSPixels, b CSSPixels) CSSPixels {
	return if a.raw_value() > b.raw_value() { a } else { b }
}

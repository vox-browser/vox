// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import html
import math
import os
import painting
import svg
import time

fn paint_local_offset(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	mut offset := used.offset
	if coordinate := used.containing_line_box_fragment {
		if containing_block := node.containing_block() {
			containing_styled := unsafe { &NodeWithStyle(containing_block) }
			if containing_used := state.try_get(containing_styled) {
				if coordinate.line_box_index >= 0 && coordinate.line_box_index < containing_used.line_boxes.len {
					line_box := containing_used.line_boxes[coordinate.line_box_index]
					if coordinate.fragment_index >= 0 && coordinate.fragment_index < line_box.fragments_.len {
						offset = line_box.fragments_[coordinate.fragment_index].offset()
					}
				}
			}
		}
	}
	if used.node().computed_values().position() == .relative {
		offset = css_pixel_point_add(offset, css.CSSPixelPoint.from_values(used.inset_left.to_double(), used.inset_top.to_double()))
	}
	return offset
}

fn paint_cumulative_offset(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	offset := paint_local_offset(node, state, used)
	if containing := used.containing_block_used_values() {
		containing_node := unsafe { &Node(containing.node()) }
		return css_pixel_point_add(paint_cumulative_offset(containing_node, state, containing), offset)
	}
	return offset
}

fn color_resolution_context_for_typed_node(node &Node, current_color css.Color) css.ColorResolutionContext {
	mut context := css.ColorResolutionContext{
		current_color: current_color
	}
	if dom_node := node.dom_node() {
		if layout_node := dom_node.unsafe_layout_node() {
			context = css.color_resolution_context_for_layout_node(layout_node)
			context.current_color = current_color
		}
	}
	return context
}

fn computed_paint_color(computed &css.ComputedProperties, property css.PropertyID, context css.ColorResolutionContext, fallback css.Color) css.Color {
	value := computed.typed_property_value(property) or { return fallback }
	return value.to_color(context) or {
		fallback
	}
}

fn compatibility_scrollbar_color(color css.ComputedColor) css.Color {
	return css.Color{color.red(), color.green(), color.blue(), color.alpha()}
}

fn compatibility_overflow_allows_scrolling(overflow css.Overflow, is_viewport bool) bool {
	return (is_viewport && overflow != .hidden) || overflow in [.auto_, .scroll]
}

fn compatibility_has_resizer(node &Node, computed &css.ComputedProperties) bool {
	// Translation of PaintableBox::physical_resize_axes() and has_resizer().
	if node.is_viewport() || node.is_generated_for_pseudo_element() || computed.resize() == .none_ {
		return false
	}
	display := computed.display()
	if display.is_inline_outside() && display.is_flow_inside() {
		return false
	}
	horizontal_writing_mode := computed.writing_mode() == .horizontal_tb
	resize := computed.resize()
	horizontal := computed.overflow_x() !in [.visible, .clip] && (resize in [.both, .horizontal] || (resize == .inline_ && horizontal_writing_mode) || (resize == .block && !horizontal_writing_mode))
	vertical := computed.overflow_y() !in [.visible, .clip] && (resize in [.both, .vertical] || (resize == .inline_ && !horizontal_writing_mode) || (resize == .block && horizontal_writing_mode))
	return horizontal || vertical
}

fn compatibility_overlay_data(node &Node, computed &css.ComputedProperties, used &UsedValues) ?CompatibilityOverlayData {
	overflow := used.scrollable_overflow_rect() or { return none }
	padding_width := used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
	padding_height := used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
	can_scroll_horizontally := compatibility_overflow_allows_scrolling(computed.overflow_x(), node.is_viewport()) && overflow.width.to_double() > padding_width
	can_scroll_vertically := compatibility_overflow_allows_scrolling(computed.overflow_y(), node.is_viewport()) && overflow.height.to_double() > padding_height
	has_resizer := compatibility_has_resizer(node, computed)
	if !can_scroll_horizontally && !can_scroll_vertically && !has_resizer {
		return none
	}

	mut scroll_offset_x := 0.0
	mut scroll_offset_y := 0.0
	mut thumb_color := css.Color{64, 64, 64, 192}
	mut track_color := css.Color{212, 208, 200, 192}
	mut default_colors := true
	colors := unsafe { &css.ComputedValues(computed) }.computed_scrollbar_color()
	if !colors.auto_ {
		thumb_color = compatibility_scrollbar_color(colors.thumb)
		track_color = compatibility_scrollbar_color(colors.track)
		default_colors = false
	}
	if dom_node := node.dom_node() {
		if paintable := dom_node.paintable_box() {
			scroll_offset := paintable.scroll_offset()
			scroll_offset_x = scroll_offset.x()
			scroll_offset_y = scroll_offset.y()
		}
	}
	writing_mode := computed.writing_mode()
	chrome_mirrored := (writing_mode == .horizontal_tb && computed.direction() == .rtl) || writing_mode in [
		.vertical_rl,
		.sideways_rl,
	]
	return CompatibilityOverlayData{
		scrollable_overflow: LayoutRect{
			x: overflow.x.to_double()
			y: overflow.y.to_double()
			width: overflow.width.to_double()
			height: overflow.height.to_double()
		}
		scroll_offset_x: scroll_offset_x
		scroll_offset_y: scroll_offset_y
		can_scroll_horizontally: can_scroll_horizontally
		can_scroll_vertically: can_scroll_vertically
		scrollbar_width: computed.scrollbar_width()
		scrollbar_thumb_color: thumb_color
		scrollbar_track_color: track_color
		default_scrollbar_colors: default_colors
		has_resizer: has_resizer
		chrome_mirrored: chrome_mirrored
	}
}

// Translation of ViewportPaintable::compute_clip_data() and
// PaintableBox::overflow_clip_edge_rect(). Geometry remains in CSS pixels; the
// visual-context builder performs the device-pixel rounding at commit time.
fn compatibility_overflow_clip(node &Node, computed &css.ComputedProperties, used &UsedValues, position css.CSSPixelPoint, border_radii BoxRadii) ?CompatibilityOverflowClip {
	mut overflow_x := computed.overflow_x()
	mut overflow_y := computed.overflow_y()
	if node.has_paint_containment() {
		if overflow_x == .visible {
			overflow_x = .clip
		}
		if overflow_y == .visible {
			overflow_y = .clip
		}
	}
	if overflow_x == .visible && overflow_y == .visible {
		return none
	}
	display := computed.display()
	if node.is_svg_box() || node.is_inline_node() || display.is_ruby_inside()
		|| (display.is_internal() && !display.is_table_cell() && !display.is_table_caption()) {
		return none
	}

	padding_rect := LayoutRect{
		x: position.x().to_double() - used.padding_left.to_double()
		y: position.y().to_double() - used.padding_top.to_double()
		width: used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
		height: used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
	}
	mut overflow_clip_edge := if node.is_replaced_box() {
		LayoutRect{
			x: position.x().to_double()
			y: position.y().to_double()
			width: used.content_width().to_double()
			height: used.content_height().to_double()
		}
	} else {
		padding_rect
	}
	clip_margin := unsafe { &css.ComputedValues(computed) }.overflow_clip_margin()
	context := computed.length_resolution_context()
	margin_top := clip_margin.top().to_px_or_zero(context, css.CSSPixels{}).to_double()
	margin_right := clip_margin.right().to_px_or_zero(context, css.CSSPixels{}).to_double()
	margin_bottom := clip_margin.bottom().to_px_or_zero(context, css.CSSPixels{}).to_double()
	margin_left := clip_margin.left().to_px_or_zero(context, css.CSSPixels{}).to_double()
	overflow_clip_edge = LayoutRect{
		x: overflow_clip_edge.x - margin_left
		y: overflow_clip_edge.y - margin_top
		width: overflow_clip_edge.width + margin_left + margin_right
		height: overflow_clip_edge.height + margin_top + margin_bottom
	}

	unbounded_clip_extent := 1_000_000_000.0
	clip_x := if overflow_x == .visible {
		-unbounded_clip_extent
	} else if overflow_x == .clip {
		overflow_clip_edge.x
	} else {
		padding_rect.x
	}
	clip_width := if overflow_x == .visible {
		unbounded_clip_extent * 2
	} else if overflow_x == .clip {
		overflow_clip_edge.width
	} else {
		padding_rect.width
	}
	clip_y := if overflow_y == .visible {
		-unbounded_clip_extent
	} else if overflow_y == .clip {
		overflow_clip_edge.y
	} else {
		padding_rect.y
	}
	clip_height := if overflow_y == .visible {
		unbounded_clip_extent * 2
	} else if overflow_y == .clip {
		overflow_clip_edge.height
	} else {
		padding_rect.height
	}
	clip_rect := LayoutRect{clip_x, clip_y, clip_width, clip_height}

	mut radii := BoxRadii{}
	if overflow_x != .visible && overflow_y != .visible {
		radii = normalize_box_radii(BoxRadii{
			top_left: shrink_corner_radius(border_radii.top_left, used.border_left.to_double(), used.border_top.to_double())
			top_right: shrink_corner_radius(border_radii.top_right, used.border_right.to_double(), used.border_top.to_double())
			bottom_right: shrink_corner_radius(border_radii.bottom_right, used.border_right.to_double(), used.border_bottom.to_double())
			bottom_left: shrink_corner_radius(border_radii.bottom_left, used.border_left.to_double(), used.border_bottom.to_double())
		}, clip_rect.width, clip_rect.height)
	}
	return CompatibilityOverflowClip{
		rect: clip_rect
		corner_radii: radii
	}
}

fn computed_border_colors(computed &css.ComputedValues) BoxColors {
	return BoxColors{
		top: computed.border_top().color
		right: computed.border_right().color
		bottom: computed.border_bottom().color
		left: computed.border_left().color
	}
}

fn computed_border_styles(computed &css.ComputedValues) BoxBorderStyles {
	return BoxBorderStyles{
		top: table_painting_line_style(computed.border_top().line_style)
		right: table_painting_line_style(computed.border_right().line_style)
		bottom: table_painting_line_style(computed.border_bottom().line_style)
		left: table_painting_line_style(computed.border_left().line_style)
	}
}

fn retained_table_cell_borders(values &css.ComputedValues, used &UsedValues, colors BoxColors) painting.BordersDataWithElementKind {
	return painting.BordersDataWithElementKind{
		top: painting.BorderDataWithElementKind{
			border_data: painting.BorderData{
				color: painting.Color{colors.top.r, colors.top.g, colors.top.b, colors.top.a}
				line_style: table_painting_line_style(values.border_top().line_style)
				width: used.border_top.to_double()
			}
			element_kind: .cell
		}
		right: painting.BorderDataWithElementKind{
			border_data: painting.BorderData{
				color: painting.Color{colors.right.r, colors.right.g, colors.right.b, colors.right.a}
				line_style: table_painting_line_style(values.border_right().line_style)
				width: used.border_right.to_double()
			}
			element_kind: .cell
		}
		bottom: painting.BorderDataWithElementKind{
			border_data: painting.BorderData{
				color: painting.Color{colors.bottom.r, colors.bottom.g, colors.bottom.b, colors.bottom.a}
				line_style: table_painting_line_style(values.border_bottom().line_style)
				width: used.border_bottom.to_double()
			}
			element_kind: .cell
		}
		left: painting.BorderDataWithElementKind{
			border_data: painting.BorderData{
				color: painting.Color{colors.left.r, colors.left.g, colors.left.b, colors.left.a}
				line_style: table_painting_line_style(values.border_left().line_style)
				width: used.border_left.to_double()
			}
			element_kind: .cell
		}
	}
}

fn computed_corner_radius(values &css.ComputedValues, property css.PropertyID, width f64, height f64) CornerRadius {
	radius := match property {
		.border_bottom_left_radius { values.border_bottom_left_radius() }
		.border_bottom_right_radius { values.border_bottom_right_radius() }
		.border_top_left_radius { values.border_top_left_radius() }
		.border_top_right_radius { values.border_top_right_radius() }
		else {
			return CornerRadius{}
		}
	}
	context := css.LengthResolutionContext.for_computed_properties(values)
	x := non_negative(radius.horizontal_radius.to_px(context, css.CSSPixels.nearest_value_for(width)).to_double())
	y := non_negative(radius.vertical_radius.to_px(context, css.CSSPixels.nearest_value_for(height)).to_double())
	return CornerRadius{x, y}
}

fn computed_box_radii(computed &css.ComputedValues, width f64, height f64) BoxRadii {
	return normalize_box_radii(BoxRadii{
		top_left: computed_corner_radius(computed, .border_top_left_radius, width, height)
		top_right: computed_corner_radius(computed, .border_top_right_radius, width, height)
		bottom_right: computed_corner_radius(computed, .border_bottom_right_radius, width, height)
		bottom_left: computed_corner_radius(computed, .border_bottom_left_radius, width, height)
	}, width, height)
}

fn computed_outline_width(computed &css.ComputedValues) f64 {
	return match computed.outline_style() {
		.auto_ { 2.0 }
		.none_ { 0.0 }
		else { computed.outline_width().to_double() }
	}
}

fn computed_outline_line_style(style css.OutlineStyle) painting.LineStyle {
	return match style {
		.auto_ { .solid }
		.none_ { .none }
		.dotted { .dotted }
		.dashed { .dashed }
		.solid { .solid }
		.double_ { .double }
		.groove { .groove }
		.ridge { .ridge }
		.inset { .inset }
		.outset { .outset }
	}
}

fn computed_box_shadows(computed &css.ComputedValues) []BoxShadow {
	context := css.LengthResolutionContext.for_computed_properties(computed)
	shadow_data := computed.box_shadow()
	mut shadows := []BoxShadow{cap: shadow_data.len}
	for shadow in shadow_data {
		shadows << BoxShadow{
			offset_x: shadow.offset_x.to_px(context).to_double()
			offset_y: shadow.offset_y.to_px(context).to_double()
			blur: non_negative(shadow.blur_radius.to_px(context).to_double())
			spread: shadow.spread_distance.to_px(context).to_double()
			color: css.Color{shadow.color.red(), shadow.color.green(), shadow.color.blue(), shadow.color.alpha()}
			inset: shadow.inset
		}
	}
	return shadows
}

fn compatibility_color_filter_type(operation css.ColorFilterType) painting.ColorFilterType {
	return match operation {
		.brightness { .brightness }
		.contrast { .contrast }
		.grayscale { .grayscale }
		.invert { .invert }
		.opacity { .opacity }
		.saturate { .saturate }
		.sepia { .sepia }
	}
}

// Translation of Painting::resolve_css_filter() for the computed CSS filter
// operations. Computed filter lengths have already been absolutized by the
// style computer, just as they are before the C++ paintable resolver runs.
fn painting_filter_from_svg_graph(graph svg.FilterGraph) ?painting.GfxFilter {
	root_id := graph.root_id or { return none }
	mut nodes := []painting.GfxFilterNode{cap: graph.nodes.len}
	for node in graph.nodes {
		mut color_tables := []painting.GfxFilterColorTable{cap: node.color_tables.len}
		for table in node.color_tables {
			color_tables << painting.GfxFilterColorTable{
				channel: table.channel
				values: table.values.clone()
			}
		}
		nodes << painting.GfxFilterNode{
			id: node.id
			kind: node.kind
			input_ids: node.input_ids.clone()
			parameters: node.parameters.clone()
			string_parameters: node.string_parameters.clone()
			color: painting.Color{
				r: u8((node.color >> 16) & 0xff)
				g: u8((node.color >> 8) & 0xff)
				b: u8(node.color & 0xff)
				a: u8((node.color >> 24) & 0xff)
			}
			matrix: node.matrix.clone()
			color_tables: color_tables
		}
	}
	return painting.GfxFilter{
		nodes: nodes
		root_id: root_id
	}
}

fn resolved_svg_filter(element &dom.Element, reference string) ?painting.GfxFilter {
	// PaintableBox.cpp accepts same-document fragments only; external URL
	// filter resources are intentionally ignored by the upstream algorithm.
	if reference.len < 2 || reference[0] != `#` {
		return none
	}
	filter_element := element.document().get_element_by_id(reference[1..]) or { return none }
	if !filter_element.is_svg_element() || filter_element.local_name() != 'filter' {
		return none
	}
	return painting_filter_from_svg_graph(svg_element_model(filter_element).gfx_filter())
}

fn resolved_css_filter_for_element(computed &css.ComputedValues, color_context css.ColorResolutionContext,
	element ?&dom.Element, bounds ?painting.Rect) painting.ResolvedCSSFilter {
	if !computed.filter().has_filters() {
		return painting.ResolvedCSSFilter{}
	}
	mut operations := []painting.ResolvedFilterOperation{}
	mut svg_filter := ?painting.GfxFilter(none)
	mut svg_filter_bounds := ?painting.Rect(none)
	for filter_operation in computed.filter().filters() {
		match filter_operation {
			css.FilterOperationBlur {
				operations << painting.BlurFilter{
					radius: css.CSSPixels.nearest_value_for(filter_operation.resolved_radius()).to_double()
				}
			}
			css.FilterOperationDropShadow {
				fallback_color := computed.color()
				resolved_color := if color := filter_operation.color {
					color.to_color(color_context) or { fallback_color }
				} else {
					fallback_color
				}
				operations << painting.DropShadowFilter{
					offset_x: css.Length.from_style_value_logic(filter_operation.offset_x, none).absolute_length_to_px().to_double()
					offset_y: css.Length.from_style_value_logic(filter_operation.offset_y, none).absolute_length_to_px().to_double()
					radius: if radius := filter_operation.radius {
						css.Length.from_style_value_logic(radius, none).absolute_length_to_px().to_double()
					} else {
						0
					}
					color: painting.Color{resolved_color.r, resolved_color.g, resolved_color.b, resolved_color.a}
				}
			}
			css.FilterOperationColor {
				operations << painting.ColorFilter{
					operation: compatibility_color_filter_type(filter_operation.operation)
					amount: filter_operation.resolved_amount()
				}
			}
			css.FilterOperationHueRotate {
				operations << painting.HueRotateFilter{
					angle_degrees: filter_operation.angle_degrees()
				}
			}
			css.URL {
				if painted_element := element {
					if resolved := resolved_svg_filter(painted_element, filter_operation.url()) {
						svg_filter = resolved
						svg_filter_bounds = bounds
					}
				}
			}
		}
	}
	return painting.ResolvedCSSFilter{
		operations: operations
		svg_filter: svg_filter
		svg_filter_bounds: svg_filter_bounds
	}
}

fn resolved_css_filter(computed &css.ComputedValues, color_context css.ColorResolutionContext) painting.ResolvedCSSFilter {
	return resolved_css_filter_for_element(computed, color_context, none, none)
}

struct TypedGradientStop {
mut:
	color           css.Color
	position        ?f64
	transition_hint ?f64
}

fn interpolate_typed_gradient_color(from css.Color, to css.Color, amount f64) css.Color {
	t := math.max(0.0, math.min(amount, 1.0))
	return css.Color{
		r: u8(int(math.round(f64(from.r) + (f64(to.r) - f64(from.r)) * t)))
		g: u8(int(math.round(f64(from.g) + (f64(to.g) - f64(from.g)) * t)))
		b: u8(int(math.round(f64(from.b) + (f64(to.b) - f64(from.b)) * t)))
		a: u8(int(math.round(f64(from.a) + (f64(to.a) - f64(from.a)) * t)))
	}
}

fn typed_gradient_color_stop_step(previous TypedGradientStop, next TypedGradientStop, position f64) f64 {
	previous_position := previous.position or { return 0 }
	next_position := next.position or { return 1 }
	if position < previous_position {
		return 0
	}
	if position > next_position {
		return 1
	}
	stop_length := next_position - previous_position
	if stop_length <= 0 {
		return 1
	}
	p := (position - previous_position) / stop_length
	hint := next.transition_hint or { return p }
	if hint >= 1 {
		return 0
	}
	if hint <= 0 {
		return 1
	}
	return math.pow(p, math.log(0.5) / math.log(hint))
}

// Painting::replace_transition_hints_with_normal_color_stops(). Five sampled
// stops reproduce the specified non-linear midpoint closely with a renderer
// that performs ordinary linear interpolation.
fn replace_typed_gradient_transition_hints(stops []TypedGradientStop) []TypedGradientStop {
	if stops.len == 0 {
		return []TypedGradientStop{}
	}
	mut result := [TypedGradientStop{
		color: stops[0].color
		position: stops[0].position
	}]
	for index := 1; index < stops.len; index++ {
		stop := stops[index]
		hint := stop.transition_hint or {
			result << TypedGradientStop{
				color: stop.color
				position: stop.position
			}
			continue
		}
		previous := stops[index - 1]
		previous_position := previous.position or { 0.0 }
		next_position := stop.position or { previous_position }
		distance := next_position - previous_position
		for relative_position in [hint * 0.33, hint * 0.66, hint, hint + (1.0 - hint) * 0.33,
			hint + (1.0 - hint) * 0.66] {
			position := previous_position + relative_position * distance
			amount := typed_gradient_color_stop_step(previous, stop, position)
			result << TypedGradientStop{
				color: interpolate_typed_gradient_color(previous.color, stop.color, amount)
				position: position
			}
		}
		result << TypedGradientStop{
			color: stop.color
			position: stop.position
		}
	}
	return result
}

fn typed_gradient_color_at_stops(previous TypedGradientStop, next TypedGradientStop, position f64) css.Color {
	amount := typed_gradient_color_stop_step(previous, next, position)
	return interpolate_typed_gradient_color(previous.color, next.color, amount)
}

// Painting::expand_repeat_length(), used because the compact native transport
// has no Skia-style repeat-length field of its own.
fn expand_typed_repeating_gradient(stops []TypedGradientStop) []TypedGradientStop {
	if stops.len < 2 {
		return stops
	}
	first_position := stops[0].position or { return stops }
	last_position := stops[stops.len - 1].position or { return stops }
	repeat_length := last_position - first_position
	if repeat_length <= 0 {
		return stops
	}
	negative_repeat_count := int(math.ceil(first_position / repeat_length))
	positive_repeat_count := int(math.ceil((1.0 - first_position) / repeat_length))
	mut expanded := stops.clone()
	for repeat_count := 1; repeat_count <= negative_repeat_count; repeat_count++ {
		for source_index := stops.len - 1; source_index >= 0; source_index-- {
			mut stop := stops[source_index]
			stop.position = (stop.position or { 0.0 }) - repeat_length * f64(repeat_count)
			if (stop.position or { 0.0 }) < 0 {
				first := expanded[0]
				stop.color = typed_gradient_color_at_stops(stop, first, 0)
				stop.position = 0.0
				expanded.prepend(stop)
				break
			}
			expanded.prepend(stop)
		}
	}
	for repeat_count := 1; repeat_count < positive_repeat_count; repeat_count++ {
		for source in stops {
			mut stop := source
			stop.position = (stop.position or { 0.0 }) + repeat_length * f64(repeat_count)
			if (stop.position or { 0.0 }) > 1 {
				last := expanded[expanded.len - 1]
				stop.color = typed_gradient_color_at_stops(last, stop, 1)
				stop.position = 1.0
				expanded << stop
				break
			}
			expanded << stop
		}
	}
	return expanded
}

fn typed_gradient_length_percentage_px(value css.StyleValue,
	resolution_context css.LengthResolutionContext, basis f64) ?f64 {
	if value.is_percentage() {
		return value.as_percentage().percentage().value() * basis / 100.0
	}
	if value.is_calculated() {
		calculation_context := css.CalculationResolutionContext{
			percentage_basis: css.Length.make_px(basis)
			length_resolution_context: resolution_context
		}
		length := value.as_calculated().resolve_length(calculation_context) or { return none }
		return length.to_px(resolution_context).to_double()
	}
	if value.is_length() {
		return value.as_length().length().to_px(resolution_context).to_double()
	}
	return none
}

fn typed_gradient_position_as_length(resolution_context css.LengthResolutionContext,
	value css.StyleValue, basis f64) f64 {
	if basis == 0 {
		return 0
	}
	return (typed_gradient_length_percentage_px(value, resolution_context, basis) or { 0.0 }) / basis
}

fn typed_gradient_position_as_angle(value css.StyleValue) f64 {
	if value.is_percentage() {
		return value.as_percentage().percentage().value() / 100.0
	}
	if value.is_angle() {
		return value.as_angle().angle().to_degrees() / 360.0
	}
	if value.is_calculated() {
		if angle := value.as_calculated().resolve_angle(css.CalculationResolutionContext{}) {
			return angle.to_degrees() / 360.0
		}
	}
	return 0
}

fn resolve_typed_gradient_stops(elements []css.ColorStopListElement, context css.ColorResolutionContext, repeating bool, resolve_position fn (css.StyleValue) f64) []GradientStop {
	if elements.len == 0 {
		return []GradientStop{}
	}
	mut resolved := []TypedGradientStop{}
	for element in elements {
		color := element.color_stop.color.to_color(context) or { continue }
		mut stop := TypedGradientStop{
			color: color
		}
		if hint := element.transition_hint {
			stop.transition_hint = resolve_position(hint)
		}
		if position := element.color_stop.position {
			stop.position = resolve_position(position)
		}
		resolved << stop
		if second_position := element.color_stop.second_position {
			resolved << TypedGradientStop{
				color: color
				position: resolve_position(second_position)
			}
		}
	}
	if resolved.len == 0 {
		return []GradientStop{}
	}
	if resolved[0].position == none {
		resolved[0].position = 0.0
	}
	if resolved[resolved.len - 1].position == none {
		resolved[resolved.len - 1].position = 1.0
	}
	mut maximum_previous := resolved[0].position or { 0.0 }
	for index in 0 .. resolved.len {
		if hint := resolved[index].transition_hint {
			clamped := math.max(hint, maximum_previous)
			resolved[index].transition_hint = clamped
			maximum_previous = clamped
		}
		if position := resolved[index].position {
			clamped := math.max(position, maximum_previous)
			resolved[index].position = clamped
			maximum_previous = clamped
		}
	}
	mut index := 1
	for index < resolved.len - 1 {
		if resolved[index].position != none {
			index++
			continue
		}
		run_start := index - 1
		mut run_end := index + 1
		for run_end < resolved.len - 1 && resolved[run_end].position == none && resolved[run_end].transition_hint == none {
			run_end++
		}
		start_position := resolved[index].transition_hint or {
			resolved[run_start].position or { 0.0 }
		}
		end_position := resolved[run_end].transition_hint or {
			resolved[run_end].position or { start_position }
		}
		spacing := (end_position - start_position) / f64(run_end - run_start)
		for missing := index; missing < run_end; missing++ {
			resolved[missing].position = start_position + f64(missing - run_start) * spacing
		}
		index = run_end
	}
	for hint_index := 1; hint_index < resolved.len; hint_index++ {
		if hint := resolved[hint_index].transition_hint {
			previous_position := resolved[hint_index - 1].position or { 0.0 }
			position := resolved[hint_index].position or { previous_position }
			stop_length := position - previous_position
			resolved[hint_index].transition_hint = if stop_length > 0 {
				(hint - previous_position) / stop_length
			} else {
				0.0
			}
		}
	}
	if repeating {
		resolved = expand_typed_repeating_gradient(resolved)
	}
	resolved = replace_typed_gradient_transition_hints(resolved)
	mut result := []GradientStop{cap: resolved.len}
	for stop in resolved {
		result << GradientStop{
			color: stop.color
			offset: stop.position or { 0.0 }
		}
	}
	return result
}

fn resolved_typed_gradient_position(resolution_context css.LengthResolutionContext,
	position css.PositionStyleValue, width f64, height f64) (f64, f64) {
	resolved := position.with_resolved_keywords()
	x := typed_gradient_position_as_length(resolution_context, resolved.edge_x().offset(), width)
	y := typed_gradient_position_as_length(resolution_context, resolved.edge_y().offset(), height)
	return x, y
}

fn resolved_typed_linear_gradient(resolution_context css.LengthResolutionContext,
	gradient css.LinearGradientStyleValue, width f64, height f64,
	context css.ColorResolutionContext) LinearGradient {
	angle := gradient.angle_degrees(css.CSSPixelSize.from_values(width, height))
	radians := angle * math.pi / 180.0
	direction_x := math.sin(radians)
	direction_y := -math.cos(radians)
	real_angle := (90.0 - angle) * math.pi / 180.0
	gradient_length := math.abs(height * math.sin(real_angle)) + math.abs(width * math.cos(real_angle))
	half_x := if width == 0 { 0.0 } else { direction_x * gradient_length / (2.0 * width) }
	half_y := if height == 0 { 0.0 } else { direction_y * gradient_length / (2.0 * height) }
	stops := resolve_typed_gradient_stops(gradient.color_stop_list_, context, gradient.is_repeating(), fn [resolution_context, gradient_length] (value css.StyleValue) f64 {
		return typed_gradient_position_as_length(resolution_context, value, gradient_length)
	})
	return LinearGradient{
		x1: 0.5 - half_x
		y1: 0.5 - half_y
		x2: 0.5 + half_x
		y2: 0.5 + half_y
		colors: stops.map(it.color)
		stops: stops
		interpolation_method: gradient.interpolation_method()
	}
}

fn radial_extent_size(extent css.RadialExtent, center_x f64, center_y f64, width f64, height f64) (f64, f64) {
	left := math.abs(center_x)
	right := math.abs(width - center_x)
	top := math.abs(center_y)
	bottom := math.abs(height - center_y)
	match extent {
		.closest_side {
			return math.min(left, right), math.min(top, bottom)
		}
		.farthest_side {
			return math.max(left, right), math.max(top, bottom)
		}
		.closest_corner, .farthest_corner {
			base_x := if extent == .closest_corner {
				math.min(left, right)
			} else {
				math.max(left, right)
			}
			base_y := if extent == .closest_corner {
				math.min(top, bottom)
			} else {
				math.max(top, bottom)
			}
			if base_y == 0 {
				return base_x, 1.0 / 64.0
			}
			aspect := base_x / base_y
			x := math.sqrt(base_y * base_y * aspect * aspect + base_x * base_x)
			return x, x / aspect
		}
	}
}

fn resolved_typed_radial_gradient(resolution_context css.LengthResolutionContext,
	gradient css.RadialGradientStyleValue, width f64, height f64,
	context css.ColorResolutionContext) LinearGradient {
	center_fraction_x, center_fraction_y := resolved_typed_gradient_position(resolution_context, gradient.position_, width, height)
	center_x := center_fraction_x * width
	center_y := center_fraction_y * height
	components := if radial_size := gradient.size_.as_radial_size() {
		radial_size.components()
	} else {
		[]css.RadialSizeStyleValueComponent{}
	}
	mut radius_x := width / 2.0
	mut radius_y := height / 2.0
	if components.len > 0 {
		first := components[0]
		match first {
			css.RadialExtentComponent {
				radius_x, radius_y = radial_extent_size(first.extent, center_x, center_y, width, height)
			}
			css.StyleValue {
				if gradient.ending_shape_ == .circle {
					reference := math.sqrt(width * width + height * height) / math.sqrt(2.0)
					radius_x = typed_gradient_length_percentage_px(first, resolution_context, reference) or {
						0.0
					}
					radius_y = radius_x
				} else {
					radius_x = typed_gradient_length_percentage_px(first, resolution_context, width) or {
						0.0
					}
					second := if components.len > 1 { components[1] } else { first }
					match second {
						css.RadialExtentComponent {}
						css.StyleValue {
							radius_y = typed_gradient_length_percentage_px(second, resolution_context, height) or {
								0.0
							}
						}
					}
				}
			}
		}
	}
	if gradient.ending_shape_ == .circle {
		if components.len > 0 && components[0] is css.RadialExtentComponent {
			extent := (components[0] as css.RadialExtentComponent).extent
			radius := match extent {
				.closest_side { math.min(radius_x, radius_y) }
				.farthest_side { math.max(radius_x, radius_y) }
				.closest_corner, .farthest_corner {
					math.sqrt(radius_x * radius_x + radius_y * radius_y)
				}
			}
			radius_x = radius
			radius_y = radius
		}
	}
	if radius_x <= 0 {
		radius_x = 1.0 / 64.0
	}
	if radius_y <= 0 {
		radius_y = 1.0 / 64.0
	}
	stops := resolve_typed_gradient_stops(gradient.color_stop_list_, context, gradient.is_repeating(), fn [resolution_context, radius_x] (value css.StyleValue) f64 {
		return typed_gradient_position_as_length(resolution_context, value, radius_x)
	})
	return LinearGradient{
		colors: stops.map(it.color)
		stops: stops
		interpolation_method: gradient.interpolation_method()
		radial: true
		kind: 'radial'
		center_x: center_fraction_x
		center_y: center_fraction_y
		radius_x: if width == 0 { 0.0 } else { radius_x / width }
		radius_y: if height == 0 { 0.0 } else { radius_y / height }
	}
}

fn resolved_typed_conic_gradient(resolution_context css.LengthResolutionContext,
	gradient css.ConicGradientStyleValue, width f64, height f64,
	context css.ColorResolutionContext) LinearGradient {
	center_x, center_y := resolved_typed_gradient_position(resolution_context, gradient.position_, width, height)
	stops := resolve_typed_gradient_stops(gradient.color_stop_list_, context, gradient.is_repeating(), fn (value css.StyleValue) f64 {
		return typed_gradient_position_as_angle(value)
	})
	return LinearGradient{
		colors: stops.map(it.color)
		stops: stops
		interpolation_method: gradient.interpolation_method()
		kind: 'conic'
		center_x: center_x
		center_y: center_y
		start_degrees: gradient.angle_degrees()
	}
}

// Resolve a retained CSS gradient for its concrete image tile. BackgroundPainting first runs the
// image sizing algorithm, then asks the gradient to resolve for exactly this size; radial geometry
// and length-valued stops therefore must not be frozen to the element's border box in the adapter.
pub fn resolve_background_gradient(source css.StyleValue, width f64, height f64,
	resolution_context css.LengthResolutionContext,
	color_context css.ColorResolutionContext) ?LinearGradient {
	if gradient := source.as_linear_gradient() {
		return resolved_typed_linear_gradient(resolution_context, gradient, width, height, color_context)
	}
	if gradient := source.as_radial_gradient() {
		return resolved_typed_radial_gradient(resolution_context, gradient, width, height, color_context)
	}
	if gradient := source.as_conic_gradient() {
		return resolved_typed_conic_gradient(resolution_context, gradient, width, height, color_context)
	}
	return none
}

fn computed_background_gradient(computed &css.ComputedProperties, width f64, height f64, context css.ColorResolutionContext) ?LinearGradient {
	value := computed.typed_property_value(.background_image) or { return none }
	values := if list := value.as_value_list() { list.values() } else { [value] }
	for item in values {
		if gradient := resolve_background_gradient(item, width, height, computed.length_resolution_context(), context) {
			return gradient
		}
	}
	return none
}

fn computed_coordinated_background_value(computed &css.ComputedProperties, property css.PropertyID, index int, fallback string) string {
	value := computed.typed_property_value(property) or { return fallback }
	if list := value.as_value_list() {
		if list.separator() != .comma {
			return value.serialize(.normal)
		}
		if list.size() == 0 {
			return fallback
		}
		return list.value_at(index, true).serialize(.normal)
	}
	return value.serialize(.normal)
}

fn computed_background_image_layers(element &dom.Element, computed &css.ComputedProperties,
	color_context css.ColorResolutionContext) []BackgroundImageLayer {
	value := computed.typed_property_value(.background_image) or { return []BackgroundImageLayer{} }
	computed_layers := computed.background_layers()
	base_url := if dom_value := computed.property(.background_image, .yes) {
		dom_value.base_url
	} else {
		?string(none)
	}
	values := if list := value.as_value_list() {
		if list.separator() == .comma { list.values() } else { [value] }
	} else {
		[value]
	}
	mut layers := []BackgroundImageLayer{}
	mut computed_layer_index := 0
	for index, item in values {
		mut computed_layer := ?css.BackgroundLayerData(none)
		if !(item.is_keyword() && item.to_keyword() == .none_) {
			if computed_layer_index < computed_layers.len {
				computed_layer = computed_layers[computed_layer_index]
			}
			computed_layer_index++
		}
		mut gradient_source := ?css.StyleValue(none)
		if item is css.LinearGradientStyleValue || item is css.RadialGradientStyleValue
			|| item is css.ConicGradientStyleValue {
			gradient_source = item
		}
		mut resolved_url := ''
		if image := item.as_image() {
			source := image.url_.url()
			resolved_url = if base := base_url {
				if parsed := dom.dom_url_parse(source, dom.URL{base}, '') {
					parsed.to_string()
				} else {
					source
				}
			} else {
				element.document().encoding_parse_and_serialize_url(source) or { source }
			}
		} else if gradient_source == none {
			continue
		}
		repeat_x, repeat_y := parsed_background_repeat(computed_coordinated_background_value(computed, .background_repeat, index, 'repeat'))
		layers << BackgroundImageLayer{
			url: resolved_url
			gradient_source: gradient_source
			gradient_context: color_context
			repeat_x: repeat_x
			repeat_y: repeat_y
			size: computed_coordinated_background_value(computed, .background_size, index, 'auto')
			position_x: computed_coordinated_background_value(computed, .background_position_x, index, '0%')
			position_y: computed_coordinated_background_value(computed, .background_position_y, index, '0%')
			origin: computed_coordinated_background_value(computed, .background_origin, index, 'padding-box')
			clip: computed_coordinated_background_value(computed, .background_clip, index, 'border-box')
			attachment: computed_coordinated_background_value(computed, .background_attachment, index, 'scroll')
			computed_layer: computed_layer
			resolution_context: computed.length_resolution_context()
		}
	}
	return layers
}

fn computed_text_decoration_thickness(computed &css.ComputedProperties, font_size f64) f64 {
	thickness := computed.text_decoration_thickness()
	if thickness.is_auto || thickness.from_font {
		return 0
	}
	return non_negative(thickness.length_percentage.to_px(computed.length_resolution_context(), css.CSSPixels.nearest_value_for(font_size)).to_double())
}

fn computed_text_decoration_style(computed &css.ComputedProperties) string {
	return match computed.text_decoration_style() {
		.solid { 'solid' }
		.double_ { 'double' }
		.dotted { 'dotted' }
		.dashed { 'dashed' }
		.wavy { 'wavy' }
	}
}

fn computed_transform_is_none(computed &css.ComputedProperties) bool {
	value := computed.typed_property_value(.transform) or { return true }
	return value.is_keyword() && value.to_keyword() == .none_
}

fn computed_svg_paint_color(computed &css.ComputedValues, property css.PropertyID) ?css.Color {
	paint := match property {
		.fill { computed.fill() or { return none } }
		.stroke { computed.stroke() or { return none } }
		else {
			return none
		}
	}
	if paint.is_color() {
		return paint.as_color()
	}
	return paint.fallback_color()
}

fn svg_paint_fragment(reference string) ?string {
	fragment_offset := reference.index('#') or { return none }
	if fragment_offset + 1 >= reference.len {
		return none
	}
	return reference[fragment_offset + 1..]
}

fn svg_gradient_link_fragment(document &dom.Document, reference string) ?string {
	if reference == '' {
		return none
	}
	parsed := document.encoding_parse_url(reference) or { return none }
	fragment := parsed.fragment() or { return none }
	return if fragment == '' { none } else { fragment }
}

fn svg_gradient_href(element &dom.Element) string {
	if element.has_attribute('href') {
		return element.get_attribute_value('href').trim_space()
	}
	if href := element.get_attribute_ns('http://www.w3.org/1999/xlink', 'href') {
		return href.trim_space()
	}
	return element.get_attribute_value('xlink:href').trim_space()
}

fn linked_svg_gradient(element &dom.Element, mut seen map[i64]bool) ?&dom.Element {
	identity := element.as_node().unique_id().value()
	if !seen[identity] {
		seen[identity] = true
	}
	fragment := svg_gradient_link_fragment(element.document(), svg_gradient_href(element)) or {
		return none
	}
	linked := element.document().get_element_by_id(fragment) or { return none }
	if !linked.is_svg_element() || linked.local_name() !in ['linearGradient', 'radialGradient'] {
		return none
	}
	linked_identity := linked.as_node().unique_id().value()
	if seen[linked_identity] {
		return none
	}
	return linked
}

fn svg_gradient_units(element &dom.Element, mut seen map[i64]bool) svg.Units {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return .object_bounding_box
	}
	seen[identity] = true
	if units := svg.parse_units(element.get_attribute_value('gradientUnits')) {
		return units
	}
	if linked := linked_svg_gradient(element, mut seen) {
		return svg_gradient_units(linked, mut seen)
	}
	return .object_bounding_box
}

fn svg_gradient_spread(element &dom.Element, mut seen map[i64]bool) svg.SpreadMethod {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return .pad
	}
	seen[identity] = true
	if spread := svg.parse_spread_method(element.get_attribute_value('spreadMethod')) {
		return spread
	}
	if linked := linked_svg_gradient(element, mut seen) {
		return svg_gradient_spread(linked, mut seen)
	}
	return .pad
}

fn svg_gradient_transform(element &dom.Element, mut seen map[i64]bool) svg.AffineTransform {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return svg.AffineTransform{}
	}
	seen[identity] = true
	if element.has_attribute('gradientTransform') {
		if transforms := svg.parse_transform(element.get_attribute_value('gradientTransform')) {
			return svg.compose_transforms(transforms)
		}
	}
	if linked := linked_svg_gradient(element, mut seen) {
		return svg_gradient_transform(linked, mut seen)
	}
	return svg.AffineTransform{}
}

fn svg_linear_gradient_coordinate(element &dom.Element, name string,
	fallback svg.NumberPercentage, mut seen map[i64]bool) svg.NumberPercentage {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return fallback
	}
	seen[identity] = true
	if coordinate := svg.parse_number_percentage(element.get_attribute_value(name)) {
		return coordinate
	}
	if linked := linked_svg_gradient(element, mut seen) {
		if linked.local_name() == 'linearGradient' {
			return svg_linear_gradient_coordinate(linked, name, fallback, mut seen)
		}
	}
	return fallback
}

fn svg_radial_gradient_coordinate(element &dom.Element, name string,
	fallback svg.NumberPercentage, nonnegative bool, mut seen map[i64]bool) svg.NumberPercentage {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return fallback
	}
	seen[identity] = true
	if coordinate := svg.parse_number_percentage(element.get_attribute_value(name)) {
		// SVGRadialGradientElement treats a negative radius as if the attribute
		// were absent, so a linked value can still supply it.
		if !nonnegative || coordinate.value >= 0 {
			return coordinate
		}
	}
	if linked := linked_svg_gradient(element, mut seen) {
		if linked.local_name() == 'radialGradient' {
			return svg_radial_gradient_coordinate(linked, name, fallback, nonnegative, mut seen)
		}
	}
	return fallback
}

fn svg_radial_gradient_start_coordinate(element &dom.Element, name string,
	end_name string, mut seen map[i64]bool) svg.NumberPercentage {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		mut end_seen := map[i64]bool{}
		return svg_radial_gradient_coordinate(element, end_name, svg.percentage(50), false, mut end_seen)
	}
	seen[identity] = true
	if coordinate := svg.parse_number_percentage(element.get_attribute_value(name)) {
		return coordinate
	}
	if linked := linked_svg_gradient(element, mut seen) {
		if linked.local_name() == 'radialGradient' {
			return svg_radial_gradient_start_coordinate(linked, name, end_name, mut seen)
		}
	}
	// fx/fy coincide with cx/cy on the radial gradient where the href chain
	// stopped, matching SVGRadialGradientElement::start_circle_{x,y}_impl().
	mut end_seen := map[i64]bool{}
	return svg_radial_gradient_coordinate(element, end_name, svg.percentage(50), false, mut end_seen)
}

fn svg_gradient_direct_stops(element &dom.Element) []painting.ColorStop {
	mut stops := []painting.ColorStop{}
	mut previous_offset := 0.0
	for child in element.as_node().children_as_vector() {
		stop_element := child.as_element() or { continue }
		if !stop_element.is_svg_element() || stop_element.local_name() != 'stop' {
			continue
		}
		offset_value := svg.parse_number_percentage(stop_element.get_attribute_value('offset')) or {
			svg.percentage(0)
		}
		offset := math.min(math.max(offset_value.value, previous_offset), 1.0)
		mut color := css.Color{0, 0, 0, 255}
		mut opacity := 1.0
		if stop_properties := css.computed_properties_for_element(stop_element) {
			computed_stop := css.resolve_computed_values_for_document(stop_properties, stop_element.document())
			color = computed_stop.stop_color()
			opacity = f64(computed_stop.stop_opacity())
		}
		alpha := u8(math.min(math.max(math.round(f64(color.a) * math.min(math.max(opacity, 0.0), 1.0)), 0.0), 255.0))
		stops << painting.ColorStop{
			color: painting.Color{color.r, color.g, color.b, alpha}
			position: offset
		}
		previous_offset = offset
	}
	return stops
}

fn svg_gradient_stops(element &dom.Element, mut seen map[i64]bool) []painting.ColorStop {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return []painting.ColorStop{}
	}
	seen[identity] = true
	stops := svg_gradient_direct_stops(element)
	if stops.len > 0 {
		return stops
	}
	if linked := linked_svg_gradient(element, mut seen) {
		return svg_gradient_stops(linked, mut seen)
	}
	return []painting.ColorStop{}
}

fn svg_gradient_color_space(element &dom.Element) painting.ColorInterpolationMethod {
	properties := css.computed_properties_for_element(element) or { return .srgb }
	computed := css.resolve_computed_values_for_document(properties, element.document())
	return match computed.color_interpolation() {
		.srgb_linear { painting.ColorInterpolationMethod.linear_srgb }
		else { painting.ColorInterpolationMethod.srgb }
	}
}

fn svg_paint_viewport_size(node &Node, state &LayoutState) painting.Size {
	mut current := ?&Node(node)
	for {
		candidate := current or { break }
		if candidate.is_svg_svg_box() {
			if element := svg_element_for_layout_node(candidate) {
				if view_box := svg.parse_viewbox(element.get_attribute_value('viewBox')) {
					if view_box.width >= 0 && view_box.height >= 0 {
						return painting.Size{view_box.width, view_box.height}
					}
				}
			}
			if styled := candidate.as_node_with_style() {
				if used := state.try_get(styled) {
					return painting.Size{used.content_width().to_double(), used.content_height().to_double()}
				}
			}
		}
		current = candidate.parent()
	}
	return painting.Size{}
}

fn painting_clip_path_bounds(path painting.ClipPathVisualData) ?painting.Rect {
	mut has_point := false
	mut min_x := 0.0
	mut min_y := 0.0
	mut max_x := 0.0
	mut max_y := 0.0
	for polygon in path.polygons {
		for point in polygon {
			if !has_point {
				min_x = point.x
				max_x = point.x
				min_y = point.y
				max_y = point.y
				has_point = true
			} else {
				min_x = math.min(min_x, point.x)
				max_x = math.max(max_x, point.x)
				min_y = math.min(min_y, point.y)
				max_y = math.max(max_y, point.y)
			}
		}
	}
	if !has_point {
		return none
	}
	return painting.Rect{min_x, min_y, max_x - min_x, max_y - min_y}
}

fn resolve_svg_linear_gradient_paint_style(node &Node, state &LayoutState,
	paint css.SVGPaint, path painting.ClipPathVisualData) ?painting.SVGLinearGradientPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or {
		return none
	}
	element := dom_node.document().get_element_by_id(fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'linearGradient' {
		return none
	}
	bounds := painting_clip_path_bounds(path) or { return none }
	viewport := svg_paint_viewport_size(node, state)
	mut seen := map[i64]bool{}
	units := svg_gradient_units(element, mut seen)
	seen.clear()
	x1 := svg_linear_gradient_coordinate(element, 'x1', svg.percentage(0), mut seen)
	seen.clear()
	y1 := svg_linear_gradient_coordinate(element, 'y1', svg.percentage(0), mut seen)
	seen.clear()
	x2 := svg_linear_gradient_coordinate(element, 'x2', svg.percentage(100), mut seen)
	seen.clear()
	y2 := svg_linear_gradient_coordinate(element, 'y2', svg.percentage(0), mut seen)
	resolve_x := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.x + value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_y := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.y + value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	seen.clear()
	gradient_transform := svg_gradient_transform(element, mut seen)
	seen.clear()
	spread := svg_gradient_spread(element, mut seen)
	seen.clear()
	stops := svg_gradient_stops(element, mut seen)
	return painting.SVGLinearGradientPaintStyle{
		gradient: painting.SVGGradientPaintStyle{
			color_stops: stops
			gradient_transform: painting_affine_from_svg(gradient_transform)
			spread_method: match spread {
				.pad { painting.SVGSpreadMethod.pad }
				.repeat { painting.SVGSpreadMethod.repeat }
				.reflect { painting.SVGSpreadMethod.reflect }
			}
			color_space: svg_gradient_color_space(element)
		}
		start_point: painting.Point{resolve_x(x1), resolve_y(y1)}
		end_point: painting.Point{resolve_x(x2), resolve_y(y2)}
	}
}

fn resolve_svg_radial_gradient_paint_style(node &Node, state &LayoutState,
	paint css.SVGPaint, path painting.ClipPathVisualData) ?painting.SVGRadialGradientPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or { return none }
	element := dom_node.document().get_element_by_id(fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'radialGradient' {
		return none
	}
	bounds := painting_clip_path_bounds(path) or { return none }
	viewport := svg_paint_viewport_size(node, state)
	mut seen := map[i64]bool{}
	units := svg_gradient_units(element, mut seen)
	seen.clear()
	start_x := svg_radial_gradient_start_coordinate(element, 'fx', 'cx', mut seen)
	seen.clear()
	start_y := svg_radial_gradient_start_coordinate(element, 'fy', 'cy', mut seen)
	seen.clear()
	start_radius := svg_radial_gradient_coordinate(element, 'fr', svg.percentage(0), true, mut seen)
	seen.clear()
	end_x := svg_radial_gradient_coordinate(element, 'cx', svg.percentage(50), false, mut seen)
	seen.clear()
	end_y := svg_radial_gradient_coordinate(element, 'cy', svg.percentage(50), false, mut seen)
	seen.clear()
	end_radius := svg_radial_gradient_coordinate(element, 'r', svg.percentage(50), true, mut seen)
	resolve_x := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.x + value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_y := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.y + value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	resolve_radius := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		// This deliberately follows SVGRadialGradientElement.cpp: both object-box
		// and user-space radial lengths use the applicable width.
		return if units == .object_bounding_box {
			value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	seen.clear()
	gradient_transform := svg_gradient_transform(element, mut seen)
	seen.clear()
	spread := svg_gradient_spread(element, mut seen)
	seen.clear()
	stops := svg_gradient_stops(element, mut seen)
	return painting.SVGRadialGradientPaintStyle{
		gradient: painting.SVGGradientPaintStyle{
			color_stops: stops
			gradient_transform: painting_affine_from_svg(gradient_transform)
			spread_method: match spread {
				.pad { painting.SVGSpreadMethod.pad }
				.repeat { painting.SVGSpreadMethod.repeat }
				.reflect { painting.SVGSpreadMethod.reflect }
			}
			color_space: svg_gradient_color_space(element)
		}
		start_center: painting.Point{resolve_x(start_x), resolve_y(start_y)}
		start_radius: resolve_radius(start_radius)
		end_center: painting.Point{resolve_x(end_x), resolve_y(end_y)}
		end_radius: resolve_radius(end_radius)
	}
}

fn svg_pattern_units(element &dom.Element, name string, fallback svg.Units,
	mut seen map[i64]bool) svg.Units {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return fallback
	}
	seen[identity] = true
	if units := svg.parse_units(element.get_attribute_value(name)) {
		return units
	}
	if linked := linked_svg_pattern(element, mut seen) {
		return svg_pattern_units(linked, name, fallback, mut seen)
	}
	return fallback
}

fn svg_pattern_coordinate(element &dom.Element, name string, mut seen map[i64]bool) svg.NumberPercentage {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return svg.number(0)
	}
	seen[identity] = true
	if coordinate := svg.parse_number_percentage(element.get_attribute_value(name)) {
		return coordinate
	}
	if linked := linked_svg_pattern(element, mut seen) {
		return svg_pattern_coordinate(linked, name, mut seen)
	}
	return svg.number(0)
}

fn svg_pattern_transform(element &dom.Element, mut seen map[i64]bool) svg.AffineTransform {
	identity := element.as_node().unique_id().value()
	if seen[identity] {
		return svg.AffineTransform{}
	}
	seen[identity] = true
	if element.has_attribute('patternTransform') {
		if transforms := svg.parse_transform(element.get_attribute_value('patternTransform')) {
			return svg.compose_transforms(transforms)
		}
	}
	if linked := linked_svg_pattern(element, mut seen) {
		return svg_pattern_transform(linked, mut seen)
	}
	return svg.AffineTransform{}
}

fn multiply_painting_affine(left painting.Affine, right painting.Affine) painting.Affine {
	return painting.Affine{
		a: left.a * right.a + left.c * right.b
		b: left.b * right.a + left.d * right.b
		c: left.a * right.c + left.c * right.d
		d: left.b * right.c + left.d * right.d
		e: left.a * right.e + left.c * right.f + left.e
		f: left.b * right.e + left.d * right.f + left.f
	}
}

fn normalize_svg_pattern_operations(operations []painting.SVGMaskPaintOperation,
	inverse_target painting.Affine, content_origin painting.Point) []painting.SVGMaskPaintOperation {
	// SVGPatternElement::to_gfx_paint_style() records the tile after translating
	// by -content_origin. Object-bounding-box pattern content is laid out under
	// its target, so its retained operations otherwise keep the target's x/y
	// offset and can land partly or wholly outside the tile bitmap.
	normalization := multiply_painting_affine(painting.Affine{
		e: -content_origin.x
		f: -content_origin.y
	}, inverse_target)
	mut normalized := []painting.SVGMaskPaintOperation{cap: operations.len}
	for operation in operations {
		if operation.kind == .path {
			normalized << painting.SVGMaskPaintOperation{
				...operation
				transform: multiply_painting_affine(normalization, operation.transform)
			}
		} else if operation.kind == .image {
			normalized << painting.SVGMaskPaintOperation{
				...operation
				image_rect: normalization.map_rect(operation.image_rect)
				transform: multiply_painting_affine(normalization, operation.transform)
			}
		} else {
			normalized << operation
		}
	}
	return normalized
}

fn resolve_svg_pattern_paint_style(node &Node, state &LayoutState, paint css.SVGPaint,
	path painting.ClipPathVisualData, target_transform svg.AffineTransform) ?&painting.SVGPatternPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or { return none }
	element := dom_node.document().get_element_by_id(fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'pattern' {
		return none
	}
	content_element := svg_pattern_content_element(element) or { return none }
	content_identity := content_element.as_node().unique_id().value()
	mut pattern_box := ?&Node(none)
	for child in node.children() {
		if !child.is_svg_pattern_box() {
			continue
		}
		if child_dom := child.dom_node() {
			if child_dom.unique_id().value() == content_identity {
				pattern_box = child
				break
			}
		}
	}
	resource := pattern_box or { return none }
	bounds := painting_clip_path_bounds(path) or { return none }
	viewport := svg_paint_viewport_size(node, state)
	mut seen := map[i64]bool{}
	units := svg_pattern_units(element, 'patternUnits', .object_bounding_box, mut seen)
	seen.clear()
	x := svg_pattern_coordinate(element, 'x', mut seen)
	seen.clear()
	y := svg_pattern_coordinate(element, 'y', mut seen)
	seen.clear()
	width := svg_pattern_coordinate(element, 'width', mut seen)
	seen.clear()
	height := svg_pattern_coordinate(element, 'height', mut seen)
	resolve_x := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.x + value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_y := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			bounds.y + value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	resolve_width := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_height := fn [units, bounds, viewport] (value svg.NumberPercentage) f64 {
		return if units == .object_bounding_box {
			value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	tile_rect := painting.Rect{
		x: resolve_x(x)
		y: resolve_y(y)
		width: resolve_width(width)
		height: resolve_height(height)
	}
	if tile_rect.width <= 0 || tile_rect.height <= 0 {
		return none
	}
	target_affine := painting_affine_from_svg(target_transform)
	inverse_target := target_affine.inverse() or { return none }
	target_styled := node.as_node_with_style() or { return none }
	target_used := state.try_get(target_styled) or { return none }
	resource_transform := target_used.svg_transform().multiply(svg.element_transform(svg_element_model(content_element)))
	mut collection := SVGMaskPaintCollection{}
	collect_svg_mask_paint_operations(resource, state, resource_transform, true, mut collection)
	mut content_origin := painting.Point{}
	if svg.parse_viewbox(content_element.get_attribute_value('viewBox')) == none {
		seen.clear()
		content_units := svg_pattern_units(content_element, 'patternContentUnits', .user_space_on_use, mut seen)
		if content_units == .object_bounding_box {
			content_origin = painting.Point{bounds.x, bounds.y}
		}
	}
	operations := normalize_svg_pattern_operations(collection.operations, inverse_target, content_origin)
	seen.clear()
	mut pattern_transform := painting_affine_from_svg(svg_pattern_transform(element, mut seen))
	if computed_properties := css.computed_properties_for_element(element) {
		if !computed_transform_is_none(computed_properties) {
			resource_styled := resource.as_node_with_style() or { return none }
			resource_used := state.try_get(resource_styled) or { return none }
			matrix := resolved_computed_transform_matrix(computed_properties, resource_used.offset.x().to_double(), resource_used.offset.y().to_double(), resource_used.border_box_width().to_double(), resource_used.border_box_height().to_double())
			pattern_transform = painting.Affine{
				a: if matrix == [6]f64{} { 1.0 } else { matrix[0] }
				b: matrix[1]
				c: matrix[2]
				d: if matrix == [6]f64{} { 1.0 } else { matrix[3] }
				e: matrix[4]
				f: matrix[5]
			}
		}
	}
	if pattern_transform.inverse() == none {
		return none
	}
	mut cache_key := svg_mask_visual_cache_key(painting.IntRect{
		width: int(math.ceil(tile_rect.width))
		height: int(math.ceil(tile_rect.height))
	}, .alpha, operations)
	for value in [tile_rect.x, tile_rect.y, tile_rect.width, tile_rect.height, pattern_transform.a,
		pattern_transform.b, pattern_transform.c, pattern_transform.d, pattern_transform.e,
		pattern_transform.f] {
		cache_key = svg_clip_hash_mix(cache_key, math.f64_bits(value))
	}
	return &painting.SVGPatternPaintStyle{
		tile_display_list_id: '${content_identity}'
		tile_rect: tile_rect
		pattern_transform: pattern_transform
		tile_display_list: &painting.SVGPatternDisplayList{
			operations: operations
		}
		cache_key: cache_key
	}
}

fn computed_font_is_monospace(computed &css.ComputedProperties) bool {
	value := computed.typed_property_value(.font_family) or { return false }
	values := if list := value.as_value_list() { list.values() } else { [value] }
	if values.len == 0 {
		return false
	}
	// The V renderer transport chooses one native family. Like the upstream font
	// cascade, inspect the first requested family rather than substring-matching
	// the serialized declaration (which misclassified names such as Monotype).
	return values[0].serialize(.normal).trim('"\'').to_lower() in ['monospace', 'ui-monospace']
}

fn background_box_name(box css.BackgroundBox) string {
	return match box {
		.border_box { 'border-box' }
		.padding_box { 'padding-box' }
		.content_box { 'content-box' }
		.text { 'text' }
	}
}

fn direct_body_layout_node(root &Node) ?&Node {
	for child in root.children() {
		dom_node := child.dom_node() or { continue }
		element := dom_node.as_element() or { continue }
		if element.is_html_element() && element.local_name() == 'body' {
			return child
		}
	}
	return none
}

fn suppress_background_for_node_id(mut box BlockBox, node_id i64) {
	if box.node_id == node_id {
		box.skip_background_paint = true
		return
	}
	for mut child in box.children {
		suppress_background_for_node_id(mut child, node_id)
	}
}

fn inline_relative_offset(node &Node, state &LayoutState) css.CSSPixelPoint {
	mut result := css.CSSPixelPoint.from_values(0, 0)
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if !current.display().is_inline_outside() || !current.display().is_flow_inside() {
			break
		}
		if current.computed_values().position() == .relative {
			if styled := current.as_node_with_style() {
				if used := state.try_get(styled) {
					result = css_pixel_point_add(result, css.CSSPixelPoint.from_values(used.inset_left.to_double(), used.inset_top.to_double()))
				}
			}
		}
		ancestor = current.parent()
	}
	return result
}

// Build the renderer-facing box tree from the canonical typed Layout tree and
// LayoutState. BlockBox remains the display-list transport used by the native
// shell; it no longer runs an independent layout algorithm.
pub fn layout_document_typed_in_viewport(document &dom.Document, viewport_width f64, viewport_height f64) BlockBox {
	// Enter the same Document::update_layout pipeline used by every other typed
	// layout caller. Keeping one orchestration path is important here: style
	// invalidation, media evaluation, layout-tree retention, and viewport-change
	// handling all have source-defined ordering in DOM::Document.
	adapter_checkpoint := time.sys_mono_now()
	result := run_document_layout(document, viewport_width, viewport_height) or {
		return BlockBox{}
	}
	layout_completed := time.sys_mono_now()
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		eprintln('Ladybird V timing:     typed_pipeline ${(layout_completed - adapter_checkpoint) / 1_000_000} ms')
	}
	return result.paint_tree
}

// Translate the committed typed layout tree into the renderer transport. This
// is shared by the native shell and DOM's callback-backed viewport paintable;
// both must record and hit-test the exact same paint-order tree.
fn renderer_box_from_document_layout_result(result &DocumentLayoutResult, viewport_width f64, viewport_height f64) BlockBox {
	layout_completed := time.sys_mono_now()
	root_layout_node := result.root.first_child() or { return BlockBox{} }
	mut root_box := block_box_from_typed_layout(root_layout_node, result.state)

	// PaintableBox::paint_background expands the root background to the viewport and the root's
	// scrollable overflow. Keep the root's layout geometry intact and retain that canvas separately.
	mut canvas_rect := LayoutRect{0, 0, viewport_width, viewport_height}
	if root_styled := root_layout_node.as_node_with_style() {
		if root_used := result.state.try_get(root_styled) {
			if overflow := root_used.scrollable_overflow_rect() {
				canvas_rect = rect_union(canvas_rect, LayoutRect{overflow.x.to_double(), overflow.y.to_double(), overflow.width.to_double(), overflow.height.to_double()})
			}
		}
	}
	root_box.paints_canvas_background = true
	root_box.canvas_x = canvas_rect.x
	root_box.canvas_y = canvas_rect.y
	root_box.canvas_width = canvas_rect.width
	root_box.canvas_height = canvas_rect.height
	// The compatibility transport omits the typed Viewport node itself. Mark its
	// root element as the owner of the mandatory viewport scroll frame so replay
	// still follows ViewportPaintable::assign_scroll_frames().
	root_box.is_viewport_scroller = true
	root_box.viewport_width = viewport_width
	root_box.viewport_height = viewport_height

	// HTMLHtmlElement::should_use_body_background_properties(): propagation is disabled by any
	// containment on html/body and otherwise happens only when the root has no image layers and a
	// transparent color. The body background is then painted by the root and not painted again.
	if body_layout_node := direct_body_layout_node(root_layout_node) {
		root_computed := root_layout_node.computed_values()
		body_computed := body_layout_node.computed_values()
		should_use_body := root_computed.contain().is_empty() && body_computed.contain().is_empty()
			&& root_computed.background_layers().len == 0 && root_box.background_color.a == 0
		if should_use_body {
			if body_dom_node := body_layout_node.dom_node() {
				if body_element := body_dom_node.as_element() {
					mut color_context := color_resolution_context_for_typed_node(body_layout_node, css.Color{0, 0, 0, 255})
					color_context.current_color = computed_paint_color(body_computed, .color, color_context, css.Color{0, 0, 0, 255})
					root_box.background_color = computed_paint_color(body_computed, .background_color, color_context, css.Color{0, 0, 0, 0})
					root_box.background_gradient = computed_background_gradient(body_computed, root_box.border_box().width, root_box.border_box().height, color_context)
					root_box.background_images = computed_background_image_layers(body_element, body_computed, color_context)
					suppress_background_for_node_id(mut root_box, i64(body_element.as_node().unique_id()))
				}
			}
		}
	}
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		eprintln('Ladybird V timing:     renderer_adapter ${(time.sys_mono_now() - layout_completed) / 1_000_000} ms')
	}
	return root_box
}

fn block_box_from_typed_layout(node &Node, state &LayoutState) BlockBox {
	return block_box_from_typed_layout_with_ancestor(node, state, [6]f64{})
}

fn painting_clip_path_segment(segment html.PathSegment) painting.ClipPathSegment {
	kind := match segment.kind {
		.move_to { painting.ClipPathSegmentKind.move_to }
		.line_to { painting.ClipPathSegmentKind.line_to }
		.quadratic_bezier_curve_to { painting.ClipPathSegmentKind.quadratic_bezier_curve_to }
		.cubic_bezier_curve_to { painting.ClipPathSegmentKind.cubic_bezier_curve_to }
		.elliptical_arc_to { painting.ClipPathSegmentKind.elliptical_arc_to }
		.close_path { painting.ClipPathSegmentKind.close_path }
	}
	return painting.ClipPathSegment{
		kind: kind
		point: painting.Point{segment.point.x, segment.point.y}
		control_point_0: painting.Point{segment.control_point_0.x, segment.control_point_0.y}
		control_point_1: painting.Point{segment.control_point_1.x, segment.control_point_1.y}
		radii: painting.Size{segment.radii.width, segment.radii.height}
		rotation: segment.x_axis_rotation
		large_arc: segment.large_arc
		sweep: segment.sweep
	}
}

fn painting_clip_path_from_canvas_path(path html.CanvasGfxPath,
	fill_rule painting.WindingRule) painting.ClipPathVisualData {
	mut segments := []painting.ClipPathSegment{cap: path.length()}
	for segment in path.segments() {
		segments << painting_clip_path_segment(segment)
	}
	mut polygons := [][]painting.Point{}
	for polygon in html.canvas_gfx_path_flattened_polygons(path) {
		mut points := []painting.Point{cap: polygon.len}
		for point in polygon {
			points << painting.Point{point.x, point.y}
		}
		polygons << points
	}
	return painting.ClipPathVisualData{
		segments: segments
		polygons: polygons
		fill_rule: fill_rule
	}
}

// ViewportPaintable::assign_accumulated_visual_contexts() asks each basic
// shape for its Gfx::Path relative to the border box, then offsets that path to
// the absolute masking area. Keep both the exact segment model used by native
// replay and its one-time flattened hit-test contours.
fn basic_shape_clip_path_for_box(node &Node, computed &css.ComputedValues,
	border_rect LayoutRect) ?painting.ClipPathVisualData {
	reference := computed.clip_path() or { return none }
	if !reference.is_basic_shape() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	dom_layout_node := dom_node.layout_node() or { return none }
	style_path := reference.basic_shape().to_path(css.CSSPixelRect.new(0, 0, border_rect.width, border_rect.height), dom_layout_node)
	local_path := html.canvas_gfx_path_from_style_value_path(style_path)
	path := local_path.copy_transformed(html.CanvasAffineTransform{
		e: border_rect.x
		f: border_rect.y
	})
	clip := painting_clip_path_from_canvas_path(path, if style_path.fill_rule == .evenodd {
		painting.WindingRule.even_odd
	} else {
		painting.WindingRule.nonzero
	})
	return painting.ClipPathVisualData{
		bounding_rect: compatibility_enclosing_int_rect(border_rect)
		segments: clip.segments
		polygons: clip.polygons
		fill_rule: clip.fill_rule
	}
}

fn svg_clip_hash_mix(hash u64, value u64) u64 {
	return (hash ^ value) * u64(1099511628211)
}

fn svg_clip_visual_cache_key(components []painting.SVGClipPathComponent) u64 {
	mut hash := u64(14695981039346656037)
	for component in components {
		hash = svg_clip_hash_mix(hash, u64(component.path.fill_rule))
		for value in [component.transform.a, component.transform.b, component.transform.c,
			component.transform.d, component.transform.e, component.transform.f] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
		for segment in component.path.segments {
			hash = svg_clip_hash_mix(hash, u64(segment.kind))
			for value in [segment.point.x, segment.point.y, segment.control_point_0.x,
				segment.control_point_0.y, segment.control_point_1.x, segment.control_point_1.y,
				segment.radii.width, segment.radii.height, segment.rotation] {
				hash = svg_clip_hash_mix(hash, math.f64_bits(value))
			}
			hash = svg_clip_hash_mix(hash, if segment.large_arc { u64(1) } else { u64(0) })
			hash = svg_clip_hash_mix(hash, if segment.sweep { u64(1) } else { u64(0) })
		}
	}
	return hash
}

fn svg_mask_color_key(color painting.Color) u64 {
	return u64(color.r) << 24 | u64(color.g) << 16 | u64(color.b) << 8 | u64(color.a)
}

fn svg_gradient_visual_cache_key(seed u64, style painting.SVGLinearGradientPaintStyle) u64 {
	mut hash := svg_clip_hash_mix(seed, 1)
	for value in [style.start_point.x, style.start_point.y, style.end_point.x, style.end_point.y] {
		hash = svg_clip_hash_mix(hash, math.f64_bits(value))
	}
	hash = svg_clip_hash_mix(hash, u64(style.gradient.spread_method))
	hash = svg_clip_hash_mix(hash, u64(style.gradient.color_space))
	if transform := style.gradient.gradient_transform {
		for value in [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
	}
	for stop in style.gradient.color_stops {
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(stop.color))
		hash = svg_clip_hash_mix(hash, math.f64_bits(stop.position))
	}
	return hash
}

fn svg_radial_gradient_visual_cache_key(seed u64,
	style painting.SVGRadialGradientPaintStyle) u64 {
	mut hash := svg_clip_hash_mix(seed, 2)
	for value in [style.start_center.x, style.start_center.y, style.start_radius, style.end_center.x,
		style.end_center.y, style.end_radius] {
		hash = svg_clip_hash_mix(hash, math.f64_bits(value))
	}
	hash = svg_clip_hash_mix(hash, u64(style.gradient.spread_method))
	hash = svg_clip_hash_mix(hash, u64(style.gradient.color_space))
	if transform := style.gradient.gradient_transform {
		for value in [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
	}
	for stop in style.gradient.color_stops {
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(stop.color))
		hash = svg_clip_hash_mix(hash, math.f64_bits(stop.position))
	}
	return hash
}

fn svg_mask_visual_cache_key(bounds painting.IntRect, mask_type painting.SVGMaskType,
	operations []painting.SVGMaskPaintOperation) u64 {
	mut hash := svg_clip_hash_mix(u64(14695981039346656037), u64(mask_type))
	for value in [bounds.x, bounds.y, bounds.width, bounds.height] {
		hash = svg_clip_hash_mix(hash, u64(value))
	}
	for operation in operations {
		hash = svg_clip_hash_mix(hash, u64(operation.kind))
		hash = svg_clip_hash_mix(hash, math.f64_bits(operation.opacity))
		if operation.kind == .image {
			for byte in operation.image_url.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			for byte in operation.image_position_x.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			for byte in operation.image_position_y.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			for value in [operation.image_rect.x, operation.image_rect.y, operation.image_rect.width,
				operation.image_rect.height] {
				hash = svg_clip_hash_mix(hash, math.f64_bits(value))
			}
			hash = svg_clip_hash_mix(hash, u64(operation.image_rendering))
			for value in [operation.transform.a, operation.transform.b, operation.transform.c,
				operation.transform.d, operation.transform.e, operation.transform.f] {
				hash = svg_clip_hash_mix(hash, math.f64_bits(value))
			}
			continue
		}
		if operation.kind != .path {
			continue
		}
		hash = svg_clip_hash_mix(hash, u64(operation.path.fill_rule))
		for value in [operation.transform.a, operation.transform.b, operation.transform.c,
			operation.transform.d, operation.transform.e, operation.transform.f,
			operation.fill_opacity, operation.stroke_opacity, operation.stroke_width,
			operation.stroke_miter_limit] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(operation.fill_color))
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(operation.stroke_color))
		if gradient := operation.fill_linear_gradient {
			hash = svg_gradient_visual_cache_key(hash, gradient)
		}
		if gradient := operation.stroke_linear_gradient {
			hash = svg_gradient_visual_cache_key(hash, gradient)
		}
		if gradient := operation.fill_radial_gradient {
			hash = svg_radial_gradient_visual_cache_key(hash, gradient)
		}
		if gradient := operation.stroke_radial_gradient {
			hash = svg_radial_gradient_visual_cache_key(hash, gradient)
		}
		if pattern := operation.fill_pattern {
			hash = svg_clip_hash_mix(svg_clip_hash_mix(hash, 3), pattern.cache_key)
		}
		if pattern := operation.stroke_pattern {
			hash = svg_clip_hash_mix(svg_clip_hash_mix(hash, 4), pattern.cache_key)
		}
		hash = svg_clip_hash_mix(hash, if operation.has_fill { u64(1) } else { u64(0) })
		hash = svg_clip_hash_mix(hash, if operation.has_stroke { u64(1) } else { u64(0) })
		hash = svg_clip_hash_mix(hash, if operation.stroke_first { u64(1) } else { u64(0) })
		hash = svg_clip_hash_mix(hash, u64(operation.stroke_linecap))
		hash = svg_clip_hash_mix(hash, u64(operation.stroke_linejoin))
		for segment in operation.path.segments {
			hash = svg_clip_hash_mix(hash, u64(segment.kind))
			for value in [segment.point.x, segment.point.y, segment.control_point_0.x,
				segment.control_point_0.y, segment.control_point_1.x, segment.control_point_1.y,
				segment.radii.width, segment.radii.height, segment.rotation] {
				hash = svg_clip_hash_mix(hash, math.f64_bits(value))
			}
			hash = svg_clip_hash_mix(hash, if segment.large_arc { u64(1) } else { u64(0) })
			hash = svg_clip_hash_mix(hash, if segment.sweep { u64(1) } else { u64(0) })
		}
	}
	return hash
}

fn svg_resource_scope_id(node &Node, kind u64) u64 {
	mut identity := u64(voidptr(node))
	if dom_node := node.dom_node() {
		identity = u64(dom_node.unique_id())
	}
	return svg_clip_hash_mix(identity, kind)
}

fn painting_affine_from_svg(transform svg.AffineTransform) painting.Affine {
	return painting.Affine{
		a: transform.a
		b: transform.b
		c: transform.c
		d: transform.d
		e: transform.e
		f: transform.f
	}
}

struct SVGClipPathCollection {
mut:
	components []painting.SVGClipPathComponent
	bounds     svg.Rect
	has_bounds bool
}

fn collect_svg_clip_path_components(node &Node, state &LayoutState,
	resource_transform svg.AffineTransform, mut collection SVGClipPathCollection) {
	if node.is_svg_mask_box() || node.is_svg_pattern_box() {
		return
	}
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			if svg_path := used.computed_svg_path() {
				position := paint_cumulative_offset(node, state, used)
				page_delta_x := position.x().to_double() - used.offset.x().to_double()
				page_delta_y := position.y().to_double() - used.offset.y().to_double()
				to_page := svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(resource_transform).multiply(used.svg_transform())
				local_path := html.canvas_gfx_path_from_svg_path(svg_path)
				clip_path := painting_clip_path_from_canvas_path(local_path, if styled.computed_values().clip_rule() == .evenodd {
					painting.WindingRule.even_odd
				} else {
					painting.WindingRule.nonzero
				})
				if clip_path.segments.len > 0 {
					collection.components << painting.SVGClipPathComponent{
						path: clip_path
						transform: painting_affine_from_svg(to_page)
					}
					for polygon in clip_path.polygons {
						for point in polygon {
							mapped := to_page.map_point(svg.Point{point.x, point.y})
							point_rect := svg.Rect{mapped.x, mapped.y, 0, 0}
							collection.bounds = if collection.has_bounds {
								union_svg_rect(collection.bounds, point_rect)
							} else {
								point_rect
							}
							collection.has_bounds = true
						}
					}
				}
			}
		}
	}
	for child in node.children() {
		if child.is_box() && !child.is_svg_clip_box() {
			collect_svg_clip_path_components(child, state, resource_transform, mut collection)
		}
	}
}

// SVGMaskable::calculate_svg_clip_display_list(): find the attached resource,
// prepend the target and resource transforms at paint time, and retain every
// geometry as one alpha-mask component. The resource subtree itself is not a
// normal painted descendant.
fn svg_url_clip_path_for_box(node &Node, state &LayoutState,
	target_used &UsedValues) ?painting.SVGClipVisualData {
	mut resource := ?&Node(none)
	for child in node.children() {
		if child.is_svg_clip_box() {
			resource = child
			break
		}
	}
	clip_box := resource or { return none }
	clip_element := svg_element_for_layout_node(clip_box) or { return none }
	resource_transform := target_used.svg_transform().multiply(svg.element_transform(svg_element_model(clip_element)))
	mut collection := SVGClipPathCollection{}
	collect_svg_clip_path_components(clip_box, state, resource_transform, mut collection)
	return painting.SVGClipVisualData{
		bounding_rect: compatibility_enclosing_int_rect(LayoutRect{
			x: collection.bounds.x
			y: collection.bounds.y
			width: collection.bounds.width
			height: collection.bounds.height
		})
		components: collection.components
		cache_key: svg_clip_visual_cache_key(collection.components)
		scope_id: svg_resource_scope_id(node, 1)
	}
}

struct SVGMaskPaintCollection {
mut:
	operations []painting.SVGMaskPaintOperation
}

fn svg_mask_painting_color(color css.Color) painting.Color {
	return painting.Color{color.r, color.g, color.b, color.a}
}

fn svg_mask_stroke_precedes_fill(order css.PaintOrderList) bool {
	mut fill_index := order.order.len
	mut stroke_index := order.order.len
	for index, item in order.order {
		match item {
			.fill {
				fill_index = index
			}
			.stroke {
				stroke_index = index
			}
			.markers {}
		}
	}
	return stroke_index < fill_index
}

fn svg_image_href(element &dom.Element) string {
	if element.has_attribute('href') {
		return element.get_attribute_value('href').trim_space()
	}
	return element.get_attribute_value('xlink:href').trim_space()
}

fn resolved_svg_image_url(element &dom.Element) string {
	source := svg_image_href(element)
	if source == '' {
		return ''
	}
	return element.document().encoding_parse_and_serialize_url(source) or { source }
}

fn collect_svg_mask_paint_operations(node &Node, state &LayoutState,
	resource_transform svg.AffineTransform, is_resource_root bool,
	mut collection SVGMaskPaintCollection) {
	if !is_resource_root
		&& (node.is_svg_mask_box() || node.is_svg_clip_box() || node.is_svg_pattern_box()) {
		return
	}
	styled := node.as_node_with_style() or { return }
	used := state.try_get(styled) or { return }
	computed := styled.computed_values()
	opacity := f64(computed.opacity())
	if opacity <= 0 {
		return
	}
	wrap_opacity := opacity < 1
	if wrap_opacity {
		collection.operations << painting.SVGMaskPaintOperation{
			kind: .begin_opacity
			opacity: opacity
		}
	}
	if computed.visibility() == .visible {
		if node.is_svg_image_box() {
			if element := svg_element_for_layout_node(node) {
				image_url := resolved_svg_image_url(element)
				if image_url != '' && used.content_width().to_double() > 0
					&& used.content_height().to_double() > 0 {
					position := paint_cumulative_offset(node, state, used)
					object_position := computed.object_position()
					collection.operations << painting.SVGMaskPaintOperation{
						kind: .image
						image_url: image_url
						image_rect: painting.Rect{
							x: position.x().to_double()
							y: position.y().to_double()
							width: used.content_width().to_double()
							height: used.content_height().to_double()
						}
						image_position_x: object_position.offset_x.to_string()
						image_position_y: object_position.offset_y.to_string()
						image_rendering: computed.image_rendering()
					}
				}
			}
		} else if svg_path := used.computed_svg_path() {
			diagonal := math.sqrt(used.content_width().to_double() * used.content_width().to_double() + used.content_height().to_double() * used.content_height().to_double())
			stroke_width := computed.length_percentage_to_px(.stroke_width, diagonal) or { 1.0 }
			position := paint_cumulative_offset(node, state, used)
			page_delta_x := position.x().to_double() - used.offset.x().to_double()
			page_delta_y := position.y().to_double() - used.offset.y().to_double()
			to_page := svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(resource_transform).multiply(used.svg_transform())
			path := painting_clip_path_from_canvas_path(html.canvas_gfx_path_from_svg_path(svg_path), if computed.fill_rule() == .evenodd {
				painting.WindingRule.even_odd
			} else {
				painting.WindingRule.nonzero
			})
			if path.segments.len > 0 {
				mut fill_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
				mut stroke_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
				mut fill_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
				mut stroke_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
				mut fill_pattern := ?&painting.SVGPatternPaintStyle(none)
				mut stroke_pattern := ?&painting.SVGPatternPaintStyle(none)
				if fill_paint := computed.fill() {
					fill_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, fill_paint, path)
					fill_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, fill_paint, path)
					fill_pattern = resolve_svg_pattern_paint_style(node, state, fill_paint, path, to_page)
				}
				if stroke_paint := computed.stroke() {
					stroke_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, stroke_paint, path)
					stroke_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, stroke_paint, path)
					stroke_pattern = resolve_svg_pattern_paint_style(node, state, stroke_paint, path, to_page)
				}
				fill := if fill_linear_gradient == none && fill_radial_gradient == none
					&& fill_pattern == none {
					computed_svg_paint_color(computed, .fill)
				} else {
					none
				}
				stroke := if stroke_linear_gradient == none && stroke_radial_gradient == none
					&& stroke_pattern == none {
					computed_svg_paint_color(computed, .stroke)
				} else {
					none
				}
				has_fill := fill != none || fill_linear_gradient != none || fill_radial_gradient != none
					|| fill_pattern != none
				has_stroke := stroke_width > 0
					&& (stroke != none || stroke_linear_gradient != none
						|| stroke_radial_gradient != none || stroke_pattern != none)
				if has_fill || has_stroke {
					fill_color := if color := fill {
						svg_mask_painting_color(color)
					} else {
						painting.Color{ a: 0 }
					}
					stroke_color := if color := stroke {
						svg_mask_painting_color(color)
					} else {
						painting.Color{ a: 0 }
					}
					collection.operations << painting.SVGMaskPaintOperation{
						kind: .path
						path: path
						transform: painting_affine_from_svg(to_page)
						fill_linear_gradient: fill_linear_gradient
						stroke_linear_gradient: stroke_linear_gradient
						fill_radial_gradient: fill_radial_gradient
						stroke_radial_gradient: stroke_radial_gradient
						fill_pattern: fill_pattern
						stroke_pattern: stroke_pattern
						fill_color: fill_color
						stroke_color: stroke_color
						has_fill: has_fill
						has_stroke: has_stroke
						stroke_first: svg_mask_stroke_precedes_fill(computed.paint_order())
						fill_opacity: f64(computed.fill_opacity())
						stroke_opacity: f64(computed.stroke_opacity())
						stroke_width: stroke_width
						stroke_linecap: match computed.stroke_linecap() {
							.butt { painting.LineCap.butt }
							.round { painting.LineCap.round }
							.square { painting.LineCap.square }
						}
						stroke_linejoin: match computed.stroke_linejoin() {
							.miter { painting.LineJoin.miter }
							.round { painting.LineJoin.round }
							.bevel { painting.LineJoin.bevel }
						}
						stroke_miter_limit: computed.stroke_miterlimit()
					}
				}
			}
		}
	}
	for child in node.children() {
		if child.is_box() {
			collect_svg_mask_paint_operations(child, state, resource_transform, false, mut collection)
		}
	}
	if wrap_opacity {
		collection.operations << painting.SVGMaskPaintOperation{
			kind: .end_opacity
		}
	}
}

// SVGMaskable::get_svg_mask_area()/calculate_svg_mask_display_list(): retain
// the mask resource's normal SVG foreground painting, its layer boundaries,
// and the mask-type conversion. SVGMaskElement::resolve_masking_area() still
// intentionally follows upstream's current 20% inflation TODO.
fn svg_url_mask_for_box(node &Node, state &LayoutState,
	target_used &UsedValues) ?painting.SVGMaskVisualData {
	mut resource := ?&Node(none)
	for child in node.children() {
		if child.is_svg_mask_box() {
			resource = child
			break
		}
	}
	mask_box := resource or { return none }
	mask_styled := mask_box.as_node_with_style() or { return none }
	mask_used := state.try_get(mask_styled) or { return none }
	mask_element := svg_element_for_layout_node(mask_box) or { return none }
	resource_transform := target_used.svg_transform().multiply(svg.element_transform(svg_element_model(mask_element)))
	mut collection := SVGMaskPaintCollection{}
	collect_svg_mask_paint_operations(mask_box, state, resource_transform, true, mut collection)
	position := paint_cumulative_offset(mask_box, state, mask_used)
	resource_border_rect := svg.Rect{
		x: position.x().to_double() - mask_used.padding_left.to_double() - mask_used.border_left.to_double()
		y: position.y().to_double() - mask_used.padding_top.to_double() - mask_used.border_top.to_double()
		width: mask_used.border_box_width().to_double()
		height: mask_used.border_box_height().to_double()
	}
	mask_area := svg.resolve_masking_area(resource_border_rect)
	bounding_rect := compatibility_enclosing_int_rect(LayoutRect{
		x: mask_area.x
		y: mask_area.y
		width: mask_area.width
		height: mask_area.height
	})
	mask_type := if mask_styled.computed_values().mask_type() == .alpha {
		painting.SVGMaskType.alpha
	} else {
		painting.SVGMaskType.luminance
	}
	return painting.SVGMaskVisualData{
		bounding_rect: bounding_rect
		mask_type: mask_type
		operations: collection.operations
		cache_key: svg_mask_visual_cache_key(bounding_rect, mask_type, collection.operations)
		scope_id: svg_resource_scope_id(node, 2)
	}
}

// StackingContext composes transforms while descending the paintable tree.
// Carry the accumulated matrix through construction too, instead of copying a
// complete child subtree once for every transformed ancestor.
fn block_box_from_typed_layout_with_ancestor(node &Node, state &LayoutState, ancestor_paint_transform [6]f64) BlockBox {
	styled := node.as_node_with_style() or { return BlockBox{} }
	used := state.try_get(styled) or { return BlockBox{} }
	if used.svg_rendering_disabled() {
		return BlockBox{}
	}
	computed := styled.computed_values()
	position := paint_cumulative_offset(node, state, used)
	mut element := ?&dom.Element(none)
	mut tag_name := ''
	mut node_id := i64(0)
	if dom_node := node.dom_node() {
		if dom_element := dom_node.as_element() {
			element = dom_element
			tag_name = dom_element.local_name()
			node_id = i64(dom_element.as_node().unique_id())
		}
	}

	mut background_color := css.Color{0, 0, 0, 0}
	mut text_color := css.Color{0, 0, 0, 255}
	mut border_color := text_color
	mut border_colors := BoxColors{text_color, text_color, text_color, text_color}
	mut border_styles := solid_box_border_styles()
	mut border_radius := 0.0
	mut border_radii := BoxRadii{}
	mut outline_width := 0.0
	mut outline_offset := 0.0
	mut outline_color := text_color
	mut outline_style := painting.LineStyle.solid
	mut shadow := ?BoxShadow(none)
	mut shadows := []BoxShadow{}
	mut background_gradient := ?LinearGradient(none)
	mut background_images := []BackgroundImageLayer{}
	mut replaced_image_url := ''
	mut replaced_image_size := ''
	mut replaced_image_position_x := '50%'
	mut replaced_image_position_y := '50%'
	mut form_control_kind := ''
	mut form_control_checked := false
	mut form_control_indeterminate := false
	mut svg_path := ''
	mut svg_path_data := []f32{}
	mut svg_transform := [f64(1), 0, 0, 1, 0, 0]!
	mut svg_points := []f64{}
	mut svg_fill_color := ''
	mut svg_fill_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
	mut svg_fill_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
	mut svg_fill_pattern := ?&painting.SVGPatternPaintStyle(none)
	mut svg_fill_even_odd := false
	mut svg_stroke_color := ''
	mut svg_stroke_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
	mut svg_stroke_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
	mut svg_stroke_pattern := ?&painting.SVGPatternPaintStyle(none)
	mut svg_stroke_width := 0.0
	mut svg_stroke_first := false
	mut svg_stroke_linecap := 0
	mut svg_stroke_linejoin := 0
	mut svg_stroke_miterlimit := 4.0
	mut svg_fill_opacity := 1.0
	mut svg_stroke_opacity := 1.0
	mut z_index := 0
	mut z_index_auto := true
	positioned := node.is_positioned()
	floating := node.is_floating()
	inline_or_replaced := node.is_inline() || node.is_replaced_box()
	mut stacking_context := node.establishes_stacking_context()
	mut marker_shape := ''
	mut paint_transform := [6]f64{}
	mut clip_path := ?painting.ClipPathVisualData(none)
	mut svg_clip := ?painting.SVGClipVisualData(none)
	mut svg_mask := ?painting.SVGMaskVisualData(none)
	mut color_context := color_resolution_context_for_typed_node(node, text_color)
	text_color = computed.color()
	color_context.current_color = text_color
	mut paint_element := element
	if paint_element == none && node.is_generated_for_pseudo_element() {
		paint_element = painted_owner_element(node)
	}
	filter := resolved_css_filter_for_element(computed, color_context, paint_element, painting.Rect{
		x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
		y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
		width: used.border_box_width().to_double()
		height: used.border_box_height().to_double()
	})
	if styled_element := paint_element {
		text_color = computed.color()
		color_context.current_color = text_color
		background_color = computed.background_color()
		border_colors = computed_border_colors(computed)
		border_color = border_colors.top
		border_styles = computed_border_styles(computed)
		border_radii = computed_box_radii(computed, used.border_box_width().to_double(), used.border_box_height().to_double())
		border_radius = border_radii.top_left.x
		outline_width = computed_outline_width(computed)
		outline_style = computed_outline_line_style(computed.outline_style())
		outline_offset_value := computed.typed_property_value(.outline_offset) or {
			css.StyleValue(css.LengthStyleValue.create(css.Length.make_px(0)))
		}
		outline_offset = computed.resolve_length_percentage_value_px(outline_offset_value, 0) or {
			0.0
		}
		outline_color = if computed.outline_style() == .auto_ {
			computed.accent_color() or { computed.outline_color() }
		} else {
			computed.outline_color()
		}
		shadows = computed_box_shadows(computed)
		if shadows.len > 0 {
			shadow = shadows[0]
		}
		background_gradient = computed_background_gradient(computed, used.border_box_width().to_double(), used.border_box_height().to_double(), color_context)
		background_images = computed_background_image_layers(styled_element, computed, color_context)
		if node.is_positioned() {
			if computed_z_index := computed.z_index() {
				z_index = computed_z_index
				z_index_auto = false
			}
		}
		if !computed_transform_is_none(computed) {
			paint_transform = resolved_computed_transform_matrix(computed, position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double(), position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double(), used.border_box_width().to_double(), used.border_box_height().to_double())
		}
		clip_path = basic_shape_clip_path_for_box(node, computed, LayoutRect{
			x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
			y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
			width: used.border_box_width().to_double()
			height: used.border_box_height().to_double()
		})
	}
	accumulated_paint_transform := if affine_is_compact_identity(ancestor_paint_transform) {
		paint_transform
	} else if affine_is_compact_identity(paint_transform) {
		ancestor_paint_transform
	} else {
		multiply_affine(ancestor_paint_transform, paint_transform)
	}
	if path := used.computed_svg_path() {
		svg_path = path.serialize()
		exact_path := html.canvas_gfx_path_from_svg_path(path)
		exact_visual_path := painting_clip_path_from_canvas_path(exact_path, if computed.fill_rule() == .evenodd {
			painting.WindingRule.even_odd
		} else {
			painting.WindingRule.nonzero
		})
		svg_path_data = compatibility_pack_clip_path_segments(exact_visual_path)
		svg_fill_even_odd = computed.fill_rule() == .evenodd
		page_delta_x := position.x().to_double() - used.offset.x().to_double()
		page_delta_y := position.y().to_double() - used.offset.y().to_double()
		to_page := svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(used.svg_transform())
		svg_transform = [to_page.a, to_page.b, to_page.c, to_page.d, to_page.e, to_page.f]!
		for point in path.endpoints() {
			mapped := to_page.map_point(point)
			svg_points << mapped.x
			svg_points << mapped.y
		}
		if fill_paint := computed.fill() {
			svg_fill_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, fill_paint, exact_visual_path)
			svg_fill_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, fill_paint, exact_visual_path)
			svg_fill_pattern = resolve_svg_pattern_paint_style(node, state, fill_paint, exact_visual_path, to_page)
		}
		if stroke_paint := computed.stroke() {
			svg_stroke_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, stroke_paint, exact_visual_path)
			svg_stroke_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, stroke_paint, exact_visual_path)
			svg_stroke_pattern = resolve_svg_pattern_paint_style(node, state, stroke_paint, exact_visual_path, to_page)
		}
		if svg_fill_linear_gradient == none && svg_fill_radial_gradient == none
			&& svg_fill_pattern == none {
			if fill_color := computed_svg_paint_color(computed, .fill) {
				svg_fill_color = fill_color.serialize()
			}
		}
		if svg_stroke_linear_gradient == none && svg_stroke_radial_gradient == none
			&& svg_stroke_pattern == none {
			if stroke_color := computed_svg_paint_color(computed, .stroke) {
				svg_stroke_color = stroke_color.serialize()
			}
		}
		diagonal := math.sqrt(used.content_width().to_double() * used.content_width().to_double() + used.content_height().to_double() * used.content_height().to_double())
		svg_stroke_width = computed.length_percentage_to_px(.stroke_width, diagonal) or { 1.0 }
		svg_stroke_first = svg_mask_stroke_precedes_fill(computed.paint_order())
		svg_stroke_linecap = match computed.stroke_linecap() {
			.butt { 0 }
			.round { 1 }
			.square { 2 }
		}
		svg_stroke_linejoin = match computed.stroke_linejoin() {
			.miter { 0 }
			.round { 1 }
			.bevel { 2 }
		}
		svg_stroke_miterlimit = computed.stroke_miterlimit()
		svg_fill_opacity = f64(computed.fill_opacity())
		svg_stroke_opacity = f64(computed.stroke_opacity())
	}
	svg_clip = svg_url_clip_path_for_box(node, state, used)
	svg_mask = svg_url_mask_for_box(node, state, used)
	if marker := node.as_list_item_marker_box() {
		if marker.text() == none {
			marker_shape = marker.list_style_type_.name
		}
	}
	if image_box := node.as_image_box() {
		if !image_box.renders_as_alt_text() && image_box.source() != '' {
			source := image_box.source()
			replaced_image_url = if styled_element := element {
				styled_element.document().encoding_parse_and_serialize_url(source) or { source }
			} else {
				source
			}
			replaced_image_size = match computed.object_fit() {
				.fill { '100% 100%' }
				.contain { 'contain' }
				.cover { 'cover' }
				.none_ { 'auto' }
				.scale_down { 'scale-down' }
			}
			object_position := computed.object_position()
			replaced_image_position_x = object_position.offset_x.to_string()
			replaced_image_position_y = object_position.offset_y.to_string()
		}
	}
	if node.is_svg_image_box() {
		if svg_image_element := element {
			replaced_image_url = resolved_svg_image_url(svg_image_element)
			replaced_image_size = 'contain'
			object_position := computed.object_position()
			replaced_image_position_x = object_position.offset_x.to_string()
			replaced_image_position_y = object_position.offset_y.to_string()
		}
	}
	if styled_element := element {
		if styled_element.local_name() == 'input' && computed.appearance() != .none_ {
			input_type := styled_element.get_attribute_value('type').to_lower()
			if input_type in ['checkbox', 'radio'] {
				form_control_kind = input_type
				input := unsafe { &dom.HTMLInputElement(styled_element) }
				form_control_checked = input.checked()
				form_control_indeterminate = input.indeterminate()
			}
		}
	}
	overlay := compatibility_overlay_data(node, computed, used)
	overflow_clip := compatibility_overflow_clip(node, computed, used, position, border_radii)
	mut scrollable_overflow := ?LayoutRect(none)
	if overflow := used.scrollable_overflow_rect() {
		scrollable_overflow = LayoutRect{
			x: overflow.x.to_double()
			y: overflow.y.to_double()
			width: overflow.width.to_double()
			height: overflow.height.to_double()
		}
	}

	mut children := []BlockBox{}
	for child in node.children() {
		if child.is_svg_mask_box() || child.is_svg_clip_box() || child.is_svg_pattern_box() {
			continue
		}
		if child.is_box() {
			if child_styled := child.as_node_with_style() {
				if state.try_get(child_styled) == none {
					children << typed_block_descendants(child, state, accumulated_paint_transform)
					continue
				}
			}
			child_box := block_box_from_typed_layout_with_ancestor(child, state, accumulated_paint_transform)
			if child_box.tag_name != '' || child.is_anonymous() || child.is_generated_for_pseudo_element() {
				children << child_box
			}
		} else if child.is_inline_node() {
			children << typed_block_descendants(child, state, accumulated_paint_transform)
		}
	}

	mut lines := text_lines_from_typed_layout(node, used, state, position)
	if list_item := node.as_list_item_box() {
		if marker_node := list_item.marker() {
			if marker := marker_node.as_list_item_marker_box() {
				if marker_text := marker.text() {
					if marker_styled := marker_node.as_node_with_style() {
						if marker_used := state.try_get(marker_styled) {
							marker_position := paint_cumulative_offset(marker_node, state, marker_used)
							lines.prepend(TextLine{
								x: marker_position.x().to_double()
								y: marker_position.y().to_double()
								width: marker_used.content_width().to_double()
								height: marker_used.content_height().to_double()
								fragments: [
									TextFragment{
										x: marker_position.x().to_double()
										y: marker_position.y().to_double()
										width: marker_used.content_width().to_double()
										height: marker_used.content_height().to_double()
										text: marker_text.trim_right(' ')
										color: text_color
										font_size: marker.computed_values().resolved_font_size_px()
									},
								]
							})
						}
					}
				}
			}
		}
	}
	display := computed.display()
	uses_collapsed_borders := computed.border_collapse() == .collapse
	mut table_cell_borders := used.override_borders_data()
	if display.is_table_cell() && table_cell_borders == none {
		table_cell_borders = retained_table_cell_borders(computed, used, border_colors)
	}
	// PaintableBox::absolute_border_box_rect() uses half of each winning
	// collapsed edge (rounded in CSS pixels) around the cell padding box.
	paint_border := if used.use_collapsing_borders_model() {
		BoxEdges{
			top: math.round(used.border_top.to_double() / 2.0)
			right: math.round(used.border_right.to_double() / 2.0)
			bottom: math.round(used.border_bottom.to_double() / 2.0)
			left: math.round(used.border_left.to_double() / 2.0)
		}
	} else {
		BoxEdges{used.border_top.to_double(), used.border_right.to_double(), used.border_bottom.to_double(), used.border_left.to_double()}
	}
	return BlockBox{
		tag_name: tag_name
		x: position.x().to_double()
		y: position.y().to_double()
		width: used.content_width().to_double()
		height: used.content_height().to_double()
		margin: BoxEdges{used.margin_top.to_double(), used.margin_right.to_double(), used.margin_bottom.to_double(), used.margin_left.to_double()}
		border: paint_border
		padding: BoxEdges{used.padding_top.to_double(), used.padding_right.to_double(), used.padding_bottom.to_double(), used.padding_left.to_double()}
		outer_top_margin: used.margin_top.to_double()
		outer_bottom_margin: used.margin_bottom.to_double()
		z_index: z_index
		z_index_auto: z_index_auto
		positioned: positioned
		floating: floating
		absolutely_positioned: node.is_absolutely_positioned()
		inline_or_replaced: inline_or_replaced
		stacking_context: stacking_context
		paintable_with_lines: layout_debug_paintable_class(node) == 'PaintableWithLines'
		table_inside: display.is_table_inside()
		table_cell: display.is_table_cell()
		uses_collapsed_borders: uses_collapsed_borders
		table_cell_coordinates: used.table_cell_coordinates()
		table_cell_borders: table_cell_borders
		empty_cells_hide: computed.empty_cells() == .hide
		has_layout_children: node.has_children()
		background_color: background_color
		text_color: text_color
		border_color: border_color
		border_colors: border_colors
		border_styles: border_styles
		border_radius: border_radius
		border_radii: border_radii
		outline_width: outline_width
		outline_offset: outline_offset
		outline_color: outline_color
		outline_style: outline_style
		shadow: shadow
		shadows: shadows
		background_gradient: background_gradient
		background_images: background_images
		background_color_clip: background_box_name(computed.background_color_clip())
		replaced_image_url: replaced_image_url
		replaced_image_size: replaced_image_size
		replaced_image_position_x: replaced_image_position_x
		replaced_image_position_y: replaced_image_position_y
		replaced_image_rendering: computed.image_rendering()
		is_svg_image: node.is_svg_image_box()
		form_control_kind: form_control_kind
		form_control_checked: form_control_checked
		form_control_indeterminate: form_control_indeterminate
		opacity: f64(computed.opacity())
		filter: filter
		visible: computed.visibility() == .visible
		pointer_events_enabled: computed.pointer_events() != .none_
		node_id: node_id
		layout_handle: voidptr(node)
		children: children
		lines: lines
		svg_path: svg_path
		svg_path_data: svg_path_data
		svg_transform: svg_transform
		svg_points: svg_points
		svg_fill_color: svg_fill_color
		svg_fill_linear_gradient: svg_fill_linear_gradient
		svg_fill_radial_gradient: svg_fill_radial_gradient
		svg_fill_pattern: svg_fill_pattern
		svg_fill_even_odd: svg_fill_even_odd
		svg_stroke_color: svg_stroke_color
		svg_stroke_linear_gradient: svg_stroke_linear_gradient
		svg_stroke_radial_gradient: svg_stroke_radial_gradient
		svg_stroke_pattern: svg_stroke_pattern
		svg_stroke_width: svg_stroke_width
		svg_stroke_first: svg_stroke_first
		svg_stroke_linecap: svg_stroke_linecap
		svg_stroke_linejoin: svg_stroke_linejoin
		svg_stroke_miterlimit: svg_stroke_miterlimit
		svg_fill_opacity: svg_fill_opacity
		svg_stroke_opacity: svg_stroke_opacity
		marker_shape: marker_shape
		overlay: overlay
		has_scrollable_overflow: used.has_scrollable_overflow() && !node.is_viewport()
		scrollable_overflow: scrollable_overflow
		overflow_clip: overflow_clip
		clip_path: clip_path
		svg_clip: svg_clip
		svg_mask: svg_mask
		sticky_position: node.is_sticky_position()
		own_paint_transform: paint_transform
		paint_transform: accumulated_paint_transform
	}
}

fn typed_block_descendants(node &Node, state &LayoutState, ancestor_paint_transform [6]f64) []BlockBox {
	mut descendants := []BlockBox{}
	for child in node.children() {
		if child.is_svg_mask_box() || child.is_svg_clip_box() || child.is_svg_pattern_box() {
			continue
		}
		if child.is_box() {
			if styled := child.as_node_with_style() {
				if state.try_get(styled) == none {
					descendants << typed_block_descendants(child, state, ancestor_paint_transform)
					continue
				}
			}
			descendants << block_box_from_typed_layout_with_ancestor(child, state, ancestor_paint_transform)
		} else {
			descendants << typed_block_descendants(child, state, ancestor_paint_transform)
		}
	}
	return descendants
}

fn text_lines_from_typed_layout(container &Node, used &UsedValues, state &LayoutState, container_position css.CSSPixelPoint) []TextLine {
	mut lines := []TextLine{}
	for line_box in used.line_boxes {
		mut fragments := []TextFragment{}
		for fragment in line_box.fragments_ {
			text := fragment.text() or { continue }
			computed := fragment.layout_node_.computed_values()
			mut color := css.Color{0, 0, 0, 255}
			mut background := css.Color{0, 0, 0, 0}
			mut background_images := []BackgroundImageLayer{}
			mut border_color := color
			mut border_colors := BoxColors{color, color, color, color}
			mut border_styles := solid_box_border_styles()
			mut decoration_color := color
			mut decoration_style := 'solid'
			mut decoration_thickness := 0.0
			mut border := BoxEdges{}
			mut radius := 0.0
			mut radii := BoxRadii{}
			mut inline_shadow := ?BoxShadow(none)
			mut inline_shadows := []BoxShadow{}
			mut inline_node_id := i64(0)
			mut color_context := color_resolution_context_for_typed_node(fragment.layout_node_, color)
			color = computed.color()
			color_context.current_color = color
			decoration_color = computed.text_decoration_color()
			decoration_style = computed_text_decoration_style(computed)
			decoration_thickness = computed_text_decoration_thickness(computed, computed.font_size().to_double())
			// LayoutState::commit() relocates a line-box fragment to the first
			// non-atomic InlineNode ancestor. Only that inline paintable owns box
			// decorations; text left in the block paintable must not repaint the
			// block's background, borders, radii, or box shadow.
			if inline_owner := inline_paint_owner(fragment.layout_node_) {
				owner_computed := inline_owner.computed_values()
				background = computed_paint_color(owner_computed, .background_color, color_context, background)
				if owner := painted_owner_element(inline_owner) {
					mut owner_color_context := color_resolution_context_for_typed_node(inline_owner, owner_computed.color())
					owner_color_context.current_color = owner_computed.color()
					background_images = computed_background_image_layers(owner, owner_computed, owner_color_context)
					inline_node_id = i64(owner.as_node().unique_id())
				}
				border_colors = computed_border_colors(owner_computed)
				border_color = border_colors.top
				border_styles = computed_border_styles(owner_computed)
				radii = computed_box_radii(owner_computed, fragment.width().to_double(), fragment.height().to_double())
				radius = radii.top_left.x
				inline_shadows = computed_box_shadows(owner_computed)
				if inline_shadows.len > 0 {
					inline_shadow = inline_shadows[0]
				}
				if inline_styled := inline_owner.as_node_with_style() {
					if inline_used := state.try_get(inline_styled) {
						border = BoxEdges{inline_used.border_top.to_double(), inline_used.border_right.to_double(), inline_used.border_bottom.to_double(), inline_used.border_left.to_double()}
					}
				}
			}
			offset := css_pixel_point_add(fragment.offset(), inline_relative_offset(fragment.layout_node_, state))
			transport_fragment := TextFragment{
				x: container_position.x().plus(offset.x()).to_double()
				y: container_position.y().plus(offset.y()).to_double()
				width: fragment.width().to_double()
				height: fragment.height().to_double()
				text: text
				color: color
				font_size: computed.font_size().to_double()
				bold: computed.font_weight() >= 600
				italic: computed.font_slope() != 0
				mono: computed_font_is_monospace(computed)
				text_run_id: text_run_identity(fragment.layout_node_)
				shape_as_run: resolved_text_spacing_for_node(fragment.layout_node_, .letter_spacing).raw_value() == 0 && resolved_text_spacing_for_node(fragment.layout_node_, .word_spacing).raw_value() == 0
				inline_node_id: inline_node_id
				background_color: background
				background_images: background_images
				border: border
				border_color: border_color
				border_colors: border_colors
				border_styles: border_styles
				border_radius: radius
				border_radii: radii
				shadow: inline_shadow
				shadows: inline_shadows
				decoration: text_decoration_string(computed.text_decoration_line())
				decoration_color: decoration_color
				decoration_color_set: true
				decoration_style: decoration_style
				decoration_thickness: decoration_thickness
			}
			// PaintableFragment is constructed directly from the committed
			// LineBoxFragment upstream. Preserve that run instead of splitting it
			// into words and making paint_commands() concatenate it again.
			fragments << transport_fragment
		}
		mut line_x := container_position.x().to_double()
		mut line_y := container_position.y().plus(CSSPixels.nearest_value_for(line_box.bottom().to_double() - line_box.height().to_double())).to_double()
		if fragments.len > 0 {
			line_x = fragments[0].x
			line_y = fragments[0].y
		}
		lines << TextLine{
			x: line_x
			y: line_y
			width: line_box.width().to_double()
			height: line_box.height().to_double()
			fragments: fragments
		}
	}
	_ = container
	return lines
}

// Translation of LayoutState::commit()'s try_to_relocate_fragment_in_inline_node
// ancestor walk. Atomic inline ancestors keep their fragment in the containing
// block; otherwise the nearest InlineNode receives the fragment paintable.
fn inline_paint_owner(node &Node) ?&Node {
	mut next_ancestor := node.parent()
	for {
		ancestor := next_ancestor or { break }
		if ancestor.is_atomic_inline() {
			break
		}
		if ancestor.is_inline_node() {
			return ancestor
		}
		next_ancestor = ancestor.parent()
	}
	return none
}

fn painted_owner_element(node &Node) ?&dom.Element {
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			return element
		}
		if parent := dom_node.parent_element() {
			return parent
		}
	}
	mut next_ancestor := node.parent()
	for {
		ancestor := next_ancestor or { break }
		if dom_node := ancestor.dom_node() {
			if element := dom_node.as_element() {
				return element
			}
		}
		next_ancestor = ancestor.parent()
	}
	return none
}

fn painted_owner_computed_values(node &Node, owner &dom.Element) &css.ComputedProperties {
	mut current := node
	for {
		if dom_node := current.dom_node() {
			if element := dom_node.as_element() {
				if voidptr(element) == voidptr(owner) {
					return current.computed_values()
				}
			}
		}
		current = current.parent() or { break }
	}
	return node.computed_values()
}

fn text_run_identity(node &Node) i64 {
	dom_node := node.dom_node() or { return 0 }
	return i64(dom_node.unique_id())
}

fn text_decoration_string(lines []css.TextDecorationLine) string {
	mut names := []string{}
	for line in lines {
		match line {
			.underline { names << 'underline' }
			.overline { names << 'overline' }
			.line_through { names << 'line-through' }
			.spelling_error { names << 'spelling-error' }
			.grammar_error { names << 'grammar-error' }
			else {}
		}
	}
	return if names.len == 0 { 'none' } else { names.join(' ') }
}

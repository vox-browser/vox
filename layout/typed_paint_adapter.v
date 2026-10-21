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
import platform
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

// LayoutState::commit() does not materialize a paintable for an atomic inline
// fragment displaced by text-overflow ellipsis. The fragment stays in its line
// so the coordinate recorded during layout remains stable.
fn is_fully_truncated_inline_fragment(node &Node, state &LayoutState) bool {
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	if used.is_invisible_for_line_clamp() {
		return true
	}
	coordinate := used.containing_line_box_fragment or { return false }
	containing_block := node.containing_block() or { return false }
	containing_styled := unsafe { &NodeWithStyle(containing_block) }
	containing_used := state.try_get(containing_styled) or { return false }
	if coordinate.line_box_index < 0
		|| coordinate.line_box_index >= containing_used.line_boxes.len {
		return false
	}
	line_box := containing_used.line_boxes[coordinate.line_box_index]
	if coordinate.fragment_index < 0 || coordinate.fragment_index >= line_box.fragments_.len {
		return false
	}
	return line_box.fragments_[coordinate.fragment_index].is_fully_truncated()
}

fn paint_cumulative_offset(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	session := state.paint_coordinates_
	if session != unsafe { nil } {
		if value := cached_paint_coordinate(node, state, used, session, 0) { return value.position }
	}
	mut offset := css.CSSPixelPoint{}
	mut current_node := node
	mut current_used := used
	mut checkpoint := used
	mut distance := u64(0)
	mut window := u64(1)
	for {
		offset = css_pixel_point_add(offset, paint_local_offset(current_node, state, current_used))
		containing := current_used.containing_block_used_values() or { break }
		current_used = containing
		current_node = unsafe { &Node(containing.node()) }
		distance++
		// Brent's cycle check needs no visited collection for ordinary ancestor
		// chains. A malformed cycle takes the guarded path below, which retains
		// the old rule of adding each distinct record exactly once.
		if voidptr(current_used) == voidptr(checkpoint) {
			return paint_cumulative_offset_with_cycle_guard(node, state, used)
		}
		if distance == window {
			checkpoint = current_used
			window *= 2
			distance = 0
		}
	}
	return offset
}

fn paint_cumulative_offset_with_cycle_guard(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	mut offset := css.CSSPixelPoint{}
	mut current_node := node
	mut current_used := used
	mut visited := map[u64]bool{}
	for {
		key := u64(voidptr(current_used))
		if visited[key] {
			break
		}
		visited[key] = true
		offset = css_pixel_point_add(offset, paint_local_offset(current_node, state, current_used))
		containing := current_used.containing_block_used_values() or { break }
		current_used = containing
		current_node = unsafe { &Node(containing.node()) }
	}
	return offset
}

// The committed rectangle of content below an SVG viewport is relative to
// that viewport, not the page. Painting applies the viewport transform later.
fn layout_offset_in_svg_user_space(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelPoint {
	position := paint_cumulative_offset(node, state, used)
	mut ancestor := node.parent()
	for ancestor != none {
		ancestor_node := ancestor or { break }
		if ancestor_node.is_svg_svg_box() {
			ancestor_styled := ancestor_node.as_node_with_style() or { return position }
			ancestor_used := state.try_get(ancestor_styled) or { return position }
			viewport_position := paint_cumulative_offset(ancestor_node, state, ancestor_used)
			return css.CSSPixelPoint.new(position.x().minus(viewport_position.x()), position.y().minus(viewport_position.y()))
		}
		ancestor = ancestor_node.parent()
	}
	return position
}

// SVG layout keeps geometry in viewport user units. Build the corresponding
// page-space CTM in tree order so viewport placement and element transforms
// remain correctly interleaved instead of being flattened into every box.
fn svg_path_transform_to_page(node &Node, state &LayoutState) svg.AffineTransform {
	mut chain := []&Node{}
	mut current := ?&Node(node)
	mut outermost_viewport_index := -1
	for current != none {
		candidate := current or { break }
		chain << candidate
		if candidate.is_svg_svg_box() {
			outermost_viewport_index = chain.len - 1
		}
		current = candidate.parent()
	}
	if outermost_viewport_index < 0 {
		return svg.AffineTransform{}
	}
	root := chain[outermost_viewport_index]
	root_styled := root.as_node_with_style() or { return svg.AffineTransform{} }
	root_used := state.try_get(root_styled) or { return svg.AffineTransform{} }
	root_position := svg_root_position_for_paint(root, state, root_used)
	mut transform := svg.AffineTransform{}.translated(root_position.x().to_double(), root_position.y().to_double())
	for index := outermost_viewport_index; index >= 0; index-- {
		part := chain[index]
		part_styled := part.as_node_with_style() or { continue }
		part_used := state.try_get(part_styled) or { continue }
		if part_used.has_computed_svg_transforms() {
			transform = transform.multiply(part_used.svg_local_transform())
		} else if element := svg_element_for_layout_node(part) {
			transform = transform.multiply(svg_element_attribute_transform(element))
		}
		if viewport_transform := part_used.svg_viewport_transform() {
			if index != outermost_viewport_index {
				transform = transform.translated(part_used.offset.x().to_double(), part_used.offset.y().to_double())
			}
			transform = transform.multiply(viewport_transform)
		}
	}
	return transform
}

fn svg_box_visual_bounds_to_page(node &Node, state &LayoutState, used &UsedValues) svg.Rect {
	mut chain := []&Node{}
	mut current := ?&Node(node)
	mut outermost_viewport_index := -1
	for current != none {
		candidate := current or { break }
		chain << candidate
		if candidate.is_svg_svg_box() {
			outermost_viewport_index = chain.len - 1
		}
		current = candidate.parent()
	}
	if outermost_viewport_index < 0 {
		position := paint_cumulative_offset(node, state, used)
		return svg.Rect{position.x().to_double(), position.y().to_double(), used.content_width().to_double(), used.content_height().to_double()}
	}
	root := chain[outermost_viewport_index]
	root_styled := root.as_node_with_style() or { return svg.Rect{} }
	root_used := state.try_get(root_styled) or { return svg.Rect{} }
	root_position := svg_root_position_for_paint(root, state, root_used)
	mut transform := svg.AffineTransform{}.translated(root_position.x().to_double(), root_position.y().to_double())
	for index := outermost_viewport_index; index >= 0; index-- {
		part := chain[index]
		part_styled := part.as_node_with_style() or { continue }
		part_used := state.try_get(part_styled) or { continue }
		if part_used.has_computed_svg_transforms() {
			transform = transform.multiply(part_used.svg_local_transform())
		} else if element := svg_element_for_layout_node(part) {
			transform = transform.multiply(svg_element_attribute_transform(element))
		}
		if viewport_transform := part_used.svg_viewport_transform() {
			if index != outermost_viewport_index {
				transform = transform.translated(part_used.offset.x().to_double(), part_used.offset.y().to_double())
			}
			if layout_nodes_same(part, node) {
				return transform.map_rect(svg.Rect{0, 0, part_used.content_width().to_double(), part_used.content_height().to_double()})
			}
			transform = transform.multiply(viewport_transform)
			continue
		}
		if part.is_svg_foreign_object_box() {
			transform = transform.translated(part_used.offset.x().to_double(), part_used.offset.y().to_double())
			if layout_nodes_same(part, node) {
				return transform.map_rect(svg.Rect{0, 0, part_used.content_width().to_double(), part_used.content_height().to_double()})
			}
			continue
		}
		if layout_nodes_same(part, node) {
			return transform.map_rect(svg.Rect{part_used.offset.x().to_double(), part_used.offset.y().to_double(), part_used.content_width().to_double(), part_used.content_height().to_double()})
		}
	}
	return svg.Rect{}
}

// Legacy resource collection already builds its transform in CSS layout
// coordinates. Object-bounding-box resources additionally need the outer SVG
// viewport transform conjugated around that coordinate space.
fn outer_svg_viewport_transform_in_page_space(node &Node, state &LayoutState) svg.AffineTransform {
	mut current := ?&Node(node)
	mut root := ?&Node(none)
	for current != none {
		candidate := current or { break }
		if candidate.is_svg_svg_box() {
			root = candidate
		}
		current = candidate.parent()
	}
	root_node := root or { return svg.AffineTransform{} }
	root_styled := root_node.as_node_with_style() or { return svg.AffineTransform{} }
	root_used := state.try_get(root_styled) or { return svg.AffineTransform{} }
	viewport_transform := root_used.svg_viewport_transform() or { return svg.AffineTransform{} }
	position := paint_cumulative_offset(root_node, state, root_used)
	paint_position := svg_root_position_for_paint(root_node, state, root_used)
	return svg.AffineTransform{}.translated(paint_position.x().to_double(), paint_position.y().to_double()).multiply(viewport_transform).translated(-position.x().to_double(), -position.y().to_double())
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

fn paint_image_needs_color_context(value css.StyleValue) bool {
	if value.is_keyword() || value is css.ImageStyleValue { return false }
	if list := value.as_value_list() {
		return list.values().any(paint_image_needs_color_context(it))
	}
	// Gradients and image-set candidates can resolve colors and calculations.
	return true
}

fn paint_color_context_for_box(node &Node, computed &css.ComputedProperties,
	current_color css.Color) css.ColorResolutionContext {
	if computed.filter().has_filters() || computed.backdrop_filter().has_filters() {
		return color_resolution_context_for_typed_node(node, current_color)
	}
	if image := computed.typed_property_value(.background_image) {
		if paint_image_needs_color_context(image) {
			return color_resolution_context_for_typed_node(node, current_color)
		}
	}
	// Ordinary resolved box colors and URL images do not consume a calculation
	// context. Resolve font-relative metrics only for paint which needs them.
	return css.ColorResolutionContext{current_color: current_color}
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

// Direct translation of PaintableBox::overflow_property_applies().
fn paintable_box_overflow_property_applies(node &Node, computed &css.ComputedProperties) bool {
	if node.is_svg_box() || node.is_inline_node() {
		return false
	}
	display := computed.display()
	if display.is_ruby_inside() {
		return false
	}
	if display.is_internal() && !display.is_table_cell() && !display.is_table_caption() {
		return false
	}
	return true
}

// Direct translation of PaintableBox::physical_resize_axes().
fn paintable_box_physical_resize_axes(_node &Node, computed &css.ComputedProperties) painting.PhysicalResizeAxes {
	if computed.resize() == .none_ {
		return painting.PhysicalResizeAxes{}
	}
	if computed.display().is_inline_outside() && computed.display().is_flow_inside() {
		return painting.PhysicalResizeAxes{}
	}
	values := unsafe { &css.ComputedValues(computed) }
	horizontal_writing_mode := values.writing_mode() == .horizontal_tb
	resize := computed.resize()
	horizontal := values.overflow_x() !in [.visible, .clip] && (resize in [.both, .horizontal] || (resize == .inline_ && horizontal_writing_mode) || (resize == .block && !horizontal_writing_mode))
	vertical := values.overflow_y() !in [.visible, .clip] && (resize in [.both, .vertical] || (resize == .inline_ && !horizontal_writing_mode) || (resize == .block && horizontal_writing_mode))
	return painting.PhysicalResizeAxes{horizontal, vertical}
}

// Direct translation of PaintableBox::has_resizer().
fn paintable_box_has_resizer(node &Node, computed &css.ComputedProperties) bool {
	if node.is_viewport() || node.is_generated_for_pseudo_element() {
		return false
	}
	axes := paintable_box_physical_resize_axes(node, computed)
	return axes.horizontal || axes.vertical
}

// Direct translation of PaintableBox::is_chrome_mirrored().
fn paintable_box_is_chrome_mirrored(computed &css.ComputedProperties) bool {
	values := unsafe { &css.ComputedValues(computed) }
	writing_mode := values.writing_mode()
	return (writing_mode == .horizontal_tb && values.direction() == .rtl)
		|| writing_mode in [.vertical_rl, .sideways_rl]
}

fn is_canvas_background_source(node &Node) bool {
	if node.is_root_element() {
		return true
	}
	if !node.is_body() {
		return false
	}
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_root_element() {
			root_computed := current.computed_values()
			body_computed := node.computed_values()
			return root_computed.contain().is_empty() && body_computed.contain().is_empty()
				&& root_computed.background_layers().len == 0
				&& root_computed.background_color().a == 0
		}
		ancestor = current.parent()
	}
	return false
}

// Paintable.cpp::effective_scrollbar_background_color(). Start with the
// propagated canvas background, then composite non-canvas ancestor
// backgrounds from the root towards the scroll container.
fn effective_scrollbar_background_color(node &Node) css.Color {
	canvas := node.document().background_color()
	mut background := css.Color{canvas.r, canvas.g, canvas.b, canvas.a}
	mut ancestors := []&Node{}
	mut current := ?&Node(node)
	for current != none {
		ancestor := current or { break }
		ancestors << ancestor
		current = ancestor.parent()
	}
	for index := ancestors.len - 1; index >= 0; index-- {
		ancestor := ancestors[index]
		if is_canvas_background_source(ancestor) {
			continue
		}
		if styled := ancestor.as_node_with_style() {
			color := styled.computed_values().background_color()
			if color.a != 0 {
				background = background.blend(color)
			}
		}
	}
	return background
}

fn automatic_scrollbar_colors(node &Node) (css.Color, css.Color) {
	background := effective_scrollbar_background_color(node)
	black_thumb := css.Color{0, 0, 0, 128}
	white_thumb := css.Color{255, 255, 255, 128}
	black_contrast := background.contrast_ratio(background.blend(black_thumb))
	white_contrast := background.contrast_ratio(background.blend(white_thumb))
	thumb := if black_contrast >= white_contrast { black_thumb } else { white_thumb }
	return thumb, css.Color{thumb.r, thumb.g, thumb.b, 25}
}

fn compatibility_overlay_data(node &Node, computed &css.ComputedProperties, used &UsedValues) ?CompatibilityOverlayData {
	overflow := used.scrollable_overflow_rect() or { return none }
	// Viewport propagation overrides the box values without changing the
	// originating element's computed CSS properties.
	values := unsafe { &css.ComputedValues(computed) }
	padding_width := used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
	padding_height := used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
	can_scroll_horizontally := compatibility_overflow_allows_scrolling(values.overflow_x(), node.is_viewport()) && overflow.width.to_double() > padding_width
	can_scroll_vertically := compatibility_overflow_allows_scrolling(values.overflow_y(), node.is_viewport()) && overflow.height.to_double() > padding_height
	has_resizer := paintable_box_has_resizer(node, computed)
	if !can_scroll_horizontally && !can_scroll_vertically && !has_resizer {
		return none
	}

	mut scroll_offset_x := 0.0
	mut scroll_offset_y := 0.0
	mut thumb_color := css.Color{64, 64, 64, 192}
	mut track_color := css.Color{212, 208, 200, 192}
	mut default_colors := true
	colors := values.computed_scrollbar_color()
	if colors.auto_ {
		thumb_color, track_color = automatic_scrollbar_colors(node)
	} else {
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
		scrollbar_width: values.scrollbar_width()
		scrollbar_thumb_color: thumb_color
		scrollbar_track_color: track_color
		default_scrollbar_colors: default_colors
		has_resizer: has_resizer
		chrome_mirrored: paintable_box_is_chrome_mirrored(computed)
	}
}

fn compatibility_scroll_snap_edges(computed &css.ComputedProperties, used &UsedValues,
	padding bool) BoxEdges {
	zero := css.LengthPercentageOrAuto.from_length(css.Length.make_px(0))
	values := if padding {
		computed.length_box(.scroll_padding_left, .scroll_padding_top, .scroll_padding_right,
			.scroll_padding_bottom, css.LengthPercentageOrAuto.make_auto())
	} else {
		computed.length_box(.scroll_margin_left, .scroll_margin_top, .scroll_margin_right,
			.scroll_margin_bottom, zero)
	}
	// Auto, percentages and absolute lengths need only the used reference
	// sizes below. Resolve font/viewport/container inputs when an edge uses
	// them, rather than allocating a query-container cache for every box.
	context := if scroll_snap_edge_needs_resolution_context(values.top())
		|| scroll_snap_edge_needs_resolution_context(values.right())
		|| scroll_snap_edge_needs_resolution_context(values.bottom())
		|| scroll_snap_edge_needs_resolution_context(values.left()) {
		computed.length_resolution_context()
	} else {
		css.LengthResolutionContext{}
	}
	horizontal_reference := if padding {
		css.CSSPixels.nearest_value_for(used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double())
	} else {
		css.CSSPixels.new(0)
	}
	vertical_reference := if padding {
		css.CSSPixels.nearest_value_for(used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double())
	} else {
		css.CSSPixels.new(0)
	}
	return BoxEdges{
		top: values.top().to_px_or_zero(context, vertical_reference).to_double()
		right: values.right().to_px_or_zero(context, horizontal_reference).to_double()
		bottom: values.bottom().to_px_or_zero(context, vertical_reference).to_double()
		left: values.left().to_px_or_zero(context, horizontal_reference).to_double()
	}
}

fn scroll_snap_edge_needs_resolution_context(value css.LengthPercentageOrAuto) bool {
	return value.is_calculated() || (value.is_length() && !value.length().is_absolute())
}

// Direct translation of PaintableBox::overflow_clip_edge_rect(). Geometry
// remains in CSS pixels; the visual-context builder performs device rounding.
fn paintable_box_overflow_clip_edge_rect(node &Node, computed &css.ComputedProperties, used &UsedValues, position css.CSSPixelPoint) LayoutRect {
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
	return LayoutRect{
		x: overflow_clip_edge.x - margin_left
		y: overflow_clip_edge.y - margin_top
		width: overflow_clip_edge.width + margin_left + margin_right
		height: overflow_clip_edge.height + margin_top + margin_bottom
	}
}

// Translation of ViewportPaintable::compute_clip_data().
fn compatibility_overflow_clip(node &Node, computed &css.ComputedProperties, used &UsedValues, position css.CSSPixelPoint, border_radii BoxRadii) ?CompatibilityOverflowClip {
	values := unsafe { &css.ComputedValues(computed) }
	mut overflow_x := values.overflow_x()
	mut overflow_y := values.overflow_y()
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
	if !paintable_box_overflow_property_applies(node, computed) {
		return none
	}

	padding_rect := LayoutRect{
		x: position.x().to_double() - used.padding_left.to_double()
		y: position.y().to_double() - used.padding_top.to_double()
		width: used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
		height: used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
	}
	overflow_clip_edge := paintable_box_overflow_clip_edge_rect(node, computed, used, position)

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

	radii := if overflow_x != .visible && overflow_y != .visible {
		paintable_box_normalized_border_radii_data(border_radii, computed, .yes)
	} else {
		BoxRadii{}
	}
	return CompatibilityOverflowClip{
		rect: clip_rect
		corner_radii: radii
	}
}

fn compatibility_paint_border_edges(used &UsedValues) BoxEdges {
	return BoxEdges{
		top: used.border_top_collapsed().to_double()
		right: used.border_right_collapsed().to_double()
		bottom: used.border_bottom_collapsed().to_double()
		left: used.border_left_collapsed().to_double()
	}
}

// Direct translation of PaintableBox::get_clip_rect() and
// ViewportPaintable::effective_css_clip_rect(). The legacy CSS `clip` property
// applies only to absolutely positioned boxes, is resolved from their absolute
// border box, and clips both the box itself and its descendants.
fn paintable_box_get_clip_rect(node &Node, computed &css.ComputedProperties, used &UsedValues, position css.CSSPixelPoint) ?LayoutRect {
	clip := computed.clip()
	if !clip.is_rect() || !node.is_absolutely_positioned() {
		return none
	}
	border := compatibility_paint_border_edges(used)
	border_box := css.CSSPixelRect.new(
		position.x().to_double() - used.padding_left.to_double() - border.left,
		position.y().to_double() - used.padding_top.to_double() - border.top,
		used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double() + border.left + border.right,
		used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double() + border.top + border.bottom,
	)
	resolved := clip.to_rect().resolved(computed.length_resolution_context(), border_box)
	if resolved.width_value() < 0 || resolved.height_value() < 0 {
		return LayoutRect{}
	}
	return LayoutRect{
		x: resolved.left_value()
		y: resolved.top_value()
		width: resolved.width_value()
		height: resolved.height_value()
	}
}

fn paintable_box_border_reference_box(used &UsedValues, position css.CSSPixelPoint) LayoutRect {
	border := compatibility_paint_border_edges(used)
	return LayoutRect{
		x: position.x().to_double() - used.padding_left.to_double() - border.left
		y: position.y().to_double() - used.padding_top.to_double() - border.top
		width: used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double() + border.left + border.right
		height: used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double() + border.top + border.bottom
	}
}

// https://www.w3.org/TR/css-transforms-1/#reference-box
// Direct translation of PaintableBox::transform_reference_box(). SVG
// paintables remap content/border to fill/stroke, while CSS layout boxes remap
// fill/stroke/view to content/border. Ladybird currently approximates SVG
// fill/stroke boxes with the paintable content/border rects; preserve that
// behavior until upstream grows exact SVG geometry boxes.
fn paintable_box_transform_reference_box(node &Node, computed &css.ComputedProperties, used &UsedValues, position css.CSSPixelPoint, state &LayoutState) LayoutRect {
	mut transform_box := computed.transform_box()
	if node.is_svg_box() {
		transform_box = match transform_box {
			.content_box { .fill_box }
			.border_box { .stroke_box }
			else { transform_box }
		}
	} else {
		transform_box = match transform_box {
			.fill_box { .content_box }
			.stroke_box, .view_box { .border_box }
			else { transform_box }
		}
	}
	match transform_box {
		.content_box, .fill_box {
			return LayoutRect{
				x: position.x().to_double()
				y: position.y().to_double()
				width: used.content_width().to_double()
				height: used.content_height().to_double()
			}
		}
		.border_box, .stroke_box {
			return paintable_box_border_reference_box(used, position)
		}
		.view_box {
			mut ancestor := node.parent()
			for ancestor != none {
				current := ancestor or { break }
				if current.is_svg_svg_box() {
					styled := current.as_node_with_style() or { break }
					ancestor_used := state.try_get(styled) or { break }
					ancestor_position := paint_cumulative_offset(current, state, ancestor_used)
					return LayoutRect{
						x: ancestor_position.x().to_double()
						y: ancestor_position.y().to_double()
						width: ancestor_used.content_width().to_double()
						height: ancestor_used.content_height().to_double()
					}
				}
				ancestor = current.parent()
			}
			return paintable_box_border_reference_box(used, position)
		}
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

struct PaintableBoxPixelCornerRadius {
	horizontal CSSPixels
	vertical   CSSPixels
}

// Direct translation of Paintable::visible_for_hit_testing().
fn paintable_visible_for_hit_testing(node &Node, computed &css.ComputedValues) bool {
	if dom_node := node.dom_node() {
		if dom_node.is_inert() {
			return false
		}
	}
	return computed.pointer_events() != .none_
}

// Direct translation of PaintableBox::hit_test_continuation(). Anonymous block
// boxes in the middle of a split inline chain target the principal inline
// paintable when none of their block descendants handled the hit.
fn paintable_box_hit_test_continuation(node &Node) i64 {
	if !node.is_anonymous() {
		return 0
	}
	metrics := node.as_node_with_style_and_box_model_metrics() or { return 0 }
	mut continuation := metrics.continuation_of_node() or { return 0 }
	for {
		previous := continuation.continuation_of_node() or { break }
		continuation = previous
	}
	principal := unsafe { &Node(continuation) }
	principal_style := principal.as_node_with_style() or { return 0 }
	if !paintable_visible_for_hit_testing(principal, principal_style.computed_values()) {
		return 0
	}
	dom_node := principal.dom_node() or { return 0 }
	element := dom_node.as_element() or { return 0 }
	return i64(element.as_node().unique_id())
}

fn resolved_paintable_box_corner_radius(values &css.ComputedValues, radius css.BorderRadiusData, width CSSPixels, height CSSPixels) PaintableBoxPixelCornerRadius {
	context := css.LengthResolutionContext.for_computed_properties(values)
	return PaintableBoxPixelCornerRadius{
		horizontal: radius.horizontal_radius.to_px(context, width)
		vertical: radius.vertical_radius.to_px(context, height)
	}
}

fn scale_paintable_box_corner_radius(radius PaintableBoxPixelCornerRadius, factor CSSPixelFraction) PaintableBoxPixelCornerRadius {
	return PaintableBoxPixelCornerRadius{
		horizontal: radius.horizontal.times_fraction(factor)
		vertical: radius.vertical.times_fraction(factor)
	}
}

fn paintable_box_corner_radius_transport(radius PaintableBoxPixelCornerRadius) CornerRadius {
	return CornerRadius{radius.horizontal.to_double(), radius.vertical.to_double()}
}

// Direct translation of PaintableBox::border_radii_data() and
// normalize_border_radii_data(). Keep the resolved radii and the overlap factor
// in fixed-point units, including upstream's second refinement pass, and only
// convert to the f64 paint transport after normalization is complete.
fn paintable_box_border_radii_data(computed &css.ComputedValues, width CSSPixels, height CSSPixels) BoxRadii {
	if !computed.has_noninitial_border_radii() {
		return BoxRadii{}
	}

	mut top_left := resolved_paintable_box_corner_radius(computed, computed.border_top_left_radius(), width, height)
	mut top_right := resolved_paintable_box_corner_radius(computed, computed.border_top_right_radius(), width, height)
	mut bottom_right := resolved_paintable_box_corner_radius(computed, computed.border_bottom_right_radius(), width, height)
	mut bottom_left := resolved_paintable_box_corner_radius(computed, computed.border_bottom_left_radius(), width, height)

	one := CSSPixelFraction.new(CSSPixels.new(1), CSSPixels.new(1))
	for _ in 0 .. 2 {
		s_top := top_left.horizontal.plus(top_right.horizontal)
		s_right := top_right.vertical.plus(bottom_right.vertical)
		s_bottom := bottom_right.horizontal.plus(bottom_left.horizontal)
		s_left := bottom_left.vertical.plus(top_left.vertical)

		mut factor := one
		if s_top.compare(width) > 0 {
			factor = width.divided_by(s_top)
		}
		if s_right.compare(height) > 0 {
			candidate := height.divided_by(s_right)
			if candidate.compare(factor) < 0 {
				factor = candidate
			}
		}
		if s_bottom.compare(width) > 0 {
			candidate := width.divided_by(s_bottom)
			if candidate.compare(factor) < 0 {
				factor = candidate
			}
		}
		if s_left.compare(height) > 0 {
			candidate := height.divided_by(s_left)
			if candidate.compare(factor) < 0 {
				factor = candidate
			}
		}
		if factor.compare(one) >= 0 {
			break
		}

		top_left = scale_paintable_box_corner_radius(top_left, factor)
		top_right = scale_paintable_box_corner_radius(top_right, factor)
		bottom_right = scale_paintable_box_corner_radius(bottom_right, factor)
		bottom_left = scale_paintable_box_corner_radius(bottom_left, factor)
	}

	return BoxRadii{
		top_left: paintable_box_corner_radius_transport(top_left)
		top_right: paintable_box_corner_radius_transport(top_right)
		bottom_right: paintable_box_corner_radius_transport(bottom_right)
		bottom_left: paintable_box_corner_radius_transport(bottom_left)
	}
}

enum PaintableBoxShrinkRadiiForBorders {
	no
	yes
}

// Direct translation of PaintableBox::normalized_border_radii_data(). Shrinking
// is deliberately not followed by another overlap-normalization pass upstream.
fn paintable_box_normalized_border_radii_data(border_radii BoxRadii, computed &css.ComputedValues, shrink PaintableBoxShrinkRadiiForBorders) BoxRadii {
	if shrink == .no {
		return border_radii
	}
	return BoxRadii{
		top_left: shrink_corner_radius(border_radii.top_left, computed.border_left().width.to_double(), computed.border_top().width.to_double())
		top_right: shrink_corner_radius(border_radii.top_right, computed.border_right().width.to_double(), computed.border_top().width.to_double())
		bottom_right: shrink_corner_radius(border_radii.bottom_right, computed.border_right().width.to_double(), computed.border_bottom().width.to_double())
		bottom_left: shrink_corner_radius(border_radii.bottom_left, computed.border_left().width.to_double(), computed.border_bottom().width.to_double())
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

// Direct translation of PaintableBox::outline_data(). ComputedValues already
// carries the layout-node-resolved system accent color at this bridge boundary.
fn paintable_box_outline_data(computed &css.ComputedValues) ?painting.BordersData {
	mut outline_color := computed.outline_color()
	mut line_style := computed_outline_line_style(computed.outline_style())
	mut outline_width := computed.outline_width().to_double()
	if computed.outline_style() == .auto_ {
		line_style = .solid
		outline_color = computed.accent_color() or { outline_color }
		outline_width = 2
	}
	return painting.borders_data_for_outline(painting.Color{outline_color.r, outline_color.g, outline_color.b, outline_color.a}, line_style, outline_width)
}

fn computed_shadow_transport(shadow_data []css.ShadowData, context css.LengthResolutionContext) []BoxShadow {
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

fn computed_box_shadows(computed &css.ComputedValues) []BoxShadow {
	shadows := computed.box_shadow()
	if shadows.len == 0 { return []BoxShadow{} }
	context := css.LengthResolutionContext.for_computed_properties(computed)
	return computed_shadow_transport(shadows, context)
}

fn computed_text_shadows(computed &css.ComputedValues) []BoxShadow {
	shadows := computed.text_shadow()
	if shadows.len == 0 { return []BoxShadow{} }
	context := css.LengthResolutionContext.for_computed_properties(computed)
	return computed_shadow_transport(shadows, context)
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
			image_url: node.image_url
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
	filter_element := resolve_svg_fragment_identifier_to_element(element.as_node(), reference[1..]) or {
		return none
	}
	if !filter_element.is_svg_element() || filter_element.local_name() != 'filter' {
		return none
	}
	mut mutable_filter := unsafe { &dom.Element(filter_element) }
	mutable_filter.register_svg_paint_resource_referencing_element(element)
	return painting_filter_from_svg_graph(svg_element_model(filter_element).gfx_filter())
}

fn resolve_css_filter(computed_filter css.Filter, computed &css.ComputedValues,
	color_context css.ColorResolutionContext,
	element ?&dom.Element, bounds ?painting.Rect) painting.ResolvedCSSFilter {
	if !computed_filter.has_filters() {
		return painting.ResolvedCSSFilter{}
	}
	mut operations := []painting.ResolvedFilterOperation{}
	mut svg_filter := ?painting.GfxFilter(none)
	mut svg_filter_bounds := ?painting.Rect(none)
	for filter_operation in computed_filter.filters() {
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
	return painting.ResolvedCSSFilter.with_svg_filter(operations, svg_filter, svg_filter_bounds)
}

fn resolved_css_filter_for_element(computed &css.ComputedValues,
	color_context css.ColorResolutionContext, element ?&dom.Element,
	bounds ?painting.Rect) painting.ResolvedCSSFilter {
	return resolve_css_filter(computed.filter(), computed, color_context, element, bounds)
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

// Position resolution is borrowed for this synchronous pass. A stored closure
// would keep the subject element in LengthResolutionContext alive after paint.
struct TypedGradientPositionResolver {
	resolution_context css.LengthResolutionContext
	reference_length   f64
	angle              bool
}

fn (resolver &TypedGradientPositionResolver) resolve(value css.StyleValue) f64 {
	if resolver.angle {
		return typed_gradient_position_as_angle(value)
	}
	return typed_gradient_position_as_length(resolver.resolution_context, value,
		resolver.reference_length)
}

fn resolve_color_stop_positions(elements []css.ColorStopListElement, context css.ColorResolutionContext,
	repeating bool, position_resolver &TypedGradientPositionResolver) painting.ColorStopData {
	if elements.len == 0 {
		return painting.ColorStopData{}
	}
	mut resolved := []TypedGradientStop{}
	for element in elements {
		color := element.color_stop.color.to_color(context) or { continue }
		mut stop := TypedGradientStop{
			color: color
		}
		if hint := element.transition_hint {
			stop.transition_hint = position_resolver.resolve(hint)
		}
		if position := element.color_stop.position {
			stop.position = position_resolver.resolve(position)
		}
		resolved << stop
		if second_position := element.color_stop.second_position {
			resolved << TypedGradientStop{
				color: color
				position: position_resolver.resolve(second_position)
			}
		}
	}
	if resolved.len == 0 {
		return painting.ColorStopData{}
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
	mut result := []painting.ColorStop{cap: resolved.len}
	for stop in resolved {
		result << painting.ColorStop{
			color: painting.Color{stop.color.r, stop.color.g, stop.color.b, stop.color.a}
			position: stop.position or { 0.0 }
			transition_hint: stop.transition_hint
		}
	}
	repeat_length := if repeating && result.len > 0 {
		?f64(result[result.len - 1].position - result[0].position)
	} else {
		?f64(none)
	}
	return painting.ColorStopData{
		list: result
		repeat_length: repeat_length
		repeating: repeating
	}
}

// The native gradient transport has no Skia repeat-length field, so expand the
// source data at this final renderer boundary after resolving positions.
fn gradient_stops_for_transport(data painting.ColorStopData) []GradientStop {
	expanded := painting.expand_color_stops_for_painting(data.list, data.repeat_length)
	mut result := []GradientStop{cap: expanded.len}
	for stop in expanded {
		result << GradientStop{
			color: css.Color{stop.color.r, stop.color.g, stop.color.b, stop.color.a}
			offset: stop.position
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

fn resolve_linear_gradient_data(resolution_context css.LengthResolutionContext,
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
	position_resolver := TypedGradientPositionResolver{
		resolution_context: resolution_context
		reference_length: gradient_length
	}
	color_stops := resolve_color_stop_positions(gradient.color_stop_list_, context,
		gradient.is_repeating(), position_resolver)
	stops := gradient_stops_for_transport(color_stops)
	return LinearGradient{
		x1: 0.5 - half_x
		y1: 0.5 - half_y
		x2: 0.5 + half_x
		y2: 0.5 + half_y
		colors: stops.map(it.color)
		stops: stops
		interpolation_method: gradient.interpolation_method()
		css_angle_degrees: angle
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

fn resolve_radial_gradient_data(resolution_context css.LengthResolutionContext,
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
	position_resolver := TypedGradientPositionResolver{
		resolution_context: resolution_context
		reference_length: radius_x
	}
	color_stops := resolve_color_stop_positions(gradient.color_stop_list_, context,
		gradient.is_repeating(), position_resolver)
	stops := gradient_stops_for_transport(color_stops)
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

fn resolve_conic_gradient_data(resolution_context css.LengthResolutionContext,
	gradient css.ConicGradientStyleValue, width f64, height f64,
	context css.ColorResolutionContext) LinearGradient {
	center_x, center_y := resolved_typed_gradient_position(resolution_context, gradient.position_, width, height)
	position_resolver := TypedGradientPositionResolver{angle: true}
	color_stops := resolve_color_stop_positions(gradient.color_stop_list_, context,
		gradient.is_repeating(), position_resolver)
	stops := gradient_stops_for_transport(color_stops)
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
		return resolve_linear_gradient_data(resolution_context, gradient, width, height, color_context)
	}
	if gradient := source.as_radial_gradient() {
		return resolve_radial_gradient_data(resolution_context, gradient, width, height, color_context)
	}
	if gradient := source.as_conic_gradient() {
		return resolve_conic_gradient_data(resolution_context, gradient, width, height, color_context)
	}
	return none
}

fn computed_background_gradient(computed &css.ComputedProperties, width f64, height f64, context css.ColorResolutionContext) ?LinearGradient {
	value := computed.typed_property_value(.background_image) or { return none }
	values := if list := value.as_value_list() { list.values() } else { [value] }
	for item in values {
		if item !is css.LinearGradientStyleValue && item !is css.RadialGradientStyleValue
			&& item !is css.ConicGradientStyleValue { continue }
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

fn supports_light_or_dark_color_scheme(schemes []string) bool {
	return 'light' in schemes || 'dark' in schemes
}

// Controls use light when neither the element nor its document opts into a
// supported color scheme. Embedded SVG images instead follow the page's
// preference in that case, while preserving explicit element/document schemes.
fn image_color_scheme(document &dom.Document, computed &css.ComputedProperties) css.PreferredColorScheme {
	preferred_scheme := css.preferred_color_scheme_from_string(document.preferred_color_scheme())
	if value := computed.typed_property_value(.color_scheme) {
		if value is css.ColorSchemeStyleValue
			&& supports_light_or_dark_color_scheme(value.schemes()) {
			return computed.color_scheme(preferred_scheme, document.supported_color_schemes())
		}
	}
	if schemes := document.supported_color_schemes() {
		if supports_light_or_dark_color_scheme(schemes) {
			return computed.color_scheme(preferred_scheme, schemes)
		}
	}
	return preferred_scheme
}

fn computed_image_value_has_no_layers(value css.StyleValue) bool {
	if value.is_keyword() { return value.to_keyword() == .none_ }
	if list := value.as_value_list() {
		if list.separator() != .comma || list.size() == 0 { return false }
		for item in list.values() {
			if !item.is_keyword() || item.to_keyword() != .none_ { return false }
		}
		return true
	}
	return false
}

fn computed_background_image_layers(node &Node, element &dom.Element, computed &css.ComputedProperties,
	color_context css.ColorResolutionContext) []BackgroundImageLayer {
	value := computed.typed_property_value(.background_image) or { return []BackgroundImageLayer{} }
	// Computed coordinating properties retain even a lone `none` in a list.
	// Avoid layer/context storage when that retained list contains no image.
	if computed_image_value_has_no_layers(value) {
		return []BackgroundImageLayer{}
	}
	computed_layers := css.background_layers_outside_samples(element.document(),
		resolved_background_layers_for_paint(computed))
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
		mut effective_item := item
		if item is css.ImageSetStyleValue {
			selected := item.image_for_device_pixel_ratio(element.document().device_pixels_per_css_pixel()) or {
				continue
			}
			effective_item = match selected {
				css.ConicGradientStyleValue { css.StyleValue(selected) }
				css.ImageStyleValue { css.StyleValue(selected) }
				css.LinearGradientStyleValue { css.StyleValue(selected) }
				css.RadialGradientStyleValue { css.StyleValue(selected) }
			}
		}
		mut computed_layer := ?css.BackgroundLayerData(none)
		if !(item.is_keyword() && item.to_keyword() == .none_) {
			if computed_layer_index < computed_layers.len {
				computed_layer = computed_layers[computed_layer_index]
			}
			computed_layer_index++
		}
		mut gradient_source := ?css.StyleValue(none)
		if effective_item is css.LinearGradientStyleValue
			|| effective_item is css.RadialGradientStyleValue
			|| effective_item is css.ConicGradientStyleValue {
			gradient_source = effective_item
		}
		mut resolved_url := ''
		if image := effective_item.as_image() {
			source := image.url_.url()
			resolved_url = resolve_css_paint_image_url(node, source, base_url)
		} else if gradient_source == none {
			continue
		}
		color_scheme := image_color_scheme(element.document(), computed)
		svg_document := svg_image_document_for_source_in_viewport(node, resolved_url, color_scheme)
		intrinsic_width, intrinsic_height := background_svg_intrinsic_dimensions(svg_document)
		repeat_x, repeat_y := parsed_background_repeat(computed_coordinated_background_value(computed, .background_repeat, index, 'repeat'))
		layers << BackgroundImageLayer{
			url: resolved_url
			svg_document: svg_document
			intrinsic_width: intrinsic_width
			intrinsic_height: intrinsic_height
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
			color_scheme: color_scheme
		}
	}
	return layers
}

// CSS mask-image uses the same decoded-image provider as backgrounds, but its
// pixels are composited into an alpha mask around the element's complete paint
// subtree. Retain URL layers as mask image operations so animated resources are
// sampled at replay time and all consumers share the provider's frame timing.
fn css_mask_image_for_box(element &dom.Element, computed &css.ComputedProperties,
	border_rect painting.Rect, node &Node) ?painting.SVGMaskVisualData {
	value := computed.typed_property_value(.mask_image) or { return none }
	if computed_image_value_has_no_layers(value) {
		return none
	}
	values := if list := value.as_value_list() {
		if list.separator() == .comma { list.values() } else { [value] }
	} else {
		[value]
	}
	base_url := if dom_value := computed.property(.mask_image, .yes) {
		dom_value.base_url
	} else {
		?string(none)
	}
	mut operations := []painting.SVGMaskPaintOperation{}
	for item in values {
		mut effective_item := item
		if item is css.ImageSetStyleValue {
			selected := item.image_for_device_pixel_ratio(element.document().device_pixels_per_css_pixel()) or {
				continue
			}
			effective_item = match selected {
				css.ConicGradientStyleValue { css.StyleValue(selected) }
				css.ImageStyleValue { css.StyleValue(selected) }
				css.LinearGradientStyleValue { css.StyleValue(selected) }
				css.RadialGradientStyleValue { css.StyleValue(selected) }
			}
		}
		image := effective_item.as_image() or {
			// A transparent gradient contributes no coverage. Other generated
			// mask images remain available for the subsequent gradient slice.
			continue
		}
		source := image.url_.url()
		resolved_url := if base := base_url {
			if parsed := dom.dom_url_parse(source, dom.URL{value: base}, '') {
				parsed.to_string()
			} else {
				source
			}
		} else {
			element.document().encoding_parse_and_serialize_url(source) or { source }
		}
		if resolved_url == '' {
			continue
		}
		// SVG mask images are vector image documents, just like SVG images
		// inside a mask resource. The bitmap-only replay cannot decode them.
		mut vector := SVGMaskPaintCollection{}
		// CSS mask images use the snapped image origin of the background
		// painting geometry. Keep SVG <image> resource coordinates fractional.
		vector_rect := if element.document().font_rendering_policy() == .chromium {
			painting.Rect{math.floor(border_rect.x + .5), math.floor(border_rect.y + .5),
				border_rect.width, border_rect.height}
		} else { border_rect }
		if collect_svg_vector_image_paint_operations(node, resolved_url, vector_rect,
			image_color_scheme(element.document(), computed), mut vector) {
			operations << vector.operations
			continue
		}
		operations << painting.SVGMaskPaintOperation{
			kind: .image
			image_url: resolved_url
			image_rect: border_rect
			image_position_x: '0%'
			image_position_y: '0%'
			image_rendering: computed.image_rendering()
			image_paintable: painting.ImagePaintable{
				image_rect: border_rect
				object_fit: .fill
				object_position: css.Position{}
				resolution_context: computed.length_resolution_context()
				image_rendering: computed.image_rendering()
			}
			transform: painting.Affine{}
		}
	}
	if operations.len == 0 {
		return none
	}
	bounding_rect := compatibility_enclosing_int_rect(LayoutRect{
		x: border_rect.x
		y: border_rect.y
		width: border_rect.width
		height: border_rect.height
	})
	return painting.SVGMaskVisualData{
		bounding_rect: bounding_rect
		mask_type: .alpha
		operations: operations
		cache_key: svg_mask_visual_cache_key(bounding_rect, .alpha, operations)
		scope_id: svg_resource_scope_id(node, 3)
	}
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
	if computed.translate() != none || computed.rotate() != none || computed.scale() != none {
		return false
	}
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

fn resolve_svg_fragment_identifier_to_element(node &dom.Node, fragment string) ?&dom.Element {
	decoded_fragment := svg.decode_fragment_identifier(fragment)
	if element := node.document().get_element_by_id(decoded_fragment) {
		return element
	}
	if shadow_root := node.containing_shadow_root() {
		return unsafe { &dom.ParentNode(shadow_root) }.get_element_by_id(decoded_fragment)
	}
	return none
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

fn register_svg_gradient_paint_resource_chain(element &dom.Element,
	referencing_element &dom.Element) {
	mut current := element
	mut seen := map[i64]bool{}
	for {
		identity := current.as_node().unique_id().value()
		if seen[identity] {
			return
		}
		seen[identity] = true
		mut mutable_current := unsafe { &dom.Element(current) }
		mutable_current.register_svg_paint_resource_referencing_element(referencing_element)
		current = linked_svg_gradient(current, mut seen) or { return }
	}
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
		if element := svg_element_for_layout_node(candidate) {
			if candidate.is_svg_svg_box() || element.local_name() == 'symbol' {
				if view_box := svg.parse_viewbox(element.get_attribute_value('viewBox')) {
					if view_box.width >= 0 && view_box.height >= 0 {
						return painting.Size{view_box.width, view_box.height}
					}
				}
				if styled := candidate.as_node_with_style() {
					if used := state.try_get(styled) {
						return painting.Size{used.content_width().to_double(), used.content_height().to_double()}
					}
				}
			}
		}
		current = candidate.parent()
	}
	return painting.Size{}
}

fn viewport_percentage_basis(node &Node, state &LayoutState) f64 {
	viewport := svg_paint_viewport_size(node, state)
	return (viewport.width + viewport.height) * 0.5
}

fn resolved_svg_stroke_dasharray(computed &css.ComputedProperties, percentage_basis f64) []f64 {
	mut dasharray := []f64{}
	context := computed.length_resolution_context()
	reference := css.CSSPixels.nearest_value_for(percentage_basis)
	for item in computed.stroke_dasharray() {
		value := if item.is_length_percentage {
			item.length_percentage.to_px(context, reference).to_double()
		} else {
			item.number
		}
		if value < 0 {
			return []
		}
		dasharray << value
	}
	if dasharray.all(it == 0) {
		return []
	}
	if dasharray.len % 2 == 1 {
		dasharray << dasharray.clone()
	}
	return dasharray
}

// The native twelve-float SVG protocol reserves kind 6 for an explicit
// ellipse's LTRB rectangle. Keep source identity: an authored four-arc <path>
// must still reach Skia as arcs, even when it has the same outline.
fn retained_svg_ellipse_data(node &Node, path svg.Path) ?[]f32 {
	if node.document().font_rendering_policy() != .chromium || !node.is_svg_geometry_box() {
		return none
	}
	element := svg_element_for_layout_node(node) or { return none }
	if element.local_name() !in ['circle', 'ellipse'] || path.instructions.len != 5 {
		return none
	}
	move := path.instructions[0]
	arc := path.instructions[1]
	if move.type_ != .move || move.data.len != 2 || arc.type_ != .elliptical_arc
		|| arc.data.len != 7 {
		return none
	}
	cx := arc.data[5]
	cy := move.data[1]
	rx := arc.data[0]
	ry := arc.data[1]
	if rx <= 0 || ry <= 0 {
		return none
	}
	mut packed := []f32{len: 12}
	packed[0] = 6
	for index, coordinate in [cx - rx, cy - ry, cx + rx, cy + ry] {
		// Comparisons also reject NaN; don't publish an infinite float rectangle.
		if !(coordinate >= -3.4028234663852886e38 && coordinate <= 3.4028234663852886e38) {
			return none
		}
		packed[index + 1] = f32(coordinate)
	}
	return packed
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

// SVG maps objectBoundingBox gradient coordinates through the bounding-box
// transform, so a non-square box skews linear isolines and makes radial
// gradients elliptical, as in Chromium. LibWeb maps only the endpoints into
// user space; Chromium-policy documents follow the specification.
fn svg_gradient_uses_bounding_box_space(node &Node) bool {
	return node.document().font_rendering_policy() == .chromium
}

fn svg_bounding_box_gradient_transform(gradient_transform svg.AffineTransform, bounds painting.Rect,
	unit_space bool) svg.AffineTransform {
	if !unit_space {
		return gradient_transform
	}
	return svg.AffineTransform{}.translated(bounds.x, bounds.y).scaled(bounds.width,
		bounds.height).multiply(gradient_transform)
}

fn resolve_svg_linear_gradient_paint_style(node &Node, state &LayoutState,
	paint css.SVGPaint, path_bounds ?painting.Rect) ?painting.SVGLinearGradientPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or {
		return none
	}
	element := resolve_svg_fragment_identifier_to_element(dom_node, fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'linearGradient' {
		return none
	}
	register_svg_gradient_paint_resource_chain(element, dom_node.as_element() or { return none })
	bounds := path_bounds or { return none }
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
	unit_space := units == .object_bounding_box && svg_gradient_uses_bounding_box_space(node)
	resolve_x := fn [units, bounds, viewport, unit_space] (value svg.NumberPercentage) f64 {
		return if unit_space {
			value.value
		} else if units == .object_bounding_box {
			bounds.x + value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_y := fn [units, bounds, viewport, unit_space] (value svg.NumberPercentage) f64 {
		return if unit_space {
			value.value
		} else if units == .object_bounding_box {
			bounds.y + value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	seen.clear()
	gradient_transform := svg_bounding_box_gradient_transform(svg_gradient_transform(element, mut seen),
		bounds, unit_space)
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
	paint css.SVGPaint, path_bounds ?painting.Rect) ?painting.SVGRadialGradientPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or { return none }
	element := resolve_svg_fragment_identifier_to_element(dom_node, fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'radialGradient' {
		return none
	}
	register_svg_gradient_paint_resource_chain(element, dom_node.as_element() or { return none })
	bounds := path_bounds or { return none }
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
	unit_space := units == .object_bounding_box && svg_gradient_uses_bounding_box_space(node)
	resolve_x := fn [units, bounds, viewport, unit_space] (value svg.NumberPercentage) f64 {
		return if unit_space {
			value.value
		} else if units == .object_bounding_box {
			bounds.x + value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	resolve_y := fn [units, bounds, viewport, unit_space] (value svg.NumberPercentage) f64 {
		return if unit_space {
			value.value
		} else if units == .object_bounding_box {
			bounds.y + value.value * bounds.height
		} else {
			value.resolve_relative_to(viewport.height)
		}
	}
	resolve_radius := fn [units, bounds, viewport, unit_space] (value svg.NumberPercentage) f64 {
		// This deliberately follows SVGRadialGradientElement.cpp: both object-box
		// and user-space radial lengths use the applicable width.
		return if unit_space {
			value.value
		} else if units == .object_bounding_box {
			value.value * bounds.width
		} else {
			value.resolve_relative_to(viewport.width)
		}
	}
	seen.clear()
	gradient_transform := svg_bounding_box_gradient_transform(svg_gradient_transform(element, mut seen),
		bounds, unit_space)
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

fn register_svg_pattern_paint_resource_chain(element &dom.Element,
	referencing_element &dom.Element) {
	mut current := element
	mut seen := map[i64]bool{}
	for {
		identity := current.as_node().unique_id().value()
		if seen[identity] {
			return
		}
		seen[identity] = true
		mut mutable_current := unsafe { &dom.Element(current) }
		mutable_current.register_svg_paint_resource_referencing_element(referencing_element)
		current = linked_svg_pattern(current, mut seen) or { return }
	}
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

fn transform_svg_mask_paint_operations(operations []painting.SVGMaskPaintOperation,
	transform painting.Affine) []painting.SVGMaskPaintOperation {
	mut transformed := []painting.SVGMaskPaintOperation{cap: operations.len}
	for operation in operations {
		if operation.kind == .begin_filter {
			filter := operation.filter or {
				transformed << operation
				continue
			}
			mut bounds := ?painting.Rect(none)
			if filter_bounds := filter.bounds {
				bounds = transform.map_rect(filter_bounds)
			}
			transformed << painting.SVGMaskPaintOperation{
				...operation
				filter: painting.GfxFilter{
					...filter
					bounds: bounds
				}
			}
		} else if operation.kind == .path {
			transformed << painting.SVGMaskPaintOperation{
				...operation
				transform: multiply_painting_affine(transform, operation.transform)
			}
		} else if operation.kind == .image {
			transformed << painting.SVGMaskPaintOperation{
				...operation
				transform: multiply_painting_affine(transform, operation.transform)
			}
		} else {
			transformed << operation
		}
	}
	return transformed
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
	return transform_svg_mask_paint_operations(operations, normalization)
}

fn resolve_svg_pattern_paint_style(node &Node, state &LayoutState, paint css.SVGPaint,
	path_bounds ?painting.Rect, target_transform svg.AffineTransform) ?&painting.SVGPatternPaintStyle {
	if !paint.is_url() {
		return none
	}
	dom_node := node.dom_node() or { return none }
	fragment := svg_paint_fragment(paint.as_url().url()) or { return none }
	element := resolve_svg_fragment_identifier_to_element(dom_node, fragment) or { return none }
	if !element.is_svg_element() || element.local_name() != 'pattern' {
		return none
	}
	register_svg_pattern_paint_resource_chain(element, dom_node.as_element() or { return none })
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
	bounds := path_bounds or { return none }
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
	resource_transform := target_used.svg_transform().multiply(svg_element_attribute_transform(content_element))
	mut collection := SVGMaskPaintCollection{}
	collect_svg_mask_paint_operations(resource, state, resource_transform, true, false, true,
		mut collection)
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
	body := root.document().body() or { return none }
	body_node := unsafe { &dom.Element(body) }.as_node()
	for child in root.children() {
		if dom_node := child.dom_node() {
			if voidptr(dom_node) == voidptr(body_node) {
				return child
			}
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

// Direct translation of the root/body branches in PaintableBox::paint_background().
// Ordinary boxes already retain their resolved background directly; the root additionally
// expands to the canvas and may paint the body's propagated properties.
fn paintable_box_paint_background(mut root_box BlockBox, root_layout_node &Node,
	state &LayoutState, viewport_width f64, viewport_height f64) {
	mut canvas_rect := LayoutRect{0, 0, viewport_width, viewport_height}
	if root_styled := root_layout_node.as_node_with_style() {
		if root_used := state.try_get(root_styled) {
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
					root_box.background_gradient = retained_box_paint_payload(computed_background_gradient(body_computed, root_box.border_box().width, root_box.border_box().height, color_context))
					root_box.background_images = computed_background_image_layers(body_layout_node, body_element, body_computed, color_context)
					// If the body's background was propagated to the root element, use the
					// body's image-rendering value too.
					root_box.replaced_image_rendering = body_computed.image_rendering()
					suppress_background_for_node_id(mut root_box, i64(body_element.as_node().unique_id()))
				}
			}
		}
	}
}

// Translate the committed typed layout tree into the renderer transport. This
// is shared by the native shell and DOM's callback-backed viewport paintable;
// both must record and hit-test the exact same paint-order tree.
fn renderer_box_from_document_layout_result(result &DocumentLayoutResult, viewport_width f64, viewport_height f64) BlockBox {
	mut projection_owner := unsafe { &DocumentLayoutResult(result) }
	projection_owner.paint_tree_storage = unsafe { nil }
	layout_completed := time.sys_mono_now()
	root_layout_node := result.root.first_child() or { return BlockBox{} }
	document := root_layout_node.document()
	storage := projection_owner.acquire_paint_tree_storage(document)
	mut entry := platform.ArenaEntry{}
	if storage != unsafe { nil } { entry = storage.arena.enter() }
	defer { if storage != unsafe { nil } { storage.arena.leave(entry) } }
	coordinates := begin_paint_coordinate_session(result.state)
	defer { coordinates.finish() }
	svg_sources := begin_paint_svg_source_session(root_layout_node)
	defer { svg_sources.finish() }
	mut incomplete := PaintProjectionStatus{}
	mut root_box := build_typed_paint_tree_projection(root_layout_node, result.state, layout_to_css_transform(document), result.paint_projection_interest, mut incomplete)
	projection_owner.paint_tree_storage = storage
	projection_owner.paint_projection_incomplete = incomplete.incomplete
	paintable_box_paint_background(mut root_box, root_layout_node, result.state,
		viewport_width * document.layout_coordinate_scale(),
		viewport_height * document.layout_coordinate_scale())

	// The compatibility transport omits the typed Viewport node itself. Mark its
	// root element as the owner of the mandatory viewport scroll frame so replay
	// still follows ViewportPaintable::assign_scroll_frames().
	root_box.is_viewport_scroller = true
	root_box.viewport_width = viewport_width * document.layout_coordinate_scale()
	root_box.viewport_height = viewport_height * document.layout_coordinate_scale()
	if viewport_styled := result.root.as_node_with_style() {
		if viewport_used := result.state.try_get(viewport_styled) {
			root_box.overlay = retained_box_paint_payload(compatibility_overlay_data(result.root, viewport_styled.computed_values(), viewport_used))
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

// Build into one exact-sized backing store so ordinary small child groups do
// not each allocate a large, separately scanned BlockBox vector.
fn block_box_from_typed_layout_with_ancestor(node &Node, state &LayoutState, ancestor_paint_transform [6]f64) BlockBox {
	return build_typed_paint_tree_in_arena(node, state, ancestor_paint_transform)
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
		if operation.kind == .begin_filter {
			if filter := operation.filter {
				hash = svg_filter_visual_cache_key(hash, filter)
			}
			continue
		}
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

fn svg_filter_visual_cache_key(seed u64, filter painting.GfxFilter) u64 {
	mut hash := seed
	if root_id := filter.root_id {
		hash = svg_clip_hash_mix(hash, u64(root_id + 1))
	}
	if bounds := filter.bounds {
		for value in [bounds.x, bounds.y, bounds.width, bounds.height] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
	}
	for operation in filter.operations {
		for byte in operation.kind.bytes() {
			hash = svg_clip_hash_mix(hash, u64(byte))
		}
		for value in [operation.first, operation.second, operation.third] {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(operation.color))
		hash = svg_clip_hash_mix(hash, u64(operation.color_operation))
	}
	for node in filter.nodes {
		hash = svg_clip_hash_mix(hash, u64(node.id + 1))
		for byte in node.kind.bytes() {
			hash = svg_clip_hash_mix(hash, u64(byte))
		}
		for input_id in node.input_ids {
			hash = svg_clip_hash_mix(hash, u64(input_id + 2))
		}
		mut parameter_names := node.parameters.keys()
		parameter_names.sort()
		for name in parameter_names {
			for byte in name.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			hash = svg_clip_hash_mix(hash, math.f64_bits(node.parameters[name]))
		}
		mut string_parameter_names := node.string_parameters.keys()
		string_parameter_names.sort()
		for name in string_parameter_names {
			for byte in name.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			for byte in node.string_parameters[name].bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
		}
		for byte in node.image_url.bytes() {
			hash = svg_clip_hash_mix(hash, u64(byte))
		}
		hash = svg_clip_hash_mix(hash, svg_mask_color_key(node.color))
		for value in node.matrix {
			hash = svg_clip_hash_mix(hash, math.f64_bits(value))
		}
		for table in node.color_tables {
			for byte in table.channel.bytes() {
				hash = svg_clip_hash_mix(hash, u64(byte))
			}
			for value in table.values {
				hash = svg_clip_hash_mix(hash, u64(value))
			}
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

// The transform from a userSpaceOnUse clip child's own coordinates to the page:
// the referencing element's user space (including every nested <svg> viewport
// between it and the outermost root), then the clipPath's and each enclosing
// clip descendant's transform attributes.
fn svg_clip_child_transform_to_page(node &Node, clip_box &Node, target_to_page svg.AffineTransform) svg.AffineTransform {
	mut chain := []&Node{}
	mut current := ?&Node(node)
	for current != none {
		candidate := current or { break }
		chain << candidate
		if layout_nodes_same(candidate, clip_box) {
			break
		}
		current = candidate.parent()
	}
	mut transform := target_to_page
	for index := chain.len - 1; index >= 0; index-- {
		if element := svg_element_for_layout_node(chain[index]) {
			transform = transform.multiply(svg_element_attribute_transform(element))
		}
	}
	return transform
}

fn collect_svg_clip_path_components(node &Node, state &LayoutState,
	resource_transform svg.AffineTransform, object_bounding_box_units bool,
	mut collection SVGClipPathCollection) {
	collect_svg_clip_path_components_in(node, unsafe { nil }, state, resource_transform,
		object_bounding_box_units, none, mut collection)
}

fn collect_svg_clip_path_components_in(node &Node, clip_box &Node, state &LayoutState,
	resource_transform svg.AffineTransform, object_bounding_box_units bool,
	target_to_page ?svg.AffineTransform, mut collection SVGClipPathCollection) {
	if node.is_svg_mask_box() || node.is_svg_pattern_box() {
		return
	}
	if styled := node.as_node_with_style() {
		// SVGPaintable::contributes_to_clip_path(): an invisible resource node
		// contributes neither its own geometry nor any descendant geometry to the
		// union used for the clip mask and its masking area.
		if styled.computed_values().visibility() != .visible || node.display().is_none() {
			return
		}
		if used := state.try_get(styled) {
			if svg_path := used.computed_svg_path() {
				position := paint_cumulative_offset(node, state, used)
				page_delta_x := position.x().to_double() - used.offset.x().to_double()
				page_delta_y := position.y().to_double() - used.offset.y().to_double()
				mut to_page := svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(resource_transform).multiply(used.svg_transform())
				if object_bounding_box_units {
					to_page = outer_svg_viewport_transform_in_page_space(node, state).multiply(to_page)
				} else if user_space := target_to_page {
					to_page = svg_clip_child_transform_to_page(node, clip_box, user_space)
				}
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
			collect_svg_clip_path_components_in(child, clip_box, state, resource_transform,
				object_bounding_box_units, target_to_page, mut collection)
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
	resource_transform := target_used.svg_transform().multiply(svg_element_attribute_transform(clip_element))
	object_bounding_box_units := svg.parse_units(clip_element.get_attribute_value('clipPathUnits')) or {
		svg.Units.user_space_on_use
	} == .object_bounding_box
	mut collection := SVGClipPathCollection{}
	// userSpaceOnUse clip geometry lives in the referencing element's user
	// space; map it exactly as that element's own shapes are mapped, so nested
	// <svg> viewport offsets are applied once.
	target_to_page := if object_bounding_box_units || !node.is_svg_box() || node.is_svg_svg_box() {
		?svg.AffineTransform(none)
	} else {
		?svg.AffineTransform(svg_path_transform_to_page(node, state))
	}
	collect_svg_clip_path_components_in(clip_box, clip_box, state, resource_transform,
		object_bounding_box_units, target_to_page, mut collection)
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

fn collect_svg_vector_image_paint_operations(node &Node, image_url string,
	image_rect painting.Rect, color_scheme css.PreferredColorScheme,
	mut collection SVGMaskPaintCollection) bool {
	// Masks share decoded SVG documents with backgrounds in this layout tree.
	// Recheck response bytes and color scheme before reuse; layout below still
	// resolves each consumer's own image size.
	svg_document := svg_image_document_for_source_in_viewport(node, image_url, color_scheme) or {
		return false
	}
	nested_layout := run_document_layout(svg_document, image_rect.width, image_rect.height) or {
		return false
	}
	mut nested_collection := SVGMaskPaintCollection{}
	collect_svg_mask_paint_operations(nested_layout.root, nested_layout.state, svg.AffineTransform{},
		true, false, true, mut nested_collection)
	translation := painting.Affine{
		e: image_rect.x
		f: image_rect.y
	}
	for operation in transform_svg_mask_paint_operations(nested_collection.operations, translation) {
		collection.operations << operation
	}
	return true
}

fn collect_svg_mask_paint_operations(node &Node, state &LayoutState,
	resource_transform svg.AffineTransform, is_resource_root bool, object_bounding_box_units bool,
	retain_filters bool, mut collection SVGMaskPaintCollection) {
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
	mut retained_filter := ?painting.GfxFilter(none)
	if retain_filters {
		if element := node.dom_node() {
			if paint_element := element.as_element() {
				position := paint_cumulative_offset(node, state, used)
				bounds := painting.Rect{
					x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
					y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
					width: used.border_box_width().to_double()
					height: used.border_box_height().to_double()
				}
				color_context := color_resolution_context_for_typed_node(node, computed.color())
				resolved := resolved_css_filter_for_element(computed, color_context, paint_element,
					bounds)
				retained_filter = resolved.to_gfx_filter(1)
			}
		}
	}
	if retained_filter != none {
		collection.operations << painting.SVGMaskPaintOperation{
			kind: .begin_filter
			filter: retained_filter
		}
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
					image_rect := painting.Rect{
						x: position.x().to_double()
						y: position.y().to_double()
						width: used.content_width().to_double()
						height: used.content_height().to_double()
					}
					if !collect_svg_vector_image_paint_operations(node, image_url, image_rect,
						image_color_scheme(element.document(), computed), mut collection) {
						collection.operations << painting.SVGMaskPaintOperation{
							kind: .image
							image_url: image_url
							image_rect: image_rect
							image_position_x: object_position.offset_x.to_string()
							image_position_y: object_position.offset_y.to_string()
							image_rendering: computed.image_rendering()
							image_paintable: painting.ImagePaintable{
								image_rect: image_rect
								object_fit: .contain
								object_position: object_position
								resolution_context: computed.length_resolution_context()
								image_rendering: computed.image_rendering()
								is_svg_image: true
							}
						}
					}
				}
			}
		} else if svg_path := used.computed_svg_path() {
			stroke_width := computed.length_percentage_to_px(.stroke_width, viewport_percentage_basis(node, state)) or { 1.0 }
			position := paint_cumulative_offset(node, state, used)
			page_delta_x := position.x().to_double() - used.offset.x().to_double()
			page_delta_y := position.y().to_double() - used.offset.y().to_double()
			mut to_page := svg.AffineTransform{}.translated(page_delta_x, page_delta_y).multiply(used.svg_viewbox_transform()).multiply(resource_transform).multiply(used.svg_transform())
			if object_bounding_box_units {
				to_page = outer_svg_viewport_transform_in_page_space(node, state).multiply(to_page)
			}
			path := painting_clip_path_from_canvas_path(html.canvas_gfx_path_from_svg_path(svg_path), if computed.fill_rule() == .evenodd {
				painting.WindingRule.even_odd
			} else {
				painting.WindingRule.nonzero
			})
			if path.segments.len > 0 {
				path_bounds := painting_clip_path_bounds(path)
				mut fill_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
				mut stroke_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
				mut fill_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
				mut stroke_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
				mut fill_pattern := ?&painting.SVGPatternPaintStyle(none)
				mut stroke_pattern := ?&painting.SVGPatternPaintStyle(none)
				if fill_paint := computed.fill() {
					fill_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, fill_paint, path_bounds)
					fill_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, fill_paint, path_bounds)
					fill_pattern = resolve_svg_pattern_paint_style(node, state, fill_paint, path_bounds, to_page)
				}
				if stroke_paint := computed.stroke() {
					stroke_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, stroke_paint, path_bounds)
					stroke_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, stroke_paint, path_bounds)
					stroke_pattern = resolve_svg_pattern_paint_style(node, state, stroke_paint, path_bounds, to_page)
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
			collect_svg_mask_paint_operations(child, state, resource_transform, false,
				object_bounding_box_units, retain_filters, mut collection)
		}
	}
	if wrap_opacity {
		collection.operations << painting.SVGMaskPaintOperation{
			kind: .end_opacity
		}
	}
	if retained_filter != none {
		collection.operations << painting.SVGMaskPaintOperation{
			kind: .end_filter
		}
	}
}

fn svg_target_user_space_object_bounding_box(target_used &UsedValues) svg.Rect {
	if path := target_used.computed_svg_path() {
		return svg_path_bounds(path) or { svg.Rect{} }
	}
	return svg.Rect{
		x: target_used.offset.x().to_double()
		y: target_used.offset.y().to_double()
		width: target_used.content_width().to_double()
		height: target_used.content_height().to_double()
	}
}

fn resolve_svg_masking_area(mask_element &dom.Element, target_bounds svg.Rect,
	viewport painting.Size) svg.Rect {
	return svg_element_model(mask_element).masking_area_in_user_space(target_bounds, svg.Point{
		x: viewport.width
		y: viewport.height
	})
}

// SVGMaskable::get_svg_mask_area()/calculate_svg_mask_display_list(): retain
// the mask resource's normal SVG foreground painting, its layer boundaries,
// and the mask-type conversion.
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
	_ = state.try_get(mask_styled) or { return none }
	mask_element := svg_element_for_layout_node(mask_box) or { return none }
	resource_transform := target_used.svg_transform().multiply(svg_element_attribute_transform(mask_element))
	object_bounding_box_units := svg.parse_units(mask_element.get_attribute_value('maskContentUnits')) or {
		svg.Units.user_space_on_use
	} == .object_bounding_box
	mut collection := SVGMaskPaintCollection{}
	collect_svg_mask_paint_operations(mask_box, state, resource_transform, true,
		object_bounding_box_units, false, mut collection)
	target_bounds := svg_target_user_space_object_bounding_box(target_used)
	viewport := svg_paint_viewport_size(node, state)
	user_space_mask_area := resolve_svg_masking_area(mask_element, target_bounds, viewport)
	mask_area := svg_path_transform_to_page(node, state).map_rect(user_space_mask_area)
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
//
// Paintable's cached positioned bit has a painting-specific exception to
// Layout::Node::is_positioned(): flex and grid items with a non-auto z-index
// behave as positioned for stacking even when their computed position remains
// static.
fn paintable_is_positioned(node &Node, computed &css.ComputedValues) bool {
	return node.is_positioned()
		|| ((node.is_flex_item() || node.is_grid_item()) && computed.z_index() != none)
}

fn uncached_block_box_from_typed_layout_shallow(node &Node, state &LayoutState, ancestor_paint_transform [6]f64) BlockBox {
	platform.cooperative_work_checkpoint()
	styled := node.as_node_with_style() or { return BlockBox{} }
	used := state.try_get(styled) or { return BlockBox{} }
	if used.svg_rendering_disabled() {
		return BlockBox{}
	}
	computed := styled.computed_values()
	position := paint_cumulative_offset(node, state, used)
	mut paint_position := position
	mut paint_width := used.content_width().to_double()
	mut paint_height := used.content_height().to_double()
	if node.is_svg_svg_box() || node.is_svg_foreign_object_box() {
		mapped_bounds := svg_box_visual_bounds_to_page(node, state, used)
		paint_position = CSSPixelPoint.from_values(mapped_bounds.x, mapped_bounds.y)
		paint_width = mapped_bounds.width
		paint_height = mapped_bounds.height
	}
	mut element := ?&dom.Element(none)
	mut tag_name := ''
	mut is_html_video := false
	mut node_id := i64(0)
	if dom_node := node.dom_node() {
		if dom_element := dom_node.as_element() {
			element = dom_element
			tag_name = dom_element.local_name()
			is_html_video = dom_element.is_html_element() && tag_name == 'video'
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
	mut outline_is_auto := false
	mut shadow := ?BoxShadow(none)
	mut shadows := []BoxShadow{}
	mut background_gradient := ?LinearGradient(none)
	mut background_images := []BackgroundImageLayer{}
	mut replaced_image_url := ''
	mut replaced_image_size := ''
	mut replaced_image_position_x := '50%'
	mut replaced_image_position_y := '50%'
	mut replaced_image_paintable := ?&painting.ImagePaintable(none)
	mut replaced_image_bitmap := ?&dom.Bitmap_(none)
	mut canvas_bitmap := ?&dom.Bitmap_(none)
	mut canvas_paintable := ?&painting.CanvasPaintable(none)
	mut video_bitmap := ?&dom.Bitmap_(none)
	mut video_frame_source := ?&painting.VideoFrameSource(none)
	mut video_representation := painting.VideoRepresentation.transparent_black
	mut video_paintable := ?&painting.VideoPaintable(none)
	mut nested_viewport_document := ?&dom.Document(none)
	mut nested_viewport_paintable := ?&painting.NavigableContainerViewportPaintable(none)
	mut form_control_kind := ''
	mut form_control_checked := false
	mut form_control_indeterminate := false
	mut form_control_enabled := true
	mut form_control_activated := false
	mut fieldset_paintable := ?painting.FieldSetPaintable(none)
	mut has_svg_path := false
	mut svg_path := ''
	mut svg_path_data := []f32{}
	mut svg_path_bounding_box := painting.Rect{}
	mut svg_transform := [f64(1), 0, 0, 1, 0, 0]!
	mut svg_points := []f64{}
	mut svg_fill_color := ''
	mut svg_solid_color_data := &PaintSVGSolidColorData(unsafe { nil })
	mut svg_fill_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
	mut svg_fill_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
	mut svg_fill_pattern := ?&painting.SVGPatternPaintStyle(none)
	mut svg_fill_even_odd := false
	mut svg_stroke_color := ''
	mut svg_stroke_linear_gradient := ?painting.SVGLinearGradientPaintStyle(none)
	mut svg_stroke_radial_gradient := ?painting.SVGRadialGradientPaintStyle(none)
	mut svg_stroke_pattern := ?&painting.SVGPatternPaintStyle(none)
	mut svg_stroke_width := 0.0
	mut svg_stroke_dasharray := []f64{}
	mut svg_stroke_dashoffset := 0.0
	mut svg_non_scaling_stroke := false
	mut svg_stroke_first := false
	mut svg_stroke_linecap := 0
	mut svg_stroke_linejoin := 0
	mut svg_stroke_miterlimit := 4.0
	mut svg_fill_opacity := 1.0
	mut svg_stroke_opacity := 1.0
	mut z_index := 0
	mut z_index_auto := true
	positioned := paintable_is_positioned(node, computed)
	floating := node.is_floating()
	inline_or_replaced := node.is_inline() || node.is_replaced_box()
	mut stacking_context := node.establishes_stacking_context()
	mut marker_shape := ''
	mut paint_transform := [6]f64{}
	mut paint_transform_4x4 := css.FloatMatrix4x4.identity()
	mut uses_paint_transform_4x4 := false
	mut clip_path := ?painting.ClipPathVisualData(none)
	mut svg_clip := ?painting.SVGClipVisualData(none)
	mut svg_mask := ?painting.SVGMaskVisualData(none)
	text_color = computed.color()
	mut color_context := paint_color_context_for_box(node, computed, text_color)
	mut paint_element := element
	if paint_element == none && node.is_generated_for_pseudo_element() {
		paint_element = painted_owner_element(node)
	}
	border_box_bounds := painting.Rect{
		x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
		y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
		width: used.border_box_width().to_double()
		height: used.border_box_height().to_double()
	}
	filter := resolved_css_filter_for_element(computed, color_context, paint_element, border_box_bounds)
	backdrop_filter := resolve_css_filter(computed.backdrop_filter(), computed, color_context, paint_element, border_box_bounds)
	if styled_element := paint_element {
		text_color = computed.color()
		color_context.current_color = text_color
		background_color = computed.background_color()
		border_colors = computed_border_colors(computed)
		border_color = border_colors.top
		border_styles = computed_border_styles(computed)
		border_radii = paintable_box_normalized_border_radii_data(paintable_box_border_radii_data(computed, used.border_box_width(), used.border_box_height()), computed, .no)
		border_radius = border_radii.top_left.x
		if outline := paintable_box_outline_data(computed) {
			outline_width = outline.top.width
			outline_style = outline.top.line_style
			outline_color = css.Color{outline.top.color.r, outline.top.color.g, outline.top.color.b, outline.top.color.a}
		}
		outline_is_auto = computed.outline_style() == .auto_
		outline_offset_value := computed.typed_property_value(.outline_offset) or {
			css.StyleValue(css.LengthStyleValue.create(css.Length.make_px(0)))
		}
		outline_offset = computed.resolve_length_percentage_value_px(outline_offset_value, 0) or {
			0.0
		}
		shadows = computed_box_shadows(computed)
		if shadows.len > 0 {
			shadow = shadows[0]
		}
		background_gradient = computed_background_gradient(computed, used.border_box_width().to_double(), used.border_box_height().to_double(), color_context)
		background_images = computed_background_image_layers(node, styled_element, computed, color_context)
		if positioned {
			if computed_z_index := computed.z_index() {
				z_index = computed_z_index
				z_index_auto = false
			}
		}
		// A transform presentation attribute is already part of the SVG
		// user-space CTM. CSS-only transforms still use the ordinary paint
		// transform path; when CSS overrides an attribute, its computed matrix
		// replaces that attribute in the SVG CTM above.
		has_svg_transform_attribute := node.is_svg_graphics_box()
			&& styled_element.has_attribute('transform')
		if !has_svg_transform_attribute && !computed_transform_is_none(computed) {
			reference_box := paintable_box_transform_reference_box(node, computed, used, position, state)
			paint_transform_4x4 = resolved_computed_transform_4x4_matrix(computed, reference_box.x, reference_box.y, reference_box.width, reference_box.height)
			uses_paint_transform_4x4 = true
			paint_transform = css.project_plane_to_affine_transform(paint_transform_4x4) or {
				[f64(0), 0, 0, 0, 0, 0]!
			}
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
		mut svg_fill_rgba := ?css.Color(none)
		mut svg_stroke_rgba := ?css.Color(none)
		has_svg_path = true
		svg_path = path.serialize()
		if path_bounds := svg_path_bounds(path) {
			svg_path_bounding_box = painting.Rect{path_bounds.x, path_bounds.y, path_bounds.width, path_bounds.height}
		}
		ellipse_data := retained_svg_ellipse_data(node, path)
		projection := svg_paint_path_projection(path, if computed.fill_rule() == .evenodd {
			painting.WindingRule.even_odd
		} else { painting.WindingRule.nonzero }, ellipse_data == none)
		svg_path_data = ellipse_data or { projection.packed_segments }
		svg_fill_even_odd = computed.fill_rule() == .evenodd
		to_page := svg_path_transform_to_page(node, state)
		svg_transform = [to_page.a, to_page.b, to_page.c, to_page.d, to_page.e, to_page.f]!
		mapped_bounds := svg_box_visual_bounds_to_page(node, state, used)
		paint_position = CSSPixelPoint.from_values(mapped_bounds.x, mapped_bounds.y)
		paint_width = mapped_bounds.width
		paint_height = mapped_bounds.height
		for point in path.endpoints() {
			mapped := to_page.map_point(point)
			svg_points << mapped.x
			svg_points << mapped.y
		}
		if fill_paint := computed.fill() {
			svg_fill_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, fill_paint, projection.bounds)
			svg_fill_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, fill_paint, projection.bounds)
			svg_fill_pattern = resolve_svg_pattern_paint_style(node, state, fill_paint, projection.bounds, to_page)
		}
		if stroke_paint := computed.stroke() {
			svg_stroke_linear_gradient = resolve_svg_linear_gradient_paint_style(node, state, stroke_paint, projection.bounds)
			svg_stroke_radial_gradient = resolve_svg_radial_gradient_paint_style(node, state, stroke_paint, projection.bounds)
			svg_stroke_pattern = resolve_svg_pattern_paint_style(node, state, stroke_paint, projection.bounds, to_page)
		}
		if svg_fill_linear_gradient == none && svg_fill_radial_gradient == none
			&& svg_fill_pattern == none {
			if fill_color := computed_svg_paint_color(computed, .fill) {
				svg_fill_color = fill_color.serialize()
				svg_fill_rgba = fill_color
			}
		}
		if svg_stroke_linear_gradient == none && svg_stroke_radial_gradient == none
			&& svg_stroke_pattern == none {
			if stroke_color := computed_svg_paint_color(computed, .stroke) {
				svg_stroke_color = stroke_color.serialize()
				svg_stroke_rgba = stroke_color
			}
		}
		svg_solid_color_data = retained_svg_solid_color_data(svg_fill_color, svg_fill_rgba,
			svg_stroke_color, svg_stroke_rgba)
		percentage_basis := viewport_percentage_basis(node, state)
		svg_stroke_width = computed.length_percentage_to_px(.stroke_width, percentage_basis) or { 1.0 }
		svg_stroke_dasharray = resolved_svg_stroke_dasharray(computed, percentage_basis)
		svg_stroke_dashoffset = computed.stroke_dashoffset().to_px(computed.length_resolution_context(), css.CSSPixels.nearest_value_for(percentage_basis)).to_double()
		svg_non_scaling_stroke = computed.vector_effect() == .non_scaling_stroke
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
	if svg_mask == none {
		if target_element := paint_element {
			svg_mask = css_mask_image_for_box(target_element, computed, border_box_bounds, node)
		}
	}
	if image_box := node.as_image_box() {
		if image_element := element {
			if image_element.is_html_element() && image_element.local_name() == 'object' {
				object_element := unsafe { &dom.HTMLObjectElement(image_element) }
				model := html.html_object_element_model_for_dom_element(object_element)
				replaced_image_bitmap = model.image_data()
			}
		}
		if image_box.source() != '' {
			source := image_box.source()
			replaced_image_url = node.document().encoding_parse_and_serialize_url(source) or { source }
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
		// SVGDecodedImageData::paint() does not flatten an SVG image through the
		// platform image decoder. It records the isolated SVG document at the
		// replaced element's concrete size and nests that display list here.
		if svg_document := image_box.svg_image_document() {
			mut mutable_svg_document := unsafe { &dom.Document(svg_document) }
			mutable_svg_document.set_svg_image_color_scheme(css.preferred_color_scheme_to_string(image_color_scheme(node.document(), computed)))
			nested_viewport_document = svg_document
			natural_size := image_box.natural_size()
			default_size := css.CSSPixelSize.new(used.content_width(), used.content_height())
			concrete_size := css.run_default_sizing_algorithm(none, none, natural_size, default_size)
			nested_rect_css := painting.get_replaced_box_painting_rect(painting.Rect{
				x: position.x().to_double()
				y: position.y().to_double()
				width: used.content_width().to_double()
				height: used.content_height().to_double()
			}, painting.Size{concrete_size.width().to_double(), concrete_size.height().to_double()}, computed.object_fit(), computed.object_position(), computed.length_resolution_context())
			mut nested_rect_device := ?painting.IntRect(none)
			mut nested_layout_size := ?painting.Size(none)
			if fitted := nested_rect_css {
				converter := painting.new_device_pixel_converter(1.0) or { panic(err) }
				nested_rect_device = converter.rounded_device_rect(fitted)
				if node.document().font_rendering_policy() == .chromium {
					nested_layout_size = painting.Size{fitted.width, fitted.height}
				}
			}
			nested_viewport_paintable = &painting.NavigableContainerViewportPaintable{
				nested_layout_size: nested_layout_size
				viewport_rect: painting.Rect{
					x: position.x().to_double()
					y: position.y().to_double()
					width: used.content_width().to_double()
					height: used.content_height().to_double()
				}
				nested_rect: if fitted := nested_rect_device {
					painting.Rect{f64(fitted.x), f64(fitted.y), f64(fitted.width), f64(fitted.height)}
				} else {
					none
				}
				border_radii: painting.BorderRadiiData{
					top_left: painting.BorderRadiusData{border_radii.top_left.x, border_radii.top_left.y}
					top_right: painting.BorderRadiusData{border_radii.top_right.x, border_radii.top_right.y}
					bottom_right: painting.BorderRadiusData{border_radii.bottom_right.x, border_radii.bottom_right.y}
					bottom_left: painting.BorderRadiusData{border_radii.bottom_left.x, border_radii.bottom_left.y}
				}
				border_widths: painting.PixelBox{
					top: used.border_top.to_double()
					right: used.border_right.to_double()
					bottom: used.border_bottom.to_double()
					left: used.border_left.to_double()
				}
			}
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
		mapped_bounds := svg_box_visual_bounds_to_page(node, state, used)
		paint_position = CSSPixelPoint.from_values(mapped_bounds.x, mapped_bounds.y)
		paint_width = mapped_bounds.width
		paint_height = mapped_bounds.height
	}
	if replaced_image_url != '' || node.is_image_box() {
		mut replaced_intrinsic_size := ?css.SizeWithAspectRatio(none)
		if image_box := node.as_box() {
			replaced_intrinsic_size = image_box.natural_size()
		}
		replaced_image_paintable = &painting.ImagePaintable{
			image_rect: painting.Rect{
				x: paint_position.x().to_double()
				y: paint_position.y().to_double()
				width: paint_width
				height: paint_height
			}
			border_radii: painting.BorderRadiiData{
				top_left: painting.BorderRadiusData{border_radii.top_left.x, border_radii.top_left.y}
				top_right: painting.BorderRadiusData{border_radii.top_right.x, border_radii.top_right.y}
				bottom_right: painting.BorderRadiusData{border_radii.bottom_right.x, border_radii.bottom_right.y}
				bottom_left: painting.BorderRadiusData{border_radii.bottom_left.x, border_radii.bottom_left.y}
			}
			border_widths: painting.PixelBox{
				top: used.border_top.to_double()
				right: used.border_right.to_double()
				bottom: used.border_bottom.to_double()
				left: used.border_left.to_double()
			}
			object_fit: computed.object_fit()
			object_position: computed.object_position()
			resolution_context: computed.length_resolution_context()
			image_rendering: computed.image_rendering()
			is_svg_image: node.is_svg_image_box()
			intrinsic_size: replaced_intrinsic_size
		}
	}
	if tag_name == 'canvas' {
		if canvas_element := element {
			canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
			if bitmap := html.html_canvas_element_present_existing_surface(canvas) {
				canvas_bitmap = bitmap
				canvas_paintable = &painting.CanvasPaintable{
					canvas_rect: painting.Rect{
						x: position.x().to_double()
						y: position.y().to_double()
						width: used.content_width().to_double()
						height: used.content_height().to_double()
					}
					border_radii: painting.BorderRadiiData{
						top_left: painting.BorderRadiusData{border_radii.top_left.x, border_radii.top_left.y}
						top_right: painting.BorderRadiusData{border_radii.top_right.x, border_radii.top_right.y}
						bottom_right: painting.BorderRadiusData{border_radii.bottom_right.x, border_radii.bottom_right.y}
						bottom_left: painting.BorderRadiusData{border_radii.bottom_left.x, border_radii.bottom_left.y}
					}
					border_widths: painting.PixelBox{
						top: used.border_top.to_double()
						right: used.border_right.to_double()
						bottom: used.border_bottom.to_double()
						left: used.border_left.to_double()
					}
					image_rendering: computed.image_rendering()
				}
			}
		}
	}
	if is_html_video {
		if video_element := element {
			video := unsafe { &dom.HTMLVideoElement(video_element) }
			mut model := html.html_video_element_model_for_dom_element(video)
			model.set_paint_facts_update_hook(push_video_paint_facts)
			video_representation = match model.current_representation() {
				.video_frame { .video_frame }
				.first_video_frame { .first_video_frame }
				.poster_frame { .poster_frame }
				.transparent_black { .transparent_black }
			}
			match video_representation {
				.video_frame, .first_video_frame {
					mut media := model.media
					video_frame_source = media.ensure_video_frame_source()
				}
				.poster_frame {
					video_bitmap = model.poster_frame()
				}
				.transparent_black {}
			}
			video_paintable = &painting.VideoPaintable{
				video_rect: painting.Rect{
					x: position.x().to_double()
					y: position.y().to_double()
					width: used.content_width().to_double()
					height: used.content_height().to_double()
				}
				border_radii: painting.BorderRadiiData{
					top_left: painting.BorderRadiusData{border_radii.top_left.x, border_radii.top_left.y}
					top_right: painting.BorderRadiusData{border_radii.top_right.x, border_radii.top_right.y}
					bottom_right: painting.BorderRadiusData{border_radii.bottom_right.x, border_radii.bottom_right.y}
					bottom_left: painting.BorderRadiusData{border_radii.bottom_left.x, border_radii.bottom_left.y}
				}
				border_widths: painting.PixelBox{
					top: used.border_top.to_double()
					right: used.border_right.to_double()
					bottom: used.border_bottom.to_double()
					left: used.border_left.to_double()
				}
				image_rendering: computed.image_rendering()
				object_fit: computed.object_fit()
				object_position: computed.object_position()
				resolution_context: computed.length_resolution_context()
				natural_media_size: if dimensions := model.natural_media_size() {
					painting.IntSize{int(dimensions.width), int(dimensions.height)}
				} else {
					none
				}
			}
		}
	}
	if node.is_navigable_container_viewport() && used.content_width().to_double() > 0
		&& used.content_height().to_double() > 0 {
		viewport := unsafe { &NavigableContainerViewport(node) }
		viewport.did_set_content_size(used.content_size())
		nested_viewport_document = viewport.content_document()
		nested_viewport_paintable = &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{
				x: position.x().to_double()
				y: position.y().to_double()
				width: used.content_width().to_double()
				height: used.content_height().to_double()
			}
			border_radii: painting.BorderRadiiData{
				top_left: painting.BorderRadiusData{border_radii.top_left.x, border_radii.top_left.y}
				top_right: painting.BorderRadiusData{border_radii.top_right.x, border_radii.top_right.y}
				bottom_right: painting.BorderRadiusData{border_radii.bottom_right.x, border_radii.bottom_right.y}
				bottom_left: painting.BorderRadiusData{border_radii.bottom_left.x, border_radii.bottom_left.y}
			}
			border_widths: painting.PixelBox{
				top: used.border_top.to_double()
				right: used.border_right.to_double()
				bottom: used.border_bottom.to_double()
				left: used.border_left.to_double()
			}
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
				form_control_enabled = !styled_element.is_actually_disabled()
				form_control_activated = styled_element.is_being_activated()
			}
		}
	}
	if node.is_fieldset_box() {
		mut legend_border_rect := ?painting.Rect(none)
		mut legend_margin_box_height := 0.0
		fieldset := unsafe { &FieldSetBox(node) }
		if legend := fieldset.rendered_legend() {
			legend_node := unsafe { &Node(legend) }
			if legend_styled := legend_node.as_node_with_style() {
				if legend_used := state.try_get(legend_styled) {
					legend_position := paint_cumulative_offset(legend_node, state, legend_used)
					legend_border_rect = painting.Rect{
						x: legend_position.x().to_double() - legend_used.padding_left.to_double() - legend_used.border_left.to_double()
						y: legend_position.y().to_double() - legend_used.padding_top.to_double() - legend_used.border_top.to_double()
						width: legend_used.border_box_width().to_double()
						height: legend_used.border_box_height().to_double()
					}
					legend_margin_box_height = legend_used.margin_top.to_double() + legend_used.border_box_height().to_double() + legend_used.margin_bottom.to_double()
				}
			}
		}
		fieldset_paintable = painting.FieldSetPaintable{
			border_rect: painting.Rect{
				x: position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
				y: position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
				width: used.border_box_width().to_double()
				height: used.border_box_height().to_double()
			}
			css_border_top: used.border_top.to_double()
			legend_margin_box_height: legend_margin_box_height
			legend_border_rect: legend_border_rect
		}
	}
	overlay := compatibility_overlay_data(node, computed, used)
	mut overflow_clip := compatibility_overflow_clip(node, computed, used, paint_position, border_radii)
	if node.is_svg_svg_box() {
		if clip := overflow_clip {
			overflow_clip = CompatibilityOverflowClip{
				...clip
				rect: LayoutRect{paint_position.x().to_double(), paint_position.y().to_double(), paint_width, paint_height}
			}
		}
	}
	css_clip := paintable_box_get_clip_rect(node, computed, used, position)
	mut scrollable_overflow := ?LayoutRect(none)
	if overflow := used.scrollable_overflow_rect() {
		scrollable_overflow = LayoutRect{
			x: overflow.x.to_double()
			y: overflow.y.to_double()
			width: overflow.width.to_double()
			height: overflow.height.to_double()
		}
	}

	mut lines := text_lines_from_typed_layout(node, used, state, position)
	if marker := node.as_list_item_marker_box() {
		if marker.chromium_symbol_marker() && marker.list_style_position() == .outside {
			ascent := marker.chromium_symbol_ascent()
			size := f64((ascent * 2 / 3 + 1) / 2)
			baseline := layout_box_first_content_baseline(state, node) or { CSSPixels.new(ascent) }
			marker_shape = marker.list_style_type_.name
			paint_position = CSSPixelPoint.from_values(position.x().to_double() + 1,
				position.y().to_double() + baseline.to_double() - f64(ascent)
					+ f64(3 * (ascent - ascent * 2 / 3) / 2))
			paint_width = size
			paint_height = size
			lines = []TextLine{}
		}
	}
	display := computed.display()
	uses_collapsed_borders := computed.border_collapse() == .collapse
	mut table_cell_borders := used.override_borders_data()
	if display.is_table_cell() && table_cell_borders == none {
		table_cell_borders = retained_table_cell_borders(computed, used, border_colors)
	}
	paint_border := compatibility_paint_border_edges(used)
	return BlockBox{
		tag_name: tag_name
		snaps_background_rect: node.document().font_rendering_policy() == .chromium
		x: paint_position.x().to_double()
		y: paint_position.y().to_double()
		width: paint_width
		height: paint_height
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
		atomic_in_flow: node.is_flex_item() || node.is_grid_item()
		stacking_context: stacking_context
		paintable_with_lines: layout_debug_paintable_class(node) == 'PaintableWithLines'
		table_inside: display.is_table_inside()
		table_cell: display.is_table_cell()
		uses_collapsed_borders: uses_collapsed_borders
		table_cell_coordinates: retained_box_paint_payload(used.table_cell_coordinates())
		table_cell_borders: retained_box_paint_payload(table_cell_borders)
		empty_cells_hide: computed.empty_cells() == .hide
		has_layout_children: node.has_children()
		background_color: background_color
		background_srgb_color: chromium_background_srgb_color(node, computed, background_color)
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
		outline_is_auto: outline_is_auto
		shadow: shadow
		shadows: shadows
		background_gradient: retained_box_paint_payload(background_gradient)
		background_images: background_images
		background_color_clip: background_box_name(computed.background_color_clip())
		replaced_image_url: replaced_image_url
		replaced_image_size: replaced_image_size
		replaced_image_position_x: replaced_image_position_x
		replaced_image_position_y: replaced_image_position_y
		replaced_image_rendering: computed.image_rendering()
		replaced_image_paintable: replaced_image_paintable
		replaced_image_bitmap: replaced_image_bitmap
		canvas_bitmap: canvas_bitmap
		canvas_paintable: canvas_paintable
		video_bitmap: video_bitmap
		video_frame_source: video_frame_source
		video_representation: video_representation
		video_paintable: video_paintable
		nested_viewport_document: nested_viewport_document
		nested_viewport_paintable: nested_viewport_paintable
		is_svg_image: node.is_svg_image_box()
		form_control_kind: form_control_kind
		form_control_checked: form_control_checked
		form_control_indeterminate: form_control_indeterminate
		form_control_enabled: form_control_enabled
		form_control_activated: form_control_activated
		form_control_color_scheme: computed.color_scheme()
		form_control_accent_color: computed.accent_color()
		fieldset_paintable: retained_box_paint_payload(fieldset_paintable)
		opacity: f64(computed.opacity())
		mix_blend_mode: painting.mix_blend_mode_to_compositing_and_blending_operator(painting.blend_mode_from_css(computed.mix_blend_mode()))
		filter: filter
		backdrop_filter: backdrop_filter
		visible: computed.visibility() == .visible
		pointer_events_enabled: paintable_visible_for_hit_testing(node, computed)
		node_id: node_id
		hit_test_continuation_node_id: paintable_box_hit_test_continuation(node)
		layout_handle: voidptr(node)
		children: []
		lines: lines
		has_svg_path: has_svg_path
		svg_path: svg_path
		svg_path_data: svg_path_data
		svg_path_bounding_box: svg_path_bounding_box
		svg_transform: svg_transform
		svg_points: svg_points
		svg_fill_color: svg_fill_color
		svg_solid_color_data: svg_solid_color_data
		svg_gradient_data: retained_svg_gradient_data(svg_fill_linear_gradient,
			svg_stroke_linear_gradient, svg_fill_radial_gradient, svg_stroke_radial_gradient) or {
			unsafe { nil }
		}
		svg_fill_pattern: svg_fill_pattern
		svg_fill_even_odd: svg_fill_even_odd
		svg_stroke_color: svg_stroke_color
		svg_stroke_pattern: svg_stroke_pattern
		svg_stroke_width: svg_stroke_width
		svg_stroke_dasharray: svg_stroke_dasharray
		svg_stroke_dashoffset: svg_stroke_dashoffset
		svg_non_scaling_stroke: svg_non_scaling_stroke
		svg_stroke_first: svg_stroke_first
		svg_stroke_linecap: svg_stroke_linecap
		svg_stroke_linejoin: svg_stroke_linejoin
		svg_stroke_miterlimit: svg_stroke_miterlimit
		svg_fill_opacity: svg_fill_opacity
		svg_stroke_opacity: svg_stroke_opacity
		marker_shape: marker_shape
		overlay: retained_box_paint_payload(overlay)
		has_scrollable_overflow: used.has_scrollable_overflow() && !node.is_viewport()
		scrollable_overflow: scrollable_overflow
		overflow_clip: retained_box_paint_payload(overflow_clip)
		scroll_snap_align: computed.scroll_snap_align()
		scroll_snap_stop: computed.scroll_snap_stop()
		scroll_snap_type: computed.scroll_snap_type()
		scroll_margin: compatibility_scroll_snap_edges(computed, used, false)
		scroll_padding: compatibility_scroll_snap_edges(computed, used, true)
		writing_mode: computed.writing_mode()
		direction: computed.direction()
		css_clip: retained_box_paint_payload(css_clip)
		clip_path: retained_box_paint_payload(clip_path)
		svg_clip: retained_box_paint_payload(svg_clip)
		svg_mask: retained_box_paint_payload(svg_mask)
		sticky_position: node.is_sticky_position()
		own_paint_transform: paint_transform
		own_paint_transform_4x4: paint_transform_4x4
		uses_own_paint_transform_4x4: uses_paint_transform_4x4
		paint_transform: accumulated_paint_transform
	}
}

fn typed_paint_child_nodes(node &Node, state &LayoutState) []&Node {
	mut children := []&Node{}
	mut pending := []&Node{}
	direct_children := node.children()
	for reverse_index in 0 .. direct_children.len {
		child := direct_children[direct_children.len - 1 - reverse_index]
		if child.is_box() || child.is_inline_node() {
			pending << child
		}
	}
	for pending.len > 0 {
		child := pending.pop()
		if child.is_svg_mask_box() || child.is_svg_clip_box() || child.is_svg_pattern_box() {
			continue
		}
		if child.is_box() && is_fully_truncated_inline_fragment(child, state) {
			continue
		}
		mut has_committed_box := child.is_box()
		if has_committed_box {
			if styled := child.as_node_with_style() {
				if used := state.try_get(styled) {
					// A cell wholly covered by collapsed columns is removed from the
					// display together with its subtree. Filtering it here keeps the
					// retained paint and hit-test plans in agreement.
					if used.hidden_by_collapsed_columns() {
						continue
					}
				} else {
					has_committed_box = false
				}
			}
		}
		if has_committed_box {
			children << child
			continue
		}
		grandchildren := child.children()
		for reverse_index in 0 .. grandchildren.len {
			pending << grandchildren[grandchildren.len - 1 - reverse_index]
		}
	}
	return children
}

fn uncached_text_lines_from_typed_layout(container &Node, used &UsedValues, state &LayoutState, container_position css.CSSPixelPoint) []TextLine {
	mut lines := []TextLine{cap: used.line_boxes.len}
	mut paint_parent_pieces := []InlineBoxPiece{}
	mut paint_parent_pieces_ready := false
	for line_index, line_box in used.line_boxes {
		// Reserve only text-bearing fragments. Growing these wide paint records
		// leaves every old buffer in the page's arena; atomic inline boxes and
		// truncated fragments need no transport slot.
		mut fragment_count := 0
		for fragment_index in 0 .. line_box.fragments_.len {
			fragment := unsafe { &line_box.fragments_[fragment_index] }
			if !fragment.is_fully_truncated()
				&& (fragment.block_ellipsis_text_ != none || fragment.layout_node_.is_text_node()) {
				fragment_count++
			}
		}
		mut fragments := []TextFragment{cap: fragment_count}
		mut first_fragment_continues_previous_line := false
		if line_index > 0 && used.line_boxes[line_index - 1].fragments_.len > 0
			&& line_box.fragments_.len > 0 {
			previous := used.line_boxes[line_index - 1].fragments_.last()
			first_fragment_continues_previous_line = voidptr(previous.layout_node_) == voidptr(line_box.fragments_.first().layout_node_)
		}
		mut last_fragment_continues_next_line := false
		if line_index + 1 < used.line_boxes.len && line_box.fragments_.len > 0
			&& used.line_boxes[line_index + 1].fragments_.len > 0 {
			next := used.line_boxes[line_index + 1].fragments_.first()
			last_fragment_continues_next_line = voidptr(line_box.fragments_.last().layout_node_) == voidptr(next.layout_node_)
		}
		for fragment_index in 0 .. line_box.fragments_.len {
			fragment := unsafe { &line_box.fragments_[fragment_index] }
			if fragment.is_fully_truncated() {
				continue
			}
			text := fragment.text() or { continue }
			computed := fragment.style_source().computed_values()
			font_metrics := fragment.style_source().first_available_font().pixel_metrics()
			mut color := css.Color{0, 0, 0, 255}
			mut background := css.Color{0, 0, 0, 0}
			mut background_images := []BackgroundImageLayer{}
			mut border_color := color
			mut border_colors := BoxColors{color, color, color, color}
			mut border_styles := solid_box_border_styles()
			mut decoration_color := color
			mut decoration_style := 'solid'
			mut decoration_thickness := 0.0
			mut decoration_thickness_set := false
			mut text_underline_offset := 0.0
			mut text_underline_position := 'auto'
			mut border := BoxEdges{}
			mut padding := BoxEdges{}
			mut radius := 0.0
			mut radii := BoxRadii{}
			mut outline_width := 0.0
			mut outline_offset := 0.0
			mut outline_color := css.Color{}
			mut outline_style := painting.LineStyle.none
			mut outline_is_auto := false
			mut inline_shadow := ?BoxShadow(none)
			mut inline_shadows := []BoxShadow{}
			mut inline_node_id := i64(0)
			mut color_context := color_resolution_context_for_typed_node(fragment.layout_node_, color)
			// PaintableWithLines::compute_render_spans() uses the resolved
			// -webkit-text-fill-color, not color, for ordinary glyph spans.
			color = computed.webkit_text_fill_color()
			color_context.current_color = color
			decoration_color = computed.text_decoration_color()
			decoration_style = computed_text_decoration_style(computed)
			decoration_thickness = computed_text_decoration_thickness(computed, computed.font_size().to_double())
			decoration_thickness_value := computed.text_decoration_thickness()
			decoration_thickness_set = !decoration_thickness_value.is_auto
				&& !decoration_thickness_value.from_font
			text_underline_offset = computed.text_underline_offset().to_double()
			text_underline_position = match computed.text_underline_position().horizontal {
				.under { 'under' }
				.from_font { 'from-font' }
				else { 'auto' }
			}
			// LayoutState::commit() relocates a line-box fragment to the first
			// non-atomic InlineNode ancestor. Only that inline paintable owns box
			// decorations; text left in the block paintable must not repaint the
			// block's background, borders, radii, or box shadow.
			if !fragment.is_block_ellipsis() {
				if inline_owner := inline_paint_owner(fragment.layout_node_) {
					owner_computed := inline_owner.computed_values()
					background = computed_paint_color(owner_computed, .background_color, color_context, background)
					if owner := painted_owner_element(inline_owner) {
						mut owner_color_context := color_resolution_context_for_typed_node(inline_owner, owner_computed.color())
						owner_color_context.current_color = owner_computed.color()
						background_images = computed_background_image_layers(inline_owner, owner, owner_computed, owner_color_context)
						inline_node_id = i64(owner.as_node().unique_id())
					}
					border_colors = computed_border_colors(owner_computed)
					border_color = border_colors.top
					border_styles = computed_border_styles(owner_computed)
					radii = paintable_box_border_radii_data(owner_computed, fragment.width(), fragment.height())
					radius = radii.top_left.x
					if outline := paintable_box_outline_data(owner_computed) {
						outline_width = outline.top.width
						outline_style = outline.top.line_style
						outline_color = css.Color{outline.top.color.r, outline.top.color.g, outline.top.color.b, outline.top.color.a}
					}
					outline_is_auto = owner_computed.outline_style() == .auto_
					outline_offset_value := owner_computed.typed_property_value(.outline_offset) or {
						css.StyleValue(css.LengthStyleValue.create(css.Length.make_px(0)))
					}
					outline_offset = owner_computed.resolve_length_percentage_value_px(outline_offset_value, 0) or { 0.0 }
					inline_shadows = computed_box_shadows(owner_computed)
					if inline_shadows.len > 0 {
						inline_shadow = inline_shadows[0]
					}
					if inline_styled := inline_owner.as_node_with_style() {
						if inline_used := state.try_get(inline_styled) {
							border = BoxEdges{inline_used.border_top.to_double(), inline_used.border_right.to_double(), inline_used.border_bottom.to_double(), inline_used.border_left.to_double()}
							padding = BoxEdges{inline_used.padding_top.to_double(), inline_used.padding_right.to_double(), inline_used.padding_bottom.to_double(), inline_used.padding_left.to_double()}
						}
					}
				}
			}
			offset := css_pixel_point_add(fragment.offset(), inline_relative_offset(fragment.layout_node_, state))
			absolute_x := container_position.x().plus(offset.x()).to_double()
			absolute_y := container_position.y().plus(offset.y()).to_double()
			mut paint_line_top := container_position.y().to_double() + line_box.bottom().to_double() - line_box.height().to_double()
			if container.document().font_rendering_policy() == .chromium {
				mut parent := fragment.layout_node_.parent()
				for parent != none {
					inline_parent := parent or { break }
					if !inline_parent.is_inline_node() || inline_parent.is_atomic_inline() { break }
					parent_style := inline_parent.as_node_with_style() or { break }
					if parent_used := state.try_get(parent_style) {
						if chromium_inline_needs_paint_box(inline_parent, parent_used) {
							if !paint_parent_pieces_ready {
								paint_parent_pieces = compute_inline_box_pieces(container, used, state)
								paint_parent_pieces_ready = true
								}
							for piece in paint_parent_pieces {
								if piece.line_index == line_index && layout_nodes_same(piece.node, inline_parent) {
									paint_line_top = container_position.y().plus(piece.border_box_rect.y)
										.plus(inline_relative_offset(fragment.layout_node_, state).y()).to_double()
									break
								}
							}
							break
						}
					}
					parent = inline_parent.parent()
				}
			}
			orientation := if fragment.writing_mode() == .horizontal_tb {
				painting.Orientation.horizontal
			} else {
				painting.Orientation.vertical
			}
			fragment_text_for_rendering := if text_node := fragment.layout_node_.as_text_node() {
				text_node.text_for_rendering()
			} else {
				text
			}
			// Preserve the committed run instead of splitting it into words and
			// making paint_commands() concatenate it again.
			// Transfer the freshly projected payload directly. Appending a named
			// record deep-clones its strings and arrays in current V.
			fragments << TextFragment{
				x: absolute_x
				y: absolute_y
				paint_line_top: paint_line_top
				width: fragment.width().to_double()
				height: fragment.height().to_double()
				text: text
				color: color
				font_size: computed.font_size().to_double()
				bold: computed.font_weight() >= 600
				italic: computed.font_slope() != 0
				mono: computed_font_is_monospace(computed)
				font_smoothing: computed.font_smoothing()
				text_run_id: text_run_identity(fragment.layout_node_)
				shape_as_run: resolved_text_spacing_for_node(fragment.layout_node_, .letter_spacing).raw_value() == 0 && resolved_text_spacing_for_node(fragment.layout_node_, .word_spacing).raw_value() == 0
				inline_node_id: inline_node_id
				fragment_left_edge_away: fragment_index == 0 && first_fragment_continues_previous_line
				fragment_right_edge_away: fragment_index == line_box.fragments_.len - 1
					&& last_fragment_continues_next_line
				background_color: background
				background_images: background_images
				border: border
				padding: padding
				border_color: border_color
				border_colors: border_colors
				border_styles: border_styles
				border_radius: radius
				border_radii: radii
				outline_width: outline_width
				outline_offset: outline_offset
				outline_color: outline_color
				outline_style: outline_style
				outline_is_auto: outline_is_auto
				shadow: inline_shadow
				shadows: inline_shadows
				decoration: text_decoration_string(computed.text_decoration_line())
				decoration_color: decoration_color
				decoration_color_set: true
				decoration_skip_ink: computed.text_decoration_skip_ink() != .none_
				decoration_style: decoration_style
				decoration_thickness: decoration_thickness
				baseline: fragment.baseline().to_double()
				baseline_set: true
				font_metrics_set: true
				font_ascent: f64(font_metrics.ascent)
				font_descent: f64(font_metrics.descent)
				font_x_height: f64(font_metrics.x_height)
				glyph_height: f64(font_metrics.size)
				decoration_thickness_set: decoration_thickness_set
				text_underline_offset: text_underline_offset
				text_underline_position: text_underline_position
				chromium_decorations: fragment.layout_node_.document().font_rendering_policy() == .chromium
				text_underline_offset_auto: property_is_auto(computed, .text_underline_offset)
				layout_handle: voidptr(fragment.layout_node_)
				paintable_fragment: painting.PaintableFragment{
					text_value: fragment_text_for_rendering
					offset: painting.Point{absolute_x, absolute_y}
					size: painting.Size{fragment.width().to_double(), fragment.height().to_double()}
					start_offset: fragment.source_start()
					uses_text_mapping:       fragment.layout_node_.is_text_node()
					rendered_start_offset:   fragment.start()
					source_range_start:      if mapped_text := fragment.layout_node_.as_text_node() {
						mapped_text.source_range_start_
					} else {
						0
					}
					source_range_length:     if mapped_text := fragment.layout_node_.as_text_node() {
						mapped_text.rendered_source_length_
					} else {
						fragment.length_in_code_units()
					}
					text_mapping_edits:      if mapped_text := fragment.layout_node_.as_text_node() {
						mapped_text.rendered_text_edits_.clone()
					} else {
						[]platform.TextMappingEdit{}
					}
					length_in_code_units: fragment.length_in_code_units()
					glyph_run: fragment.glyph_run()
					baseline: fragment.baseline().to_double()
					font_ascent: f64(font_metrics.ascent)
					font_descent: f64(font_metrics.descent)
					orientation: orientation
					has_trailing_whitespace: fragment.has_trailing_whitespace()
				}
				text_shadows: computed_text_shadows(computed)
				selection_style: selection_style(fragment.layout_node_)
			}
		}
		mut box_decorations := []TextFragment{}
		if container.document().font_rendering_policy() == .chromium {
			mut nested_owners := map[u64]bool{}
			for fragment_index in 0 .. line_box.fragments_.len {
				fragment := unsafe { &line_box.fragments_[fragment_index] }
				for ancestor in nested_decorated_inline_ancestors(fragment.layout_node_, state) {
					nested_owners[u64(voidptr(ancestor))] = true
				}
			}
			if nested_owners.len > 0 {
				if !paint_parent_pieces_ready {
					paint_parent_pieces = compute_inline_box_pieces(container, used, state)
					paint_parent_pieces_ready = true
				}
				mut owner_ids := map[i64]bool{}
				for piece in paint_parent_pieces {
					if piece.line_index != line_index || piece.is_geometry_only_placeholder
						|| u64(voidptr(piece.node)) !in nested_owners {
						continue
					}
					if decoration := inline_piece_decoration_fragment(piece, container_position, state) {
						if box_decorations.cap == 0 {
							box_decorations = []TextFragment{cap: 1}
						}
						box_decorations << decoration
						owner_ids[decoration.inline_node_id] = true
					}
				}
				for index in 0 .. fragments.len {
					if fragments[index].inline_node_id in owner_ids {
						fragments[index] = TextFragment{
							...fragments[index]
							decorations_from_piece: true
						}
					}
				}
			}
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
			box_decorations: box_decorations
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

fn selection_style_has_styling(style TextSelectionStyle) bool {
	return style.background_color.a > 0 || style.text_color_set || style.text_shadows_set
		|| style.decoration_set
}

// Direct translation of Paintable::selection_style()'s per-element lookup.
// Inherited ::selection values remain represented in ComputedProperties, but
// text color/shadow/decoration only override a span when the property was
// explicitly specified on that pseudo-element upstream.
fn selection_style_from_element(element &dom.Element) ?TextSelectionStyle {
	element_layout := element.as_node().unsafe_layout_node() or { return none }
	computed := css.computed_properties_for_pseudo_element(element, .selection) or {
		return none
	}
	context := css.color_resolution_context_for_layout_node(element_layout)
	mut style := TextSelectionStyle{
		background_color: computed_paint_color(computed, .background_color, context, css.Color{})
	}
	if !computed.is_property_inherited(.color) {
		style = TextSelectionStyle{
			...style
			text_color: computed_paint_color(computed, .color, context, css.Color{})
			text_color_set: true
		}
	}
	if !computed.is_property_inherited(.text_shadow) {
		style = TextSelectionStyle{
			...style
			text_shadows: computed_shadow_transport(computed.text_shadow(element_layout), computed.length_resolution_context())
			text_shadows_set: true
		}
	}
	if !computed.is_property_inherited(.text_decoration_line) {
		fallback := if style.text_color_set { style.text_color } else { css.Color{0, 0, 0, 255} }
		style = TextSelectionStyle{
			...style
			decoration: text_decoration_string(computed.text_decoration_line())
			decoration_color: computed_paint_color(computed, .text_decoration_color, context, fallback)
			decoration_style: computed_text_decoration_style(computed)
			decoration_set: true
		}
	}
	if !selection_style_has_styling(style) {
		return none
	}
	return style
}

// https://drafts.csswg.org/css-pseudo-4/#highlight-styling
// Direct translation of Paintable::selection_style(), including the UA shadow
// host fallback used by input controls.
fn selection_style(node &Node) TextSelectionStyle {
	default_style := TextSelectionStyle{
		background_color: css.SystemColor.highlight(node.computed_values().color_scheme())
	}
	dom_node := node.dom_node() or { return default_style }
	mut element := dom_node.as_element() or {
		dom_node.parent_element() or { return default_style }
	}
	if style := selection_style_from_element(element) {
		return style
	}
	if shadow_root := element.as_node().containing_shadow_root() {
		if shadow_root.is_user_agent_internal() {
			if host := shadow_root.host() {
				if style := selection_style_from_element(host) {
					return style
				}
			}
		}
	}
	return default_style
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

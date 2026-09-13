// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import html
import math
import platform
import svg

struct SVGFormattingContext {
	context_box              &Node = unsafe { nil }
	parent_viewbox_transform svg.AffineTransform
	available_space          AvailableSpace
mut:
	state                     &LayoutState = unsafe { nil }
	current_viewbox_transform svg.AffineTransform
	viewport_size             CSSPixelSize
	current_text_position     svg.Point
}

struct SVGViewBoxTransform {
	offset         CSSPixelPoint
	scale_factor_x f64
	scale_factor_y f64
}

// https://svgwg.org/svg2-draft/coords.html#PreserveAspectRatioAttribute
fn scale_and_align_viewbox_content(preserve_aspect_ratio svg.PreserveAspectRatio, view_box svg.ViewBox, scale_width f64, scale_height f64, box_state &UsedValues) SVGViewBoxTransform {
	if preserve_aspect_ratio.align == .none_ {
		return SVGViewBoxTransform{
			scale_factor_x: f64(f32(scale_width))
			scale_factor_y: f64(f32(scale_height))
		}
	}
	uniform_scale := f64(if preserve_aspect_ratio.meet_or_slice == .meet {
		math.min(f32(scale_width), f32(scale_height))
	} else {
		math.max(f32(scale_width), f32(scale_height))
	})
	scaled_width := CSSPixels.nearest_value_for(f64(f32(view_box.width)) * uniform_scale)
	scaled_height := CSSPixels.nearest_value_for(f64(f32(view_box.height)) * uniform_scale)
	remaining_x := box_state.content_width().minus(scaled_width)
	remaining_y := box_state.content_height().minus(scaled_height)
	mut offset_x := CSSPixels{}
	mut offset_y := CSSPixels{}
	if box_state.has_definite_width() {
		offset_x = match preserve_aspect_ratio.align {
			.x_mid_y_min, .x_mid_y_mid, .x_mid_y_max {
				CSSPixels.from_raw(remaining_x.raw_value() / 2)
			}
			.x_max_y_min, .x_max_y_mid, .x_max_y_max {
				remaining_x
			}
			else {
				CSSPixels{}
			}
		}
	}
	// Match the upstream width check, including its current height-branch typo.
	if box_state.has_definite_width() {
		offset_y = match preserve_aspect_ratio.align {
			.x_min_y_mid, .x_mid_y_mid, .x_max_y_mid {
				CSSPixels.from_raw(remaining_y.raw_value() / 2)
			}
			.x_min_y_max, .x_mid_y_max, .x_max_y_max {
				remaining_y
			}
			else {
				CSSPixels{}
			}
		}
	}
	return SVGViewBoxTransform{
		offset: CSSPixelPoint.new(offset_x, offset_y)
		scale_factor_x: uniform_scale
		scale_factor_y: uniform_scale
	}
}

fn run_svg_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, available_space AvailableSpace, parent_viewbox_transform svg.AffineTransform) FormattingContextResult {
	mut context := SVGFormattingContext{
		state: state
		context_box: context_box
		parent_viewbox_transform: parent_viewbox_transform
		available_space: available_space
	}
	context.run(mut root_state)
	// SVGFormattingContext::automatic_content_width/height() both return zero.
	return FormattingContextResult{}
}

fn run_root_svg_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	return run_svg_formatting_context(mut state, context_box, mut root_state, available_space, svg.AffineTransform{})
}

fn (mut context SVGFormattingContext) run(mut svg_box_state UsedValues) {
	// SVG roots are considered definite in both axes; the viewBox transform
	// depends on this invariant in upstream Layout as well.
	svg_box_state.set_has_definite_width(true)
	svg_box_state.set_has_definite_height(true)

	element := svg_element_for_layout_node(context.context_box) or { return }
	mut active_view_box := svg.parse_viewbox(element.get_attribute_value('viewBox'))
	if active_view_box == none
		&& (context.context_box.is_svg_mask_box() || context.context_box.is_svg_clip_box()) {
		units_attribute := if context.context_box.is_svg_mask_box() {
			'maskContentUnits'
		} else {
			'clipPathUnits'
		}
		if svg.parse_units(element.get_attribute_value(units_attribute)) or {
			svg.Units.user_space_on_use
		} == .object_bounding_box {
			active_view_box = svg.ViewBox{
				width: 1
				height: 1
			}
		}
	}
	// SVGSVGElement::update_fallback_view_box_for_svg_as_image(): when an SVG
	// image has no authored viewBox but does have absolute intrinsic dimensions,
	// those dimensions establish its user coordinate system. The destination
	// ImageBox viewport can then scale that coordinate system normally.
	if active_view_box == none && context.context_box.is_svg_svg_box()
		&& context.context_box.document().is_svg_image_document() {
		if root_box := context.context_box.as_box() {
			natural_size := root_box.natural_size()
			if natural_width := natural_size.width {
				if natural_height := natural_size.height {
					active_view_box = svg.ViewBox{
						width: natural_width.to_double()
						height: natural_height.to_double()
					}
				}
			}
		}
	}
	if view_box := active_view_box {
		if view_box.width < 0 || view_box.height < 0 {
			active_view_box = none
		} else if view_box.width == 0 || view_box.height == 0 {
			if context.context_box.is_svg_svg_box()
				|| element.local_name() in ['symbol', 'pattern'] {
				svg_box_state.set_svg_viewport_transform(svg.AffineTransform{})
			}
			disable_svg_rendering_for_descendants(mut context.state, context.context_box)
			return
		}
	}

	// SVGFormattingContext::run() starts with the inherited viewBox transform.
	// The SVG viewport's own offset remains in its paintable and is accumulated
	// through the containing-block chain; folding it into this transform would
	// apply the viewport position twice to descendants.
	context.current_viewbox_transform = context.parent_viewbox_transform
	mut viewport_transform := svg.AffineTransform{}
	if view_box := active_view_box {
		scale_width := if svg_box_state.has_definite_width() {
			f64(f32(svg_box_state.content_width().to_double()) / f32(view_box.width))
		} else {
			1.0
		}
		scale_height := if svg_box_state.has_definite_height() {
			f64(f32(svg_box_state.content_height().to_double()) / f32(view_box.height))
		} else {
			1.0
		}
		preserve_aspect_ratio := if context.context_box.is_svg_mask_box()
			|| context.context_box.is_svg_clip_box() {
			svg.PreserveAspectRatio{
				align: .none_
			}
		} else {
			svg.parse_preserve_aspect_ratio(element.get_attribute_value('preserveAspectRatio')) or {
				svg.PreserveAspectRatio{}
			}
		}
		viewbox_transform := scale_and_align_viewbox_content(preserve_aspect_ratio, view_box, scale_width, scale_height, svg_box_state)
		viewport_transform = viewport_transform.translated(viewbox_transform.offset.x().to_double(), viewbox_transform.offset.y().to_double()).scaled(viewbox_transform.scale_factor_x, viewbox_transform.scale_factor_y).translated(-view_box.min_x, -view_box.min_y)
		context.current_viewbox_transform = context.current_viewbox_transform.translated(viewbox_transform.offset.x().to_double(), viewbox_transform.offset.y().to_double()).scaled(viewbox_transform.scale_factor_x, viewbox_transform.scale_factor_y).translated(-view_box.min_x, -view_box.min_y)
	}
	if context.context_box.is_svg_svg_box() || element.local_name() in ['symbol', 'pattern'] {
		svg_box_state.set_svg_viewport_transform(viewport_transform)
	}

	viewport_width := if view_box := active_view_box {
		CSSPixels.nearest_value_for(view_box.width)
	} else {
		svg_box_state.content_width()
	}
	viewport_height := if view_box := active_view_box {
		CSSPixels.nearest_value_for(view_box.height)
	} else {
		svg_box_state.content_height()
	}
	context.viewport_size = CSSPixelSize.new(viewport_width, viewport_height)

	for child in context.context_box.children() {
		if child.is_box() {
			context.layout_svg_element(child)
		} else if child.is_inline_node() {
			// SVG animation elements use the ordinary InlineNode layout class.
			// SVGFormattingContext does not lay out their text, but LayoutState
			// still retains their empty inline paintable and box-model entry.
			if styled := child.as_node_with_style() {
				context.state.get_mutable(styled)
			}
		}
	}
}

fn disable_svg_rendering_for_descendants(mut state LayoutState, root &Node) {
	for child in root.children() {
		if styled := child.as_node_with_style() {
			mut child_state := state.get_mutable(styled)
			child_state.set_svg_rendering_disabled(true)
		}
		disable_svg_rendering_for_descendants(mut state, child)
	}
}

fn (mut context SVGFormattingContext) layout_svg_element(child &Node) {
	is_symbol := if element := svg_element_for_layout_node(child) {
		element.local_name() == 'symbol'
	} else {
		false
	}
	if child.is_svg_svg_box() || is_symbol {
		context.layout_nested_viewport(child)
	} else if child.is_svg_foreign_object_box() {
		context.layout_foreign_object(child)
	} else if child.is_svg_graphics_box() {
		context.layout_graphics_element(child)
	}
}

fn (mut context SVGFormattingContext) layout_nested_viewport(viewport &Node) {
	styled := viewport.as_node_with_style() or { return }
	mut viewport_state := context.state.get_mutable(styled)
	_ = svg_element_for_layout_node(viewport) or { return }
	computed := viewport.computed_values()
	x := resolve_computed_svg_length(computed, .x, context.viewport_size.width(), CSSPixels.new(0))
	y := resolve_computed_svg_length(computed, .y, context.viewport_size.height(), CSSPixels.new(0))
	width := resolve_computed_svg_viewport_dimension(computed, .width, context.viewport_size.width())
	height := resolve_computed_svg_viewport_dimension(computed, .height, context.viewport_size.height())

	content_rect := svg.Rect{
		x: x.to_double()
		y: y.to_double()
		width: width.to_double()
		height: height.to_double()
	}
	set_used_values_rect(mut viewport_state, content_rect)
	viewport_state.set_has_definite_width(true)
	viewport_state.set_has_definite_height(true)
	// A nested viewport is placed in its parent's user space. Its own viewBox
	// transform follows that placement; neither operation changes committed
	// layout geometry.
	parent_viewbox_transform := context.current_viewbox_transform.translated(x.to_double(), y.to_double())
	run_svg_formatting_context(mut context.state, viewport, mut viewport_state, context.available_space, parent_viewbox_transform)
}

fn (mut context SVGFormattingContext) layout_foreign_object(child &Node) {
	styled := child.as_node_with_style() or { return }
	mut child_state := context.state.get_mutable(styled)
	_ = svg_element_for_layout_node(child) or { return }
	computed := child.computed_values()
	rect := svg.Rect{
		x: resolve_computed_svg_length(computed, .x, context.viewport_size.width(), CSSPixels.new(0)).to_double()
		y: resolve_computed_svg_length(computed, .y, context.viewport_size.height(), CSSPixels.new(0)).to_double()
		width: resolve_computed_svg_length(computed, .width, context.viewport_size.width(), CSSPixels.new(0)).to_double()
		height: resolve_computed_svg_length(computed, .height, context.viewport_size.height(), CSSPixels.new(0)).to_double()
	}
	set_used_values_rect(mut child_state, rect)
	child_state.set_has_definite_width(true)
	child_state.set_has_definite_height(true)
	layout_inside_independent_formatting_context(mut context.state, child, mut child_state, AvailableSpace.new(AvailableSize.make_definite(child_state.content_width()), AvailableSize.make_definite(child_state.content_height())))
	for resource in child.children() {
		if resource.is_svg_mask_box() || resource.is_svg_clip_box() {
			context.layout_mask_or_clip(resource)
		}
	}
}

fn (mut context SVGFormattingContext) layout_graphics_element(graphics_box &Node) {
	styled := graphics_box.as_node_with_style() or { return }
	mut graphics_state := context.state.get_mutable(styled)
	element := svg_element_for_layout_node(graphics_box) or { return }
	parent_svg_transform := context.parent_svg_transform(graphics_box)
	svg_transform :=
		parent_svg_transform.multiply(svg.element_transform(svg_element_model(element)))
	graphics_state.set_computed_svg_transforms(context.current_viewbox_transform, svg_transform)

	if is_svg_container_element(element) {
		context.layout_container_element(graphics_box)
	} else if graphics_box.is_svg_image_box() {
		context.layout_image_element(graphics_box)
	} else {
		context.layout_path_like_element(graphics_box)
	}
	// Resource boxes attached by the resource-resolution phase are laid out as
	// nested SVG viewports without contributing to the graphics bounds.
	for child in graphics_box.children() {
		if child.is_svg_mask_box() || child.is_svg_clip_box() || child.is_svg_pattern_box() {
			context.layout_mask_or_clip(child)
		}
	}
}

fn (context &SVGFormattingContext) parent_svg_transform(box &Node) svg.AffineTransform {
	mut ancestor := box.parent()
	for {
		candidate := ancestor or { return svg.AffineTransform{} }
		if candidate.is_svg_mask_box() || candidate.is_svg_clip_box()
			|| candidate.is_svg_pattern_box() {
			return svg.AffineTransform{}
		}
		if candidate.is_svg_graphics_box() {
			styled := candidate.as_node_with_style() or { return svg.AffineTransform{} }
			if state := context.state.try_get(styled) {
				if state.has_computed_svg_transforms() {
					return state.svg_transform()
				}
			}
		}
		ancestor = candidate.parent()
	}
	return svg.AffineTransform{}
}

fn (mut context SVGFormattingContext) layout_path_like_element(graphics_box &Node) {
	styled := graphics_box.as_node_with_style() or { return }
	mut graphics_state := context.state.get_mutable(styled)
	element := svg_element_for_layout_node(graphics_box) or { return }
	if graphics_box.is_svg_geometry_box() {
		path := svg.geometry_path(svg_geometry_element_model(graphics_box, element, context.viewport_size), context.viewport_size.width().to_double(), context.viewport_size.height().to_double())
		bounds := svg_path_bounds(path) or { svg.Rect{} }
		stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
		set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(bounds), stroke_width))
		graphics_state.set_computed_svg_path(path)
	} else if graphics_box.is_svg_text_box() {
		text_bounds := context.layout_text_element(graphics_box, element, mut graphics_state)
		// <text> and <tspan> elements can contain more text elements.
		for child in graphics_box.children() {
			if child.is_svg_text_box() || child.is_svg_text_path_box() {
				context.layout_graphics_element(child)
			}
		}
		// C++ advances the current text position from this element's own path only after
		// its children have been laid out. A <text> whose characters all live in nested
		// <tspan>s has an empty path, so advancing before the recursion would discard the
		// x/y it just established and start every child from the origin instead.
		context.current_text_position = svg.Point{
			x: text_bounds.x + text_bounds.width
			y: text_bounds.y + text_bounds.height
		}
	} else if graphics_box.is_svg_text_path_box() {
		context.layout_text_path_element(graphics_box, element, mut graphics_state)
	} else {
		set_used_values_rect(mut graphics_state, svg.Rect{})
	}
	graphics_state.set_has_definite_width(true)
	graphics_state.set_has_definite_height(true)
}

fn (mut context SVGFormattingContext) layout_text_element(graphics_box &Node, element &dom.Element, mut graphics_state UsedValues) svg.Rect {
	if x := first_svg_text_position(element.get_attribute_value('x'), context.viewport_size.width()) {
		context.current_text_position = svg.Point{
			x: x
			y: context.current_text_position.y
		}
	}
	if y := first_svg_text_position(element.get_attribute_value('y'), context.viewport_size.height()) {
		context.current_text_position = svg.Point{
			x: context.current_text_position.x
			y: y
		}
	}
	if dx := first_svg_text_position(element.get_attribute_value('dx'), context.viewport_size.width()) {
		context.current_text_position = svg.Point{
			x: context.current_text_position.x + dx
			y: context.current_text_position.y
		}
	}
	if dy := first_svg_text_position(element.get_attribute_value('dy'), context.viewport_size.height()) {
		context.current_text_position = svg.Point{
			x: context.current_text_position.x
			y: context.current_text_position.y + dy
		}
	}
	text := svg_direct_text_contents(element)
	computed := graphics_box.computed_values()
	font := &platform.Font{
		family: 'sans-serif'
		point_size: f32(computed.resolved_font_size_px())
		weight: int(computed.font_weight())
	}
	run := platform.shape_text(0, 0, text, font, .context_dependent)
	text_width := f64(run.width())
	mut x := context.current_text_position.x
	anchor := match computed.text_anchor() {
		.start { svg.TextAnchor.start }
		.middle { svg.TextAnchor.middle }
		.end_ { svg.TextAnchor.end }
	}
	match anchor {
		.middle {
			x -= text_width / 2
		}
		.end {
			x -= text_width
		}
		else {}
	}
	baseline_metric := resolve_dominant_baseline_metric(computed)
	baseline_y := context.current_text_position.y + f64(dominant_baseline_offset(baseline_metric, font.pixel_metrics()))
	path := svg_text_outline_path(text, font, x, baseline_y)
	final_local_bounds := svg_path_bounds(path) or { svg.Rect{} }
	stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
	set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(final_local_bounds), stroke_width))
	graphics_state.set_computed_svg_path(path)
	return final_local_bounds
}

fn svg_outline_point(point platform.FontGlyphOutlinePoint, transform svg.AffineTransform) svg.Point {
	// SkFont glyph paths use CSS/Skia's positive-down coordinates while the
	// TrueType source contours are positive-up.
	return transform.map_point(svg.Point{
		x: f64(point.x)
		y: -f64(point.y)
	})
}

fn svg_midpoint(a svg.Point, b svg.Point) svg.Point {
	return svg.Point{
		x: (a.x + b.x) / 2
		y: (a.y + b.y) / 2
	}
}

// Gfx::Path::text()/SkFont::getPath() materializes TrueType's quadratic
// contours. Consecutive off-curve points have an implied on-curve midpoint;
// an off-curve first point starts at the last on-curve point or the implied
// midpoint between the last and first points.
fn append_svg_glyph_contour(mut instructions []svg.PathInstruction, contour []platform.FontGlyphOutlinePoint, transform svg.AffineTransform) {
	if contour.len == 0 {
		return
	}
	first := contour[0]
	last := contour[contour.len - 1]
	mut start := svg.Point{}
	mut first_index := 0
	mut point_count := contour.len
	if first.on_curve {
		start = svg_outline_point(first, transform)
		first_index = 1
		point_count--
	} else if last.on_curve {
		start = svg_outline_point(last, transform)
		point_count--
	} else {
		start = svg_midpoint(svg_outline_point(last, transform), svg_outline_point(first, transform))
	}
	instructions << svg.PathInstruction{
		type_: .move
		absolute: true
		data: [start.x, start.y]
	}
	mut control := ?svg.Point(none)
	for offset in 0 .. point_count {
		point := contour[(first_index + offset) % contour.len]
		mapped := svg_outline_point(point, transform)
		if point.on_curve {
			if previous_control := control {
				instructions << svg.PathInstruction{
					type_: .quadratic_bezier_curve
					absolute: true
					data: [previous_control.x, previous_control.y, mapped.x, mapped.y]
				}
			} else {
				instructions << svg.PathInstruction{
					type_: .line
					absolute: true
					data: [mapped.x, mapped.y]
				}
			}
			control = none
		} else if previous_control := control {
			implied := svg_midpoint(previous_control, mapped)
			instructions << svg.PathInstruction{
				type_: .quadratic_bezier_curve
				absolute: true
				data: [previous_control.x, previous_control.y, implied.x, implied.y]
			}
			control = mapped
		} else {
			control = mapped
		}
	}
	if final_control := control {
		instructions << svg.PathInstruction{
			type_: .quadratic_bezier_curve
			absolute: true
			data: [final_control.x, final_control.y, start.x, start.y]
		}
	}
	instructions << svg.PathInstruction{
		type_: .close_path
		absolute: true
	}
}

fn svg_text_outline_path(text string, font &platform.Font, x f64, baseline_y f64) svg.Path {
	mut instructions := []svg.PathInstruction{}
	mut glyph_x := x
	for character in text.runes() {
		advance, glyph_index := font.glyph_advance_and_index(u32(character))
		if outline := font.glyph_outline(glyph_index) {
			transform := svg.AffineTransform{
				e: glyph_x
				f: baseline_y
			}
			for contour in outline.contours {
				append_svg_glyph_contour(mut instructions, contour, transform)
			}
		}
		glyph_x += f64(advance)
	}
	return svg.Path{
		instructions: instructions
	}
}

fn first_svg_text_position(text string, reference CSSPixels) ?f64 {
	first := text.replace(',', ' ').fields()
	if first.len == 0 {
		return none
	}
	value := svg.parse_number_percentage(first[0]) or { return none }
	return value.resolve_relative_to(reference.to_double())
}

fn svg_direct_text_contents(element &dom.Element) string {
	mut text := ''
	for child in element.as_node().children_as_vector() {
		if character_data := child.as_character_data() {
			text += character_data.data()
		}
	}
	return text.trim(' \t\n\r\f')
}

fn (mut context SVGFormattingContext) layout_text_path_element(graphics_box &Node, element &dom.Element, mut graphics_state UsedValues) {
	href := element.get_attribute_value('href').trim_space()
	legacy_href := element.get_attribute_value('xlink:href').trim_space()
	reference := if href.len > 0 { href } else { legacy_href }
	if !reference.starts_with('#') {
		set_used_values_rect(mut graphics_state, svg.Rect{})
		return
	}
	shape := graphics_box.document().get_element_by_id(reference[1..]) or {
		set_used_values_rect(mut graphics_state, svg.Rect{})
		return
	}
	shape_path := svg.geometry_path(svg_element_model(shape), context.viewport_size.width().to_double(), context.viewport_size.height().to_double())
	computed := graphics_box.computed_values()
	font := &platform.Font{
		family: 'sans-serif'
		point_size: f32(computed.resolved_font_size_px())
		weight: int(computed.font_weight())
	}
	path := svg_place_text_along_path(shape_path, svg_direct_text_contents(element), font)
	local_bounds := svg_path_bounds(path) or { svg.Rect{} }
	stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
	set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(local_bounds), stroke_width))
	graphics_state.set_computed_svg_path(path)
	context.current_text_position = svg.Point{
		x: local_bounds.x + local_bounds.width
		y: local_bounds.y + local_bounds.height
	}
}

struct SVGFirstContourMeasure {
	points     []svg.Point
	cumulative []f64
	length     f64
}

struct SVGPathPositionAndTangent {
	position svg.Point
	tangent  svg.Point
}

// SkPathMeasure(path, false) measures only the first contour. Curve
// subdivision is shared with the retained Canvas/Gfx path fallback and is
// performed once during layout, never during repaint.
fn svg_first_contour_measure(path svg.Path) ?SVGFirstContourMeasure {
	polyline := html.canvas_gfx_path_first_contour_polyline(html.canvas_gfx_path_from_svg_path(path))
	if polyline.len < 2 {
		return none
	}
	mut points := []svg.Point{cap: polyline.len}
	mut cumulative := []f64{cap: polyline.len}
	mut length := 0.0
	for index, point in polyline {
		mapped := svg.Point{point.x, point.y}
		if index > 0 {
			previous := points[index - 1]
			length += math.hypot(mapped.x - previous.x, mapped.y - previous.y)
		}
		points << mapped
		cumulative << length
	}
	if length <= 0 {
		return none
	}
	return SVGFirstContourMeasure{
		points: points
		cumulative: cumulative
		length: length
	}
}

fn (measure SVGFirstContourMeasure) position_and_tangent(distance f64) ?SVGPathPositionAndTangent {
	if distance < 0 || distance > measure.length {
		return none
	}
	for index := 1; index < measure.points.len; index++ {
		segment_length := measure.cumulative[index] - measure.cumulative[index - 1]
		if segment_length <= 0 || (measure.cumulative[index] < distance
			&& index + 1 < measure.points.len) {
			continue
		}
		fraction := math.max(0.0, math.min(1.0, (distance - measure.cumulative[index - 1]) / segment_length))
		start := measure.points[index - 1]
		end := measure.points[index]
		return SVGPathPositionAndTangent{
			position: svg.Point{
				x: start.x + (end.x - start.x) * fraction
				y: start.y + (end.y - start.y) * fraction
			}
			tangent: svg.Point{
				x: (end.x - start.x) / segment_length
				y: (end.y - start.y) / segment_length
			}
		}
	}
	return none
}

// Gfx::Path::place_text_along(): place each unshaped SkFont glyph at the
// current path distance, rotate it to the tangent, reject a glyph whose
// midpoint falls beyond the first contour, then advance by its SkFont width.
fn svg_place_text_along_path(shape_path svg.Path, text string, font &platform.Font) svg.Path {
	measure := svg_first_contour_measure(shape_path) or { return svg.Path{} }
	mut accumulated_distance := 0.0
	mut instructions := []svg.PathInstruction{}
	for character in text.runes() {
		advance, glyph_index := font.glyph_advance_and_index(u32(character))
		position_and_tangent := measure.position_and_tangent(accumulated_distance) or {
			continue
		}
		if accumulated_distance + f64(advance) / 2.0 > measure.length {
			break
		}
		angle := math.atan2(position_and_tangent.tangent.y, position_and_tangent.tangent.x)
		cosine := math.cos(angle)
		sine := math.sin(angle)
		transform := svg.AffineTransform{
			a: cosine
			b: sine
			c: -sine
			d: cosine
			e: position_and_tangent.position.x
			f: position_and_tangent.position.y
		}
		if outline := font.glyph_outline(glyph_index) {
			for contour in outline.contours {
				append_svg_glyph_contour(mut instructions, contour, transform)
			}
		}
		accumulated_distance += f64(advance)
	}
	return svg.Path{
		instructions: instructions
	}
}

fn (mut context SVGFormattingContext) layout_image_element(image_box &Node) {
	styled := image_box.as_node_with_style() or { return }
	mut image_state := context.state.get_mutable(styled)
	element := svg_element_for_layout_node(image_box) or { return }
	mut source := ''
	if element.has_attribute('href') {
		source = element.get_attribute_value('href').trim_space()
	} else {
		source = element.get_attribute_value('xlink:href').trim_space()
	}
	intrinsic := image_intrinsic_size_for_source(image_box.document(), source) or {
		css.SizeWithAspectRatio{}
	}
	mut width := ?f64(none)
	mut height := ?f64(none)
	if element.has_attribute('width') {
		width = resolve_svg_attribute_length(element, 'width', context.viewport_size.width(), CSSPixels.new(0)).to_double()
	}
	if element.has_attribute('height') {
		height = resolve_svg_attribute_length(element, 'height', context.viewport_size.height(), CSSPixels.new(0)).to_double()
	}
	// SVGImageElement::bounding_box() derives a missing author dimension from
	// the decoded image ratio before falling back to each intrinsic dimension.
	if width_value := width {
		if height == none {
			if ratio := intrinsic.aspect_ratio {
				height = width_value / ratio.to_double()
			}
		}
	} else if height_value := height {
		if ratio := intrinsic.aspect_ratio {
			width = height_value * ratio.to_double()
		}
	}
	if width == none {
		if intrinsic_width := intrinsic.width {
			width = intrinsic_width.to_double()
		}
	}
	if height == none {
		if intrinsic_height := intrinsic.height {
			height = intrinsic_height.to_double()
		}
	}
	rect := svg.Rect{
		x: resolve_svg_attribute_length(element, 'x', context.viewport_size.width(), CSSPixels.new(0)).to_double()
		y: resolve_svg_attribute_length(element, 'y', context.viewport_size.height(), CSSPixels.new(0)).to_double()
		width: width or { 0.0 }
		height: height or { 0.0 }
	}
	set_used_values_rect(mut image_state, rect)
	image_state.set_has_definite_width(true)
	image_state.set_has_definite_height(true)
}

fn (mut context SVGFormattingContext) layout_mask_or_clip(mask_or_clip &Node) {
	styled := mask_or_clip.as_node_with_style() or { return }
	mut layout_state := context.state.get_mutable(styled)
	// The resource box is not normal-flow content. A formatting context inside a
	// foreignObject may have initialized its UsedValues while walking siblings;
	// SVGFormattingContext starts the referenced viewport at its own origin.
	layout_state.set_content_offset(CSSPixelPoint{})
	element := svg_element_for_layout_node(mask_or_clip) or { return }
	units_attribute := if mask_or_clip.is_svg_mask_box() {
		'maskContentUnits'
	} else if mask_or_clip.is_svg_clip_box() {
		'clipPathUnits'
	} else {
		'patternContentUnits'
	}
	mut seen_patterns := map[i64]bool{}
	content_units := if mask_or_clip.is_svg_pattern_box() {
		svg_pattern_units(element, units_attribute, .user_space_on_use, mut seen_patterns)
	} else {
		svg.parse_units(element.get_attribute_value(units_attribute)) or {
			svg.Units.user_space_on_use
		}
	}
	mut parent_transform := context.current_viewbox_transform
	parent := mask_or_clip.parent() or { return }
	parent_styled := parent.as_node_with_style() or { return }
	parent_state := context.state.try_get(parent_styled) or { return }
	resource_containing_block_is_parent := if containing_block := mask_or_clip.containing_block() {
		layout_nodes_same(unsafe { &Node(containing_block) }, parent)
	} else {
		false
	}
	if mask_or_clip.is_svg_pattern_box()
		&& svg.parse_viewbox(element.get_attribute_value('viewBox')) != none {
		seen_patterns.clear()
		pattern_units := svg_pattern_units(element, 'patternUnits', .object_bounding_box, mut seen_patterns)
		seen_patterns.clear()
		pattern_width := svg_pattern_coordinate(element, 'width', mut seen_patterns)
		seen_patterns.clear()
		pattern_height := svg_pattern_coordinate(element, 'height', mut seen_patterns)
		if pattern_units == .user_space_on_use {
			layout_state.set_content_width(CSSPixels.nearest_value_for(pattern_width.resolve_relative_to(context.viewport_size.width().to_double())))
			layout_state.set_content_height(CSSPixels.nearest_value_for(pattern_height.resolve_relative_to(context.viewport_size.height().to_double())))
		} else {
			layout_state.set_content_width(CSSPixels.nearest_value_for(pattern_width.value * parent_state.content_width().to_double()))
			layout_state.set_content_height(CSSPixels.nearest_value_for(pattern_height.value * parent_state.content_height().to_double()))
			parent_transform = if resource_containing_block_is_parent {
				svg.AffineTransform{}
			} else {
				svg.AffineTransform{}.translated(parent_state.offset.x().to_double(), parent_state.offset.y().to_double())
			}
		}
	} else if content_units == .object_bounding_box {
		layout_state.set_content_width(parent_state.content_width())
		layout_state.set_content_height(parent_state.content_height())
		parent_transform = if resource_containing_block_is_parent {
			svg.AffineTransform{}
		} else {
			svg.AffineTransform{}.translated(parent_state.offset.x().to_double(), parent_state.offset.y().to_double())
		}
		if mask_or_clip.is_svg_pattern_box() {
			parent_transform = parent_transform.scaled(parent_state.content_width().to_double(), parent_state.content_height().to_double())
		}
	} else {
		layout_state.set_content_width(context.viewport_size.width())
		layout_state.set_content_height(context.viewport_size.height())
		if resource_containing_block_is_parent {
			parent_transform = parent_transform.translated(-parent_state.offset.x().to_double(), -parent_state.offset.y().to_double())
		}
	}
	layout_state.set_has_definite_width(true)
	layout_state.set_has_definite_height(true)
	run_svg_formatting_context(mut context.state, mask_or_clip, mut layout_state, context.available_space, parent_transform)
}

fn (mut context SVGFormattingContext) layout_container_element(container &Node) {
	styled := container.as_node_with_style() or { return }
	mut box_state := context.state.get_mutable(styled)
	mut bounds := ?svg.Rect(none)
	for child in container.children() {
		if !child.is_box() || child.is_svg_mask_box() || child.is_svg_clip_box()
			|| child.is_svg_pattern_box() {
			continue
		}
		context.layout_svg_element(child)
		child_styled := child.as_node_with_style() or { continue }
		child_state := context.state.try_get(child_styled) or { continue }
		mut child_rect := svg.Rect{
			x: child_state.offset.x().to_double()
			y: child_state.offset.y().to_double()
			width: child_state.content_width().to_double()
			height: child_state.content_height().to_double()
		}
		if child_element := svg_element_for_layout_node(child) {
			child_rect = svg.element_transform(svg_element_model(child_element)).map_rect(child_rect)
		}
		bounds = if current := bounds { union_svg_rect(current, child_rect) } else { child_rect }
	}
	set_used_values_rect(mut box_state, bounds or { svg.Rect{} })
	box_state.set_has_definite_width(true)
	box_state.set_has_definite_height(true)
}

fn svg_element_for_layout_node(node &Node) ?&dom.Element {
	dom_node := node.dom_node() or { return none }
	return dom_node.as_element()
}

fn is_svg_container_element(element &dom.Element) bool {
	return element.local_name() in ['a', 'use', 'symbol', 'g', 'mask', 'switch']
}

fn resolve_svg_attribute_length(element &dom.Element, name string, reference CSSPixels, fallback CSSPixels) CSSPixels {
	value := svg.parse_number_percentage(element.get_attribute_value(name)) or { return fallback }
	return CSSPixels.nearest_value_for(value.resolve_relative_to(reference.to_double()))
}

fn resolve_computed_svg_length(computed &css.ComputedProperties, property_id css.PropertyID, reference CSSPixels, fallback CSSPixels) CSSPixels {
	value := computed.length_percentage_to_px(property_id, reference.to_double()) or {
		return fallback
	}
	return CSSPixels.nearest_value_for(value)
}

fn resolve_computed_svg_viewport_dimension(computed &css.ComputedProperties, property_id css.PropertyID, reference CSSPixels) CSSPixels {
	if value := computed.property(property_id, .yes) {
		if value.css_text.trim_space().to_lower() == 'auto' {
			return reference
		}
	}
	return resolve_computed_svg_length(computed, property_id, reference, reference)
}

fn resolve_svg_viewport_dimension(element &dom.Element, name string, reference CSSPixels) CSSPixels {
	text := element.get_attribute_value(name).trim_space()
	if text.len == 0 || text == 'auto' {
		return reference
	}
	return resolve_svg_attribute_length(element, name, reference, reference)
}

fn visible_svg_stroke_width(graphics_box &Node, viewport_size CSSPixelSize) f64 {
	computed := graphics_box.computed_values()
	stroke := computed.property(.stroke, .yes) or { return 0 }
	stroke_text := stroke.css_text.trim_space().to_lower()
	if stroke_text == 'none' || stroke_text == 'transparent' {
		return 0
	}
	if color := css.parse_color_string(stroke_text) {
		if color.a == 0 {
			return 0
		}
	}
	scaled_viewport_size := (viewport_size.width().to_double() + viewport_size.height().to_double()) * 0.5
	return computed.length_percentage_to_px(.stroke_width, scaled_viewport_size) or { 1.0 }
}

// Most SVG shapes in current LibWeb still build geometry from their parsed
// DOM attributes. SVGCircleElement is the exception: its geometry properties
// are taken from ComputedValues, so author CSS and presentation attributes
// participate. Mirror that exact boundary here.
fn svg_geometry_element_model(graphics_box &Node, element &dom.Element, viewport_size CSSPixelSize) svg.Element {
	mut model := svg_element_model(element)
	if element.local_name() != 'circle' {
		return model
	}
	computed := graphics_box.computed_values()
	diagonal := math.sqrt((viewport_size.width().to_double() * viewport_size.width().to_double() + viewport_size.height().to_double() * viewport_size.height().to_double()) / 2.0)
	model.attributes['cx'] = '${computed.length_percentage_to_px(.cx, viewport_size.width().to_double()) or { 0.0 }}'
	model.attributes['cy'] = '${computed.length_percentage_to_px(.cy, viewport_size.height().to_double()) or { 0.0 }}'
	model.attributes['r'] = '${computed.length_percentage_to_px(.r, diagonal) or { 0.0 }}'
	return model
}

fn set_used_values_rect(mut state UsedValues, rect svg.Rect) {
	state.set_content_offset(CSSPixelPoint.from_values(rect.x, rect.y))
	state.set_content_width(CSSPixels.nearest_value_for(rect.width))
	state.set_content_height(CSSPixels.nearest_value_for(rect.height))
}

fn quantize_svg_rect(rect svg.Rect) svg.Rect {
	return svg.Rect{
		x: CSSPixels.nearest_value_for(rect.x).to_double()
		y: CSSPixels.nearest_value_for(rect.y).to_double()
		width: CSSPixels.nearest_value_for(rect.width).to_double()
		height: CSSPixels.nearest_value_for(rect.height).to_double()
	}
}

fn inflate_svg_rect(rect svg.Rect, stroke_width f64) svg.Rect {
	if stroke_width <= 0 {
		return rect
	}
	quantized_stroke_width := CSSPixels.nearest_value_for(stroke_width)
	half_stroke_width := CSSPixels.from_raw(quantized_stroke_width.raw_value() / 2).to_double()
	return svg.Rect{
		x: rect.x - half_stroke_width
		y: rect.y - half_stroke_width
		width: rect.width + quantized_stroke_width.to_double()
		height: rect.height + quantized_stroke_width.to_double()
	}
}

fn union_svg_rect(a svg.Rect, b svg.Rect) svg.Rect {
	left := math.min(a.x, b.x)
	top := math.min(a.y, b.y)
	right := math.max(a.x + a.width, b.x + b.width)
	bottom := math.max(a.y + a.height, b.y + b.height)
	return svg.Rect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}

// Gfx::Path::bounding_box(). Skia's path bounds include the points which define
// line and Bézier segments and the actual extrema of converted elliptical arcs.
fn svg_path_bounds(path svg.Path) ?svg.Rect {
	if path.instructions.len == 0 {
		return none
	}
	mut points := []svg.Point{}
	mut current := svg.Point{}
	mut subpath_start := svg.Point{}
	mut previous_cubic_control := svg.Point{}
	mut previous_quadratic_control := svg.Point{}
	mut previous_type := svg.PathInstructionType.move
	for instruction in path.instructions {
		origin := current
		mut endpoint := current
		match instruction.type_ {
			.move, .line {
				endpoint = svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
			}
			.horizontal_line {
				endpoint = svg.Point{
					x: instruction.data[0] + if instruction.absolute { 0 } else { origin.x }
					y: origin.y
				}
			}
			.vertical_line {
				endpoint = svg.Point{
					x: origin.x
					y: instruction.data[0] + if instruction.absolute { 0 } else { origin.y }
				}
			}
			.curve {
				first_control := svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
				second_control := svg_command_point(instruction.data[2], instruction.data[3], instruction.absolute, origin)
				points << first_control
				points << second_control
				previous_cubic_control = second_control
				endpoint = svg_command_point(instruction.data[4], instruction.data[5], instruction.absolute, origin)
			}
			.smooth_curve {
				first_control := if previous_type in [.curve, .smooth_curve] {
					reflect_svg_point(previous_cubic_control, origin)
				} else {
					origin
				}
				second_control := svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
				points << first_control
				points << second_control
				previous_cubic_control = second_control
				endpoint = svg_command_point(instruction.data[2], instruction.data[3], instruction.absolute, origin)
			}
			.quadratic_bezier_curve {
				control := svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
				points << control
				previous_quadratic_control = control
				endpoint = svg_command_point(instruction.data[2], instruction.data[3], instruction.absolute, origin)
			}
			.smooth_quadratic_bezier_curve {
				control := if previous_type in [.quadratic_bezier_curve,
					.smooth_quadratic_bezier_curve] {
					reflect_svg_point(previous_quadratic_control, origin)
				} else {
					origin
				}
				points << control
				previous_quadratic_control = control
				endpoint = svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
			}
			.elliptical_arc {
				endpoint = svg_command_point(instruction.data[5], instruction.data[6], instruction.absolute, origin)
				points << svg_arc_extrema(origin, endpoint, instruction.data[0], instruction.data[1], instruction.data[2], instruction.data[3] != 0, instruction.data[4] != 0)
			}
			.close_path {
				endpoint = subpath_start
			}
		}
		if instruction.type_ == .move {
			subpath_start = endpoint
		}
		points << endpoint
		current = endpoint
		previous_type = instruction.type_
	}
	if points.len == 0 {
		return none
	}
	mut min_x := points[0].x
	mut max_x := points[0].x
	mut min_y := points[0].y
	mut max_y := points[0].y
	for point in points[1..] {
		min_x = math.min(min_x, point.x)
		max_x = math.max(max_x, point.x)
		min_y = math.min(min_y, point.y)
		max_y = math.max(max_y, point.y)
	}
	return svg.Rect{
		x: min_x
		y: min_y
		width: max_x - min_x
		height: max_y - min_y
	}
}

fn reflect_svg_point(point svg.Point, around svg.Point) svg.Point {
	return svg.Point{
		x: around.x * 2 - point.x
		y: around.y * 2 - point.y
	}
}

fn normalized_svg_angle(angle f64) f64 {
	mut normalized := math.fmod(angle, math.pi * 2)
	if normalized < 0 {
		normalized += math.pi * 2
	}
	return normalized
}

fn svg_angle_is_on_arc(angle f64, start f64, delta f64) bool {
	if delta >= 0 {
		return normalized_svg_angle(angle - start) <= delta + 1e-10
	}
	return normalized_svg_angle(start - angle) <= -delta + 1e-10
}

// SVG 2, implementation notes: conversion from endpoint to center
// parameterization. The extrema angles are then tested against the selected
// large/small clockwise/counter-clockwise sweep.
fn svg_arc_extrema(start svg.Point, end svg.Point, radius_x f64, radius_y f64, rotation_degrees f64, large_arc bool, sweep bool) []svg.Point {
	mut points := [start, end]
	mut rx := math.abs(radius_x)
	mut ry := math.abs(radius_y)
	if rx == 0 || ry == 0 || (start.x == end.x && start.y == end.y) {
		return points
	}
	phi := rotation_degrees * math.pi / 180.0
	cos_phi := math.cos(phi)
	sin_phi := math.sin(phi)
	dx := (start.x - end.x) / 2.0
	dy := (start.y - end.y) / 2.0
	x1_prime := cos_phi * dx + sin_phi * dy
	y1_prime := -sin_phi * dx + cos_phi * dy
	lambda := x1_prime * x1_prime / (rx * rx) + y1_prime * y1_prime / (ry * ry)
	if lambda > 1 {
		scale := math.sqrt(lambda)
		rx *= scale
		ry *= scale
	}
	rx2 := rx * rx
	ry2 := ry * ry
	x1_prime2 := x1_prime * x1_prime
	y1_prime2 := y1_prime * y1_prime
	denominator := rx2 * y1_prime2 + ry2 * x1_prime2
	mut factor := 0.0
	if denominator != 0 {
		factor = math.sqrt(math.max(0.0, (rx2 * ry2 - rx2 * y1_prime2 - ry2 * x1_prime2) / denominator))
	}
	if large_arc == sweep {
		factor = -factor
	}
	cx_prime := factor * rx * y1_prime / ry
	cy_prime := factor * -ry * x1_prime / rx
	cx := cos_phi * cx_prime - sin_phi * cy_prime + (start.x + end.x) / 2.0
	cy := sin_phi * cx_prime + cos_phi * cy_prime + (start.y + end.y) / 2.0
	ux := (x1_prime - cx_prime) / rx
	uy := (y1_prime - cy_prime) / ry
	vx := (-x1_prime - cx_prime) / rx
	vy := (-y1_prime - cy_prime) / ry
	theta_start := math.atan2(uy, ux)
	mut theta_delta := math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
	if !sweep && theta_delta > 0 {
		theta_delta -= math.pi * 2
	} else if sweep && theta_delta < 0 {
		theta_delta += math.pi * 2
	}
	x_extreme := math.atan2(-ry * sin_phi, rx * cos_phi)
	y_extreme := math.atan2(ry * cos_phi, rx * sin_phi)
	for angle in [x_extreme, x_extreme + math.pi, y_extreme, y_extreme + math.pi] {
		if !svg_angle_is_on_arc(angle, theta_start, theta_delta) {
			continue
		}
		points << svg.Point{
			x: cx + rx * cos_phi * math.cos(angle) - ry * sin_phi * math.sin(angle)
			y: cy + rx * sin_phi * math.cos(angle) + ry * cos_phi * math.sin(angle)
		}
	}
	// Skia stores SVG arcs as a sequence of rational quadratic (conic)
	// segments of at most 90 degrees. Path::getBounds(), which backs
	// Gfx::Path::bounding_box(), includes those conic control points rather
	// than computing tight curve bounds. Include the same tangent-intersection
	// controls so the translated layout geometry has identical conservative
	// bounds.
	segment_count := int(math.ceil(math.abs(theta_delta) / (math.pi / 2.0)))
	if segment_count > 0 {
		segment_delta := theta_delta / f64(segment_count)
		for segment_index in 0 .. segment_count {
			angle_start := theta_start + f64(segment_index) * segment_delta
			angle_end := angle_start + segment_delta
			middle := (angle_start + angle_end) / 2.0
			weight := math.cos(segment_delta / 2.0)
			if math.abs(weight) < 1e-12 {
				continue
			}
			control_x := math.cos(middle) / weight
			control_y := math.sin(middle) / weight
			points << svg.Point{
				x: cx + rx * cos_phi * control_x - ry * sin_phi * control_y
				y: cy + rx * sin_phi * control_x + ry * cos_phi * control_y
			}
		}
	}
	return points
}

fn svg_command_point(x f64, y f64, absolute bool, origin svg.Point) svg.Point {
	return svg.Point{
		x: x + if absolute { 0 } else { origin.x }
		y: y + if absolute { 0 } else { origin.y }
	}
}

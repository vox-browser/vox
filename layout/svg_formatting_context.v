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
	offset         svg.Point
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
		offset: svg.Point{offset_x.to_double(), offset_y.to_double()}
		scale_factor_x: uniform_scale
		scale_factor_y: uniform_scale
	}
}

// Blink keeps the viewBox matrix in double precision. Its alignment offset
// must not be quantized to LayoutUnit/CSSPixels before it reaches Skia.
fn chromium_scale_and_align_viewbox_content(preserve svg.PreserveAspectRatio,
	view_box svg.ViewBox, width f64, height f64) SVGViewBoxTransform {
	sx := width / f64(f32(view_box.width))
	sy := height / f64(f32(view_box.height))
	if preserve.align == .none_ {
		return SVGViewBoxTransform{scale_factor_x: sx, scale_factor_y: sy}
	}
	scale := if preserve.meet_or_slice == .meet { math.min(sx, sy) } else { math.max(sx, sy) }
	x := width - f64(f32(view_box.width)) * scale
	y := height - f64(f32(view_box.height)) * scale
	return SVGViewBoxTransform{
		offset: svg.Point{
			x: match preserve.align {
				.x_mid_y_min, .x_mid_y_mid, .x_mid_y_max { x / 2 }
				.x_max_y_min, .x_max_y_mid, .x_max_y_max { x }
				else { 0 }
			}
			y: match preserve.align {
				.x_min_y_mid, .x_mid_y_mid, .x_max_y_mid { y / 2 }
				.x_min_y_max, .x_mid_y_max, .x_max_y_max { y }
				else { 0 }
			}
		}
		scale_factor_x: scale
		scale_factor_y: scale
	}
}

fn run_svg_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, available_space AvailableSpace, parent_viewbox_transform svg.AffineTransform) FormattingContextResult {
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
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
	mut image_dimension_view_box := false
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
					image_dimension_view_box = true
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
		// Chromium stretches the intrinsic coordinate system of an SVG image
		// without an authored viewBox. preserveAspectRatio applies only to an
		// actual viewBox; applying its default here introduces letterboxing.
		preserve_aspect_ratio := if context.context_box.is_svg_mask_box()
			|| context.context_box.is_svg_clip_box()
			|| (image_dimension_view_box
			&& context.context_box.document().font_rendering_policy() == .chromium) {
			svg.PreserveAspectRatio{
				align: .none_
			}
		} else {
			svg.parse_preserve_aspect_ratio(element.get_attribute_value('preserveAspectRatio')) or {
				svg.PreserveAspectRatio{}
			}
		}
		viewbox_transform := if context.context_box.document().font_rendering_policy() == .chromium {
			chromium_scale_and_align_viewbox_content(preserve_aspect_ratio, view_box,
				svg_box_state.content_width().to_double(), svg_box_state.content_height().to_double())
		} else {
			scale_and_align_viewbox_content(preserve_aspect_ratio, view_box, scale_width, scale_height, svg_box_state)
		}
		viewport_transform = viewport_transform.translated(viewbox_transform.offset.x, viewbox_transform.offset.y).scaled(viewbox_transform.scale_factor_x, viewbox_transform.scale_factor_y).translated(-view_box.min_x, -view_box.min_y)
		context.current_viewbox_transform = context.current_viewbox_transform.translated(viewbox_transform.offset.x, viewbox_transform.offset.y).scaled(viewbox_transform.scale_factor_x, viewbox_transform.scale_factor_y).translated(-view_box.min_x, -view_box.min_y)
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
	// SVG children are positioned in the current SVG formatting context's user
	// space. Resource subtrees are structurally attached to the referencing box,
	// which need not be their coordinate containing block (notably a translated
	// foreignObject), so make that relationship explicit in UsedValues.
	if child_styled := child.as_node_with_style() {
		if context_styled := context.context_box.as_node_with_style() {
			context_state := context.state.get_mutable(context_styled)
			mut child_state := context.state.get_mutable(child_styled)
			child_state.set_containing_block_used_values(context_state)
		}
	}
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
	// SVG geometry supplies the foreignObject's used rectangle and the definite
	// available space for its independent formatting context, but it does not
	// make the CSS width/height properties definite percentage bases.
	child_state.set_has_definite_width(false)
	child_state.set_has_definite_height(false)
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
	local_transform := svg.element_transform(svg_transform_element_model(graphics_box, element, context.viewport_size))
	svg_transform := parent_svg_transform.multiply(local_transform)
	graphics_state.set_computed_svg_transforms(context.current_viewbox_transform, local_transform, svg_transform)

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
		if element.local_name() == 'path' {
			geometry := cached_svg_path_geometry(graphics_box)
			stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
			set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(geometry.bounds), stroke_width))
			graphics_state.set_computed_svg_path(geometry.path)
			graphics_state.set_has_definite_width(true)
			graphics_state.set_has_definite_height(true)
			return
		}
		path := svg.geometry_path(svg_geometry_element_model(graphics_box, element, context.viewport_size), context.viewport_size.width().to_double(), context.viewport_size.height().to_double())
		bounds := svg_path_bounds(path) or { svg.Rect{} }
		stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
		set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(bounds), stroke_width))
		graphics_state.set_computed_svg_path(path)
	} else if graphics_box.is_svg_text_box() {
		context.layout_text_element(graphics_box, element, mut graphics_state)
		// <text> and <tspan> elements can contain more text elements.
		for child in graphics_box.children() {
			if child.is_svg_text_box() || child.is_svg_text_path_box() {
				context.layout_graphics_element(child)
			}
		}
	} else if graphics_box.is_svg_text_path_box() {
		context.layout_text_path_element(graphics_box, element, mut graphics_state)
	} else {
		set_used_values_rect(mut graphics_state, svg.Rect{})
	}
	graphics_state.set_has_definite_width(true)
	graphics_state.set_has_definite_height(true)
}

fn svg_computed_path_instructions(graphics_box &Node) string {
	value := graphics_box.computed_values().typed_property_value(.d) or { return '' }
	if value is css.BasicShapeStyleValue {
		shape := value.basic_shape()
		if shape is css.BasicShapePath {
			return shape.path_instructions
		}
	}
	return ''
}

fn cached_svg_path_geometry(graphics_box &Node) &CachedSVGPathGeometry {
	mut geometry_box := unsafe { &SVGGeometryBox(graphics_box) }
	instructions := svg_computed_path_instructions(graphics_box)
	cached := geometry_box.cached_path_geometry
	if cached != unsafe { nil } {
		if cached.instructions == instructions {
			return cached
		}
	}
	// SVG path coordinates do not depend on the viewport. Layout probes can
	// share this immutable parsed path while stroke and transforms stay live.
	// Unlike probe geometry, this node-owned cache outlives the workspace that
	// first requests it. Own its text and parsed storage in the document arena.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	owned_instructions := instructions.clone()
	path := svg.parse_path_data(owned_instructions)
	geometry := &CachedSVGPathGeometry{
		instructions: owned_instructions
		path: path
		bounds: svg_path_bounds(path) or { svg.Rect{} }
	}
	geometry_box.cached_path_geometry = geometry
	return geometry
}

fn (mut context SVGFormattingContext) layout_text_element(graphics_box &Node, element &dom.Element, mut graphics_state UsedValues) svg.Rect {
	// SVGTextElement starts a new current-text-position sequence; tspans without
	// absolute coordinates continue from the preceding run.
	if element.local_name() == 'text' {
		context.current_text_position = svg.Point{}
	}
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
	shaped := svg_shape_text(graphics_box, text)
	mut x := context.current_text_position.x
	if svg_text_box_starts_text_chunk(graphics_box) {
		chunk := measure_svg_text_chunk(graphics_box)
		match chunk.anchor {
			.middle {
				x -= chunk.advance / 2
			}
			.end_ {
				x -= chunk.advance
			}
			else {}
		}
	}
	baseline_metric := resolve_dominant_baseline_metric(computed)
	baseline_font := graphics_box.first_available_font()
	baseline_y := context.current_text_position.y + f64(dominant_baseline_offset(baseline_metric,
		baseline_font.pixel_metrics()))
	path := svg_glyph_runs_outline_path(shaped.runs, x, baseline_y)
	final_local_bounds := svg_path_bounds(path) or { svg.Rect{} }
	stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
	set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(final_local_bounds), stroke_width))
	graphics_state.set_computed_svg_path(path)
	context.current_text_position = svg.Point{
		x: f64(f32(x + shaped.width))
		y: f64(f32(context.current_text_position.y))
	}
	return final_local_bounds
}

struct SVGShapedText {
	runs  []&platform.GlyphRun
	width f64
}

struct SVGTextChunkMeasurement {
mut:
	advance             f64
	anchor              css.TextAnchor
	found_chunk_start   bool
	found_rendered_text bool
	finished            bool
}

fn svg_text_box_starts_text_chunk(text_box &Node) bool {
	element := svg_element_for_layout_node(text_box) or { return false }
	if element.local_name() == 'text' {
		return true
	}
	return first_svg_text_position(element.get_attribute_value('x'), CSSPixels.new(1)) != none
		|| first_svg_text_position(element.get_attribute_value('y'), CSSPixels.new(1)) != none
}

fn measure_svg_text_chunk_subtree(node &Node, chunk_start &Node,
	mut measurement SVGTextChunkMeasurement) {
	if measurement.finished || node.is_svg_text_path_box() {
		return
	}
	if node.is_svg_text_box() {
		if voidptr(node) == voidptr(chunk_start) {
			measurement.found_chunk_start = true
		} else if measurement.found_chunk_start && svg_text_box_starts_text_chunk(node) {
			measurement.finished = true
			return
		}
		if measurement.found_chunk_start {
			if element := svg_element_for_layout_node(node) {
				text := svg_direct_text_contents(element)
				if text.len > 0 {
					if !measurement.found_rendered_text {
						measurement.anchor = node.computed_values().text_anchor()
						measurement.found_rendered_text = true
					}
					measurement.advance += svg_shape_text(node, text).width
				}
			}
		}
	}
	for child in node.children() {
		measure_svg_text_chunk_subtree(child, chunk_start, mut measurement)
		if measurement.finished {
			return
		}
	}
}

fn measure_svg_text_chunk(chunk_start &Node) SVGTextChunkMeasurement {
	mut subtree_root := unsafe { chunk_start }
	mut ancestor := chunk_start.parent()
	for {
		candidate := ancestor or { break }
		if !candidate.is_svg_text_box() {
			break
		}
		subtree_root = candidate
		ancestor = candidate.parent()
	}
	mut measurement := SVGTextChunkMeasurement{}
	measure_svg_text_chunk_subtree(subtree_root, chunk_start, mut measurement)
	return measurement
}

struct SVGPlatformFontCascade {
	fonts       []&platform.Font
	last_resort &platform.Font = unsafe { nil }
mut:
	invisible_fonts map[int]&platform.Font
}

struct SVGSelectedFont {
	font  &platform.Font = unsafe { nil }
	index int
}

fn svg_cascade_platform_fonts(font_list &css.FontCascadeList) SVGPlatformFontCascade {
	mut fonts := []&platform.Font{cap: font_list.fonts.len}
	for index in 0 .. font_list.fonts.len {
		fonts << text_node_chunk_platform_font(&font_list.fonts[index].font)
	}
	mut last_resort := &platform.Font(unsafe { nil })
	if font_list.last_resort_font != unsafe { nil } {
		converted := text_node_chunk_platform_font(font_list.last_resort_font)
		for font in fonts {
			if font.has_same_identity(converted) {
				last_resort = font
				return SVGPlatformFontCascade{
					fonts: fonts
					last_resort: last_resort
					invisible_fonts: map[int]&platform.Font{}
				}
			}
		}
		last_resort = converted
	}
	return SVGPlatformFontCascade{
		fonts: fonts
		last_resort: last_resort
		invisible_fonts: map[int]&platform.Font{}
	}
}

fn svg_font_for_code_point(font_list &css.FontCascadeList, fonts []&platform.Font,
	last_resort &platform.Font, code_point u32) SVGSelectedFont {
	for index, entry in font_list.fonts {
		font := fonts[index]
		if entry.unicode_ranges.len == 0 {
			if font.contains_glyph(code_point) {
				return SVGSelectedFont{
					font: font
					index: index
				}
			}
			continue
		}
		for range_ in entry.unicode_ranges {
			if range_.start <= code_point && code_point <= range_.end
				&& font.contains_glyph(code_point) {
				return SVGSelectedFont{
					font: font
					index: index
				}
			}
		}
	}
	if last_resort != unsafe { nil } {
		return SVGSelectedFont{
			font: last_resort
			index: fonts.len
		}
	}
	if fonts.len > 0 {
		return SVGSelectedFont{
			font: fonts[0]
		}
	}
	panic('SVG text font cascade must contain a font')
}

fn svg_invisible_font(mut cascade SVGPlatformFontCascade, selected SVGSelectedFont) &platform.Font {
	if font := cascade.invisible_fonts[selected.index] {
		return font
	}
	font := text_node_chunk_invisible_font(selected.font)
	cascade.invisible_fonts[selected.index] = font
	return font
}

// Gfx::shape_text(..., FontCascadeList) selects a concrete face for each code
// point, coalesces adjacent characters which use that face, and carries each
// shaped run's advance into the next run's baseline origin.
fn svg_shape_text(graphics_box &Node, text string) SVGShapedText {
	if text.len == 0 {
		return SVGShapedText{}
	}
	font_list := graphics_box.font_list()
	mut cascade := svg_cascade_platform_fonts(font_list)
	font_computer := css.css_style_computer_for(graphics_box.document()).font_computer()
	mut runs := []&platform.GlyphRun{}
	mut segment := ''
	mut segment_font := &platform.Font(unsafe { nil })
	mut x := f32(0)
	for character in text.runes() {
		selected := svg_font_for_code_point(font_list, cascade.fonts, cascade.last_resort,
			u32(character))
		font_generation := font_computer.environment_generation()
		fallback_is_invisible := font_list.fallback_is_invisible_for_code_point_through(u32(character),
			selected.index)
		if font_computer.environment_generation() != font_generation {
			// A synchronous lazy @font-face load invalidated the cascade. Shape
			// again so the newly available author face participates immediately.
			return svg_shape_text(graphics_box, text)
		}
		font := if fallback_is_invisible {
			svg_invisible_font(mut cascade, selected)
		} else {
			selected.font
		}
		if segment.len > 0 && voidptr(font) != voidptr(segment_font) {
			run := platform.shape_text(x, 0, segment, segment_font, .common)
			runs << run
			x += run.width()
			segment = ''
		}
		if segment.len == 0 {
			segment_font = font
		}
		segment += character.str()
	}
	if segment.len > 0 {
		run := platform.shape_text(x, 0, segment, segment_font, .common)
		runs << run
		x += run.width()
	}
	return SVGShapedText{
		runs: runs
		width: f64(x)
	}
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

fn svg_glyph_runs_outline_path(runs []&platform.GlyphRun, x f64, baseline_y f64) svg.Path {
	mut instructions := []svg.PathInstruction{}
	for run in runs {
		font := run.font()
		if font.is_invisible {
			continue
		}
		for glyph in run.glyphs() {
			if !glyph.should_paint {
				continue
			}
			if outline := font.glyph_outline(glyph.glyph_index) {
				transform := svg.AffineTransform{
					e: f64(f32(x) + glyph.position.x)
					f: f64(f32(baseline_y) + glyph.position.y)
				}
				for contour in outline.contours {
					append_svg_glyph_contour(mut instructions, contour, transform)
				}
			}
		}
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
	// The Rust/C++ bridge carries SVG text positioning through f32 values.
	// Quantize both the parsed scalar and its viewport basis at that boundary.
	quantized_value := svg.NumberPercentage{
		value: f64(f32(value.value))
		is_percentage: value.is_percentage
	}
	resolved := f64(f32(quantized_value.resolve_relative_to(f64(f32(reference.to_double())))))
	return CSSPixels.nearest_value_for(resolved).to_double()
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
	text := svg_direct_text_contents(element)
	shaped := svg_shape_text(graphics_box, text)
	measure := svg_first_contour_measure(shape_path)
	path_length := if measured := measure { measured.length } else { 0.0 }
	mut start_offset := svg_element_model(element).start_offset_for_path_length(path_length)
	// FIXME: Match upstream's pending writing-mode and text-direction handling.
	match computed.text_anchor() {
		.middle {
			start_offset -= shaped.width / 2
		}
		.end_ {
			start_offset -= shaped.width
		}
		else {}
	}
	path := svg_place_glyph_runs_along_path(shape_path, shaped.runs, start_offset)
	local_bounds := svg_path_bounds(path) or { svg.Rect{} }
	stroke_width := visible_svg_stroke_width(graphics_box, context.viewport_size)
	set_used_values_rect(mut graphics_state, inflate_svg_rect(quantize_svg_rect(local_bounds), stroke_width))
	graphics_state.set_computed_svg_path(path)
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

// Gfx::Path::place_glyph_runs_along(): place each shaped glyph at its retained
// run position, rotate it to the tangent, and stop when its midpoint passes the
// end of the first contour.
$if test {
	fn svg_place_text_along_path(shape_path svg.Path, text string, font &platform.Font,
		start_offset f64) svg.Path {
		run := platform.shape_text(0, 0, text, font, .common)
		return svg_place_glyph_runs_along_path(shape_path, [run], start_offset)
	}
}

fn svg_place_glyph_runs_along_path(shape_path svg.Path, runs []&platform.GlyphRun,
	start_offset f64) svg.Path {
	measure := svg_first_contour_measure(shape_path) or { return svg.Path{} }
	mut instructions := []svg.PathInstruction{}
	mut reached_end := false
	for run in runs {
		if reached_end || run.font().is_invisible {
			continue
		}
		for glyph in run.glyphs() {
			glyph_distance := start_offset + f64(glyph.position.x)
			position_and_tangent := measure.position_and_tangent(glyph_distance) or {
				continue
			}
			if glyph_distance + f64(glyph.advance) / 2.0 > measure.length {
				reached_end = true
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
			if outline := run.font().glyph_outline(glyph.glyph_index) {
				for contour in outline.contours {
					append_svg_glyph_contour(mut instructions, contour, transform)
				}
			}
		}
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
	intrinsic_result := image_intrinsic_size_for_source(image_box.document(), source)
	intrinsic := intrinsic_result or {
		css.SizeWithAspectRatio{}
	}
	computed := image_box.computed_values()
	specified_width := computed.length_percentage_to_px(.width, context.viewport_size.width().to_double())
	specified_height := computed.length_percentage_to_px(.height, context.viewport_size.height().to_double())
	mut default_size := CSSPixelSize{}
	if intrinsic_result != none {
		default_size = CSSPixelSize.from_values(300, 150)
	}
	sizing := if width := specified_width {
		if height := specified_height {
			css.run_default_sizing_algorithm(CSSPixels.nearest_value_for(width), CSSPixels.nearest_value_for(height), intrinsic, default_size)
		} else {
			css.run_default_sizing_algorithm(CSSPixels.nearest_value_for(width), none, intrinsic, default_size)
		}
	} else if height := specified_height {
		css.run_default_sizing_algorithm(none, CSSPixels.nearest_value_for(height), intrinsic, default_size)
	} else {
		css.run_default_sizing_algorithm(none, none, intrinsic, default_size)
	}
	rect := svg.Rect{
		x: computed.length_percentage_to_px(.x, context.viewport_size.width().to_double()) or {
			0.0
		}
		y: computed.length_percentage_to_px(.y, context.viewport_size.height().to_double()) or {
			0.0
		}
		width: sizing.width().to_double()
		height: sizing.height().to_double()
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
	// SVGFormattingContext starts the referenced viewport in its own user space.
	// Its structural owner is not its coordinate containing block: upstream
	// places every attached resource at (0, 0) after the nested run.
	layout_state.set_content_offset(CSSPixelPoint{})
	if context_styled := context.context_box.as_node_with_style() {
		layout_state.set_containing_block_used_values(context.state.get_mutable(context_styled))
	}
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
			child_rect = svg_element_attribute_transform(child_element).map_rect(child_rect)
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

fn svg_transform_element_model(graphics_box &Node, element &dom.Element, viewport_size CSSPixelSize) svg.Element {
	// element_transform reads only transform and <use> offsets. Descendants,
	// filter styles and the remaining attributes have no role in this query.
	mut model := svg.Element{tag:element.local_name(), attributes:map[string]string{}}
	computed := graphics_box.computed_values()
	if !element.has_attribute('transform') || computed_transform_is_none(computed) {
		model.attributes.delete('transform')
	} else if matrix := css.resolve_computed_transform_2d_matrix(computed, viewport_size.width().to_double(), viewport_size.height().to_double()) {
		model.attributes['transform'] = 'matrix(${matrix[0]} ${matrix[1]} ${matrix[2]} ${matrix[3]} ${matrix[4]} ${matrix[5]})'
	} else {
		model.attributes.delete('transform')
	}
	if element.local_name() != 'use' {
		return model
	}
	model.attributes['x'] = '${computed.length_percentage_to_px(.x, viewport_size.width().to_double()) or { 0.0 }}'
	model.attributes['y'] = '${computed.length_percentage_to_px(.y, viewport_size.height().to_double()) or { 0.0 }}'
	return model
}

// Materialize geometry properties that current LibWeb obtains from computed
// values. Author CSS therefore overrides their presentation attributes.
fn svg_geometry_element_model(graphics_box &Node, element &dom.Element, viewport_size CSSPixelSize) svg.Element {
	mut model := svg_element_model(element)
	computed := graphics_box.computed_values()
	match element.local_name() {
		'path' {
			model.attributes['d'] = svg_computed_path_instructions(graphics_box)
			return model
		}
		'circle' {
			diagonal := math.sqrt((viewport_size.width().to_double() * viewport_size.width().to_double() + viewport_size.height().to_double() * viewport_size.height().to_double()) / 2.0)
			model.attributes['cx'] = '${svg_ellipse_length(graphics_box, .cx, viewport_size.width().to_double()) or { 0.0 }}'
			model.attributes['cy'] = '${svg_ellipse_length(graphics_box, .cy, viewport_size.height().to_double()) or { 0.0 }}'
			model.attributes['r'] = '${svg_ellipse_length(graphics_box, .r, diagonal) or { 0.0 }}'
			return model
		}
		'ellipse' {
			rx_is_auto := computed.rx().is_auto()
			ry_is_auto := computed.ry().is_auto()
			mut rx := svg_ellipse_length(graphics_box, .rx, viewport_size.width().to_double()) or {
				0.0
			}
			mut ry := svg_ellipse_length(graphics_box, .ry, viewport_size.height().to_double()) or {
				0.0
			}
			if rx_is_auto {
				rx = ry
			}
			if ry_is_auto {
				ry = rx
			}
			model.attributes['cx'] = '${svg_ellipse_length(graphics_box, .cx, viewport_size.width().to_double()) or { 0.0 }}'
			model.attributes['cy'] = '${svg_ellipse_length(graphics_box, .cy, viewport_size.height().to_double()) or { 0.0 }}'
			model.attributes['rx'] = '${rx}'
			model.attributes['ry'] = '${ry}'
			return model
		}
		'rect' {
			width := computed.length_percentage_to_px(.width, viewport_size.width().to_double()) or {
				0.0
			}
			height := computed.length_percentage_to_px(.height, viewport_size.height().to_double()) or {
				0.0
			}
			model.attributes['x'] = '${computed.length_percentage_to_px(.x, viewport_size.width().to_double()) or { 0.0 }}'
			model.attributes['y'] = '${computed.length_percentage_to_px(.y, viewport_size.height().to_double()) or { 0.0 }}'
			model.attributes['width'] = '${width}'
			model.attributes['height'] = '${height}'
			rx_is_auto := computed.rx().is_auto()
			ry_is_auto := computed.ry().is_auto()
			if rx_is_auto && ry_is_auto {
				model.attributes.delete('rx')
				model.attributes.delete('ry')
			} else if !rx_is_auto && ry_is_auto {
				used_rx := computed.length_percentage_to_px(.rx, width) or { 0.0 }
				model.attributes['rx'] = '${used_rx}'
				model.attributes['ry'] = '${used_rx}'
			} else if rx_is_auto && !ry_is_auto {
				used_ry := computed.length_percentage_to_px(.ry, height) or { 0.0 }
				model.attributes['rx'] = '${used_ry}'
				model.attributes['ry'] = '${used_ry}'
			} else {
				model.attributes['rx'] = '${computed.length_percentage_to_px(.rx, width) or { 0.0 }}'
				model.attributes['ry'] = '${computed.length_percentage_to_px(.ry, height) or { 0.0 }}'
			}
			return model
		}
		else {
			return model
		}
	}
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
	mut points := SVGPathBounds{}
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
				points = points.including(first_control)
				points = points.including(second_control)
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
				points = points.including(first_control)
				points = points.including(second_control)
				previous_cubic_control = second_control
				endpoint = svg_command_point(instruction.data[2], instruction.data[3], instruction.absolute, origin)
			}
			.quadratic_bezier_curve {
				control := svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
				points = points.including(control)
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
				points = points.including(control)
				previous_quadratic_control = control
				endpoint = svg_command_point(instruction.data[0], instruction.data[1], instruction.absolute, origin)
			}
			.elliptical_arc {
				endpoint = svg_command_point(instruction.data[5], instruction.data[6], instruction.absolute, origin)
				points = include_svg_arc_extrema(points, origin, endpoint, instruction.data[0], instruction.data[1], instruction.data[2], instruction.data[3] != 0, instruction.data[4] != 0)
			}
			.close_path {
				endpoint = subpath_start
			}
		}
		if instruction.type_ == .move {
			subpath_start = endpoint
		}
		points = points.including(endpoint)
		current = endpoint
		previous_type = instruction.type_
	}
	return points.rect()
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
fn include_svg_arc_extrema(bounds SVGPathBounds, start svg.Point, end svg.Point, radius_x f64, radius_y f64, rotation_degrees f64, large_arc bool, sweep bool) SVGPathBounds {
	mut points := bounds
	points = points.including(start)
	points = points.including(end)
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
	for angle in [x_extreme, x_extreme + math.pi, y_extreme, y_extreme + math.pi]! {
		if !svg_angle_is_on_arc(angle, theta_start, theta_delta) {
			continue
		}
		points = points.including(svg.Point{
			x: cx + rx * cos_phi * math.cos(angle) - ry * sin_phi * math.sin(angle)
			y: cy + rx * sin_phi * math.cos(angle) + ry * cos_phi * math.sin(angle)
		})
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
			points = points.including(svg.Point{
				x: cx + rx * cos_phi * control_x - ry * sin_phi * control_y
				y: cy + rx * sin_phi * control_x + ry * cos_phi * control_y
			})
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

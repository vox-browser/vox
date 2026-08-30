// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
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
	svg_offset                CSSPixelPoint
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
		offset:         CSSPixelPoint.new(offset_x, offset_y)
		scale_factor_x: uniform_scale
		scale_factor_y: uniform_scale
	}
}

fn run_svg_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, available_space AvailableSpace, parent_viewbox_transform svg.AffineTransform) FormattingContextResult {
	mut context := SVGFormattingContext{
		state:                    state
		context_box:              context_box
		parent_viewbox_transform: parent_viewbox_transform
		available_space:          available_space
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
				width:  1
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
						width:  natural_width.to_double()
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
			disable_svg_rendering_for_descendants(mut context.state, context.context_box)
			return
		}
	}

	// Inline-level replaced boxes are laid out internally before their final
	// line-box content offset is installed, so their state still points at the
	// border-box origin here. Block-level SVG boxes already carry the content
	// origin. This is the same distinction made by the upstream inline layout
	// path before SVGFormattingContext consumes the state.
	context.svg_offset = if context.context_box.display().is_inline_outside() {
		CSSPixelPoint.new(svg_box_state.offset.x().plus(svg_box_state.border_box_left()),
			svg_box_state.offset.y().plus(svg_box_state.border_box_top()))
	} else {
		svg_box_state.offset
	}
	// SVGFormattingContext::run() starts with the inherited viewBox transform.
	// The SVG viewport's own offset remains in its paintable and is accumulated
	// through the containing-block chain; folding it into this transform would
	// apply the viewport position twice to descendants.
	context.current_viewbox_transform = context.parent_viewbox_transform
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
		viewbox_transform := scale_and_align_viewbox_content(preserve_aspect_ratio, view_box,
			scale_width, scale_height, svg_box_state)
		context.current_viewbox_transform = context.current_viewbox_transform.translated(viewbox_transform.offset.x().to_double(),
			viewbox_transform.offset.y().to_double()).scaled(viewbox_transform.scale_factor_x,
			viewbox_transform.scale_factor_y).translated(-view_box.min_x, -view_box.min_y)
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

	if svg_box_state.has_definite_width() && svg_box_state.has_definite_height() {
		mapped := context.parent_viewbox_transform.map_rect(svg.Rect{
			x:      svg_box_state.offset.x().to_double()
			y:      svg_box_state.offset.y().to_double()
			width:  svg_box_state.content_width().to_double()
			height: svg_box_state.content_height().to_double()
		})
		set_used_values_rect(mut svg_box_state, mapped)
	}

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
	element := svg_element_for_layout_node(viewport) or { return }
	computed := viewport.computed_values()
	x := resolve_computed_svg_length(computed, .x, context.viewport_size.width(), CSSPixels.new(0))
	y := resolve_computed_svg_length(computed, .y, context.viewport_size.height(), CSSPixels.new(0))
	width := resolve_computed_svg_viewport_dimension(computed, .width,
		context.viewport_size.width())
	height := resolve_computed_svg_viewport_dimension(computed, .height,
		context.viewport_size.height())

	mut content_rect := svg.Rect{
		x:      x.to_double()
		y:      y.to_double()
		width:  width.to_double()
		height: height.to_double()
	}
	mut parent_viewbox_transform := context.current_viewbox_transform
	if svg.parse_viewbox(element.get_attribute_value('viewBox')) != none {
		content_rect = context.current_viewbox_transform.map_rect(content_rect)
		parent_viewbox_transform = svg.AffineTransform{}
	}
	set_used_values_rect(mut viewport_state, content_rect)
	viewport_state.set_has_definite_width(true)
	viewport_state.set_has_definite_height(true)
	run_svg_formatting_context(mut context.state, viewport, mut viewport_state,
		context.available_space, parent_viewbox_transform)
}

fn (mut context SVGFormattingContext) layout_foreign_object(child &Node) {
	styled := child.as_node_with_style() or { return }
	mut child_state := context.state.get_mutable(styled)
	_ = svg_element_for_layout_node(child) or { return }
	computed := child.computed_values()
	rect := svg.Rect{
		x:      resolve_computed_svg_length(computed, .x,
			context.available_space.width.to_px_or_zero(), CSSPixels.new(0)).to_double()
		y:      resolve_computed_svg_length(computed, .y,
			context.available_space.height.to_px_or_zero(), CSSPixels.new(0)).to_double()
		width:  resolve_computed_svg_length(computed, .width,
			context.available_space.width.to_px_or_zero(), CSSPixels.new(0)).to_double()
		height: resolve_computed_svg_length(computed, .height,
			context.available_space.height.to_px_or_zero(), CSSPixels.new(0)).to_double()
	}
	transformed_rect := context.current_viewbox_transform.map_rect(rect)
	set_used_values_rect(mut child_state, transformed_rect)
	child_state.set_has_definite_width(true)
	child_state.set_has_definite_height(true)
	layout_inside_independent_formatting_context(mut context.state, child, mut child_state, AvailableSpace.new(AvailableSize.make_definite(child_state.content_width()),
		AvailableSize.make_definite(child_state.content_height())))
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
	to_css_pixels := context.current_viewbox_transform.multiply(graphics_state.svg_transform())

	if graphics_box.is_svg_geometry_box() {
		path := svg.geometry_path(svg_geometry_element_model(graphics_box, element,
			context.viewport_size), context.viewport_size.width().to_double(),
			context.viewport_size.height().to_double())
		bounds := svg_path_bounds(path) or { svg.Rect{} }
		mut transformed_bounds := quantize_svg_rect(to_css_pixels.map_rect(bounds))
		stroke_width := CSSPixels.nearest_value_for(visible_svg_stroke_width(graphics_box,
			context.viewport_size) * context.current_viewbox_transform.x_scale()).to_double()
		transformed_bounds = inflate_svg_rect(transformed_bounds, stroke_width)
		set_used_values_rect(mut graphics_state, transformed_bounds)
		graphics_state.set_computed_svg_path(path)
	} else if graphics_box.is_svg_text_box() {
		context.layout_text_element(graphics_box, element, to_css_pixels, mut graphics_state)
		for child in graphics_box.children() {
			if child.is_svg_text_box() || child.is_svg_text_path_box() {
				context.layout_graphics_element(child)
			}
		}
	} else if graphics_box.is_svg_text_path_box() {
		context.layout_text_path_element(graphics_box, element, to_css_pixels, mut graphics_state)
	} else {
		set_used_values_rect(mut graphics_state, svg.Rect{})
	}
	graphics_state.set_has_definite_width(true)
	graphics_state.set_has_definite_height(true)
}

fn (mut context SVGFormattingContext) layout_text_element(graphics_box &Node, element &dom.Element, transform svg.AffineTransform, mut graphics_state UsedValues) {
	if x := first_svg_text_position(element.get_attribute_value('x'), context.viewport_size.width()) {
		context.current_text_position = svg.Point{
			x: x
			y: context.current_text_position.y
		}
	}
	if y := first_svg_text_position(element.get_attribute_value('y'),
		context.viewport_size.height())
	{
		context.current_text_position = svg.Point{
			x: context.current_text_position.x
			y: y
		}
	}
	if dx := first_svg_text_position(element.get_attribute_value('dx'),
		context.viewport_size.width())
	{
		context.current_text_position = svg.Point{
			x: context.current_text_position.x + dx
			y: context.current_text_position.y
		}
	}
	if dy := first_svg_text_position(element.get_attribute_value('dy'),
		context.viewport_size.height())
	{
		context.current_text_position = svg.Point{
			x: context.current_text_position.x
			y: context.current_text_position.y + dy
		}
	}
	text := svg_direct_text_contents(element)
	computed := graphics_box.computed_values()
	font := &platform.Font{
		family:     'sans-serif'
		point_size: f32(computed.resolved_font_size_px())
		weight:     int(computed.font_weight())
	}
	run := platform.shape_text(0,
		f32(resolved_text_spacing_for_node(graphics_box, .letter_spacing).to_double()), text, font,
		.context_dependent)
	text_width := f64(run.width())
	mut x := context.current_text_position.x
	anchor := match computed.text_anchor() {
		.start { svg.TextAnchor.start }
		.middle { svg.TextAnchor.middle }
		.end_ { svg.TextAnchor.end }
	}
	match anchor {
		.middle { x -= text_width / 2 }
		.end { x -= text_width }
		else {}
	}
	baseline_y := context.current_text_position.y +
		svg_dominant_baseline_offset(computed.dominant_baseline(), font.pixel_metrics())
	mut local_bounds := ?svg.Rect(none)
	mut glyph_x := x
	for character in text.runes() {
		advance, glyph_index := font.glyph_advance_and_index(u32(character))
		bounds := font.glyph_bounds(glyph_index)
		if bounds.x_min == 0 && bounds.x_max == 0 && bounds.y_min == 0 && bounds.y_max == 0 {
			glyph_x += f64(advance)
			continue
		}
		glyph_rect := svg.Rect{
			x:      glyph_x + f64(bounds.x_min)
			y:      baseline_y - f64(bounds.y_max)
			width:  f64(bounds.x_max - bounds.x_min)
			height: f64(bounds.y_max - bounds.y_min)
		}
		local_bounds = if current := local_bounds {
			union_svg_rect(current, glyph_rect)
		} else {
			glyph_rect
		}
		glyph_x += f64(advance)
	}
	final_local_bounds := local_bounds or { svg.Rect{} }
	mut transformed_bounds := quantize_svg_rect(transform.map_rect(final_local_bounds))
	stroke_width := CSSPixels.nearest_value_for(visible_svg_stroke_width(graphics_box,
		context.viewport_size) * context.current_viewbox_transform.x_scale()).to_double()
	transformed_bounds = inflate_svg_rect(transformed_bounds, stroke_width)
	set_used_values_rect(mut graphics_state, transformed_bounds)
	graphics_state.set_svg_text(text)
	if local_bounds != none {
		context.current_text_position = svg.Point{
			x: final_local_bounds.x + final_local_bounds.width
			y: final_local_bounds.y + final_local_bounds.height
		}
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
	return text.fields().join(' ')
}

fn svg_dominant_baseline_offset(metric ?css.BaselineMetric, font_metrics platform.FontPixelMetrics) f64 {
	resolved := metric or { css.BaselineMetric.alphabetic }
	return match resolved {
		.central { f64((font_metrics.ascent - font_metrics.descent) * 0.5) }
		.middle { f64(font_metrics.x_height * 0.5) }
		.hanging { f64(font_metrics.ascent * 0.8) }
		.ideographic { f64(-font_metrics.descent) }
		.mathematical { f64(font_metrics.ascent * 0.5) }
		else { 0.0 }
	}
}

fn (mut context SVGFormattingContext) layout_text_path_element(graphics_box &Node, element &dom.Element, transform svg.AffineTransform, mut graphics_state UsedValues) {
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
	path := svg.geometry_path(svg_element_model(shape), context.viewport_size.width().to_double(),
		context.viewport_size.height().to_double())
	bounds := svg_path_bounds(path) or { svg.Rect{} }
	set_used_values_rect(mut graphics_state, transform.map_rect(bounds))
	graphics_state.set_computed_svg_path(path)
	graphics_state.set_svg_text(svg_element_model(element).text_contents())
}

fn (mut context SVGFormattingContext) layout_image_element(image_box &Node) {
	styled := image_box.as_node_with_style() or { return }
	mut image_state := context.state.get_mutable(styled)
	element := svg_element_for_layout_node(image_box) or { return }
	transform := context.current_viewbox_transform.multiply(image_state.svg_transform())
	rect := svg.Rect{
		x:      resolve_svg_attribute_length(element, 'x', context.viewport_size.width(),
			CSSPixels.new(0)).to_double()
		y:      resolve_svg_attribute_length(element, 'y', context.viewport_size.height(),
			CSSPixels.new(0)).to_double()
		width:  resolve_svg_attribute_length(element, 'width', context.viewport_size.width(),
			CSSPixels.new(0)).to_double()
		height: resolve_svg_attribute_length(element, 'height', context.viewport_size.height(),
			CSSPixels.new(0)).to_double()
	}
	set_used_values_rect(mut image_state, transform.map_rect(rect))
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
	content_units := svg.parse_units(element.get_attribute_value(units_attribute)) or {
		svg.Units.user_space_on_use
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
	if content_units == .object_bounding_box {
		layout_state.set_content_width(parent_state.content_width())
		layout_state.set_content_height(parent_state.content_height())
		parent_transform = if resource_containing_block_is_parent {
			svg.AffineTransform{}
		} else {
			svg.AffineTransform{}.translated(parent_state.offset.x().to_double(),
				parent_state.offset.y().to_double())
		}
		if mask_or_clip.is_svg_pattern_box() {
			parent_transform = parent_transform.scaled(parent_state.content_width().to_double(),
				parent_state.content_height().to_double())
		}
	} else {
		layout_state.set_content_width(context.viewport_size.width())
		layout_state.set_content_height(context.viewport_size.height())
		if resource_containing_block_is_parent {
			parent_transform = parent_transform.translated(-parent_state.offset.x().to_double(),
				-parent_state.offset.y().to_double())
		}
	}
	layout_state.set_has_definite_width(true)
	layout_state.set_has_definite_height(true)
	run_svg_formatting_context(mut context.state, mask_or_clip, mut layout_state,
		context.available_space, parent_transform)
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
		child_rect := svg.Rect{
			x:      child_state.offset.x().to_double()
			y:      child_state.offset.y().to_double()
			width:  child_state.content_width().to_double()
			height: child_state.content_height().to_double()
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
	return element.local_name() in ['a', 'use', 'symbol', 'g', 'mask']
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
	diagonal := math.sqrt((viewport_size.width().to_double() * viewport_size.width().to_double() +
		viewport_size.height().to_double() * viewport_size.height().to_double()) / 2.0)
	model.attributes['cx'] = '${computed.length_percentage_to_px(.cx,
		viewport_size.width().to_double()) or { 0.0 }}'
	model.attributes['cy'] = '${computed.length_percentage_to_px(.cy,
		viewport_size.height().to_double()) or { 0.0 }}'
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
		x:      CSSPixels.nearest_value_for(rect.x).to_double()
		y:      CSSPixels.nearest_value_for(rect.y).to_double()
		width:  CSSPixels.nearest_value_for(rect.width).to_double()
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
		x:      rect.x - half_stroke_width
		y:      rect.y - half_stroke_width
		width:  rect.width + quantized_stroke_width.to_double()
		height: rect.height + quantized_stroke_width.to_double()
	}
}

fn union_svg_rect(a svg.Rect, b svg.Rect) svg.Rect {
	left := math.min(a.x, b.x)
	top := math.min(a.y, b.y)
	right := math.max(a.x + a.width, b.x + b.width)
	bottom := math.max(a.y + a.height, b.y + b.height)
	return svg.Rect{
		x:      left
		y:      top
		width:  right - left
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
				endpoint = svg_command_point(instruction.data[0], instruction.data[1],
					instruction.absolute, origin)
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
				first_control := svg_command_point(instruction.data[0], instruction.data[1],
					instruction.absolute, origin)
				second_control := svg_command_point(instruction.data[2], instruction.data[3],
					instruction.absolute, origin)
				points << first_control
				points << second_control
				previous_cubic_control = second_control
				endpoint = svg_command_point(instruction.data[4], instruction.data[5],
					instruction.absolute, origin)
			}
			.smooth_curve {
				first_control := if previous_type in [.curve, .smooth_curve] {
					reflect_svg_point(previous_cubic_control, origin)
				} else {
					origin
				}
				second_control := svg_command_point(instruction.data[0], instruction.data[1],
					instruction.absolute, origin)
				points << first_control
				points << second_control
				previous_cubic_control = second_control
				endpoint = svg_command_point(instruction.data[2], instruction.data[3],
					instruction.absolute, origin)
			}
			.quadratic_bezier_curve {
				control := svg_command_point(instruction.data[0], instruction.data[1],
					instruction.absolute, origin)
				points << control
				previous_quadratic_control = control
				endpoint = svg_command_point(instruction.data[2], instruction.data[3],
					instruction.absolute, origin)
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
				endpoint = svg_command_point(instruction.data[0], instruction.data[1],
					instruction.absolute, origin)
			}
			.elliptical_arc {
				endpoint = svg_command_point(instruction.data[5], instruction.data[6],
					instruction.absolute, origin)
				points << svg_arc_extrema(origin, endpoint, instruction.data[0],
					instruction.data[1], instruction.data[2], instruction.data[3] != 0,
					instruction.data[4] != 0)
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
		x:      min_x
		y:      min_y
		width:  max_x - min_x
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
		factor = math.sqrt(math.max(0.0,
			(rx2 * ry2 - rx2 * y1_prime2 - ry2 * x1_prime2) / denominator))
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

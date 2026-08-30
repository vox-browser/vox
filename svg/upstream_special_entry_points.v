// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Gradient, pattern, root viewport, decoded-image, and page-client entry points.
module svg

import math

pub fn attribute_style_properties() []string {
	return ['alignment-baseline', 'baseline-shift', 'clip-path', 'clip-rule', 'color',
		'fill', 'fill-opacity', 'fill-rule', 'filter', 'flood-color', 'flood-opacity',
		'font-family', 'font-size', 'font-style', 'font-weight', 'marker-end',
		'marker-mid', 'marker-start', 'mask', 'opacity', 'paint-order', 'stop-color',
		'stop-opacity', 'stroke', 'stroke-dasharray', 'stroke-dashoffset',
		'stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit', 'stroke-opacity',
		'stroke-width', 'text-anchor', 'transform']
}

pub fn normalized_diagonal_length(width f64, height f64) f64 {
	return math.sqrt((width * width + height * height) / 2)
}

pub fn parse_channel_selector(value string) ChannelSelector { return channel_selector(value) }
pub fn parse_stitch_tiles(value string) StitchType { return stitch_type(value) }
pub fn parse_turbulence_type(value string) TurbulenceType { return turbulence_type(value) }
pub fn parse_type(value ?string) ComponentTransferType { return parse_component_transfer_type(value or { '' }) }
pub fn string_to_compositing_operator(value string) CompositeOperator { return composite_operator(value) }
pub fn to_painting_spread_method(value SpreadMethod) SpreadMethod { return value }
pub fn to_svg_fill_rule(value string) FillRule { return if value == 'evenodd' { .evenodd } else { .nonzero } }
pub fn transform_from_transform_list(values []Transform) AffineTransform { return compose_transforms(values) }

pub fn (gradient &LinearGradient) linked_linear_gradient(gradients map[string]LinearGradient) ?ResolvedLinearGradient {
	return resolve_linear_gradient(gradient.id, gradients)
}
pub fn (gradient &LinearGradient) start_x() NumberPercentage { return gradient.x1 or { percentage(0) } }
pub fn (gradient &LinearGradient) start_x_impl() NumberPercentage { return gradient.start_x() }
pub fn (gradient &LinearGradient) start_y() NumberPercentage { return gradient.y1 or { percentage(0) } }
pub fn (gradient &LinearGradient) start_y_impl() NumberPercentage { return gradient.start_y() }
pub fn (gradient &LinearGradient) end_x() NumberPercentage { return gradient.x2 or { percentage(100) } }
pub fn (gradient &LinearGradient) end_x_impl() NumberPercentage { return gradient.end_x() }
pub fn (gradient &LinearGradient) end_y() NumberPercentage { return gradient.y2 or { percentage(0) } }
pub fn (gradient &LinearGradient) end_y_impl() NumberPercentage { return gradient.end_y() }

pub fn (gradient &LinkedRadialGradient) linked_radial_gradient(gradients map[string]LinkedRadialGradient) ?ResolvedRadialGradient {
	return resolve_radial_gradient(gradient.id, gradients)
}
pub fn (gradient &LinkedRadialGradient) start_circle_x() NumberPercentage { return gradient.cx or { percentage(50) } }
pub fn (gradient &LinkedRadialGradient) start_circle_x_impl() NumberPercentage { return gradient.start_circle_x() }
pub fn (gradient &LinkedRadialGradient) start_circle_y() NumberPercentage { return gradient.cy or { percentage(50) } }
pub fn (gradient &LinkedRadialGradient) start_circle_y_impl() NumberPercentage { return gradient.start_circle_y() }
pub fn (gradient &LinkedRadialGradient) start_circle_radius() NumberPercentage { return gradient.fr or { percentage(0) } }
pub fn (gradient &LinkedRadialGradient) start_circle_radius_impl() NumberPercentage { return gradient.start_circle_radius() }
pub fn (gradient &LinkedRadialGradient) end_circle_x() NumberPercentage { return gradient.cx or { percentage(50) } }
pub fn (gradient &LinkedRadialGradient) end_circle_x_impl() NumberPercentage { return gradient.end_circle_x() }
pub fn (gradient &LinkedRadialGradient) end_circle_y() NumberPercentage { return gradient.cy or { percentage(50) } }
pub fn (gradient &LinkedRadialGradient) end_circle_y_impl() NumberPercentage { return gradient.end_circle_y() }
pub fn (gradient &LinkedRadialGradient) end_circle_radius() NumberPercentage { return gradient.r or { percentage(50) } }
pub fn (gradient &LinkedRadialGradient) end_circle_radius_impl() NumberPercentage { return gradient.end_circle_radius() }

pub fn (pattern &Pattern) linked_pattern(patterns map[string]Pattern) ?ResolvedPattern {
	return resolve_pattern(pattern.id, patterns)
}
pub fn (pattern &Pattern) pattern_x() NumberPercentage { return pattern.x or { number(0) } }
pub fn (pattern &Pattern) pattern_x_impl() NumberPercentage { return pattern.pattern_x() }
pub fn (pattern &Pattern) pattern_y() NumberPercentage { return pattern.y or { number(0) } }
pub fn (pattern &Pattern) pattern_y_impl() NumberPercentage { return pattern.pattern_y() }
pub fn (pattern &Pattern) pattern_width() NumberPercentage { return pattern.width or { number(0) } }
pub fn (pattern &Pattern) pattern_width_impl() NumberPercentage { return pattern.pattern_width() }
pub fn (pattern &Pattern) pattern_height() NumberPercentage { return pattern.height or { number(0) } }
pub fn (pattern &Pattern) pattern_height_impl() NumberPercentage { return pattern.pattern_height() }
pub fn (pattern &Pattern) pattern_units() Units { return pattern.units or { Units.object_bounding_box } }
pub fn (pattern &Pattern) pattern_units_impl() Units { return pattern.pattern_units() }
pub fn (pattern &Pattern) pattern_content_units() Units { return pattern.content_units or { Units.user_space_on_use } }
pub fn (pattern &Pattern) pattern_content_units_impl() Units { return pattern.pattern_content_units() }
pub fn (pattern &Pattern) pattern_transform() []Transform { return pattern.transform or { []Transform{} } }
pub fn (pattern &Pattern) pattern_transform_impl() []Transform { return pattern.pattern_transform() }
pub fn (pattern &Pattern) pattern_content_element(patterns map[string]Pattern) ?string { return pattern_content_id(pattern.id, patterns) }
pub fn (pattern &Pattern) pattern_content_element_impl(patterns map[string]Pattern) ?string { return pattern.pattern_content_element(patterns) }

pub fn (element &Element) linked_gradient() string { return element.href().trim_left('#') }
pub fn (element &Element) gradient_units() Units { return parse_units(element.attributes['gradientUnits'] or { '' }) or { Units.object_bounding_box } }
pub fn (element &Element) gradient_units_impl() Units { return element.gradient_units() }
pub fn (element &Element) gradient_transform() []Transform { return parse_transform(element.attributes['gradientTransform'] or { '' }) or { []Transform{} } }
pub fn (element &Element) gradient_transform_impl() []Transform { return element.gradient_transform() }
pub fn (element &Element) gradient_paint_transform() AffineTransform { return compose_transforms(element.gradient_transform()) }
pub fn (element &Element) spread_method() SpreadMethod { return parse_spread_method(element.attributes['spreadMethod'] or { '' }) or { SpreadMethod.pad } }
pub fn (element &Element) spread_method_impl() SpreadMethod { return element.spread_method() }
pub fn (element &Element) color_space() string { return element.attributes['color-interpolation'] or { 'sRGB' } }
pub fn (element &Element) for_each_color_stop() []Stop {
	mut stops := []Stop{}
	for child in element.children {
		if child.tag == 'stop' { stops << Stop{ offset: child.stop_offset(), color: child.stop_color(), opacity: child.stop_opacity() } }
	}
	return normalized_stops(stops)
}
pub fn (element &Element) for_each_color_stop_impl() []Stop { return element.for_each_color_stop() }
pub fn (element &Element) add_color_stops() []Stop { return element.for_each_color_stop() }

pub fn (transfer &ComponentTransfer) amplitude() f64 { return transfer.amplitude }
pub fn (transfer &ComponentTransfer) exponent() f64 { return transfer.exponent }
pub fn (transfer &ComponentTransfer) intercept() f64 { return transfer.intercept }
pub fn (transfer &ComponentTransfer) slope() f64 { return transfer.slope }
pub fn (transfer &ComponentTransfer) table_values() []f64 { return transfer.table_values.clone() }
pub fn (transfer &ComponentTransfer) table_float_values() []f32 { return transfer.table_values.map(f32(it)) }
pub fn (transfer &ComponentTransfer) type_from_attribute() ComponentTransferType { return transfer.type_ }

pub fn DecodedImageData.create(viewbox ?ViewBox, width ?f64, height ?f64) DecodedImageData {
	return DecodedImageData{ viewbox: viewbox, width: width, height: height }
}
pub fn (image &DecodedImageData) surface() []u8 {
	width := int(image.intrinsic_width() or { 0 }); height := int(image.intrinsic_height() or { 0 })
	return []u8{len: width * height * 4}
}
pub fn (image &DecodedImageData) render_to_surface() []u8 { return image.surface() }
pub fn (image &DecodedImageData) record_display_list() []string { return ['render_svg_${image.intrinsic_width() or { 0 }}x${image.intrinsic_height() or { 0 }}'] }
pub fn (image &DecodedImageData) paint() []u8 { return image.surface() }
pub fn (image &DecodedImageData) svg_document() string { return if image.viewbox != none { 'svg' } else { '' } }

pub fn (primitive &FilterPrimitive) this_svg_element() FilterPrimitive { return *primitive }

pub struct SVGPageClient {
pub:
	id_       u64
	headless_ bool
	dpr_      f64 = 1
	zoom_     f64 = 1
	screen_   Rect
mut:
	open_     bool = true
	finished_inputs_ []u64
}

pub fn SVGPageClient.create(id u64, headless bool) &SVGPageClient {
	return &SVGPageClient{ id_: id, headless_: headless }
}
pub fn (_ &SVGPageClient) is_svg_page_client() bool { return true }
pub fn (client &SVGPageClient) id() u64 { return client.id_ }
pub fn (client &SVGPageClient) is_headless() bool { return client.headless_ }
pub fn (client &SVGPageClient) is_connection_open() bool { return client.open_ }
pub fn (client &SVGPageClient) device_pixel_ratio() f64 { return client.dpr_ }
pub fn (client &SVGPageClient) device_pixels_per_css_pixel() f64 { return client.dpr_ * client.zoom_ }
pub fn (client &SVGPageClient) zoom_level() f64 { return client.zoom_ }
pub fn (client &SVGPageClient) screen_rect() Rect { return client.screen_ }
pub fn (_ &SVGPageClient) screen_count() int { return 1 }
pub fn (_ &SVGPageClient) preferred_color_scheme() string { return 'auto' }
pub fn (_ &SVGPageClient) preferred_contrast() string { return 'auto' }
pub fn (_ &SVGPageClient) preferred_motion() string { return 'auto' }
pub fn (_ &SVGPageClient) palette() string { return 'default' }
pub fn (_ &SVGPageClient) display_list_player_type() string { return 'software' }
pub fn (client &SVGPageClient) page() u64 { return client.id_ }
pub fn (_ &SVGPageClient) input_event_queue() []u64 { return []u64{} }
pub fn (mut client SVGPageClient) report_finished_handling_input_event(id u64) { client.finished_inputs_ << id }
pub fn (_ &SVGPageClient) request_file(path string) ?string { return if path.len > 0 { path } else { none } }

pub fn (viewport &SvgViewport) current_scale() f64 { return viewport.current_scale }
pub fn (mut viewport SvgViewport) set_current_scale(value f64) { viewport.current_scale = value }
pub fn (viewport &SvgViewport) current_translate() Point { return viewport.current_translate }
pub fn (_ &SvgViewport) active_view_element() ?Element { return none }
pub fn (_ &SvgViewport) set_active_view_element(_ ?Element) {}
pub fn (_ &SvgViewport) is_svg_container() bool { return true }
pub fn (_ &SvgViewport) requires_svg_container() bool { return false }
pub fn (mut viewport SvgViewport) set_fallback_view_box_for_svg_as_image(value ?ViewBox) { viewport.fallback_viewbox = value }
pub fn (mut viewport SvgViewport) update_fallback_view_box_for_svg_as_image(width f64, height f64) { viewport.fallback_viewbox = ViewBox{ width: width, height: height } }
pub fn (viewport &SvgViewport) width_style_value_from_attribute() f64 { box := viewport.active_viewbox() or { return 0 }; return box.width }
pub fn (viewport &SvgViewport) height_style_value_from_attribute() f64 { box := viewport.active_viewbox() or { return 0 }; return box.height }
pub fn (viewport &SvgViewport) negotiate_natural_metrics() Point { return Point{ x: viewport.width_style_value_from_attribute(), y: viewport.height_style_value_from_attribute() } }
pub fn (_ &SvgViewport) suspend_redraw(_ int) int { return 1 }
pub fn (_ &SvgViewport) unsuspend_redraw(_ int) {}
pub fn (_ &SvgViewport) unsuspend_redraw_all() {}
pub fn (_ &SvgViewport) force_redraw() {}
pub fn (_ &SvgViewport) deselect_all() {}
pub fn (_ &SvgViewport) check_intersection(first Rect, second Rect) bool { return rects_intersect(first, second) }
pub fn (_ &SvgViewport) check_enclosure(outer Rect, inner Rect) bool { return inner.x >= outer.x && inner.y >= outer.y && inner.x + inner.width <= outer.x + outer.width && inner.y + inner.height <= outer.y + outer.height }
pub fn (_ &SvgViewport) get_intersection_list(area Rect, elements []Element) []Element { return elements.filter(rects_intersect(area, it.get_b_box())) }
pub fn (_ &SvgViewport) get_enclosure_list(area Rect, elements []Element) []Element { return elements.filter(it.get_b_box().x >= area.x && it.get_b_box().y >= area.y && it.get_b_box().x + it.get_b_box().width <= area.x + area.width && it.get_b_box().y + it.get_b_box().height <= area.y + area.height) }
pub fn (_ &SvgViewport) create_svg_length() SvgLength { return SvgLength.create(0, .number, false) }
pub fn (_ &SvgViewport) create_svg_matrix() AffineTransform { return AffineTransform{} }
pub fn (_ &SvgViewport) create_svg_point() Point { return Point{} }
pub fn (_ &SvgViewport) create_svg_rect() Rect { return Rect{} }
pub fn (_ &SvgViewport) create_svg_transform() Transform { return Transform.create() }

fn rects_intersect(first Rect, second Rect) bool {
	return first.x < second.x + second.width && second.x < first.x + first.width
		&& first.y < second.y + second.height && second.y < first.y + first.height
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Direct entry points for the SVG element hierarchy. The standalone port uses
// one tagged Element record; methods project the same attributes that the C++
// subclasses reflect through WebIDL wrappers.
module svg

import math

pub struct SvgPaintStyle {
pub:
	color   u32
	opacity f64 = 1
	reference string
}

fn (element &Element) number_percentage_attribute(name string, fallback NumberPercentage) NumberPercentage {
	return parse_number_percentage(element.attributes[name] or { '' }) or { fallback }
}

fn (element &Element) number_attribute(name string, fallback f64) f64 {
	return parse_single_number(element.attributes[name] or { '' }) or { fallback }
}

fn parse_svg_color(value string) ?u32 {
	text := value.trim_space()
	if text.len == 7 && text[0] == `#` {
		return u32(text[1..].parse_uint(16, 32) or { return none }) | 0xff000000
	}
	return match text.to_lower() {
		'black' { u32(0xff000000) }
		'white' { u32(0xffffffff) }
		'red' { u32(0xffff0000) }
		'green' { u32(0xff008000) }
		'blue' { u32(0xff0000ff) }
		'transparent' { u32(0) }
		else { none }
	}
}

pub fn (element &Element) x() NumberPercentage { return element.number_percentage_attribute('x', number(0)) }
pub fn (element &Element) y() NumberPercentage { return element.number_percentage_attribute('y', number(0)) }
pub fn (element &Element) x1() NumberPercentage { return element.number_percentage_attribute('x1', percentage(0)) }
pub fn (element &Element) y1() NumberPercentage { return element.number_percentage_attribute('y1', percentage(0)) }
pub fn (element &Element) x2() NumberPercentage { return element.number_percentage_attribute('x2', percentage(100)) }
pub fn (element &Element) y2() NumberPercentage { return element.number_percentage_attribute('y2', percentage(0)) }
pub fn (element &Element) cx() NumberPercentage { return element.number_percentage_attribute('cx', percentage(50)) }
pub fn (element &Element) cy() NumberPercentage { return element.number_percentage_attribute('cy', percentage(50)) }
pub fn (element &Element) r() NumberPercentage { return element.number_percentage_attribute('r', percentage(50)) }
pub fn (element &Element) rx() NumberPercentage { return element.number_percentage_attribute('rx', number(0)) }
pub fn (element &Element) ry() NumberPercentage { return element.number_percentage_attribute('ry', number(0)) }
pub fn (element &Element) fx() NumberPercentage { return element.number_percentage_attribute('fx', element.cx()) }
pub fn (element &Element) fy() NumberPercentage { return element.number_percentage_attribute('fy', element.cy()) }
pub fn (element &Element) fr() NumberPercentage { return element.number_percentage_attribute('fr', percentage(0)) }

pub fn (element &Element) get_path() Path {
	return geometry_path(*element, 100, 100)
}

pub fn (element &Element) calculate_used_corner_radius_values(width f64, height f64) Point {
	mut rx := element.rx().resolve_relative_to(width)
	mut ry := element.ry().resolve_relative_to(height)
	if rx == 0 && 'ry' in element.attributes { rx = ry }
	if ry == 0 && 'rx' in element.attributes { ry = rx }
	return Point{ x: math.min(rx, width / 2), y: math.min(ry, height / 2) }
}

pub fn (element &Element) bounding_box(viewport_width f64, viewport_height f64) Rect {
	points := geometry_path(*element, viewport_width, viewport_height).endpoints()
	if points.len == 0 { return Rect{} }
	mut min_x := points[0].x
	mut max_x := points[0].x
	mut min_y := points[0].y
	mut max_y := points[0].y
	for point in points[1..] {
		min_x = math.min(min_x, point.x); max_x = math.max(max_x, point.x)
		min_y = math.min(min_y, point.y); max_y = math.max(max_y, point.y)
	}
	return Rect{ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
}

pub fn (element &Element) get_b_box() Rect { return element.bounding_box(100, 100) }
pub fn (element &Element) get_ctm() AffineTransform { return element.element_transform() }
pub fn (element &Element) get_screen_ctm() AffineTransform { return element.element_transform() }
pub fn (element &Element) element_transform() AffineTransform { return svg.element_transform(*element) }
pub fn (element &Element) transform() AnimatedTransformList {
	list := TransformList{ items: parse_transform(element.attributes['transform'] or { '' }) or { []Transform{} } }
	return AnimatedTransformList.create(list)
}

pub fn (element &Element) active_view_box() ?ViewBox {
	return parse_viewbox(element.attributes['viewBox'] or { element.attributes['viewbox'] or { '' } })
}

pub fn (element &Element) fill_color() ?u32 { return parse_svg_color(element.attributes['fill'] or { 'black' }) }
pub fn (element &Element) stroke_color() ?u32 { return parse_svg_color(element.attributes['stroke'] or { '' }) }
pub fn (element &Element) fill_opacity() ?f64 { return element.number_attribute('fill-opacity', 1) }
pub fn (element &Element) stroke_opacity() ?f64 { return element.number_attribute('stroke-opacity', 1) }
pub fn (element &Element) stroke_width() ?f64 { return element.number_attribute('stroke-width', 1) }
pub fn (element &Element) stroke_dashoffset() ?f64 { return element.number_attribute('stroke-dashoffset', 0) }
pub fn (element &Element) stroke_dasharray() []f32 { return (parse_number_sequence(element.attributes['stroke-dasharray'] or { '' }) or { []f64{} }).map(f32(it)) }
pub fn (element &Element) stroke_linecap() ?string { return element.attribute('stroke-linecap') }
pub fn (element &Element) stroke_linejoin() ?string { return element.attribute('stroke-linejoin') }
pub fn (element &Element) stroke_miterlimit() ?f64 { return element.number_attribute('stroke-miterlimit', 4) }
pub fn (element &Element) fill_rule() ?FillRule { return svg_fill_rule(element.attributes['fill-rule'] or { 'nonzero' }) }
pub fn (element &Element) clip_rule() ?FillRule { return svg_fill_rule(element.attributes['clip-rule'] or { 'nonzero' }) }

fn svg_fill_rule(value string) ?FillRule {
	return match value { 'nonzero' { FillRule.nonzero } 'evenodd' { FillRule.evenodd } else { none } }
}
pub fn (element &Element) paint_order() []string { return (element.attributes['paint-order'] or { 'normal' }).split(' ') }
pub fn (element &Element) visible_stroke_width() f64 {
	color := element.stroke_color() or { return 0 }
	if color >> 24 == 0 { return 0 }
	return element.stroke_width() or { 0 }
}

pub fn (element &Element) fill_paint_style() ?SvgPaintStyle {
	color := element.fill_color() or { return none }
	return SvgPaintStyle{ color: color, opacity: element.fill_opacity() or { 1 } }
}

pub fn (element &Element) stroke_paint_style() ?SvgPaintStyle {
	color := element.stroke_color() or { return none }
	return SvgPaintStyle{ color: color, opacity: element.stroke_opacity() or { 1 } }
}

pub fn (element &Element) svg_paint_computed_value_to_gfx_paint_style(value string) ?SvgPaintStyle {
	color := parse_svg_color(value) or { return none }
	return SvgPaintStyle{ color: color }
}

pub fn (element &Element) fill_pattern() ?string { return url_reference(element.attributes['fill'] or { '' }) }
pub fn (element &Element) stroke_pattern() ?string { return url_reference(element.attributes['stroke'] or { '' }) }
pub fn (element &Element) mask() ?string { return url_reference(element.attributes['mask'] or { '' }) }
pub fn (element &Element) clip_path() ?string { return url_reference(element.attributes['clip-path'] or { '' }) }

fn url_reference(value string) ?string {
	if value.starts_with('url(#') && value.ends_with(')') { return value[5..value.len - 1] }
	return none
}

pub fn (element &Element) resolve_url_to_element(url string, document map[string]Element) ?Element {
	id := url_reference(url) or { url.trim_left('#') }
	return document[id] or { none }
}

pub fn (element &Element) try_resolve_url_to(url string, document map[string]Element) ?Element {
	return element.resolve_url_to_element(url, document)
}

pub fn (_ &Element) resolve_relative_to_viewport_size(value NumberPercentage, viewport f64) f64 {
	return value.resolve_relative_to(viewport)
}

pub fn (element &Element) get_total_length() f64 {
	points := element.get_path().endpoints()
	mut total := 0.0
	for index in 1 .. points.len {
		dx := points[index].x - points[index - 1].x
		dy := points[index].y - points[index - 1].y
		total += math.sqrt(dx * dx + dy * dy)
	}
	return total
}

pub fn (element &Element) get_point_at_length(distance f64) Point {
	points := element.get_path().endpoints()
	if points.len == 0 { return Point{} }
	mut remaining := if distance < 0 { 0.0 } else { distance }
	for index in 1 .. points.len {
		start := points[index - 1]; end := points[index]
		dx := end.x - start.x; dy := end.y - start.y
		segment := math.sqrt(dx * dx + dy * dy)
		if remaining <= segment {
			ratio := if segment == 0 { 0.0 } else { remaining / segment }
			return Point{ x: start.x + dx * ratio, y: start.y + dy * ratio }
		}
		remaining -= segment
	}
	return points.last()
}

pub fn (element &Element) path_length() f64 { return element.number_attribute('pathLength', 0) }

pub fn (element &Element) in1() string { return element.attributes['in'] or { '' } }
pub fn (element &Element) in2() string { return element.attributes['in2'] or { '' } }
pub fn (element &Element) dx() f64 { return element.number_attribute('dx', if element.tag == 'feDropShadow' { 2 } else { 0 }) }
pub fn (element &Element) dy() f64 { return element.number_attribute('dy', if element.tag == 'feDropShadow' { 2 } else { 0 }) }
pub fn (element &Element) std_deviation_x() f64 { return number_optional_number(element.attributes['stdDeviation'] or { '' }, if element.tag == 'feDropShadow' { 2 } else { 0 }).x }
pub fn (element &Element) std_deviation_y() f64 { return number_optional_number(element.attributes['stdDeviation'] or { '' }, if element.tag == 'feDropShadow' { 2 } else { 0 }).y }
pub fn (mut element Element) set_std_deviation(x f64, y f64) { element.attributes['stdDeviation'] = '${format_number(x)} ${format_number(y)}' }
pub fn (element &Element) edge_mode() string { return element.attributes['edgeMode'] or { 'duplicate' } }
pub fn (element &Element) flood_color() u32 { return parse_svg_color(element.attributes['flood-color'] or { 'black' }) or { u32(0xff000000) } }
pub fn (element &Element) flood_opacity() f64 { return element.number_attribute('flood-opacity', 1) }
pub fn (element &Element) k1() f64 { return element.number_attribute('k1', 0) }
pub fn (element &Element) k2() f64 { return element.number_attribute('k2', 0) }
pub fn (element &Element) k3() f64 { return element.number_attribute('k3', 0) }
pub fn (element &Element) k4() f64 { return element.number_attribute('k4', 0) }
pub fn (element &Element) scale() f64 { return element.number_attribute('scale', 0) }
pub fn (element &Element) x_channel_selector() ChannelSelector { return channel_selector(element.attributes['xChannelSelector'] or { 'A' }) }
pub fn (element &Element) y_channel_selector() ChannelSelector { return channel_selector(element.attributes['yChannelSelector'] or { 'A' }) }
pub fn (element &Element) morphology_operator() MorphologyOperator { return morphology_operator(element.attributes['operator'] or { 'erode' }) }
pub fn (element &Element) radius_x() f64 { return number_optional_number(element.attributes['radius'] or { '' }, 0).x }
pub fn (element &Element) radius_y() f64 { return number_optional_number(element.attributes['radius'] or { '' }, 0).y }
pub fn (element &Element) base_frequency_x() f64 { return number_optional_number(element.attributes['baseFrequency'] or { '' }, 0).x }
pub fn (element &Element) base_frequency_y() f64 { return number_optional_number(element.attributes['baseFrequency'] or { '' }, 0).y }
pub fn (element &Element) num_octaves() int { return parse_integer(element.attributes['numOctaves'] or { '' }) or { 1 } }
pub fn (element &Element) seed() f64 { return element.number_attribute('seed', 0) }
pub fn (element &Element) stitch_tiles() StitchType { return stitch_type(element.attributes['stitchTiles'] or { '' }) }
pub fn (element &Element) mode_for_bindings() string { return element.attributes['mode'] or { 'normal' } }
pub fn (element &Element) values() []f64 { return parse_number_sequence(element.attributes['values'] or { '' }) or { []f64{} } }
pub fn (element &Element) content_rect() Rect { return element.bounding_box(100, 100) }
pub fn (element &Element) current_image_bitmap() ?string { return if element.href().len > 0 { element.href() } else { none } }
pub fn (_ &Element) process_href() {}

pub fn (element &Element) stop_color() u32 { return parse_svg_color(element.attributes['stop-color'] or { 'black' }) or { u32(0xff000000) } }
pub fn (element &Element) stop_opacity() f64 { return element.number_attribute('stop-opacity', 1) }
pub fn (element &Element) stop_offset() f64 { return element.number_percentage_attribute('offset', number(0)).value }

pub fn (element &Element) filter_units() Units { return parse_units(element.attributes['filterUnits'] or { '' }) or { Units.object_bounding_box } }
pub fn (element &Element) primitive_units() Units { return parse_units(element.attributes['primitiveUnits'] or { '' }) or { Units.user_space_on_use } }
pub fn (element &Element) gfx_filter() FilterGraph {
	mut primitives := []FilterPrimitive{}
	for child in element.children {
		primitives << FilterPrimitive{ kind: child.tag, in1: child.in1(), in2: child.in2(), result: child.attributes['result'] or { '' }, parameters: child.attributes.clone() }
	}
	return build_filter_graph(primitives)
}

pub fn (element &Element) mask_units() Units { return parse_units(element.attributes['maskUnits'] or { '' }) or { Units.object_bounding_box } }
pub fn (element &Element) mask_content_units() Units { return parse_units(element.attributes['maskContentUnits'] or { '' }) or { Units.user_space_on_use } }
pub fn (element &Element) resolve_masking_area(target Rect) Rect { return svg.resolve_masking_area(target) }
pub fn (element &Element) clip_path_units() Units { return parse_units(element.attributes['clipPathUnits'] or { '' }) or { Units.user_space_on_use } }

pub fn (element &Element) text_anchor() ?TextAnchor { return svg.text_anchor(element.attributes['text-anchor'] or { '' }) }
pub fn (element &Element) get_number_of_chars() int { return element.number_of_chars() }
pub fn (element &Element) get_start_position_of_char(index int) !Point {
	if index < 0 || index >= element.number_of_chars() { return error('IndexSizeError') }
	positioning := text_positioning(element.attributes)
	return positioning.apply_to_text_position(index, Point{})
}
pub fn (element &Element) path_or_shape(document map[string]Element) ?Element { return resolve_geometry_reference(element.href(), document) }

pub fn (element &Element) is_svg_a_element() bool { return element.tag == 'a' }
pub fn (element &Element) is_svg_circle_element() bool { return element.tag == 'circle' }
pub fn (element &Element) is_svg_foreign_object_element() bool { return element.tag == 'foreignObject' }
pub fn (element &Element) is_svg_g_element() bool { return element.tag == 'g' }
pub fn (element &Element) is_svg_mask_element() bool { return element.tag == 'mask' }
pub fn (element &Element) is_svg_script_element() bool { return element.tag == 'script' }
pub fn (element &Element) is_svg_style_element() bool { return element.tag == 'style' }
pub fn (element &Element) is_svg_symbol_element() bool { return element.tag == 'symbol' }
pub fn (element &Element) is_svg_use_element() bool { return element.tag == 'use' }
pub fn (element &Element) is_svg_view_element() bool { return element.tag == 'view' }
pub fn (element &Element) is_svg_graphics_element() bool { return element.tag !in ['defs', 'desc', 'metadata', 'script', 'style', 'title'] }
pub fn (element &Element) as_element() Element { return *element }

pub fn (element &Element) has_activation_behavior() bool { return element.is_svg_a_element() && element.href().len > 0 }
pub fn (element &Element) activation_behavior() ?string { return if element.has_activation_behavior() { element.href() } else { none } }
pub fn (element &Element) rel_list() []string { return (element.attributes['rel'] or { '' }).split(' ').filter(it.len > 0) }

pub fn (element &Element) should_include_in_accessibility_tree() bool { return element.includes_in_accessibility_tree() }
pub fn (element &Element) owner_svg_element() ?Element { return if element.tag == 'svg' { *element } else { none } }
pub fn (element &Element) viewport_element() ?Element { return element.owner_svg_element() }
pub fn (element &Element) requires_svg_container() bool { return element.tag != 'svg' }
pub fn (_ &Element) svg_animated_length_for_property(value NumberPercentage) AnimatedLength { return AnimatedLength.create(SvgLength.from_length_percentage(value)) }
pub fn (_ &Element) fake_animated_length_fixme(value f64) AnimatedLength { return AnimatedLength.create(SvgLength.create(value, .number, false)) }
pub fn (element &Element) cloned() Element { return clone_element_tree(*element) }
pub fn (_ &Element) adjust_computed_style() {}
pub fn (_ &Element) global_event_handlers_to_event_target() string { return 'EventTarget' }
pub fn (_ &Element) remove_from_use_element_that_reference_this() {}
pub fn (_ &Element) update_use_elements_that_reference_this() {}

pub fn (element &Element) is_parser_inserted() bool { return (element.attributes['_parser_inserted'] or { '' }) == 'true' }
pub fn (mut element Element) set_parser_inserted(value bool) { element.attributes['_parser_inserted'] = value.str() }
pub fn (mut element Element) set_source_line_number(value int) { element.attributes['_source_line'] = value.str() }
pub fn (element &Element) process_the_script_element() ?string {
	mut resource := ScriptResource{ href: element.href(), text: element.text }
	return resource.process()
}

pub fn (element &Element) is_direct_child_of_use_shadow_tree() bool { return (element.attributes['_use_shadow_child'] or { '' }) == 'true' }
pub fn (_ &Element) current_frame_index() int { return 0 }
pub fn (element &Element) intrinsic_width() ?f64 { return parse_length(element.attributes['width'] or { '' }) }
pub fn (element &Element) intrinsic_height() ?f64 { return parse_length(element.attributes['height'] or { '' }) }
pub fn (element &Element) intrinsic_aspect_ratio() ?f64 {
	width := element.intrinsic_width() or { return none }; height := element.intrinsic_height() or { return none }
	return if height == 0 { none } else { width / height }
}
pub fn (element &Element) is_image_available() bool { return element.href().len > 0 }
pub fn (_ &Element) set_visible_in_viewport(_ bool) {}
pub fn (_ &Element) animate() {}
pub fn (element &Element) decoded_image_data() DecodedImageData { return DecodedImageData{ width: element.intrinsic_width(), height: element.intrinsic_height() } }
pub fn (element &Element) current_image_bitmap_sized(width int, height int) []u8 { return if element.is_image_available() { []u8{len: width * height * 4} } else { []u8{} } }
pub fn (_ &Element) default_image_bitmap_sized(width int, height int) []u8 { return []u8{len: width * height * 4} }
pub fn (_ &Element) fetch_the_document() {}
pub fn (_ &Element) process_the_url() {}
pub fn (_ &Element) to_html_element() string { return 'img' }

pub fn (element &Element) is_valid_reference_element() bool { return valid_use_reference_tag(element.tag) }
pub fn (element &Element) is_referenced_element_same_document() bool { return element.href().starts_with('#') }
pub fn (element &Element) referenced_element(document map[string]Element) ?Element { return document[element.href().trim_left('#')] or { none } }
pub fn (element &Element) instance_root(document map[string]Element) ?Element { return element.referenced_element(document) }
pub fn (element &Element) animated_instance_root(document map[string]Element) ?Element { return element.referenced_element(document) }
pub fn (element &Element) clone_element_tree_as_our_shadow_tree(document map[string]Element) ?Element { target := element.referenced_element(document) or { return none }; return clone_element_tree(target) }
pub fn (element &Element) would_create_circular_reference(document map[string]Element) bool { mut visiting := map[string]bool{}; return element_has_use_cycle(*element, document, mut visiting) }
pub fn (element &Element) would_create_circular_reference_impl(document map[string]Element) bool { return element.would_create_circular_reference(document) }
pub fn (_ &Element) svg_element_changed() {}
pub fn (_ &Element) svg_element_removed() {}

pub fn (element &Element) text_positioning() TextPositioning { return svg.text_positioning(element.attributes) }
pub fn (element &Element) ensure_length_list(name string) LengthList {
	values := parse_number_sequence(element.attributes[name] or { '' }) or { []f64{} }
	return LengthList{ items: values.map(SvgLength{ value: it, unit: .number }) }
}
pub fn (element &Element) rotate() NumberList { return NumberList{ items: parse_number_sequence(element.attributes['rotate'] or { '' }) or { []f64{} } } }

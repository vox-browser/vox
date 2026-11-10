// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Direct entry points for the SVG element hierarchy. The standalone port uses
// one tagged Element record; methods project the same attributes that the C++
// subclasses reflect through WebIDL wrappers.
module svg

import dom
import math

pub struct SvgPaintStyle {
pub:
	color     u32
	opacity   f64 = 1
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
	if text.len == 9 && text[0] == `#` {
		rgb := u32(text[1..7].parse_uint(16, 24) or { return none })
		alpha := u32(text[7..9].parse_uint(16, 8) or { return none })
		return (alpha << 24) | rgb
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

pub fn (element &Element) x() NumberPercentage {
	return element.number_percentage_attribute('x', number(0))
}

pub fn (element &Element) y() NumberPercentage {
	return element.number_percentage_attribute('y', number(0))
}

pub fn (element &Element) x1() NumberPercentage {
	return element.number_percentage_attribute('x1', percentage(0))
}

pub fn (element &Element) y1() NumberPercentage {
	return element.number_percentage_attribute('y1', percentage(0))
}

pub fn (element &Element) x2() NumberPercentage {
	return element.number_percentage_attribute('x2', if element.tag == 'linearGradient' {
		percentage(100)
	} else {
		number(0)
	})
}

pub fn (element &Element) y2() NumberPercentage {
	return element.number_percentage_attribute('y2', percentage(0))
}

pub fn (element &Element) cx() NumberPercentage {
	return element.number_percentage_attribute('cx', if element.tag == 'radialGradient' {
		percentage(50)
	} else {
		number(0)
	})
}

pub fn (element &Element) cy() NumberPercentage {
	return element.number_percentage_attribute('cy', if element.tag == 'radialGradient' {
		percentage(50)
	} else {
		number(0)
	})
}

pub fn (element &Element) r() NumberPercentage {
	return element.number_percentage_attribute('r', if element.tag == 'radialGradient' {
		percentage(50)
	} else {
		number(0)
	})
}

pub fn (element &Element) rx() NumberPercentage {
	return element.number_percentage_attribute('rx', number(0))
}

pub fn (element &Element) ry() NumberPercentage {
	return element.number_percentage_attribute('ry', number(0))
}

pub fn (element &Element) fx() NumberPercentage {
	return element.number_percentage_attribute('fx', element.cx())
}

pub fn (element &Element) fy() NumberPercentage {
	return element.number_percentage_attribute('fy', element.cy())
}

pub fn (element &Element) fr() NumberPercentage {
	return element.number_percentage_attribute('fr', percentage(0))
}

pub fn (element &Element) get_path() Path {
	return geometry_path(*element, 100, 100)
}

pub fn (element &Element) calculate_used_corner_radius_values(viewport_width f64, viewport_height f64) Point {
	rx_value := parse_number_percentage(element.attributes['rx'] or { '' })
	ry_value := parse_number_percentage(element.attributes['ry'] or { '' })
	mut rx := 0.0
	mut ry := 0.0
	if supplied_rx := rx_value {
		rx = supplied_rx.resolve_relative_to(viewport_width)
		if supplied_ry := ry_value {
			ry = supplied_ry.resolve_relative_to(viewport_height)
		} else {
			ry = rx
		}
	} else if supplied_ry := ry_value {
		ry = supplied_ry.resolve_relative_to(viewport_height)
		rx = ry
	}
	width := element.number_percentage_attribute('width', number(0)).resolve_relative_to(viewport_width)
	height := element.number_percentage_attribute('height', number(0)).resolve_relative_to(viewport_height)
	return Point{ x: math.min(rx, width / 2), y: math.min(ry, height / 2) }
}

pub fn (element &Element) bounding_box(viewport_width f64, viewport_height f64) Rect {
	points := geometry_path(*element, viewport_width, viewport_height).endpoints()
	if points.len == 0 {
		return Rect{}
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
	return Rect{ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
}

pub fn (element &Element) get_b_box() Rect {
	return element.bounding_box(100, 100)
}

pub fn (_ &Element) get_ctm() AffineTransform {
	return AffineTransform{}
}

pub fn (_ &Element) get_screen_ctm() AffineTransform {
	return AffineTransform{}
}

pub fn (element &Element) element_transform() AffineTransform {
	return svg.element_transform(*element)
}

pub fn (element &Element) transform() AnimatedTransformList {
	return AnimatedTransformList.create(TransformList{ read_only: true }, TransformList{
		read_only: true
	})
}

pub fn (element &Element) active_view_box() ?ViewBox {
	if element.tag == 'clipPath' && element.clip_path_units() == .object_bounding_box {
		return ViewBox{ width: 1, height: 1 }
	}
	if element.tag == 'mask' && element.mask_content_units() == .object_bounding_box {
		return ViewBox{ width: 1, height: 1 }
	}
	if element.tag in ['svg', 'symbol', 'view', 'pattern'] {
		return parse_viewbox(element.attributes['viewBox'] or { element.attributes['viewbox'] or { '' } })
	}
	return none
}

pub fn (element &Element) fill_color() ?u32 {
	return parse_svg_color(element.attributes['fill'] or { 'black' })
}

pub fn (element &Element) stroke_color() ?u32 {
	return parse_svg_color(element.attributes['stroke'] or { '' })
}

pub fn (element &Element) fill_opacity() ?f64 {
	return element.number_attribute('fill-opacity', 1)
}

pub fn (element &Element) stroke_opacity() ?f64 {
	return element.number_attribute('stroke-opacity', 1)
}

pub fn (element &Element) stroke_width() ?f64 {
	value := parse_number_percentage(element.attributes['stroke-width'] or { '1' }) or { return none }
	return element.resolve_relative_to_viewport_size(value)
}

pub fn (element &Element) stroke_dashoffset() ?f64 {
	value := parse_number_percentage(element.attributes['stroke-dashoffset'] or { '0' }) or {
		return none
	}
	return element.resolve_relative_to_viewport_size(value)
}

pub fn (element &Element) stroke_dasharray() []f32 {
	mut dasharray := []f32{}
	for item in (element.attributes['stroke-dasharray'] or { '' }).replace(',', ' ').fields() {
		value := parse_number_percentage(item) or { return [] }
		dasharray << f32(element.resolve_relative_to_viewport_size(value))
	}
	if dasharray.len % 2 == 1 {
		original_length := dasharray.len
		for index in 0 .. original_length {
			dasharray << dasharray[index]
		}
	}
	mut all_zero := true
	for value in dasharray {
		if value < 0 {
			return []
		}
		if value != 0 {
			all_zero = false
		}
	}
	return if all_zero { [] } else { dasharray }
}

pub fn (element &Element) stroke_linecap() ?string {
	return element.attribute('stroke-linecap')
}

pub fn (element &Element) stroke_linejoin() ?string {
	return element.attribute('stroke-linejoin')
}

pub fn (element &Element) stroke_miterlimit() ?f64 {
	return element.number_attribute('stroke-miterlimit', 4)
}

pub fn (element &Element) fill_rule() ?FillRule {
	return svg_fill_rule(element.attributes['fill-rule'] or { 'nonzero' })
}

pub fn (element &Element) clip_rule() ?FillRule {
	return svg_fill_rule(element.attributes['clip-rule'] or { 'nonzero' })
}

fn svg_fill_rule(value string) ?FillRule {
	return match value {
		'nonzero' { FillRule.nonzero }
		'evenodd' { FillRule.evenodd }
		else { none }
	}
}

pub fn (element &Element) paint_order() []string {
	return (element.attributes['paint-order'] or { 'normal' }).split(' ')
}

pub fn (element &Element) visible_stroke_width() f64 {
	color := element.stroke_color() or { return 0 }
	if color >> 24 == 0 {
		return 0
	}
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

pub fn (element &Element) fill_pattern() ?string {
	return url_reference(element.attributes['fill'] or { '' })
}

pub fn (element &Element) stroke_pattern() ?string {
	return url_reference(element.attributes['stroke'] or { '' })
}

pub fn (element &Element) mask() ?string {
	return url_reference(element.attributes['mask'] or { '' })
}

pub fn (element &Element) clip_path() ?string {
	return url_reference(element.attributes['clip-path'] or { '' })
}

fn url_reference(value string) ?string {
	if value.starts_with('url(#') && value.ends_with(')') {
		return value[5..value.len - 1]
	}
	return none
}

pub fn (element &Element) resolve_url_to_element(url string, document map[string]Element) ?Element {
	id := if raw_id := url_reference(url) {
		decode_fragment_identifier(raw_id)
	} else {
		local_fragment_identifier(url) or { return none }
	}
	return document[id] or { none }
}

pub fn (element &Element) try_resolve_url_to(url string, document map[string]Element) ?Element {
	return element.resolve_url_to_element(url, document)
}

pub fn (element &Element) viewport_percentage_basis() f64 {
	viewport := element.viewport_size_for_percentage_resolution()
	return (viewport.width + viewport.height) * 0.5
}

pub fn (element &Element) resolve_relative_to_viewport_size(value NumberPercentage) f64 {
	return value.resolve_relative_to(element.viewport_percentage_basis())
}

pub fn (element &Element) get_total_length() f64 {
	viewport_size := element.viewport_size_for_percentage_resolution()
	return element.get_total_length_for_viewport(viewport_size.width, viewport_size.height)
}

pub fn (element &Element) get_total_length_for_viewport(viewport_width f64, viewport_height f64) f64 {
	return geometry_path(*element, viewport_width, viewport_height).length()
}

pub fn (_ &Element) get_point_at_length(_ f64) Point {
	return Point{}
}

pub fn (element &Element) path_length() f64 {
	return element.number_attribute('pathLength', 0)
}

// Keep authored pathLength separate from getTotalLength(), which always
// reports the actual geometry length. Percentages in the dash array and
// offset have already resolved to user units before this calibration.
pub fn (element &Element) calibrated_stroke_dashes(path Path, dashes []f64, offset f64) ([]f64, f64) {
	if dashes.len == 0 || element.tag !in ['circle', 'ellipse', 'line', 'path', 'polygon', 'polyline', 'rect'] {
		return dashes, offset
	}
	author_length := parse_single_number(element.attributes['pathLength'] or { '' }) or {
		return dashes, offset
	}
	if author_length == 0 {
		// For compatibility, zero pathLength paints a solid stroke, including
		// dash arrays containing zero-length dashes or gaps.
		return []f64{}, 0
	}
	if author_length > 0 {
		scale := path.length() / author_length
		return dashes.map(it * scale), offset * scale
	}
	return dashes, offset
}

pub fn (element &Element) in1() string {
	return element.attributes['in'] or { '' }
}

pub fn (element &Element) in2() string {
	return element.attributes['in2'] or { '' }
}

pub fn (element &Element) dx() f64 {
	return element.number_attribute('dx', if element.tag == 'feDropShadow' { 2 } else { 0 })
}

pub fn (element &Element) dy() f64 {
	return element.number_attribute('dy', if element.tag == 'feDropShadow' { 2 } else { 0 })
}

pub fn (element &Element) std_deviation_x() f64 {
	return number_optional_number(element.attributes['stdDeviation'] or { '' }, if element.tag == 'feDropShadow' {
		2
	} else {
		0
	}).x
}

pub fn (element &Element) std_deviation_y() f64 {
	return number_optional_number(element.attributes['stdDeviation'] or { '' }, if element.tag == 'feDropShadow' {
		2
	} else {
		0
	}).y
}

pub fn (mut element Element) set_std_deviation(x f64, y f64) {
	element.attributes['stdDeviation'] = '${format_number(x)} ${format_number(y)}'
}

pub fn (_ &Element) edge_mode() u16 {
	return 0
}

pub fn (element &Element) flood_color() u32 {
	return parse_svg_color(element.attributes['flood-color'] or { 'black' }) or { u32(0xff000000) }
}

pub fn (element &Element) flood_opacity() f64 {
	return element.number_attribute('flood-opacity', 1)
}

pub fn (element &Element) k1() f64 {
	return element.number_attribute('k1', 0)
}

pub fn (element &Element) k2() f64 {
	return element.number_attribute('k2', 0)
}

pub fn (element &Element) k3() f64 {
	return element.number_attribute('k3', 0)
}

pub fn (element &Element) k4() f64 {
	return element.number_attribute('k4', 0)
}

pub fn (element &Element) scale() f64 {
	return element.number_attribute('scale', 0)
}

pub fn (element &Element) x_channel_selector() ChannelSelector {
	return channel_selector(element.attributes['xChannelSelector'] or { 'A' })
}

pub fn (element &Element) y_channel_selector() ChannelSelector {
	return channel_selector(element.attributes['yChannelSelector'] or { 'A' })
}

pub fn (element &Element) morphology_operator() MorphologyOperator {
	return morphology_operator(element.attributes['operator'] or { 'erode' })
}

pub fn (element &Element) radius_x() f64 {
	return number_optional_number(element.attributes['radius'] or { '' }, 0).x
}

pub fn (element &Element) radius_y() f64 {
	return number_optional_number(element.attributes['radius'] or { '' }, 0).y
}

pub fn (element &Element) base_frequency_x() f64 {
	return number_optional_number(element.attributes['baseFrequency'] or { '' }, 0).x
}

pub fn (element &Element) base_frequency_y() f64 {
	return number_optional_number(element.attributes['baseFrequency'] or { '' }, 0).y
}

pub fn (element &Element) num_octaves() int {
	return parse_integer(element.attributes['numOctaves'] or { '' }) or { 1 }
}

pub fn (element &Element) seed() f64 {
	return element.number_attribute('seed', 0)
}

pub fn (element &Element) stitch_tiles() StitchType {
	return stitch_type(element.attributes['stitchTiles'] or { '' })
}

pub fn (element &Element) mode_for_bindings() string {
	mode := (element.attributes['mode'] or { 'normal' }).to_lower()
	return if mode in ['normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten', 'color-dodge',
		'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion', 'hue', 'saturation',
		'color', 'luminosity', 'plus-darker', 'plus-lighter'] {
		mode
	} else {
		'normal'
	}
}

pub fn (element &Element) values() string {
	return element.attributes['values'] or { '' }
}

pub fn (element &Element) content_rect() ?Rect {
	if !element.is_image_available() {
		return none
	}
	width := element.intrinsic_width() or { return none }
	height := element.intrinsic_height() or { return none }
	return Rect{ width: width, height: height }
}

pub fn (mut element Element) process_href() {
	element.process_the_url()
}

pub fn (element &Element) stop_color() u32 {
	return parse_svg_color(element.attributes['stop-color'] or { 'black' }) or { u32(0xff000000) }
}

pub fn (element &Element) stop_opacity() f64 {
	return element.number_attribute('stop-opacity', 1)
}

pub fn (element &Element) stop_offset() f64 {
	return element.number_percentage_attribute('offset', number(0)).value
}

pub fn (element &Element) filter_units() Units {
	return parse_units(element.attributes['filterUnits'] or { '' }) or { Units.object_bounding_box }
}

pub fn (element &Element) primitive_units() Units {
	return parse_units(element.attributes['primitiveUnits'] or { '' }) or { Units.user_space_on_use }
}

fn filter_interpolation_color_space(value string, inherited InterpolationColorSpace) InterpolationColorSpace {
	return match value.to_lower() {
		'linearrgb' { .linear_rgb }
		'auto', 'srgb' { .srgb }
		else { inherited }
	}
}

fn filter_primitive_from_element(element Element, inherited_color_space InterpolationColorSpace) FilterPrimitive {
	color_space := filter_interpolation_color_space(element.attributes['color-interpolation-filters'] or {
		''
	}, inherited_color_space)
	return FilterPrimitive{
		kind: element.tag
		in1: element.in1()
		in2: element.in2()
		result: element.attributes['result'] or { '' }
		parameters: element.attributes.clone()
		children: element.children.map(filter_primitive_from_element(it, color_space))
		color_space: color_space
	}
}

pub fn (element &Element) gfx_filter() FilterGraph {
	color_space := filter_interpolation_color_space(element.attributes['color-interpolation-filters'] or {
		''
	}, .linear_rgb)
	mut primitives := []FilterPrimitive{}
	for child in element.children {
		primitives << filter_primitive_from_element(child, color_space)
	}
	return build_filter_graph(primitives)
}

pub fn (element &Element) mask_units() Units {
	return parse_units(element.attributes['maskUnits'] or { '' }) or { Units.object_bounding_box }
}

pub fn (element &Element) mask_content_units() Units {
	return parse_units(element.attributes['maskContentUnits'] or { '' }) or { Units.user_space_on_use }
}

pub fn (element &Element) mask_x() NumberPercentage {
	return parse_number_percentage(element.attributes['x'] or { '' }) or { percentage(-10) }
}

pub fn (element &Element) mask_y() NumberPercentage {
	return parse_number_percentage(element.attributes['y'] or { '' }) or { percentage(-10) }
}

pub fn (element &Element) mask_width() NumberPercentage {
	return parse_number_percentage(element.attributes['width'] or { '' }) or { percentage(120) }
}

pub fn (element &Element) mask_height() NumberPercentage {
	return parse_number_percentage(element.attributes['height'] or { '' }) or { percentage(120) }
}

pub fn (element &Element) masking_area_in_user_space(target Rect, viewport_size Point) Rect {
	if element.mask_units() == .object_bounding_box {
		return Rect{
			x: target.x + element.mask_x().value * target.width
			y: target.y + element.mask_y().value * target.height
			width: element.mask_width().value * target.width
			height: element.mask_height().value * target.height
		}
	}
	return Rect{
		x: element.mask_x().resolve_relative_to(viewport_size.x)
		y: element.mask_y().resolve_relative_to(viewport_size.y)
		width: element.mask_width().resolve_relative_to(viewport_size.x)
		height: element.mask_height().resolve_relative_to(viewport_size.y)
	}
}

pub fn (element &Element) resolve_masking_area(target Rect, viewport_size Point,
	user_space_to_css_pixels AffineTransform) Rect {
	area := element.masking_area_in_user_space(target, viewport_size)
	if area.width <= 0 || area.height <= 0 {
		return Rect{}
	}
	mapped := user_space_to_css_pixels.map_rect(area)
	if mapped.width <= 0 || mapped.height <= 0 {
		return Rect{}
	}
	return mapped
}

pub fn (element &Element) clip_path_units() Units {
	return parse_units(element.attributes['clipPathUnits'] or { '' }) or { Units.user_space_on_use }
}

pub fn (element &Element) text_anchor() ?TextAnchor {
	return svg.text_anchor(element.attributes['text-anchor'] or { '' })
}

pub fn (element &Element) get_number_of_chars() int {
	return element.number_of_chars()
}

pub fn (_ &Element) get_start_position_of_char(_ int) !Point {
	return Point{}
}

pub fn (element &Element) path_or_shape(document map[string]Element) ?Element {
	return resolve_geometry_reference(element.href(), document)
}

// https://svgwg.org/svg2-draft/text.html#TextPathElementStartOffsetAttribute
pub fn (element &Element) start_offset_for_path_length(path_length f64) f64 {
	value := parse_number_percentage(element.attributes['startOffset'] or { '' }) or {
		return 0
	}
	return value.resolve_relative_to(path_length)
}

// https://w3c.github.io/svgwg/svg2-draft/text.html#__svg__SVGTextPathElement__startOffset
pub fn (element &Element) start_offset() AnimatedLength {
	return element.svg_animated_length_for_attribute('startOffset', .horizontal, SvgLengthValue.number(0))
}

pub fn (element &Element) is_svg_a_element() bool {
	return element.tag == 'a'
}

pub fn (element &Element) is_svg_circle_element() bool {
	return element.tag == 'circle'
}

pub fn (element &Element) is_svg_clip_path_element() bool {
	return element.tag == 'clipPath'
}

pub fn (element &Element) is_svg_foreign_object_element() bool {
	return element.tag == 'foreignObject'
}

pub fn (element &Element) is_svg_g_element() bool {
	return element.tag == 'g'
}

pub fn (element &Element) is_svg_gradient_element() bool {
	return element.tag in ['linearGradient', 'radialGradient']
}

pub fn (element &Element) is_svg_image_element() bool {
	return element.tag == 'image'
}

pub fn (element &Element) is_svg_pattern_element() bool {
	return element.tag == 'pattern'
}

pub fn (element &Element) is_svg_switch_element() bool {
	return element.tag == 'switch'
}

pub fn (element &Element) is_svg_mask_element() bool {
	return element.tag == 'mask'
}

pub fn (element &Element) is_svg_script_element() bool {
	return element.tag == 'script'
}

pub fn (element &Element) is_svg_style_element() bool {
	return element.tag == 'style'
}

pub fn (element &Element) is_svg_symbol_element() bool {
	return element.tag == 'symbol'
}

pub fn (element &Element) is_svg_use_element() bool {
	return element.tag == 'use'
}

pub fn (element &Element) is_svg_view_element() bool {
	return element.tag == 'view'
}

pub fn (element &Element) is_svg_graphics_element() bool {
	return element.tag in ['a', 'circle', 'clipPath', 'defs', 'ellipse', 'foreignObject', 'g', 'image',
		'line', 'mask', 'path', 'polygon', 'polyline', 'rect', 'svg', 'switch', 'symbol', 'text',
		'textPath', 'tspan', 'use', 'view']
}

pub fn (element &Element) as_element() Element {
	return *element
}

pub fn (element &Element) has_activation_behavior() bool {
	return element.is_svg_a_element() && element.href().len > 0
}

pub fn (element &Element) activation_behavior() ?string {
	return if element.has_activation_behavior() { element.href() } else { none }
}

pub fn (element &Element) rel_list() []string {
	return (element.attributes['rel'] or { '' }).split(' ').filter(it.len > 0)
}

pub fn (element &Element) should_include_in_accessibility_tree() bool {
	return element.includes_in_accessibility_tree()
}

pub fn (element &Element) requires_svg_container() bool {
	return element.tag != 'svg'
}

pub fn (element &Element) svg_animated_length_for_attribute(name string, directionality SvgLengthDirectionality, default_value SvgLengthValue) AnimatedLength {
	return AnimatedLength.create(SvgLength.create_reflected_attribute(*element, name, directionality, default_value, false))
}

pub fn (_ &Element) svg_animated_length_for_property(value NumberPercentage) AnimatedLength {
	return AnimatedLength.create(SvgLength.from_length_percentage(value))
}

pub fn (_ &Element) fake_animated_length_fixme(value f64) AnimatedLength {
	return AnimatedLength.create(SvgLength.create(value, .number, false))
}

pub fn (element &Element) cloned() Element {
	return clone_element_tree(*element)
}

pub fn (_ &Element) global_event_handlers_to_event_target() string {
	return 'EventTarget'
}

pub fn (element &Element) is_parser_inserted() bool {
	return (element.attributes['_parser_inserted'] or { '' }) == 'true'
}

pub fn (mut element Element) set_parser_inserted(value bool) {
	element.attributes['_parser_inserted'] = value.str()
}

pub fn (mut element Element) set_source_line_number(value int) {
	element.attributes['_source_line'] = value.str()
}

pub fn (mut element Element) process_the_script_element() ?string {
	if (element.attributes['_script_processed'] or { '' }) == 'true' {
		return none
	}
	element.attributes['_script_processed'] = 'true'
	mut resource := ScriptResource{ href: element.href(), text: element.text }
	return resource.process()
}

pub fn (element &Element) is_direct_child_of_use_shadow_tree() bool {
	return (element.attributes['_use_shadow_child'] or { '' }) == 'true'
}

pub fn (element &Element) current_frame_index() int {
	return element.current_frame_index_
}

pub fn (element &Element) intrinsic_width() ?f64 {
	if data := element.decoded_image_data_ {
		return data.intrinsic_width()
	}
	return element.image_resource.intrinsic_width
}

pub fn (element &Element) intrinsic_height() ?f64 {
	if data := element.decoded_image_data_ {
		return data.intrinsic_height()
	}
	return element.image_resource.intrinsic_height
}

pub fn (element &Element) intrinsic_aspect_ratio() ?f64 {
	width := element.intrinsic_width() or { return none }
	height := element.intrinsic_height() or { return none }
	return if height == 0 { none } else { width / height }
}

pub fn (element &Element) is_image_available() bool {
	return element.image_resource.state == .ready && element.decoded_image_data_ != none
}

pub fn (_ &Element) set_visible_in_viewport(_ bool) {}

pub fn (mut element Element) animate() {
	data := element.decoded_image_data_ or { return }
	if data.frame_count <= 1 {
		return
	}
	element.current_frame_index_ = (element.current_frame_index_ + 1) % data.frame_count
}

pub fn (element &Element) decoded_image_data() ?&DecodedImageData {
	return element.decoded_image_data_
}

pub fn (element &Element) current_image_frame_sized(width int, height int) ?&dom.DecodedImageFrame_ {
	mut data := element.decoded_image_data_ or { return none }
	return data.current_frame(width, height)
}

pub fn (element &Element) current_image_frame() ?&dom.DecodedImageFrame_ {
	width := int(element.intrinsic_width() or { return none })
	height := int(element.intrinsic_height() or { return none })
	return element.current_image_frame_sized(width, height)
}

pub fn (element &Element) default_image_frame_sized(width int, height int) ?&dom.DecodedImageFrame_ {
	mut data := element.decoded_image_data_ or { return none }
	return data.default_frame(width, height)
}

pub fn (mut element Element) fetch_the_document() {
	hook := element.image_fetch_decode_hook_ or { return }
	mut data := hook(element.image_resource.href) or {
		element.image_resource.state = .failed
		return
	}
	element.set_decoded_image_data(mut data)
}

pub fn (mut element Element) process_the_url() {
	element.decoded_image_data_ = none
	element.current_frame_index_ = 0
	element.image_resource.update_href(element.href())
	if element.image_resource.state == .loading {
		element.fetch_the_document()
	}
}

pub fn (mut element Element) set_decoded_image_data(mut data DecodedImageData) {
	data.ensure_vector_content_identity()
	element.decoded_image_data_ = data
	element.current_frame_index_ = 0
	element.image_resource.intrinsic_width = data.intrinsic_width()
	element.image_resource.intrinsic_height = data.intrinsic_height()
	element.image_resource.state = .ready
}

pub fn (_ &Element) to_html_element() string {
	return 'img'
}

pub fn (element &Element) is_valid_reference_element() bool {
	return valid_use_reference_tag(element.tag)
}

pub fn (element &Element) is_referenced_element_same_document() bool {
	return element.href().starts_with('#')
}

pub fn (element &Element) referenced_element(document map[string]Element) ?Element {
	id := local_fragment_identifier(element.href()) or { return none }
	return document[id] or { none }
}

pub fn (element &Element) instance_root(document map[string]Element) ?Element {
	return element.referenced_element(document)
}

pub fn (element &Element) animated_instance_root(document map[string]Element) ?Element {
	return element.referenced_element(document)
}

pub fn (element &Element) clone_element_tree_as_our_shadow_tree(document map[string]Element) ?Element {
	target := element.referenced_element(document) or { return none }
	return clone_element_tree(target)
}

pub fn (element &Element) would_create_circular_reference(document map[string]Element) bool {
	mut visiting := map[string]bool{}
	return element_has_use_cycle(*element, document, mut visiting)
}

pub fn (element &Element) would_create_circular_reference_impl(document map[string]Element) bool {
	return element.would_create_circular_reference(document)
}

pub fn (element &Element) text_positioning() TextPositioning {
	return svg.text_positioning(element.attributes)
}

pub fn (element &Element) ensure_length_list(name string) LengthList {
	value := parse_number_percentage(element.attributes[name] or { '' }) or { number(0) }
	return LengthList{
		items: [SvgLength{ value: value.value, unit: .number, read_only: true }]
		read_only: true
	}
}

pub fn (element &Element) rotate() NumberList {
	value := parse_number_percentage(element.attributes['rotate'] or { '' }) or { number(0) }
	return NumberList{
		items: [if value.is_percentage { 0.0 } else { value.value }]
		read_only: true
	}
}

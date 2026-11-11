module svg

import math

pub struct Element {
pub:
	tag string
pub mut:
	attributes               map[string]string
	children                 []Element
	text                     string
	image_resource           ImageResource
	decoded_image_data_      ?&DecodedImageData
	current_frame_index_     int
	image_fetch_decode_hook_ ?ImageFetchDecodeHook
}

pub fn new_element(tag string) Element {
	return Element{
		tag: tag
		attributes: map[string]string{}
	}
}

pub fn (element Element) attribute(name string) ?string {
	value := element.attributes[name] or { return none }
	return value
}

pub fn (element Element) href() string {
	return element.attributes['href'] or { element.attributes['xlink:href'] or { '' } }
}

pub fn (element Element) class_name() string {
	return element.attributes['class'] or { '' }
}

pub fn (element Element) default_role() ?string {
	if element.tag == 'a' && ('href' in element.attributes || 'xlink:href' in element.attributes) {
		return 'link'
	}
	if element.includes_in_accessibility_tree() {
		if element.tag in ['foreignObject', 'g'] {
			return 'group'
		}
		if element.tag == 'image' {
			return 'image'
		}
		if element.tag in ['circle', 'ellipse', 'path', 'polygon', 'polyline'] {
			return 'graphics-symbol'
		}
	}
	return 'generic'
}

pub fn (element Element) includes_in_accessibility_tree() bool {
	for child in element.children {
		if child.tag in ['title', 'desc'] && child.raw_text_contents().trim(' \t\n\r\f').len > 0 {
			return true
		}
	}
	for name in ['aria-label', 'aria-labelledby', 'aria-describedby'] {
		if (element.attributes[name] or { '' }).trim_space().len > 0 {
			return true
		}
	}
	return false
}

pub fn valid_use_reference_tag(tag string) bool {
	return tag in tag_names()
}

pub fn (element Element) text_contents() string {
	return element.raw_text_contents().trim(' \t\n\r\f')
}

fn (element Element) raw_text_contents() string {
	mut result := element.text
	for child in element.children {
		result += child.raw_text_contents()
	}
	return result
}

pub fn (element Element) number_of_chars() int {
	mut count := 0
	for character in element.text_contents().runes() {
		count += if character > 0xffff { 2 } else { 1 }
	}
	return count
}

pub fn resolve_geometry_reference(href string, document map[string]Element) ?Element {
	id := local_fragment_identifier(href) or { return none }
	target := document[id] or { return none }
	if target.tag !in ['circle', 'ellipse', 'line', 'path', 'polygon', 'polyline', 'rect'] {
		return none
	}
	return target
}

fn attribute_number(attributes map[string]string, name string, fallback f64) f64 {
	return parse_coordinate(attributes[name] or { '' }) or { fallback }
}

fn attribute_number_percentage(attributes map[string]string, name string) NumberPercentage {
	return parse_number_percentage(attributes[name] or { '' }) or { number(0) }
}

pub fn geometry_path(element Element, viewport_width f64, viewport_height f64) Path {
	match element.tag {
		'path' {
			return parse_path_data(element.attributes['d'] or { '' })
		}
		'line' {
			x1 :=
				attribute_number_percentage(element.attributes, 'x1').resolve_relative_to(viewport_width)
			y1 :=
				attribute_number_percentage(element.attributes, 'y1').resolve_relative_to(viewport_height)
			x2 :=
				attribute_number_percentage(element.attributes, 'x2').resolve_relative_to(viewport_width)
			y2 :=
				attribute_number_percentage(element.attributes, 'y2').resolve_relative_to(viewport_height)
			return Path{
				instructions: [
					PathInstruction{
						type_: .move
						absolute: true
						data: [x1, y1]
					},
					PathInstruction{
						type_: .line
						absolute: true
						data: [x2, y2]
					},
				]
			}
		}
		'polyline', 'polygon' {
			points := parse_points(element.attributes['points'] or { '' })
			if points.len == 0 {
				return Path{}
			}
			mut instructions := [
				PathInstruction{
					type_: .move
					absolute: true
					data: [points[0].x, points[0].y]
				},
			]
			for point in points[1..] {
				instructions << PathInstruction{
					type_: .line
					absolute: true
					data: [point.x, point.y]
				}
			}
			if element.tag == 'polygon' {
				instructions << PathInstruction{
					type_: .close_path
					absolute: true
				}
			}
			return Path{
				instructions: instructions
			}
		}
		'circle' {
			cx :=
				attribute_number_percentage(element.attributes, 'cx').resolve_relative_to(viewport_width)
			cy :=
				attribute_number_percentage(element.attributes, 'cy').resolve_relative_to(viewport_height)
			diagonal := math.sqrt((viewport_width * viewport_width + viewport_height * viewport_height) / 2)
			radius :=
				attribute_number_percentage(element.attributes, 'r').resolve_relative_to(diagonal)
			if radius <= 0 {
				return Path{}
			}
			return ellipse_path(cx, cy, radius, radius)
		}
		'ellipse' {
			cx := attribute_number(element.attributes, 'cx', 0)
			cy := attribute_number(element.attributes, 'cy', 0)
			rx := parse_positive_length(element.attributes['rx'] or { '' }) or { 0 }
			ry := parse_positive_length(element.attributes['ry'] or { '' }) or { 0 }
			return ellipse_path(cx, cy, rx, ry)
		}
		'rect' {
			return rect_path(element.attributes, viewport_width, viewport_height)
		}
		else {
			return Path{}
		}
	}
}

fn ellipse_path(cx f64, cy f64, rx f64, ry f64) Path {
	if rx <= 0 || ry <= 0 {
		return Path{}
	}
	return Path{
		instructions: [
			PathInstruction{
				type_: .move
				absolute: true
				data: [cx + rx, cy]
			},
			PathInstruction{
				type_: .elliptical_arc
				absolute: true
				data: [rx, ry, 0, 0, 1, cx, cy + ry]
			},
			PathInstruction{
				type_: .elliptical_arc
				absolute: true
				data: [rx, ry, 0, 0, 1, cx - rx, cy]
			},
			PathInstruction{
				type_: .elliptical_arc
				absolute: true
				data: [rx, ry, 0, 0, 1, cx, cy - ry]
			},
			PathInstruction{
				type_: .elliptical_arc
				absolute: true
				data: [rx, ry, 0, 0, 1, cx + rx, cy]
			},
		]
	}
}

fn rect_path(attributes map[string]string, viewport_width f64, viewport_height f64) Path {
	x := attribute_number_percentage(attributes, 'x').resolve_relative_to(viewport_width)
	y := attribute_number_percentage(attributes, 'y').resolve_relative_to(viewport_height)
	width := attribute_number_percentage(attributes, 'width').resolve_relative_to(viewport_width)
	height := attribute_number_percentage(attributes, 'height').resolve_relative_to(viewport_height)
	if width <= 0 || height <= 0 {
		return Path{}
	}
	rx_value := parse_number_percentage(attributes['rx'] or { '' })
	ry_value := parse_number_percentage(attributes['ry'] or { '' })
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
	rx = math.min(rx, width / 2)
	ry = math.min(ry, height / 2)
	mut instructions := [
		PathInstruction{
			type_: .move
			absolute: true
			data: [x + rx, y]
		},
		PathInstruction{
			type_: .horizontal_line
			absolute: true
			data: [x + width - rx]
		},
	]
	if rx > 0 && ry > 0 {
		instructions << PathInstruction{
			type_: .elliptical_arc
			absolute: true
			data: [rx, ry, 0, 0, 1, x + width, y + ry]
		}
	}
	instructions << PathInstruction{
		type_: .vertical_line
		absolute: true
		data: [y + height - ry]
	}
	if rx > 0 && ry > 0 {
		instructions << PathInstruction{
			type_: .elliptical_arc
			absolute: true
			data: [rx, ry, 0, 0, 1, x + width - rx, y + height]
		}
	}
	instructions << PathInstruction{
		type_: .horizontal_line
		absolute: true
		data: [x + rx]
	}
	if rx > 0 && ry > 0 {
		instructions << PathInstruction{
			type_: .elliptical_arc
			absolute: true
			data: [rx, ry, 0, 0, 1, x, y + height - ry]
		}
	}
	instructions << PathInstruction{
		type_: .vertical_line
		absolute: true
		data: [y + ry]
	}
	if rx > 0 && ry > 0 {
		instructions << PathInstruction{
			type_: .elliptical_arc
			absolute: true
			data: [rx, ry, 0, 0, 1, x + rx, y]
		}
	}
	instructions << PathInstruction{
		type_: .close_path
		absolute: true
	}
	return Path{
		instructions: instructions
	}
}

pub fn element_transform(element Element) AffineTransform {
	transforms := parse_transform(element.attributes['transform'] or { '' }) or { []Transform{} }
	mut result := compose_transforms(transforms)
	if element.tag == 'use' {
		x := parse_coordinate(element.attributes['x'] or { '' }) or { 0 }
		y := parse_coordinate(element.attributes['y'] or { '' }) or { 0 }
		result = result.multiply(AffineTransform{
			e: x
			f: y
		})
	}
	return result
}

pub fn resolve_masking_area(target Rect) Rect {
	return new_element('mask').resolve_masking_area(target, Point{}, AffineTransform{})
}

pub fn text_anchor(value string) ?TextAnchor {
	return match value {
		'start' { TextAnchor.start }
		'middle' { TextAnchor.middle }
		'end' { TextAnchor.end }
		else { none }
	}
}

pub struct FitToViewBox {
pub mut:
	viewbox               ?ViewBox
	preserve_aspect_ratio PreserveAspectRatio
	bindings_rect         AnimatedRect
}

pub fn (mut fit FitToViewBox) initialize_fit_to_view_box() {
	fit.bindings_rect = AnimatedRect.create(none)
}

pub fn (mut fit FitToViewBox) update_attribute(name string, value ?string) {
	if name.to_lower() == 'viewbox' {
		text := value or {
			fit.viewbox = none
			fit.bindings_rect.nulled = true
			return
		}

		parsed := parse_viewbox(text)
		fit.viewbox = parsed
		if box := parsed {
			rect := Rect{
				x: box.min_x
				y: box.min_y
				width: box.width
				height: box.height
			}
			fit.bindings_rect.base_value = rect
			fit.bindings_rect.anim_value = rect
			fit.bindings_rect.nulled = false
		} else {
			fit.bindings_rect.nulled = true
		}
	} else if name.to_lower() == 'preserveaspectratio' {
		fit.preserve_aspect_ratio = parse_preserve_aspect_ratio(value or { '' }) or {
			PreserveAspectRatio{}
		}
	}
}

pub struct SvgViewport {
pub mut:
	fit                  FitToViewBox
	fallback_viewbox     ?ViewBox
	active_view_element_ ?Element
	view_specification_viewbox ?ViewBox
	width                ?f64
	height               ?f64
}

pub fn (viewport SvgViewport) active_viewbox() ?ViewBox {
	if box := viewport.active_view_box_of_svg_view() {
		return box
	}
	if box := viewport.fit.viewbox {
		return box
	}
	if fallback := viewport.fallback_viewbox {
		return fallback
	}
	return none
}

pub struct TextPositioning {
pub:
	x      []NumberPercentage
	y      []NumberPercentage
	dx     []NumberPercentage
	dy     []NumberPercentage
	rotate []f64
}

pub fn text_positioning(attributes map[string]string) TextPositioning {
	return TextPositioning{
		x: parse_text_position(attributes['x'] or { '' })
		y: parse_text_position(attributes['y'] or { '' })
		dx: parse_text_position(attributes['dx'] or { '' })
		dy: parse_text_position(attributes['dy'] or { '' })
		// SVGTextPositioningElement::text_positioning() does not support the
		// rotate attribute yet.
		rotate: []
	}
}

fn parse_text_position(source string) []NumberPercentage {
	value := parse_number_percentage(source) or { return [] }
	return [value]
}

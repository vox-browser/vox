module layout

import css
import dom

// The native static-image cache deliberately accepts only local, shape-only
// SVGs. Command export performs a second check on the resulting paint payloads.
fn static_svg_document_is_eligible(document &dom.Document) bool {
	root := document.document_element() or { return false }
	if root.local_name() != 'svg' { return false }
	// Inspect document siblings too: an xml-stylesheet processing instruction
	// must not disappear when the parsed document is retired.
	return static_svg_node_is_eligible(document.as_node(), false)
}

fn static_svg_node_is_eligible(node &dom.Node, in_style bool) bool {
	if element := node.as_element() {
		if (element.namespace_uri() or { '' }) != 'http://www.w3.org/2000/svg'
			|| !static_svg_tag_is_eligible(element.local_name()) {
			return false
		}
		if attributes := element.attribute_list() {
			for index in 0 .. attributes.length() {
				attribute := attributes.item(index) or { return false }
				if !static_svg_attribute_is_eligible(attribute) { return false }
			}
		}
		if element.local_name() == 'style' {
			if !static_svg_stylesheet_is_eligible(node.descendant_text_content()) { return false }
		}
		mut child := node.first_child()
		for {
			current := child or { break }
			if !static_svg_node_is_eligible(current, element.local_name() == 'style') {
				return false
			}
			child = current.next_sibling()
		}
		return true
	}
	if node.is_text() {
		return in_style || (node.text_content() or { '' }).trim_space() == ''
	}
	if node.is_comment() { return true }
	if !node.is_document() { return false }
	mut child := node.first_child()
	for {
		current := child or { break }
		if !static_svg_node_is_eligible(current, false) { return false }
		child = current.next_sibling()
	}
	return true
}

fn static_svg_tag_is_eligible(name string) bool {
	return name in ['svg', 'defs', 'clipPath', 'circle', 'ellipse', 'g', 'path', 'use', 'linearGradient',
		'radialGradient', 'stop', 'style', 'rect', 'line', 'polygon', 'polyline']
}

fn static_svg_attribute_is_eligible(attribute &dom.Attr_) bool {
	name := attribute.local_name()
	value := attribute.value().trim_space()
	namespace := attribute.namespace_uri() or { '' }
	if namespace == 'http://www.w3.org/2000/xmlns/' {
		return value in ['http://www.w3.org/2000/svg', 'http://www.w3.org/1999/xlink']
	}
	if namespace != '' {
		return namespace == 'http://www.w3.org/1999/xlink' && name == 'href'
			&& static_svg_local_reference(value)
	}
	match name {
		'id', 'class', 'data-name' { return true }
		'href' { return static_svg_local_reference(value) }
		'style' { return static_svg_declaration_source_is_eligible(value) }
		'type' { return value == 'text/css' }
		'd' {
			return static_svg_literal_characters(value, 'MmZzLlHhVvCcSsQqTtAa0123456789eE+-. ,\t\r\n')
		}
		'transform', 'gradientTransform' { return static_svg_transform_is_eligible(value) }
		'viewBox', 'points' { return static_svg_numbers_are_eligible(value, false) }
		'preserveAspectRatio' {
			parts := value.fields()
			return parts.len > 0 && parts.len <= 2
				&& parts[0] in ['none', 'xMinYMin', 'xMidYMin', 'xMaxYMin', 'xMinYMid', 'xMidYMid',
					'xMaxYMid', 'xMinYMax', 'xMidYMax', 'xMaxYMax']
				&& (parts.len == 1 || parts[1] in ['meet', 'slice'])
		}
		'gradientUnits', 'clipPathUnits' { return value in ['objectBoundingBox', 'userSpaceOnUse'] }
		'spreadMethod' { return value in ['pad', 'reflect', 'repeat'] }
		'version', 'x', 'y', 'x1', 'y1', 'x2', 'y2', 'cx', 'cy', 'r', 'rx', 'ry',
		'fx', 'fy', 'fr', 'width', 'height', 'offset', 'pathLength' {
			return static_svg_numbers_are_eligible(value, true)
		}
		else { return static_svg_property_is_eligible(name, value) }
	}
}

fn static_svg_literal_characters(value string, allowed string) bool {
	if value.len == 0 { return false }
	for byte in value {
		if allowed.index_u8(byte) < 0 { return false }
	}
	return true
}

fn static_svg_numbers_are_eligible(value string, lengths bool) bool {
	// Percentages depend only on the keyed replay viewport. Font, viewport-unit
	// and calculated lengths are deliberately outside this source subset.
	plain := if lengths { value.replace('px', '').replace('%', '') } else { value }
	return static_svg_literal_characters(plain, '0123456789eE+-. ,\t\r\n')
}

fn static_svg_local_reference(value string) bool {
	return value.starts_with('#') && value.len > 1
		&& static_svg_literal_characters(value[1..], 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-')
}

fn static_svg_local_url(value string) bool {
	if !value.starts_with('url(') || !value.ends_with(')') { return false }
	mut reference := value[4..value.len - 1].trim_space()
	if reference.len >= 2 && ((reference[0] == `"` && reference[reference.len - 1] == `"`)
		|| (reference[0] == `'` && reference[reference.len - 1] == `'`)) {
		reference = reference[1..reference.len - 1]
	}
	return static_svg_local_reference(reference)
}

fn static_svg_transform_is_eligible(value string) bool {
	mut remaining := value.trim_space()
	if remaining.len == 0 { return false }
	for remaining.len > 0 {
		open := remaining.index('(') or { return false }
		close := remaining.index(')') or { return false }
		if close <= open || remaining[..open].trim_space() !in ['matrix', 'translate', 'scale',
			'rotate', 'skewX', 'skewY']
			|| !static_svg_numbers_are_eligible(remaining[open + 1..close], false) {
			return false
		}
		remaining = remaining[close + 1..].trim_space().trim_left(',').trim_space()
	}
	return true
}

fn static_svg_color_is_eligible(value string) bool {
	// A concrete parsed color excludes system colors, currentColor, light-dark,
	// substitutions and color functions that could depend on the environment.
	property := css.property_id_from_string('color') or { return false }
	parsed := css.parse_css_value_logic(property, value) or { return false }
	if parsed is css.ColorStyleValue { return true }
	// CSSOM serializes concrete hexadecimal colors to rgb(). Permit only its
	// numeric form, rather than relative colors or nested substitution functions.
	if parsed is css.RGBColorStyleValue || parsed is css.HSLColorStyleValue {
		// Named and hexadecimal colors also parse to concrete RGB values.
		if !value.contains('(') { return true }
		open := value.index('(') or { return false }
		if !value.ends_with(')') || value[..open].to_lower() !in ['rgb', 'rgba', 'hsl', 'hsla'] {
			return false
		}
		return static_svg_numbers_are_eligible(value[open + 1..value.len - 1], true)
	}
	return false
}

fn static_svg_property_is_eligible(name string, value string) bool {
	match name {
		'fill', 'stroke' {
			return value == 'none' || static_svg_local_url(value) || static_svg_color_is_eligible(value)
		}
		'color', 'stop-color' { return static_svg_color_is_eligible(value) }
		'clip-path' { return value == 'none' || static_svg_local_url(value) }
		'fill-rule', 'clip-rule' { return value in ['nonzero', 'evenodd'] }
		'stroke-linecap' { return value in ['butt', 'round', 'square'] }
		'stroke-linejoin' { return value in ['miter', 'round', 'bevel'] }
		'opacity', 'fill-opacity', 'stroke-opacity', 'stop-opacity', 'stroke-miterlimit' {
			return static_svg_numbers_are_eligible(value, false)
		}
		'stroke-width', 'stroke-dashoffset', 'stroke-dasharray' {
			return (name == 'stroke-dasharray' && value == 'none')
				|| static_svg_numbers_are_eligible(value, true)
		}
		else { return false }
	}
}

fn static_svg_declarations_are_eligible(declarations &css.CSSStyleProperties) bool {
	_ = declarations.length() // Materialize lazily parsed declarations.
	if declarations.custom_properties.len != 0 { return false }
	for property in declarations.properties {
		if !static_svg_property_is_eligible(property.name, property.value) { return false }
	}
	return true
}

fn static_svg_declaration_source_is_eligible(source string) bool {
	// No escapes/comments or nested syntax: this keeps ignored parser input from
	// concealing an unsupported declaration at the eligibility boundary.
	if source.contains('\\') || source.contains('/') || source.contains('@')
		|| source.contains('{') || source.contains('}') {
		return false
	}
	for part in source.split(';') {
		if part.trim_space() == '' { continue }
		colon := part.index(':') or { return false }
		name := part[..colon].trim_space().to_lower()
		value := part[colon + 1..].trim_space()
		if !static_svg_property_is_eligible(name, value) { return false }
	}
	return static_svg_declarations_are_eligible(css.parse_css_property_declaration_block_with_parser(source))
}

fn static_svg_stylesheet_is_eligible(source string) bool {
	if source.contains('\\') || source.contains('/') || source.contains('@') { return false }
	// Check declaration source as well as parsed declarations: CSS parsers drop
	// unknown/invalid declarations, and nested source is outside this subset.
	mut remaining := source
	for {
		open := remaining.index('{') or { break }
		close := remaining.index('}') or { return false }
		if close <= open || !static_svg_declaration_source_is_eligible(remaining[open + 1..close]) {
			return false
		}
		remaining = remaining[close + 1..]
	}
	if remaining.contains('}') { return false }
	sheet := css.parse_css_stylesheet_with_parser(source, none)
	for rule in sheet.css_rules().rules {
		if rule.type_ != .style { return false }
		if children := rule.rules {
			if children.length() != 0 { return false }
		}
		if rule.selectors.selectors.len == 0 { return false }
		for selector in rule.selectors.selectors {
			compounds := selector.compound_selectors()
			if compounds.len == 0 { return false }
			for compound in compounds {
				if compound.combinator !in [.no_combinator, .descendant, .immediate_child] {
					return false
				}
				for simple in compound.simple_selectors {
					match simple.type_ {
						.id, .class, .universal {}
						.tag_name {
							name := simple.qualified_name()
							if name.namespace_type != .default_ || !static_svg_tag_is_eligible(name.name.name) {
								return false
							}
						}
						else { return false }
					}
				}
			}
		}
		declarations := rule.style() or { return false }
		if !static_svg_declarations_are_eligible(declarations) { return false }
	}
	return true
}

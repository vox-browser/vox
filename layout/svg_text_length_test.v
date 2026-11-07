module layout

import html
import math

fn svg_text_length_node(root &Node) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == 't' {
				return root
			}
		}
	}
	for child in root.children() {
		if found := svg_text_length_node(child) {
			return found
		}
	}
	return none
}

fn svg_text_length_bounds(attributes string) SVGRect {
	document := html.parse_document('<!doctype html><style>body{margin:0}</style>' +
		'<svg width="400" height="100"><text id="t" y="50" font-size="20" ${attributes}>OOOO</text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	node := svg_text_length_node(result.root) or { panic('missing text') }
	styled := node.as_node_with_style() or { panic('text has no style') }
	used := result.used_values_for(styled) or { panic('text has no used values') }
	path := used.computed_svg_path() or { panic('text has no path') }
	bounds := svg_path_bounds(path) or { panic('text has no bounds') }
	return SVGRect{bounds.x, bounds.width}
}

struct SVGRect {
	x     f64
	width f64
}

// Brave 156 badges (shields.io) center each label with textLength. Blink's
// ResolveTextLength() adds delta/(n-1) after each character for `spacing` and
// stretches positions and glyphs for `spacingAndGlyphs`; anchoring then uses
// the adjusted extent.
fn test_svg_text_length_spacing_distributes_the_difference_between_characters() {
	plain := svg_text_length_bounds('x="20"')
	document := html.parse_document('<!doctype html><svg><text id="t" font-size="20">OOOO</text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	width := svg_shape_text(svg_text_length_node(result.root) or { panic('t') }, 'OOOO').width
	gap := (200 - width) / 3
	spaced := svg_text_length_bounds('x="20" textLength="200"')
	assert math.abs(spaced.x - plain.x) < 0.01
	assert math.abs(spaced.width - (plain.width + 3 * gap)) < 0.05
	// The anchored chunk is exactly textLength wide.
	centered := svg_text_length_bounds('x="200" text-anchor="middle" textLength="200"')
	assert math.abs(centered.x - (plain.x - 20 + 100)) < 0.05
	stretched := svg_text_length_bounds('x="20" textLength="200" lengthAdjust="spacingAndGlyphs"')
	scale := 200 / width
	assert math.abs(stretched.x - (20 + (plain.x - 20) * scale)) < 0.05
	assert math.abs(stretched.width - plain.width * scale) < 0.05
}

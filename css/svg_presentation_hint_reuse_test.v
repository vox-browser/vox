module css

import dom

fn svg_hint_reuse_element(mut document dom.Document, attributes map[string]string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', 'path') or { panic(err) }
	for name, value in attributes { element.set_attribute_value(name, value) }
	return element
}

fn svg_hint_reuse_values(element &dom.Element, computer &StyleComputer) map[PropertyID]voidptr {
	mut hints := []StyleProperty{}
	collect_svg_presentational_hints_with(mut hints, element, [], computer)
	mut values := map[PropertyID]voidptr{}
	for hint in hints { values[hint.property_id] = voidptr(hint.value) }
	return values
}

// Within a style batch equal attributes share one parsed value with the same
// serialization as an uncached parse; a different attribute text, another
// batch and callers without a computer parse their own.
fn test_svg_presentation_hints_share_parsed_values_within_a_batch() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := css_style_computer_for(document)
	attributes := {'d': 'M0 0L10 10Z', 'fill': 'currentColor', 'stroke-width': '2'}
	first := svg_hint_reuse_element(mut document, attributes)
	second := svg_hint_reuse_element(mut document, attributes)
	other := svg_hint_reuse_element(mut document, {'d': 'M0 0L10 11Z', 'fill': 'red', 'stroke-width': '2'})
	computer.begin_computed_property_page_batch()
	a := svg_hint_reuse_values(first, computer)
	b := svg_hint_reuse_values(second, computer)
	c := svg_hint_reuse_values(other, computer)
	computer.end_computed_property_page_batch()
	assert a.len == 3 && b.len == 3 && c.len == 3
	for id, value in a {
		assert b[id] == value
	}
	assert c[.d] != a[.d] && c[.fill] != a[.fill]
	assert c[.stroke_width] == a[.stroke_width]
	// The cached values serialize as uncached parses do.
	mut uncached := []StyleProperty{}
	collect_svg_presentational_hints(mut uncached, first, [])
	for hint in uncached {
		cached := unsafe { &dom.StyleValue(a[hint.property_id]) }
		assert cached.css_text == hint.value.css_text
		assert voidptr(hint.value) != a[hint.property_id]
	}
	computer.begin_computed_property_page_batch()
	next := svg_hint_reuse_values(first, computer)
	computer.end_computed_property_page_batch()
	assert next[.d] != a[.d]
	assert svg_hint_reuse_values(first, computer)[.d] != svg_hint_reuse_values(first, computer)[.d]
}

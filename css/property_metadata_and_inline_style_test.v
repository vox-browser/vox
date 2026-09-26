module css

import dom

const html_ns = 'http://www.w3.org/1999/xhtml'

fn pid(name string) PropertyID {
	return property_id_from_string(name) or { panic('unknown property ${name}') }
}

fn test_property_metadata() {
	// Inherited-by-default flags (from Properties.json).
	assert is_inherited_property(pid('color'))
	assert is_inherited_property(pid('font-size'))
	assert is_inherited_property(pid('visibility'))
	assert !is_inherited_property(pid('display'))
	assert !is_inherited_property(pid('margin-top'))
	assert !is_inherited_property(pid('background-color'))

	// Initial values.
	assert property_initial_value_string(pid('display')) == 'inline'
	assert property_initial_value_string(pid('font-size')) == 'medium'
}

fn el_with(doc &dom.Document, tag string, attr string, value string) &dom.Element {
	mut e := doc.create_element_ns(html_ns, tag) or { panic('${err}') }
	e.set_attribute_value(attr, value)
	return e
}

// inline_style: read/write an element's `style` attribute as a CSSStyleDeclaration.
fn test_inline_style_read() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'color: red; width: 10px')
	style := inline_style(el)
	assert style.get_property_value('color') == 'red'
	assert style.get_property_value('width') == '10px'
	assert style.get_property_value('height') == '' // unset
	assert style.length() == 2
}

// Setting a property updates the style attribute and round-trips.
fn test_inline_style_set() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'color: red')
	style := inline_style(el)

	style.set_property('color', 'blue') // replace existing
	style.set_property('display', 'flex') // add new
	assert style.get_property_value('color') == 'blue'
	assert style.get_property_value('display') == 'flex'
	// The change is persisted to the element's style attribute.
	assert (el.get_attribute('style') or { '' }).contains('blue')
	assert (el.get_attribute('style') or { '' }).contains('flex')
}

// Removing a property drops it from the inline style.
fn test_inline_style_remove() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'color: red; width: 10px')
	style := inline_style(el)
	style.remove_property('color')
	assert style.get_property_value('color') == ''
	assert style.get_property_value('width') == '10px' // the other declaration stays
	assert style.length() == 1
}

// The minimal media-query evaluator: width features and media types against a viewport width.
fn test_media_condition_matches() {
	// min-width matches when the viewport is at least as wide.
	assert media_condition_matches('(min-width: 600px)', 800.0)
	assert !media_condition_matches('(min-width: 600px)', 500.0)
	// max-width matches when the viewport is at most that wide.
	assert media_condition_matches('(max-width: 400px)', 300.0)
	assert !media_condition_matches('(max-width: 400px)', 500.0)
	// `screen and (...)`: the type matches and the feature is evaluated.
	assert media_condition_matches('screen and (max-width: 400px)', 300.0)
	assert !media_condition_matches('screen and (max-width: 400px)', 500.0)
	// A bare type / empty condition matches; a non-matching type does not.
	assert media_condition_matches('all', 100.0)
	assert media_condition_matches('screen', 100.0)
	assert !media_condition_matches('print', 100.0)
	// `and`-joined features must all match.
	assert media_condition_matches('(min-width: 300px) and (max-width: 900px)', 600.0)
	assert !media_condition_matches('(min-width: 300px) and (max-width: 900px)', 1000.0)
	// `only screen` — the leading `only` is a no-op.
	assert media_condition_matches('only screen and (min-width: 500px)', 700.0)
	assert media_condition_matches('(600px <= width < 900px)', 700.0)
	assert !media_condition_matches('(600px <= width < 900px)', 950.0)
	assert media_condition_matches('(orientation: landscape)', 800.0)
	assert !media_condition_matches('(orientation: landscape)', 500.0)
	assert media_condition_matches('(resolution: 1dppx)', 800.0)
	assert !media_condition_matches('not screen', 800.0)
	assert !media_condition_matches('', 800.0)
}

// flatten_media_rules includes a matching @media's children and drops a non-matching one's.
fn test_flatten_media_rules() {
	rules := parse_css_stylesheet_contents_with_parser('.a { color: red } @media (min-width: 600px) { .wide { color: blue } } @media (max-width: 400px) { .narrow { color: green } }', map[string]bool{})

	// At 800px wide: .a + the wide media's child (narrow media dropped).
	wide := flatten_media_rules(rules, 800.0)
	assert wide.len == 2
	assert wide[0].selector_text() == '.a'
	assert wide[1].selector_text() == '.wide'

	// At 300px wide: .a + the narrow media's child.
	narrow := flatten_media_rules(rules, 300.0)
	assert narrow.len == 2
	assert narrow[1].selector_text() == '.narrow'
}

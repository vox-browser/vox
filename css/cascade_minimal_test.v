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

fn test_minimal_cascade_inline_inherit_initial() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('style', 'color: red; display: block')
	mut p := doc.create_element_ns(html_ns, 'p') or { panic('${err}') }
	p.set_attribute_value('style', 'font-size: 12px')
	mut div_node := div.as_node()
	div_node.append_child(p.as_node()) or { panic('${err}') }

	// The div uses its own inline declarations.
	assert cascaded_value_for(div, pid('color')) == 'red'
	assert cascaded_value_for(div, pid('display')) == 'block'

	// The p: color INHERITS from the div; display does NOT (defaults to its initial value);
	// font-size is the p's own inline value.
	assert cascaded_value_for(p, pid('color')) == 'red'
	assert cascaded_value_for(p, pid('display')) == 'inline' // initial, not inherited
	assert cascaded_value_for(p, pid('font-size')) == '12px'

	// A property no one sets falls back to its initial value.
	assert cascaded_value_for(p, pid('margin-top')) == property_initial_value_string(pid('margin-top'))
}

fn test_inheritance_walks_multiple_ancestors() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns(html_ns, 'section') or { panic('${err}') }
	root.set_attribute_value('style', 'color: green')
	mut mid := doc.create_element_ns(html_ns, 'div') or { panic('${err}') } // no color
	mut leaf := doc.create_element_ns(html_ns, 'span') or { panic('${err}') } // no color
	mut root_node := root.as_node()
	root_node.append_child(mid.as_node()) or { panic('${err}') }
	mut mid_node := mid.as_node()
	mid_node.append_child(leaf.as_node()) or { panic('${err}') }

	// color inherits down two levels to the leaf.
	assert cascaded_value_for(leaf, pid('color')) == 'green'
}

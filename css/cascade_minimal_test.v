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

fn test_cascade_with_author_stylesheet() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('class', 'box')
	mut p := doc.create_element_ns(html_ns, 'p') or { panic('${err}') }
	p.set_attribute_value('id', 'lead')
	p.set_attribute_value('style', 'font-size: 20px') // inline overrides the author rule
	mut div_node := div.as_node()
	div_node.append_child(p.as_node()) or { panic('${err}') }

	rules := parse_css_stylesheet_contents_with_parser('.box { color: teal } p { color: black; font-size: 12px } #lead { color: maroon }',
		map[string]bool{})

	// div: matches '.box' -> color teal; display defaults to initial.
	assert cascaded_value_with_stylesheet(div, pid('color'), rules) == 'teal'
	assert cascaded_value_with_stylesheet(div, pid('display'), rules) == 'inline'

	// p: matches both 'p' and '#lead' for color; source order takes the later one (#lead).
	assert cascaded_value_with_stylesheet(p, pid('color'), rules) == 'maroon'
	// font-size: the inline declaration wins over the matching 'p' rule.
	assert cascaded_value_with_stylesheet(p, pid('font-size'), rules) == '20px'

	// A property no rule sets but that inherits: p inherits color from... itself sets it, so use a
	// non-inline element. margin-top is not inherited and unset -> initial.
	assert cascaded_value_with_stylesheet(p, pid('margin-top'), rules) == property_initial_value_string(pid('margin-top'))
}

fn el_with(doc &dom.Document, tag string, attr string, value string) &dom.Element {
	mut e := doc.create_element_ns(html_ns, tag) or { panic('${err}') }
	e.set_attribute_value(attr, value)
	return e
}

fn test_specificity_beats_source_order() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'class', 'high')
	// '.high' (0,1,0) is EARLIER in source but more specific than 'div' (0,0,1) which is LATER.
	rules := parse_css_stylesheet_contents_with_parser('.high { color: green } div { color: red }',
		map[string]bool{})
	assert cascaded_value_with_stylesheet(el, pid('color'), rules) == 'green'
}

fn test_compound_selector_specificity() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'class', 'x')
	// div.x (0,1,1) > .x (0,1,0) > div (0,0,1), regardless of source order.
	rules := parse_css_stylesheet_contents_with_parser('div.x { color: blue } div { color: red } .x { color: green }',
		map[string]bool{})
	assert cascaded_value_with_stylesheet(el, pid('color'), rules) == 'blue'
}

fn test_important_beats_higher_specificity() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'id', 'x')
	// '#x' (id, high specificity) is normal; 'div' (low specificity) is !important -> important wins.
	rules := parse_css_stylesheet_contents_with_parser('#x { color: green } div { color: red !important }',
		map[string]bool{})
	assert cascaded_value_with_stylesheet(el, pid('color'), rules) == 'red'
}

fn test_inline_important_beats_author_important() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'p', 'style', 'color: blue !important')
	rules := parse_css_stylesheet_contents_with_parser('p { color: red !important }', map[string]bool{})
	// Inline !important outranks author !important (inline has the higher specificity).
	assert cascaded_value_with_stylesheet(el, pid('color'), rules) == 'blue'
}

fn test_shorthand_expansion_inline() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'margin: 1px 2px 3px 4px')
	assert cascaded_value_with_stylesheet(el, pid('margin-top'), []&CSSRule{}) == '1px'
	assert cascaded_value_with_stylesheet(el, pid('margin-right'), []&CSSRule{}) == '2px'
	assert cascaded_value_with_stylesheet(el, pid('margin-bottom'), []&CSSRule{}) == '3px'
	assert cascaded_value_with_stylesheet(el, pid('margin-left'), []&CSSRule{}) == '4px'
}

fn test_shorthand_expansion_author_rule() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'class', 'box')
	rules := parse_css_stylesheet_contents_with_parser('.box { padding: 10px 20px }', map[string]bool{})
	// 2-value padding: top/bottom 10px, left/right 20px.
	assert cascaded_value_with_stylesheet(el, pid('padding-top'), rules) == '10px'
	assert cascaded_value_with_stylesheet(el, pid('padding-left'), rules) == '20px'
}

fn test_longhand_overrides_shorthand_in_cascade() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'class', 'box')
	// A later, equally-specific rule's longhand overrides the earlier shorthand's contribution.
	rules := parse_css_stylesheet_contents_with_parser('.box { margin: 5px } .box { margin-top: 9px }',
		map[string]bool{})
	assert cascaded_value_with_stylesheet(el, pid('margin-top'), rules) == '9px'
	assert cascaded_value_with_stylesheet(el, pid('margin-left'), rules) == '5px'
}

fn test_user_agent_default_display() {
	doc := dom.Document.create(dom.url_about_blank())
	display := pid('display')
	no_author := []&CSSRule{}
	el_div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	el_head := doc.create_element_ns(html_ns, 'head') or { panic('${err}') }
	el_li := doc.create_element_ns(html_ns, 'li') or { panic('${err}') }
	el_ul := doc.create_element_ns(html_ns, 'ul') or { panic('${err}') }
	assert cascaded_value_with_ua(el_div, display, no_author) == 'block'
	assert cascaded_value_with_ua(el_head, display, no_author) == 'none'
	assert cascaded_value_with_ua(el_li, display, no_author) == 'list-item'
	assert cascaded_value_with_ua(el_ul, display, no_author) == 'block'
}

fn test_author_normal_beats_ua_default() {
	doc := dom.Document.create(dom.url_about_blank())
	div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	// An author rule (normal) overrides the UA default (normal), even at equal specificity.
	rules := parse_css_stylesheet_contents_with_parser('div { display: inline }', map[string]bool{})
	assert cascaded_value_with_ua(div, pid('display'), rules) == 'inline'
	// Without the author rule, the UA default (block) applies.
	assert cascaded_value_with_ua(div, pid('display'), []&CSSRule{}) == 'block'
}

fn test_inline_beats_ua_default() {
	doc := dom.Document.create(dom.url_about_blank())
	mut span := doc.create_element_ns(html_ns, 'span') or { panic('${err}') }
	span.set_attribute_value('style', 'display: flex')
	assert cascaded_value_with_ua(span, pid('display'), []&CSSRule{}) == 'flex'
}

fn test_author_rule_inheritance() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	root.set_attribute_value('class', 'themed')
	mut child := doc.create_element_ns(html_ns, 'span') or { panic('${err}') } // no color anywhere
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('${err}') }

	rules := parse_css_stylesheet_contents_with_parser('.themed { color: purple }', map[string]bool{})
	// color is inherited: the child inherits the author-rule color from its ancestor.
	assert cascaded_value_with_stylesheet(child, pid('color'), rules) == 'purple'
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

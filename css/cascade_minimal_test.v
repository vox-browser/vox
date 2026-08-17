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
	rules := parse_css_stylesheet_contents_with_parser('p { color: red !important }',
		map[string]bool{})
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
	rules := parse_css_stylesheet_contents_with_parser('.box { padding: 10px 20px }',
		map[string]bool{})
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

fn test_computed_font_size_inherit_em_percent() {
	doc := dom.Document.create(dom.url_about_blank())
	html := el_with(doc, 'html', 'style', 'font-size: 20px')
	body := doc.create_element_ns(html_ns, 'body') or { panic('${err}') } // no own font-size
	div := el_with(doc, 'div', 'style', 'font-size: 1.5em') // 1.5 * parent
	span := el_with(doc, 'span', 'style', 'font-size: 150%') // 1.5 * parent
	mut html_node := html.as_node()
	html_node.append_child(body.as_node()) or { panic('${err}') }
	mut body_node := body.as_node()
	body_node.append_child(div.as_node()) or { panic('${err}') }
	mut div_node := div.as_node()
	div_node.append_child(span.as_node()) or { panic('${err}') }

	no_author := []&CSSRule{}
	assert computed_font_size_px(html, no_author) == 20.0
	assert computed_font_size_px(body, no_author) == 20.0 // inherited computed value
	assert computed_font_size_px(div, no_author) == 30.0 // 1.5em of 20
	assert computed_font_size_px(span, no_author) == 45.0 // 150% of 30
}

fn test_computed_font_size_rem_and_keyword() {
	doc := dom.Document.create(dom.url_about_blank())
	html := el_with(doc, 'html', 'style', 'font-size: 10px')
	rem_el := el_with(doc, 'p', 'style', 'font-size: 2rem') // 2 * root(10) = 20
	mut html_node := html.as_node()
	html_node.append_child(rem_el.as_node()) or { panic('${err}') }
	no_author := []&CSSRule{}
	assert computed_font_size_px(rem_el, no_author) == 20.0

	// Absolute-size keyword (large = 6/5 * 16).
	kw_el := el_with(doc, 'span', 'style', 'font-size: large')
	assert computed_font_size_px(kw_el, no_author) == default_font_size_px * 6.0 / 5.0
	// Default (no font-size anywhere) is medium = 16px.
	plain := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	assert computed_font_size_px(plain, no_author) == 16.0
}

fn test_computed_length_px() {
	doc := dom.Document.create(dom.url_about_blank())
	html := el_with(doc, 'html', 'style', 'font-size: 10px')
	// div: em resolves against the div's OWN font-size (20), rem against the root (10).
	div := el_with(doc, 'div', 'style',
		'font-size: 20px; width: 2em; margin-top: 5px; padding-left: 1.5rem')
	mut html_node := html.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }

	no_author := []&CSSRule{}
	assert (computed_length_px(div, pid('width'), no_author) or { panic('width') }) == 40.0 // 2em * 20
	assert (computed_length_px(div, pid('margin-top'), no_author) or { panic('mt') }) == 5.0 // 5px
	assert (computed_length_px(div, pid('padding-left'), no_author) or { panic('pl') }) == 15.0 // 1.5rem * 10

	// Non-length cascaded values are not resolvable to px here.
	assert computed_length_px(div, pid('width'), no_author) != none
	plain := el_with(doc, 'span', 'style', '')
	assert computed_length_px(plain, pid('width'), no_author) == none // initial 'auto'
	pct := el_with(doc, 'section', 'style', 'width: 50%')
	assert computed_length_px(pct, pid('width'), no_author) == none // % needs a containing block
}

fn test_computed_color() {
	doc := dom.Document.create(dom.url_about_blank())
	parent := el_with(doc, 'div', 'style', 'color: red')
	child := el_with(doc, 'span', 'style',
		'background-color: #00ff00; border-top-color: currentColor')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	no_author := []&CSSRule{}
	// color inherits red from the parent.
	assert (computed_color(child, pid('color'), no_author) or { panic('color') }).serialize() == 'rgb(255 0 0)'
	// explicit green background.
	assert (computed_color(child, pid('background-color'), no_author) or { panic('bg') }).serialize() == 'rgb(0 255 0)'
	// currentColor resolves to the element's computed color (red).
	assert (computed_color(child, pid('border-top-color'), no_author) or { panic('bc') }).serialize() == 'rgb(255 0 0)'

	// Initial values: color is canvastext (black), background-color is transparent.
	plain := el_with(doc, 'p', 'style', '')
	assert (computed_color(plain, pid('color'), no_author) or { panic('pc') }).serialize() == 'rgb(0 0 0)'
	assert (computed_color(plain, pid('background-color'), no_author) or { panic('pb') }).serialize() == 'rgb(0 0 0 / 0)'
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

	rules := parse_css_stylesheet_contents_with_parser('.themed { color: purple }',
		map[string]bool{})
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

// calc() resolution: absolute calc (with em) via computed_length_px; percentage calc against a basis
// via computed_calc_px.
fn test_calc_computed_length() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'font-size: 20px; margin-top: calc(10px + 2em)')
	// 2em at 20px = 40, + 10 = 50.
	assert (computed_length_px(el, pid('margin-top'), []&CSSRule{}) or { panic('calc-abs') }) == 50.0

	pct := el_with(doc, 'div', 'style', 'width: calc(100% - 40px)')
	assert (computed_calc_px(pct, pid('width'), 200.0, []&CSSRule{}) or { panic('calc-pct') }) == 160.0
}

// get_computed_style / computed_style_value: the CSSOM-style computed value as a string.
fn test_computed_style_value() {
	doc := dom.Document.create(dom.url_about_blank())
	parent := el_with(doc, 'div', 'style', 'color: red; font-size: 20px')
	child := el_with(doc, 'span', 'style',
		'width: 100px; background-color: #00ff00; line-height: 30px')
	mut pn := parent.as_node()
	pn.append_child(child.as_node()) or { panic('${err}') }

	style := get_computed_style(child, []&CSSRule{})
	// color inherits from the parent -> resolved rgb().
	assert style.get_property_value('color') == 'rgb(255 0 0)'
	// background-color resolves to rgb().
	assert style.get_property_value('background-color') == 'rgb(0 255 0)'
	// font-size inherits (20) -> px.
	assert style.get_property_value('font-size') == '20px'
	// line-height -> px.
	assert style.get_property_value('line-height') == '30px'
	// an absolute length -> px.
	assert style.get_property_value('width') == '100px'
	// display is not set -> its cascaded (initial) value.
	assert style.get_property_value('display') == 'inline'
	// unset background-color on a plain element -> transparent.
	plain := el_with(doc, 'p', 'style', '')
	assert get_computed_style(plain, []&CSSRule{}).get_property_value('background-color') == 'rgb(0 0 0 / 0)'
}

// A calc() and an em length compute to px through get_computed_style too.
fn test_computed_style_value_calc_em() {
	doc := dom.Document.create(dom.url_about_blank())
	el := el_with(doc, 'div', 'style', 'font-size: 20px; margin-left: calc(10px + 2em)')
	// 2em @ 20px = 40, + 10 = 50.
	assert get_computed_style(el, []&CSSRule{}).get_property_value('margin-left') == '50px'
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

// `inherit` resolves to the parent element's cascaded value, even for a non-inherited property.
fn test_css_wide_keyword_inherit() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	parent.set_attribute_value('style', 'color: rgb(10, 20, 30); border-top-width: 7px')
	mut child := doc.create_element_ns(html_ns, 'span') or { panic('${err}') }
	child.set_attribute_value('style', 'color: inherit; border-top-width: inherit')
	mut pn := parent.as_node()
	pn.append_child(child.as_node()) or { panic('${err}') }
	no := []&CSSRule{}

	assert cascaded_value_with_ua(child, pid('color'), no) == 'rgb(10, 20, 30)'
	// border-top-width is NOT inherited by default, but `inherit` forces it.
	assert cascaded_value_with_ua(child, pid('border-top-width'), no) == '7px'
}

// `initial` resolves to the property's initial value, overriding a UA default.
fn test_css_wide_keyword_initial() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('style', 'display: initial')
	no := []&CSSRule{}

	// display: initial -> 'inline' (the initial value), beating the UA `div { display: block }`.
	assert cascaded_value_with_ua(div, pid('display'), no) == 'inline'
}

// `unset` acts as inherit for inherited properties and initial for non-inherited ones.
fn test_css_wide_keyword_unset() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	parent.set_attribute_value('style', 'color: rgb(1, 2, 3)')
	mut child := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	child.set_attribute_value('style', 'color: unset; display: unset')
	mut pn := parent.as_node()
	pn.append_child(child.as_node()) or { panic('${err}') }
	no := []&CSSRule{}

	// color is inherited -> unset inherits the parent's color.
	assert cascaded_value_with_ua(child, pid('color'), no) == 'rgb(1, 2, 3)'
	// display is not inherited -> unset is the initial value.
	assert cascaded_value_with_ua(child, pid('display'), no) == 'inline'
}

// `inherit` chains: an intermediate ancestor that itself declares `inherit` resolves fully.
fn test_css_wide_keyword_inherit_chain() {
	doc := dom.Document.create(dom.url_about_blank())
	mut grandparent := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	grandparent.set_attribute_value('style', 'color: rgb(9, 8, 7)')
	mut parent := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	parent.set_attribute_value('style', 'color: inherit')
	mut child := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	child.set_attribute_value('style', 'color: inherit')
	mut gn := grandparent.as_node()
	gn.append_child(parent.as_node()) or { panic('${err}') }
	mut pn := parent.as_node()
	pn.append_child(child.as_node()) or { panic('${err}') }
	no := []&CSSRule{}

	assert cascaded_value_with_ua(child, pid('color'), no) == 'rgb(9, 8, 7)'
}

// var() substitutes a custom property's value; an undefined var uses its fallback.
fn test_var_basic_and_fallback() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('style',
		'--brand: rgb(1, 2, 3); color: var(--brand); width: var(--w, 9px)')
	no := []&CSSRule{}

	assert cascaded_value_with_ua(div, pid('color'), no) == 'rgb(1, 2, 3)'
	assert cascaded_value_with_ua(div, pid('width'), no) == '9px' // --w undefined -> fallback
}

// Custom properties inherit: a var() on a child resolves against an ancestor's declaration.
fn test_var_inherits_from_ancestor() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	parent.set_attribute_value('style', '--accent: rgb(200, 100, 0)')
	mut child := doc.create_element_ns(html_ns, 'span') or { panic('${err}') }
	child.set_attribute_value('style', 'color: var(--accent)')
	mut pn := parent.as_node()
	pn.append_child(child.as_node()) or { panic('${err}') }
	no := []&CSSRule{}

	assert cascaded_value_with_ua(child, pid('color'), no) == 'rgb(200, 100, 0)'
}

// A custom property whose value itself references another var() is resolved (re-scan).
fn test_var_indirection() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('style', '--a: 12px; --b: var(--a); width: var(--b)')
	no := []&CSSRule{}

	assert cascaded_value_with_ua(div, pid('width'), no) == '12px'
}

// A var() fallback may itself contain a var().
fn test_var_fallback_uses_var() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('style', '--fallback: 5px; width: var(--missing, var(--fallback))')
	no := []&CSSRule{}

	assert cascaded_value_with_ua(div, pid('width'), no) == '5px'
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
}

// flatten_media_rules includes a matching @media's children and drops a non-matching one's.
fn test_flatten_media_rules() {
	rules := parse_css_stylesheet_contents_with_parser('.a { color: red } @media (min-width: 600px) { .wide { color: blue } } @media (max-width: 400px) { .narrow { color: green } }',
		map[string]bool{})

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

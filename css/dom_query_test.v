module css

import dom

// Verifies the css-side querySelector / matches / closest entry points run the real CSS
// selector engine against a live DOM tree.

fn make_element(doc &dom.Document, tag string, id string, class string) &dom.Element {
	mut element := doc.create_element(tag) or { panic('${err}') }
	if id != '' {
		element.set_attribute_value('id', id)
	}
	if class != '' {
		element.set_attribute_value('class', class)
	}
	return element
}

fn append(mut parent dom.Node, child &dom.Element) {
	parent.append_child(child.as_node()) or { panic('${err}') }
}

fn build_tree(doc &dom.Document) &dom.Node {
	mut root := make_element(doc, 'div', 'root', 'container')
	mut root_node := root.as_node()
	mut list := make_element(doc, 'ul', 'list', '')
	append(mut root_node, list)
	mut list_node := list.as_node()
	item_a := make_element(doc, 'li', 'a', 'item')
	item_b := make_element(doc, 'li', 'b', 'item active')
	item_c := make_element(doc, 'li', 'c', 'item')
	append(mut list_node, item_a)
	append(mut list_node, item_b)
	append(mut list_node, item_c)
	mut item_b_node := item_b.as_node()
	mut link := make_element(doc, 'a', 'link', '')
	link.set_attribute_value('href', 'x')
	append(mut item_b_node, link)
	return root_node
}

fn id_of(element ?&dom.Element) string {
	el := element or { return 'none' }
	return el.get_attribute('id') or { '?' }
}

fn test_query_selector_basic() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	assert id_of(query_selector(root, 'li')) == 'a'
	assert id_of(query_selector(root, '.active')) == 'b'
	assert id_of(query_selector(root, '#c')) == 'c'
	assert query_selector(root, 'section') == none
}

fn test_query_selector_all() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	assert query_selector_all(root, 'li').len == 3
	assert query_selector_all(root, '.item').len == 3
	assert query_selector_all(root, 'ul > li').len == 3
	assert query_selector_all(root, 'ul a').len == 1
	// Selector group.
	assert query_selector_all(root, 'ul, li').len == 4
}

fn test_universal_query_lists_every_descendant_element_in_tree_order() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := build_tree(doc)
	mut svg := doc.create_element_ns('http://www.w3.org/2000/svg', 'svg') or { panic('${err}') }
	root.append_child(svg.as_node()) or { panic('${err}') }
	mut svg_node := svg.as_node()
	circle := doc.create_element_ns('http://www.w3.org/2000/svg', 'circle') or { panic('${err}') }
	svg_node.append_child(circle.as_node()) or { panic('${err}') }
	root.append_child(doc.create_text_node('text').as_node()) or { panic('${err}') }
	universal := query_selector_all(root, '*')
	assert universal.map(it.local_name()) == ['ul', 'li', 'li', 'a', 'li', 'svg', 'circle']
	// The fast path returns the same elements as the general matcher, and
	// excludes the root itself.
	general := query_selector_all(root, ':not(#none)')
	assert universal.len == general.len
	for index, element in universal {
		assert voidptr(element) == voidptr(general[index])
	}
	assert query_selector_all(circle.as_node(), '*').len == 0
}

fn test_query_selector_pseudo_and_attr() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	assert id_of(query_selector(root, 'li:first-child')) == 'a'
	assert id_of(query_selector(root, 'li:last-child')) == 'c'
	assert id_of(query_selector(root, '[href]')) == 'link'
}

fn test_element_matches_and_closest() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	link := query_selector(root, '#link') or { panic('no link') }
	assert element_matches_selector(link, 'a[href]')
	assert !element_matches_selector(link, 'div')
	// closest walks up to the nearest matching ancestor (inclusive).
	assert id_of(closest_matching_selector(link, '.container')) == 'root'
	assert id_of(closest_matching_selector(link, 'a')) == 'link'
	assert closest_matching_selector(link, 'table') == none
}

fn test_standard_dom_selector_entry_points_use_css_engine() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	install_document_selector_query_hook(doc)

	mut parent := unsafe { &dom.ParentNode(root) }
	first := parent.query_selector('ul > li.active') or { panic('DOM querySelector did not match') }
	assert id_of(first) == 'b'

	all := parent.query_selector_all('.item') or { panic('${err}') }
	assert all.length() == 3

	link := query_selector(root, '#link') or { panic('no link') }
	assert link.matches('li.active > a[href]') or { false }
	closest := link.closest('.container') or { panic('DOM closest did not match') }
	assert id_of(closest) == 'root'
}

fn test_dom_selector_namespace_validation_uses_full_selector_tree() {
	// ParentNode.cpp rejects named namespace prefixes but accepts the wildcard namespace.
	doc := dom.Document.create(dom.url_about_blank())
	root := build_tree(doc)
	install_document_selector_query_hook(doc)
	mut parent := unsafe { &dom.ParentNode(root) }
	wildcard := parent.query_selector_all('*|li') or { panic('wildcard namespace must parse') }
	assert wildcard.length() == 3
	_ := parent.query_selector_all('svg|li') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false
}

fn test_named_namespace_detection_recurses_into_pseudo_class_selector_lists() {
	selectors := parse_selector_with_parser(':is(div, :not(svg|rect))', {
		'svg': true
	}) or { panic('selector with declared namespace did not parse') }
	assert selector_list_contains_named_namespace(selectors)

	wildcard := parse_selector_with_parser(':is(*|rect)', map[string]bool{}) or {
		panic('wildcard namespace did not parse')
	}
	assert !selector_list_contains_named_namespace(wildcard)
}

fn build_has_tree(doc &dom.Document) &dom.Node {
	// root > outer(div) > inner(section) > paragraph(p.active), and root > span.
	// querySelectorAll() searches descendants only, so `root` itself never matches.
	mut root := doc.create_element('div') or { panic('create failed') }
	root.set_attribute_value('id', 'root')
	mut outer := doc.create_element('div') or { panic('create failed') }
	outer.set_attribute_value('id', 'outer')
	mut inner := doc.create_element('section') or { panic('create failed') }
	inner.set_attribute_value('id', 'inner')
	mut paragraph := doc.create_element('p') or { panic('create failed') }
	paragraph.set_attribute_value('id', 'paragraph')
	paragraph.set_attribute_value('class', 'active')
	mut span := doc.create_element('span') or { panic('create failed') }
	span.set_attribute_value('id', 'span')
	mut inner_node := inner.as_node()
	inner_node.append_child(paragraph.as_node()) or { panic('append failed') }
	mut outer_node := outer.as_node()
	outer_node.append_child(inner_node) or { panic('append failed') }
	mut root_node := root.as_node()
	root_node.append_child(outer_node) or { panic('append failed') }
	root_node.append_child(span.as_node()) or { panic('append failed') }
	return root_node
}

fn ids_of(elements []&dom.Element) []string {
	mut ids := []string{}
	for element in elements {
		ids << element.get_attribute_value('id')
	}
	return ids
}

// Parser::parse_complex_selector(): parse_compound_selector() leaves the leading
// combinator as Descendant and only SelectorType::Standalone resets it to None,
// so `:has(.a)` is a *descendant* relative selector. Leaving it as
// no-combinator made every `:has()` written without an explicit combinator match
// nothing.
fn test_relative_selectors_default_to_the_descendant_combinator() {
	doc := dom.Document.create(dom.url_about_blank())
	root := build_has_tree(doc)
	assert ids_of(query_selector_all(root, ':has(p)')) == ['outer', 'inner']
	assert ids_of(query_selector_all(root, ':has(.active)')) == ['outer', 'inner']
	assert ids_of(query_selector_all(root, 'div:has(p)')) == ['outer']
	assert ids_of(query_selector_all(root, 'section:has(.active)')) == ['inner']
	assert ids_of(query_selector_all(root, ':has(p, span)')) == ['outer', 'inner']
	// An explicit combinator keeps working.
	assert ids_of(query_selector_all(root, ':has(> p)')) == ['inner']
	assert ids_of(query_selector_all(root, ':has(> section)')) == ['outer']
	assert ids_of(query_selector_all(root, ':not(:has(p))')) == ['paragraph', 'span']
}

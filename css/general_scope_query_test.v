module css

import dom

const general_scope_svg = 'http://www.w3.org/2000/svg'

fn general_scope_child(document &dom.Document, parent &dom.Node, name string, attributes map[string]string) &dom.Node {
	mut element := if name in ['svg', 'foreignObject'] {
		document.create_element_ns(general_scope_svg, name) or { panic(err) }
	} else {
		document.create_element(name) or { panic(err) }
	}
	for key, value in attributes { element.set_attribute_value(key, value) }
	mut owner := unsafe { &dom.Node(parent) }
	_ = owner.append_child(element.as_node()) or { panic(err) }
	return element.as_node()
}

struct GeneralScopeFixture {
mut:
	document &dom.Document
	roots    []&dom.Node
}

fn general_scope_fixture(quirks bool) GeneralScopeFixture {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	if quirks { document.set_quirks_mode(.yes) }
	html := general_scope_child(document, document.as_node(), 'html', {})
	body := general_scope_child(document, html, 'body', {'class': 'page'})
	main := general_scope_child(document, body, 'main', {'id': 'main', 'class': 'layout wide'})
	first := general_scope_child(document, main, 'section', {'class': 'pane a'})
	_ = general_scope_child(document, first, 'h2', {'class': 'title'})
	_ = general_scope_child(document, first, 'p', {'class': 'text first'})
	_ = general_scope_child(document, first, 'p', {'class': 'text'})
	_ = general_scope_child(document, first, 'a', {'class': 'link', 'href': '#'})
	second := general_scope_child(document, main, 'section', {'class': 'pane b', 'data-state': 'open'})
	list := general_scope_child(document, second, 'ul', {'class': 'list'})
	_ = general_scope_child(document, list, 'li', {'class': 'item one'})
	_ = general_scope_child(document, list, 'li', {'class': 'item two selected'})
	_ = general_scope_child(document, list, 'li', {'class': 'item'})
	svg := general_scope_child(document, second, 'svg', {})
	foreign := general_scope_child(document, svg, 'foreignObject', {})
	_ = general_scope_child(document, foreign, 'div', {'class': 'inner'})
	footer := general_scope_child(document, body, 'footer', {'id': 'foot'})
	_ = general_scope_child(document, footer, 'span', {'class': 'note'})
	return GeneralScopeFixture{document, [document.as_node(), main, second, footer]}
}

// The hook's planned walk returns exactly the nodes of the DOM's own walk.
fn general_scope_compare(mut fixture GeneralScopeFixture, selector string) int {
	install_document_selector_query_hook(fixture.document)
	hook := fixture.document.selector_query_hook() or { panic('missing selector hook') }
	mut owner := unsafe { &dom.Document(fixture.document) }
	mut total := 0
	for root in fixture.roots {
		parent := unsafe { &dom.ParentNode(root) }
		owner.set_selector_query_hook(dom.DocumentSelectorQueryHook{...hook, scope_query: unsafe { nil }})
		expected := parent.query_selector_all(selector) or { panic(err) }
		expected_first := parent.query_selector(selector)
		owner.set_selector_query_hook(hook)
		actual := parent.query_selector_all(selector) or { panic(err) }
		actual_first := parent.query_selector(selector)
		assert actual.nodes.len == expected.nodes.len, selector
		for index, node in actual.nodes { assert voidptr(node) == voidptr(expected.nodes[index]), selector }
		if element := expected_first {
			found := actual_first or { panic('missed first ${selector}') }
			assert voidptr(found) == voidptr(element), selector
		} else {
			assert actual_first == none, selector
		}
		total += actual.nodes.len
	}
	return total
}

const general_scope_selectors = ['.pane .text', 'section > p.first, .missing .x', 'li:not(.selected)',
	'.list li.two, #foot span, h2', 'ul:has(.selected) li', ':scope > section', 'main p + p',
	'.pane ~ .pane a, .b .item', 'body *', 'section foreignObject', 'section foreignobject',
	'section FOREIGNOBJECT', 'svg DIV.inner', 'svg div.inner', '[data-state] li', 'li[class~=two] ~ li',
	'#main .item.selected, #nope .item', ':not(.a) > .item', 'main :is(h2, .link)', '.page > *  > section',
	'.PANE .TEXT', '#MAIN .item', 'html body main section ul li.item.one', 'main [HREF], .b [data-STATE] li, section[data-state] svg *',
	'.pane [href^="#"], main [class~=two]', '.note, .pane .title, .wide li',
	'main:not(#main) p', ':root .note', 'li:first-child, li:last-child', 'p:nth-child(2n of .text) ~ a']

// Every general selector list, from the document and from elements, in
// standards and quirks mode.
fn test_general_scope_walk_equals_the_dom_walk() {
	for quirks in [false, true] {
		mut fixture := general_scope_fixture(quirks)
		defer { fixture.document.finalize() }
		walks_before, _ := general_scope_query_statistics()
		mut matched := 0
		for selector in general_scope_selectors { matched += general_scope_compare(mut fixture, selector) }
		assert matched > 40
		walks_after, _ := general_scope_query_statistics()
		if !retain_general_scope_walk { assert walks_after > walks_before }
		// Class and ID case folds only in quirks mode.
		assert (general_scope_compare(mut fixture, '.PANE .TEXT') > 0) == quirks
	}
}

// An observer-style list of many selectors tries, for each element, only
// those whose subject the element can satisfy.
fn test_long_selector_lists_are_bucketed_by_subject() {
	mut fixture := general_scope_fixture(false)
	defer { fixture.document.finalize() }
	mut parts := []string{}
	for index in 0 .. 120 {
		parts << match index % 4 {
			0 { '.js-observer-${index} .target' }
			1 { 'form.js-form-${index} > input' }
			2 { '#widget-${index} .row' }
			else { 'details-menu-${index} [role=menuitem]' }
		}
	}
	parts << '.pane .text'
	parts << '#foot .note'
	parts << 'ul li.selected'
	selector := parts.join(',')
	_, attempts_before := general_scope_query_statistics()
	assert general_scope_compare(mut fixture, selector) > 0
	_, attempts_after := general_scope_query_statistics()
	if !retain_general_scope_walk {
		// 18 elements, 4 roots, two queries each: far fewer than every
		// selector for every element (123 * 18 * 8).
		assert attempts_after - attempts_before < 200
	}
	// The buckets belong to the plan and are built once.
	install_document_selector_query_hook(fixture.document)
	hook := fixture.document.selector_query_hook() or { panic('missing selector hook') }
	mut state := unsafe { &DocumentSelectorQueryState(hook.target) }
	plan := state.query_plan(selector) or { panic('missing plan') }
	if !retain_general_scope_walk {
		assert plan.buckets != unsafe { nil }
		// Subjects: .target, .row, .text, .note and .selected; [role]; input.
		assert plan.buckets.by_class.len == 5 && plan.buckets.by_id.len == 0
		assert plan.buckets.by_attribute.len == 1 && plan.buckets.by_tag.len == 1
		assert plan.buckets.other.len == 0
		assert plan.buckets.by_class['target'].len == 30 && plan.buckets.by_attribute['role'].len == 30
		assert voidptr(plan.subject_buckets()) == voidptr(plan.buckets)
	}
}

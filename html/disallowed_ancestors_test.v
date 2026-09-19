module html

import dom
import editing

fn append_test_element(document &dom.Document, parent &dom.Node, name string, text string) &dom.Element {
	element := document.create_element(name) or { panic(err) }
	if text != '' {
		mut mutable_element_node := unsafe { &dom.Node(element.as_node()) }
		mutable_element_node.append_child(document.create_text_node(text).as_node()) or { panic(err) }
	}
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return element
}

fn test_allowed_child_rejects_structural_html_violations() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><p id="paragraph"><a id="link"></a></p><table id="table"></table></div></body>')
	paragraph := document.get_element_by_id('paragraph') or { panic('missing paragraph') }
	link := document.get_element_by_id('link') or { panic('missing link') }
	table := document.get_element_by_id('table') or { panic('missing table') }
	block := document.create_element('section') or { panic(err) }
	nested_link := document.create_element('a') or { panic(err) }
	row := document.create_element('tr') or { panic(err) }
	non_whitespace := document.create_text_node('cell')
	whitespace := document.create_text_node('  ')

	assert !editing.is_allowed_child_of_dom_node(block.as_node(), paragraph.as_node())
	assert !editing.is_allowed_child_of_dom_node(nested_link.as_node(), link.as_node())
	assert editing.is_allowed_child_of_dom_node(row.as_node(), table.as_node())
	assert !editing.is_allowed_child_of_dom_node(non_whitespace.as_node(), table.as_node())
	assert editing.is_allowed_child_of_dom_node(whitespace.as_node(), table.as_node())
}

fn test_fix_disallowed_ancestors_splits_inline_and_paragraph_wrappers() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><p id="paragraph"><span>before</span><span id="wrapper">after</span></p></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	paragraph := document.get_element_by_id('paragraph') or { panic('missing paragraph') }
	wrapper := document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	section := append_test_element(document, wrapper.as_node(), 'section', 'middle')
	section_text := section.as_node().first_child() or { panic('missing section text') }

	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(section_text, 3) or { panic(err) }

	editing.fix_disallowed_ancestors_of_dom_node(section.as_node())

	assert host.as_node().child_count() == 2
	assert host.as_node().child_at_index(0)? == paragraph.as_node()
	assert host.as_node().child_at_index(1)? == section.as_node()
	assert paragraph.as_node().text_content()? == 'beforeafter'
	assert section.as_node().text_content()? == 'middle'
	assert selection.focus_node()? == section_text
	assert selection.focus_offset() == 3
}

fn test_fix_disallowed_ancestors_splits_a_middle_nested_anchor() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><a id="outer">left<span id="marker"></span>right</a></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	outer := document.get_element_by_id('outer') or { panic('missing outer link') }
	marker := document.get_element_by_id('marker') or { panic('missing marker') }
	inner := document.create_element('a') or { panic(err) }
	mut mutable_inner := unsafe { &dom.Element(inner) }
	mutable_inner.set_attribute_value('href', '/inner')
	mut mutable_inner_node := unsafe { &dom.Node(inner.as_node()) }
	mutable_inner_node.append_child(document.create_text_node('inner').as_node()) or { panic(err) }
	mut mutable_outer_node := unsafe { &dom.Node(outer.as_node()) }
	mutable_outer_node.insert_before(inner.as_node(), marker.as_node(), false)

	editing.fix_disallowed_ancestors_of_dom_node(inner.as_node())

	assert host.as_node().child_count() == 3
	left := host.as_node().child_at_index(0) or { panic('missing left link') }
	middle := host.as_node().child_at_index(1) or { panic('missing inner link') }
	right := host.as_node().child_at_index(2) or { panic('missing right link') }
	assert left.text_content()? == 'left'
	assert middle == inner.as_node()
	assert middle.text_content()? == 'inner'
	assert right.text_content()? == 'right'
	assert left.as_element()?.get_attribute_value('id') == 'outer'
	assert !right.as_element()?.has_attribute('id')
}

fn test_fix_disallowed_ancestors_wraps_definition_items() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	term := append_test_element(document, host.as_node(), 'dt', 'term')

	editing.fix_disallowed_ancestors_of_dom_node(term.as_node())

	assert host.as_node().child_count() == 1
	list := host.as_node().first_child() or { panic('missing definition list') }
	list_element := list.as_element() or { panic('definition list is not an element') }
	assert list_element.local_name() == 'dl'
	assert list.first_child()? == term.as_node()
}

fn test_fix_disallowed_ancestors_uses_default_container_for_orphan_list_item() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	item := append_test_element(document, host.as_node(), 'li', 'item')
	mut mutable_item := unsafe { &dom.Element(item) }
	mutable_item.set_attribute_value('class', 'kept')

	editing.fix_disallowed_ancestors_of_dom_node(item.as_node())

	replacement := host.as_node().first_child() or { panic('missing replacement') }
	replacement_element := replacement.as_element() or { panic('replacement is not an element') }
	assert replacement_element.local_name() == 'div'
	assert replacement_element.get_attribute_value('class') == 'kept'
	assert replacement.text_content()? == 'item'
}

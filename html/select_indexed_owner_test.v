// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn test_indexed_option_replacement_preserves_the_optgroup_parent() {
	mut document := parse_document('<select><optgroup><option id=old>old</option></optgroup></select>')
	select_element := document.query_selector('select') or { panic('Missing select') }
	group := document.query_selector('optgroup') or { panic('Missing group') }
	old := document.query_selector('#old') or { panic('Missing option') }
	replacement := document.create_element('option')!
	set_html_select_element_indexed_option(unsafe { &dom.HTMLSelectElement(select_element) }, 0, unsafe { &dom.HTMLOptionElement(replacement) })!
	parent := replacement.parent_node() or { panic('Missing replacement parent') }
	assert voidptr(parent) == voidptr(group.as_node())
	assert old.parent_node() == none
	first := html_select_element_item(unsafe { &dom.HTMLSelectElement(select_element) }, 0) or { panic('Missing option') }
	assert voidptr(first) == voidptr(replacement)
}

fn test_indexed_option_removal_and_gap_creation_use_the_live_option_tree() {
	mut document := parse_document('<select><optgroup><option>old</option></optgroup></select>')
	select_element := document.query_selector('select') or { panic('Missing select') }
	native := unsafe { &dom.HTMLSelectElement(select_element) }
	set_html_select_element_indexed_option(native, 0, none)!
	assert html_select_element_length(native) == 0
	replacement := document.create_element('option')!
	set_html_select_element_indexed_option(native, 2, unsafe { &dom.HTMLOptionElement(replacement) })!
	assert html_select_element_length(native) == 3
	first := html_select_element_item(native, 0) or { panic('Missing gap option') }
	last := html_select_element_item(native, 2) or { panic('Missing inserted option') }
	assert html_option_element_value(first) == ''
	assert voidptr(last) == voidptr(replacement)
}

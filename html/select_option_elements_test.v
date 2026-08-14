module html

import dom

fn select_test_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := select_test_element(child, local_name) {
			return element
		}
	}
	return none
}

fn test_select_option_list_selectedness_value_and_reset() {
	document := parse_document('<select required><option value="">Choose</option><optgroup><option value="a"> A  label </option></optgroup><option selected value="b">B</option></select>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	html_select_element_update_selectedness(select_control)
	options := html_select_element_list_of_options(select_control)
	assert options.len == 3
	assert html_select_element_selected_index(select_control) == 2
	assert html_select_element_value(select_control) == 'b'
	assert html_option_element_text(options[1]) == 'A label'
	assert html_option_element_label(options[1]) == 'A label'
	assert html_option_element_index(options[1]) == 1
	assert !html_option_element_disabled(options[1])
	placeholder := html_select_element_placeholder_label_option(select_control) or {
		panic('missing placeholder')
	}
	assert option_node(placeholder).is_same_node(option_node(options[0]))

	set_html_select_element_value(select_control, 'a')
	assert html_select_element_selected_index(select_control) == 1
	assert html_select_element_value(select_control) == 'a'
	html_select_element_reset(select_control)
	assert html_select_element_selected_index(select_control) == 2
}

fn test_select_selectedness_uses_last_updated_option_and_disabled_default() {
	document := parse_document('<select><option disabled>disabled</option><option>first</option><option>last</option></select>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	html_select_element_update_selectedness(select_control)
	options := html_select_element_list_of_options(select_control)
	assert html_select_element_selected_index(select_control) == 1
	html_option_element_set_selected_internal(options[1], true)
	html_option_element_set_selected_internal(options[2], true)
	html_select_element_update_selectedness(select_control)
	assert !html_option_element_selected(options[1])
	assert html_option_element_selected(options[2])
}

fn test_select_options_collection_mutations() {
	document := parse_document('<select><option id="a">a</option></select>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	set_html_select_element_length(select_control, 3) or { panic('${err}') }
	assert html_select_element_length(select_control) == 3
	assert html_select_element_named_item(select_control, 'a') != none
	set_html_select_element_length(select_control, 1) or { panic('${err}') }
	assert html_select_element_length(select_control) == 1

	new_option_element := dom.create_element(document, 'option', ns_html, none, none, false) or {
		panic('${err}')
	}
	new_option := unsafe { &dom.HTMLOptionElement(new_option_element) }
	set_html_option_element_text(new_option, 'new')
	set_html_select_element_indexed_option(select_control, 2, new_option) or { panic('${err}') }
	assert html_select_element_length(select_control) == 3
	assert html_option_element_text(html_select_element_item(select_control, 2) or {
		panic('missing')
	}) == 'new'
	html_select_element_remove_option(select_control, 1)
	assert html_select_element_length(select_control) == 2
}

fn test_nested_select_boundaries_and_option_disabled_by_optgroup() {
	document := dom.Document.create(dom.url_about_blank())
	select_element := dom.create_element(document, 'select', ns_html, none, none, false) or {
		panic('${err}')
	}
	outer_group := dom.create_element(document, 'optgroup', ns_html, none, none, false) or {
		panic('${err}')
	}
	mut outer_group_element := unsafe { &dom.Element(outer_group) }
	outer_group_element.set_attribute_value('disabled', '')
	first := dom.create_element(document, 'option', ns_html, none, none, false) or { panic('${err}') }
	mut first_node := first.as_node()
	first_node.string_replace_all('a')
	inner_group := dom.create_element(document, 'optgroup', ns_html, none, none, false) or {
		panic('${err}')
	}
	nested := dom.create_element(document, 'option', ns_html, none, none, false) or {
		panic('${err}')
	}
	hr := dom.create_element(document, 'hr', ns_html, none, none, false) or { panic('${err}') }
	inside_hr := dom.create_element(document, 'option', ns_html, none, none, false) or {
		panic('${err}')
	}
	last := dom.create_element(document, 'option', ns_html, none, none, false) or { panic('${err}') }
	mut last_node := last.as_node()
	last_node.string_replace_all('last')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(select_element.as_node()) or { panic('${err}') }
	mut select_element_node := select_element.as_node()
	select_element_node.append_child(outer_group.as_node()) or { panic('${err}') }
	select_element_node.append_child(hr.as_node()) or { panic('${err}') }
	select_element_node.append_child(last.as_node()) or { panic('${err}') }
	mut outer_group_node := outer_group.as_node()
	outer_group_node.append_child(first.as_node()) or { panic('${err}') }
	outer_group_node.append_child(inner_group.as_node()) or { panic('${err}') }
	mut inner_group_node := inner_group.as_node()
	inner_group_node.append_child(nested.as_node()) or { panic('${err}') }
	mut hr_node := hr.as_node()
	hr_node.append_child(inside_hr.as_node()) or { panic('${err}') }
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	options := html_select_element_list_of_options(select_control)
	assert options.len == 2
	assert html_option_element_disabled(options[0])
	assert html_option_element_text(options[1]) == 'last'
}

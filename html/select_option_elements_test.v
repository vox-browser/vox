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
		panic('missing')}) == 'new'
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
	first := dom.create_element(document, 'option', ns_html, none, none, false) or {
		panic('${err}')
	}
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
	last := dom.create_element(document, 'option', ns_html, none, none, false) or {
		panic('${err}')
	}
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

fn test_selectedcontent_cloning_disabling_and_non_primary_clearing() {
	document := parse_document('<select><selectedcontent></selectedcontent><selectedcontent>stale</selectedcontent><option selected><b>Chosen</b> text</option></select>')
	root := unsafe { &dom.Node(document) }
	select_element := select_test_element(root, 'select') or { panic('missing select') }
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	selectedcontents := html_select_element_selectedcontent_descendants(select_control)
	assert selectedcontents.len == 2
	html_selectedcontent_element_post_connection(selectedcontents[0])!
	assert unsafe { &dom.Element(selectedcontents[0]) }.as_node().descendant_text_content() == 'Chosen text'
	assert unsafe { &dom.Element(selectedcontents[1]) }.as_node().descendant_text_content() == ''
	assert !html_selectedcontent_element_disabled(selectedcontents[0])

	option := html_select_element_list_of_options(select_control)[0]
	mut option_node_ := option_node(option)
	option_node_.string_replace_all('Updated')
	html_option_element_maybe_clone_into_selectedcontent(option)!
	assert unsafe { &dom.Element(selectedcontents[0]) }.as_node().descendant_text_content() == 'Updated'

	mut select_dom := unsafe { &dom.Element(select_control) }
	select_dom.set_attribute_value('multiple', '')
	assert html_select_element_enabled_selectedcontent(select_control) == none
}

fn test_selectedcontent_nested_select_and_option_ancestors_disable_it() {
	document := parse_document('<select><option><selectedcontent>x</selectedcontent></option></select>')
	root := unsafe { &dom.Node(document) }
	selectedcontent_element := select_test_element(root, 'selectedcontent') or {
		panic('missing selectedcontent')
	}
	selectedcontent := unsafe { &dom.HTMLSelectedContentElement(selectedcontent_element) }
	html_selected_content_element_post_connection(selectedcontent)!
	assert html_selectedcontent_element_disabled(selectedcontent)
	html_selected_content_element_clear_selectedcontent(selectedcontent)
	assert selectedcontent_element.as_node().children_as_vector().len == 0
}

fn test_optgroup_lifecycle_datalist_options_and_selectedcontent_removal_boundary() {
	document := parse_document('<select><optgroup><option>one</option></optgroup><option>two</option></select><datalist><option>a</option><div><option>b</option></div></datalist>')
	root := unsafe { &dom.Node(document) }
	select_element := select_test_element(root, 'select') or { panic('select') }
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	optgroup_element := select_test_element(root, 'optgroup') or { panic('optgroup') }
	optgroup := unsafe { &dom.HTMLOptGroupElement(optgroup_element) }
	html_opt_group_element_inserted(optgroup)
	assert html_select_element_selected_index(select_control) == 0
	html_opt_group_element_removed_from(optgroup, select_element.as_node(), root)

	datalist_element := select_test_element(root, 'datalist') or { panic('datalist') }
	datalist := unsafe { &dom.HTMLDataListElement(datalist_element) }
	options := html_data_list_element_options(datalist)
	assert options.length() == 2
	assert voidptr(html_data_list_element_options(datalist)) == voidptr(options)

	selectedcontent_element := dom.create_element(document, 'selectedcontent', ns_html, none, none, false)!
	selectedcontent := unsafe { &dom.HTMLSelectedContentElement(selectedcontent_element) }
	html_selected_content_element_removed_from(selectedcontent, none, root)!
}

fn test_option_lifecycle_cached_select_form_label_role_and_selectedcontent_clone() {
	document := parse_document('<form><select><selectedcontent></selectedcontent><option selected>Alpha</option></select></form>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	option := html_select_element_list_of_options(select_control)[0]
	html_option_element_inserted(option)
	assert option.cached_nearest_select_element_? == select_control
	assert html_option_element_compute_nearest_select_element(option)? == select_control
	assert html_option_element_form(option) != none
	assert html_option_element_default_role(option) == .option

	mut model := HTMLSelectElementModel.create(select_control)
	model.form_associated_element_was_inserted()
	inner := model.inner_text_element_ or { panic('missing inner text') }
	assert inner.as_node().child_text_content() == 'Alpha'
	mut option_element := option_dom_element(option)
	option_element.set_attribute_value('label', 'Named')
	html_option_element_attribute_changed(option, 'label', none, 'Named', none)
	assert inner.as_node().child_text_content() == 'Named'

	selectedcontent_element := select_test_element(unsafe { &dom.Node(document) }, 'selectedcontent') or {
		panic('missing selectedcontent')
	}
	selectedcontent := unsafe { &dom.HTMLSelectedContentElement(selectedcontent_element) }
	html_option_element_clone_into_selectedcontent(option, selectedcontent)!
	assert selectedcontent_element.as_node().descendant_text_content() == 'Alpha'

	mut option_node_ := option_node(option)
	option_node_.string_replace_all('Beta')
	html_option_element_children_changed(option, dom.ChildrenChangedMetadata{
		type_: .mutation
		node: option_node(option)
	})
	assert html_option_element_text(option) == 'Beta'

	old_parent := option_node(option).parent_node()
	old_root := option_node(option).root()
	option_node_.remove(false)
	html_option_element_removed_from(option, old_parent, old_root)
	assert option.cached_nearest_select_element_ == none
}

fn select_test_make_document_fully_active(mut document dom.Document) {
	mut navigable := &dom.Navigable{
		active_document_: &document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
}

fn test_select_model_options_picker_notifications_and_shadow_tree() {
	mut document := parse_document('<select><option value="a">Alpha</option><optgroup label="Group"><option selected value="b"> Beta </option></optgroup><hr></select>')
	select_test_make_document_fully_active(mut document)
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	mut model := HTMLSelectElementModel.create(select_control)
	assert model.has_activation_behavior()
	assert model.default_tab_index_value() == 0
	assert model.default_role() == .combobox
	assert model.is_focusable()
	assert model.is_mutable()
	assert model.options().length() == 2
	assert model.item_value(1)? == html_select_element_list_of_options(select_control)[1]
	assert model.options().selected_index() == 1

	model.form_associated_element_was_inserted()
	assert select_element.shadow_root() != none
	inner := model.inner_text_element_ or { panic('missing inner text') }
	assert inner.as_node().child_text_content() == 'Beta'
	assert inner.get_attribute_value('style').contains('min-width:0')
	assert inner.get_attribute_value('style').contains('overflow:clip')
	assert inner.get_attribute_value('style').contains('text-overflow:inherit')
	assert inner.get_attribute_value('style').contains('margin-inline-end:20px')
	chevron := model.chevron_icon_element_ or { panic('missing chevron') }
	assert chevron.get_attribute_value('style').contains('position:absolute')
	assert chevron.get_attribute_value('style').contains('inset-inline-end:0')
	model.computed_properties_changed(true)
	assert chevron.get_attribute_value('style').contains('display:none')
	assert !inner.get_attribute_value('style').contains('margin-inline-end:20px')
	model.computed_properties_changed(false)
	assert chevron.get_attribute_value('style').contains('display:block')
	assert inner.get_attribute_value('style').contains('margin-inline-end:20px')

	model.set_picker_security_state(false, true)
	mut rejected := false
	model.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected
	model.set_picker_security_state(true, true)
	model.show_picker()!
	assert model.is_open_
	assert model.select_items_.len == 3
	model.did_select_item(1)
	assert html_select_element_value(select_control) == 'a'
	assert !model.is_open_
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert model.user_validity_

	model.reset_algorithm()
	assert html_select_element_value(select_control) == 'b'
	assert !model.user_validity_
}

fn test_select_model_collection_indexed_mutation_children_and_roles() {
	document := parse_document('<select multiple><option>a</option></select>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	mut model := HTMLSelectElementModel.create(select_control)
	assert model.default_role() == .listbox
	option_element := dom.create_element(document, 'option', ns_html, none, none, false)!
	mut option_node_ := option_element.as_node()
	option_node_.string_replace_all('new')
	option := unsafe { &dom.HTMLOptionElement(option_element) }
	model.set_value_of_indexed_property(2, option)!
	assert model.options().length() == 3
	assert model.options().item(2)? == option
	metadata := dom.ChildrenChangedMetadata{
		type_: .inserted
		node: option_node(option)
	}
	assert model.can_skip_children_changed_selectedness_update(metadata)
	model.children_changed(metadata)
	model.remove(1)
	assert model.options().length() == 2
	model.options().set_selected_index(1)
	assert model.options().selected_index() == 1
}

fn test_select_fallback_button_text_follows_every_selectedness_change() {
	document := parse_document('<select><option value="a" label="  Alpha  " selected>ignored</option><option value="b">Beta</option></select>')
	select_element := select_test_element(unsafe { &dom.Node(document) }, 'select') or {
		panic('missing select')
	}
	select_control := unsafe { &dom.HTMLSelectElement(select_element) }
	mut model := HTMLSelectElementModel.create(select_control)
	model.form_associated_element_was_inserted()
	inner := model.inner_text_element_ or { panic('missing fallback button text') }
	assert inner.as_node().child_text_content() == '  Alpha  '

	set_html_select_element_value(select_control, 'b')
	assert inner.as_node().child_text_content() == 'Beta'

	set_html_select_element_selected_index(select_control, -1)
	assert inner.as_node().child_text_content() == ''

	options := html_select_element_list_of_options(select_control)
	html_option_element_set_selected_internal(options[1], true)
	html_select_element_update_selectedness(select_control)
	assert inner.as_node().child_text_content() == 'Beta'
}

fn test_option_moving_steps_update_old_and_new_select_elements() {
	document := parse_document('<main><select id="old"><option id="moved" selected>Moved</option><option>Old fallback</option></select><select id="new" multiple><option>New</option></select></main>')
	old_element := document.get_element_by_id('old') or { panic('missing old select') }
	new_element := document.get_element_by_id('new') or { panic('missing new select') }
	moved_element := document.get_element_by_id('moved') or { panic('missing moved option') }
	old_select := unsafe { &dom.HTMLSelectElement(old_element) }
	new_select := unsafe { &dom.HTMLSelectElement(new_element) }
	moved_option := unsafe { &dom.HTMLOptionElement(moved_element) }
	mut old_model := HTMLSelectElementModel.create(old_select)
	mut new_model := HTMLSelectElementModel.create(new_select)
	old_model.form_associated_element_was_inserted()
	new_model.form_associated_element_was_inserted()
	html_option_element_inserted(moved_option)
	assert html_option_element_nearest_select_element(moved_option)? == old_select

	mut moved_node := moved_element.as_node()
	mut new_select_node := new_element.as_node()
	moved_node.move_node(mut new_select_node, none)!
	assert html_option_element_nearest_select_element(moved_option)? == new_select
	assert html_select_element_value(old_select) == 'Old fallback'
	assert old_model.inner_text_element_?.as_node().child_text_content() == 'Old fallback'
	assert new_model.inner_text_element_?.as_node().child_text_content() == 'Moved'

	moved_node.remove(false)
	assert html_option_element_nearest_select_element(moved_option) == none
	assert new_model.inner_text_element_?.as_node().child_text_content() == ''
}

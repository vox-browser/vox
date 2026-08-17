module aria

import dom

const aria_test_html_namespace = 'http://www.w3.org/1999/xhtml'

fn aria_test_element(document &dom.Document, name string) &dom.Element {
	return dom.create_element(document, name, aria_test_html_namespace, none, none, false) or {
		panic(err)
	}
}

fn test_aria_mixin_all_dom_string_reflection() {
	document := dom.Document.create(dom.url_about_blank())
	element := aria_test_element(document, 'div')
	mut mixin := ARIAMixin.create(element, none, none)
	mixin.set_role('value')
	assert mixin.role()? == 'value'
	mixin.set_aria_active_descendant('value')
	assert mixin.aria_active_descendant()? == 'value'
	mixin.set_aria_atomic('value')
	assert mixin.aria_atomic()? == 'value'
	mixin.set_aria_auto_complete('value')
	assert mixin.aria_auto_complete()? == 'value'
	mixin.set_aria_braille_label('value')
	assert mixin.aria_braille_label()? == 'value'
	mixin.set_aria_braille_role_description('value')
	assert mixin.aria_braille_role_description()? == 'value'
	mixin.set_aria_busy('value')
	assert mixin.aria_busy()? == 'value'
	mixin.set_aria_checked('value')
	assert mixin.aria_checked()? == 'value'
	mixin.set_aria_col_count('value')
	assert mixin.aria_col_count()? == 'value'
	mixin.set_aria_col_index('value')
	assert mixin.aria_col_index()? == 'value'
	mixin.set_aria_col_index_text('value')
	assert mixin.aria_col_index_text()? == 'value'
	mixin.set_aria_col_span('value')
	assert mixin.aria_col_span()? == 'value'
	mixin.set_aria_controls('value')
	assert mixin.aria_controls()? == 'value'
	mixin.set_aria_current('value')
	assert mixin.aria_current()? == 'value'
	mixin.set_aria_described_by('value')
	assert mixin.aria_described_by()? == 'value'
	mixin.set_aria_description('value')
	assert mixin.aria_description()? == 'value'
	mixin.set_aria_details('value')
	assert mixin.aria_details()? == 'value'
	mixin.set_aria_drop_effect('value')
	assert mixin.aria_drop_effect()? == 'value'
	mixin.set_aria_error_message('value')
	assert mixin.aria_error_message()? == 'value'
	mixin.set_aria_disabled('value')
	assert mixin.aria_disabled()? == 'value'
	mixin.set_aria_expanded('value')
	assert mixin.aria_expanded()? == 'value'
	mixin.set_aria_flow_to('value')
	assert mixin.aria_flow_to()? == 'value'
	mixin.set_aria_grabbed('value')
	assert mixin.aria_grabbed()? == 'value'
	mixin.set_aria_has_popup('value')
	assert mixin.aria_has_popup()? == 'value'
	mixin.set_aria_hidden('value')
	assert mixin.aria_hidden()? == 'value'
	mixin.set_aria_invalid('value')
	assert mixin.aria_invalid()? == 'value'
	mixin.set_aria_key_shortcuts('value')
	assert mixin.aria_key_shortcuts()? == 'value'
	mixin.set_aria_label('value')
	assert mixin.aria_label()? == 'value'
	mixin.set_aria_labelled_by('value')
	assert mixin.aria_labelled_by()? == 'value'
	mixin.set_aria_level('value')
	assert mixin.aria_level()? == 'value'
	mixin.set_aria_live('value')
	assert mixin.aria_live()? == 'value'
	mixin.set_aria_modal('value')
	assert mixin.aria_modal()? == 'value'
	mixin.set_aria_multi_line('value')
	assert mixin.aria_multi_line()? == 'value'
	mixin.set_aria_multi_selectable('value')
	assert mixin.aria_multi_selectable()? == 'value'
	mixin.set_aria_orientation('value')
	assert mixin.aria_orientation()? == 'value'
	mixin.set_aria_owns('value')
	assert mixin.aria_owns()? == 'value'
	mixin.set_aria_placeholder('value')
	assert mixin.aria_placeholder()? == 'value'
	mixin.set_aria_pos_in_set('value')
	assert mixin.aria_pos_in_set()? == 'value'
	mixin.set_aria_pressed('value')
	assert mixin.aria_pressed()? == 'value'
	mixin.set_aria_read_only('value')
	assert mixin.aria_read_only()? == 'value'
	mixin.set_aria_relevant('value')
	assert mixin.aria_relevant()? == 'value'
	mixin.set_aria_required('value')
	assert mixin.aria_required()? == 'value'
	mixin.set_aria_role_description('value')
	assert mixin.aria_role_description()? == 'value'
	mixin.set_aria_row_count('value')
	assert mixin.aria_row_count()? == 'value'
	mixin.set_aria_row_index('value')
	assert mixin.aria_row_index()? == 'value'
	mixin.set_aria_row_index_text('value')
	assert mixin.aria_row_index_text()? == 'value'
	mixin.set_aria_row_span('value')
	assert mixin.aria_row_span()? == 'value'
	mixin.set_aria_selected('value')
	assert mixin.aria_selected()? == 'value'
	mixin.set_aria_set_size('value')
	assert mixin.aria_set_size()? == 'value'
	mixin.set_aria_sort('value')
	assert mixin.aria_sort()? == 'value'
	mixin.set_aria_value_max('value')
	assert mixin.aria_value_max()? == 'value'
	mixin.set_aria_value_min('value')
	assert mixin.aria_value_min()? == 'value'
	mixin.set_aria_value_now('value')
	assert mixin.aria_value_now()? == 'value'
	mixin.set_aria_value_text('value')
	assert mixin.aria_value_text()? == 'value'

	mixin.set_aria_value_text(none)
	assert mixin.aria_value_text() == none
}

fn test_aria_mixin_reflection_roles_context_and_conflicts() {
	document := dom.Document.create(dom.url_about_blank())
	root := aria_test_element(document, 'div')
	parent := aria_test_element(document, 'div')
	child := aria_test_element(document, 'span')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!

	mut parent_mixin := ARIAMixin.create(parent, none, none)
	parent_mixin.set_role('list')
	mut child_mixin := ARIAMixin.create(child, Role.button, none)
	child_mixin.set_role('command listitem button')
	assert child_mixin.role_from_role_attribute_value()? == .listitem
	assert child_mixin.role_or_default()? == .listitem

	child_mixin.set_role('presentation')
	child_mixin.set_aria_label('named')
	assert child_mixin.role_or_default()? == .button
	child_mixin.set_aria_label(none)
	assert child_mixin.role_or_default()? == .none_

	child_mixin.set_role('directory')
	assert child_mixin.role_or_default()? == .list
	child_mixin.set_role('img')
	assert child_mixin.role_or_default()? == .image
}

fn test_aria_mixin_id_references_and_element_reference_caches() {
	document := dom.Document.create(dom.url_about_blank())
	root := aria_test_element(document, 'div')
	owner := aria_test_element(document, 'button')
	target_a := aria_test_element(document, 'span')
	target_b := aria_test_element(document, 'span')
	mut target_a_mut := unsafe { &dom.Element(target_a) }
	mut target_b_mut := unsafe { &dom.Element(target_b) }
	target_a_mut.set_attribute_value('id', 'a')
	target_b_mut.set_attribute_value('id', 'b')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(owner.as_node())!
	root_node.append_child(target_a.as_node())!
	root_node.append_child(target_b.as_node())!

	mut mixin := ARIAMixin.create(owner, .button, none)
	mixin.set_aria_controls('a missing b a')
	assert mixin.parse_id_reference(mixin.aria_controls()) == none
	assert mixin.parse_id_reference_list(mixin.aria_controls()) == ['a', 'b', 'a']
	mixin.set_aria_active_descendant_element(target_a)
	assert mixin.aria_active_descendant_element()? == target_a
	mixin.set_aria_controls_elements([target_a, target_b])
	assert mixin.aria_controls_elements()?.len == 2
	mixin.set_cached_aria_controls_elements([target_b])
	assert mixin.cached_aria_controls_elements()?[0] == target_b
	mixin.set_aria_controls_elements(none)
	assert mixin.aria_controls_elements() == none
	assert mixin.cached_aria_controls_elements() == none

	mixin.set_cached_aria_described_by_elements([target_a])
	mixin.set_cached_aria_details_elements([target_a])
	mixin.set_cached_aria_error_message_elements([target_a])
	mixin.set_cached_aria_flow_to_elements([target_a])
	mixin.set_cached_aria_labelled_by_elements([target_a])
	mixin.set_cached_aria_owns_elements([target_a])
	assert mixin.cached_aria_described_by_elements()?[0] == target_a
	assert mixin.cached_aria_details_elements()?[0] == target_a
	assert mixin.cached_aria_error_message_elements()?[0] == target_a
	assert mixin.cached_aria_flow_to_elements()?[0] == target_a
	assert mixin.cached_aria_labelled_by_elements()?[0] == target_a
	assert mixin.cached_aria_owns_elements()?[0] == target_a
}

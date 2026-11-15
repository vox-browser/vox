module html

import dom

fn test_lazy_select_owner_establishes_initial_selection_before_submission() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut select_element := document.create_element('select')!
	mut first := document.create_element('option')!
	mut second := document.create_element('option')!
	first.set_attribute_value('disabled', '')
	second.set_attribute_value('value', 'initial')
	select_element.as_node().append_child(first.as_node())!
	select_element.as_node().append_child(second.as_node())!
	native := unsafe { &dom.HTMLSelectElement(select_element) }
	_ := HTMLSelectElementModel.create(native)
	assert html_select_element_selected_index(native) == 1
	assert html_select_element_value(native) == 'initial'
}

fn test_lazy_select_owner_reuse_preserves_explicit_no_selection() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut select_element := document.create_element('select')!
	mut option := document.create_element('option')!
	option.set_attribute_value('value', 'v')
	select_element.as_node().append_child(option.as_node())!
	native := unsafe { &dom.HTMLSelectElement(select_element) }
	owner := HTMLSelectElementModel.create(native)
	set_html_select_element_selected_index(native, -1)
	assert voidptr(HTMLSelectElementModel.create(native)) == voidptr(owner)
	assert html_select_element_selected_index(native) == -1 && html_select_element_value(native) == ''
}

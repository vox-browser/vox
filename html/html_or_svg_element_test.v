module html

import dom

fn test_html_or_svg_element_dataset_nonce_and_clone() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut mixin := HTMLOrSVGElement.create(element)
	mut dataset := mixin.dataset()
	dataset.set_value_of_named_property('userId', '42')!
	assert element.get_attribute('data-user-id')? == '42'
	assert voidptr(mixin.dataset()) == voidptr(dataset)
	mixin.attribute_changed('nonce', 'secret', none)
	assert mixin.nonce() == 'secret'
	copy := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	copy_mixin := mixin.cloned(copy)
	assert copy_mixin.nonce() == 'secret'
	mixin.attribute_changed('nonce', none, none)
	assert mixin.nonce() == ''
}

fn test_html_or_svg_element_blur_clears_focus() {
	mut document := dom.Document.create_for_fragment_parsing()
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	document.set_focused_area(element.as_node())
	mixin := HTMLOrSVGElement.create(element)
	mixin.blur()
	assert document.focused_area() == none
}

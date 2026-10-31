module html

import dom

fn test_form_elements_discovers_lazy_native_controls_and_keeps_a_saved_collection_live() {
	mut document := parse_document('<!doctype html><input id="outside" form="owner"><form id="owner"><input id="field"><textarea id="editor"></textarea><button id="send"></button><input type="image"></form>')
	defer { document.finalize() }
	form_element := document.get_element_by_id('owner') or { panic('missing form') }
	mut model := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	collection := model.elements()
	assert collection.length() == 4
	assert collection.item(0)?.id()? == 'outside'
	assert collection.item(2)?.id()? == 'editor'
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input.set_attribute_value('name', 'late')
	mut owner := unsafe { &dom.Element(form_element) }
	owner.append_child(input)
	assert collection.length() == 5
	named := collection.named_item_or_radio_node_list('late')
	assert named is HTMLFormControlsCollectionElement
	assert voidptr((named as HTMLFormControlsCollectionElement).element) == voidptr(input)
	input.remove(false)
	assert collection.length() == 4
}

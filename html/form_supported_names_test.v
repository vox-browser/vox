module html

import dom

fn form_supported_names_find_element(node &dom.Node, local_name string) ?&dom.Element {
	for child in node.children {
		if element := child.as_element() {
			if element.local_name() == local_name {
				return element
			}
		}
		if element := form_supported_names_find_element(child, local_name) {
			return element
		}
	}
	return none
}

fn test_form_supported_property_names_follow_tree_order() {
	document := parse_document('<form><input id="first" name="shared"><input id="second" name="shared"></form>')
	form_element := form_supported_names_find_element(document.as_node(), 'form') or {
		panic('missing form')
	}
	first := document.get_element_by_id('first') or { panic('missing first input') }
	second := document.get_element_by_id('second') or { panic('missing second input') }
	mut form := unsafe { &dom.HTMLFormElement(form_element) }
	// Association order can differ from current tree order after DOM moves.
	form.associated_elements_ = [second, first]
	model := HTMLFormElementModel.create(form)

	assert model.supported_property_names() == ['first', 'shared', 'second']
}

fn test_form_supported_property_name_membership_uses_controls_images_and_past_names() {
	document := parse_document('<form><input id="control" name="field"><input id="image-button" type="image"><img id="picture" name="photo"></form>')
	form_element := form_supported_names_find_element(document.as_node(), 'form') or {
		panic('missing form')
	}
	control := document.get_element_by_id('control') or { panic('missing control') }
	image_button := document.get_element_by_id('image-button') or { panic('missing image button') }
	picture := document.get_element_by_id('picture') or { panic('missing image') }
	mut form := unsafe { &dom.HTMLFormElement(form_element) }
	form.associated_elements_ = [image_button, picture, control]
	mut model := HTMLFormElementModel.create(form)
	model.past_names_map_['legacy'] = control

	assert model.is_supported_property_name('control')
	assert model.is_supported_property_name('field')
	assert model.is_supported_property_name('picture')
	assert model.is_supported_property_name('photo')
	assert model.is_supported_property_name('legacy')
	assert !model.is_supported_property_name('image-button')
	assert !model.is_supported_property_name('missing')
}

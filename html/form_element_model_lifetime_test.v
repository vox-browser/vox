module html

import dom

// Form models live on their element. A process-wide list kept models from
// retired documents and let a later form at a reused address find them.
fn test_form_models_are_owned_by_their_elements() {
	mut document := dom.Document.create(dom.URL{ value: 'https://form-models.example/' })
	first := unsafe { &dom.HTMLFormElement(document.create_element('form') or { panic(err) }) }
	second := unsafe { &dom.HTMLFormElement(document.create_element('form') or { panic(err) }) }
	first_model := HTMLFormElementModel.create(first)
	assert voidptr(HTMLFormElementModel.create(first)) == voidptr(first_model)
	assert voidptr(first.form_element_model_) == voidptr(first_model)
	second_model := HTMLFormElementModel.create(second)
	assert voidptr(second_model) != voidptr(first_model)
	assert voidptr(second_model.element) == voidptr(second)
	if found := html_form_element_model_for(second) {
		assert voidptr(found) == voidptr(second_model)
	} else {
		assert false
	}
}

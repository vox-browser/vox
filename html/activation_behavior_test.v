module html

import dom

fn activation_test_element(document &dom.Document, id string) &dom.Element {
	return document.get_element_by_id(id) or { panic('missing ${id}') }
}

fn test_clicking_a_checkbox_toggles_it_through_its_activation_behavior() {
	document := parse_document('<!doctype html><body><input id="box" type="checkbox"></body>')
	element := activation_test_element(document, 'box')
	input := unsafe { &dom.HTMLInputElement(element) }
	model := HTMLInputElementModel.create(input)
	assert unsafe { &dom.EventTarget(element.as_node()) }.has_activation_behavior()
	assert !model.checked()

	html_element_click(unsafe { &dom.HTMLElement(element) })
	assert model.checked()
	html_element_click(unsafe { &dom.HTMLElement(element) })
	assert !model.checked()
}

fn test_a_canceled_click_restores_the_checkbox() {
	document := parse_document('<!doctype html><body><input id="box" type="checkbox"></body>')
	element := activation_test_element(document, 'box')
	model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	})
	unsafe { &dom.EventTarget(element.as_node()) }.add_event_listener_without_options('click', listener)

	html_element_click(unsafe { &dom.HTMLElement(element) })
	assert !model.checked()
}

fn test_clicking_a_summary_toggles_its_details() {
	document := parse_document('<!doctype html><body><details id="details"><summary id="summary">More</summary>Body</details></body>')
	details := activation_test_element(document, 'details')
	summary := activation_test_element(document, 'summary')
	assert !details.has_attribute('open')
	html_element_click(unsafe { &dom.HTMLElement(summary) })
	assert details.has_attribute('open')
}

fn test_plain_input_buttons_yield_activation_to_ancestor_links() {
	document := parse_document('<!doctype html><body><a href="/x"><input id="plain" type="button"></a><input id="submit" type="submit"></body>')
	plain := activation_test_element(document, 'plain')
	submit := activation_test_element(document, 'submit')
	assert !unsafe { &dom.EventTarget(plain.as_node()) }.has_activation_behavior()
	assert unsafe { &dom.EventTarget(submit.as_node()) }.has_activation_behavior()
}

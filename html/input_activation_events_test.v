module html

import dom

// The input model fired these at a private EventTarget, so a page's change
// listener never ran when the user toggled a checkbox.
fn test_checkbox_activation_fires_trusted_input_and_change_at_the_element() {
	document := parse_document('<!doctype html><body><form id="form"><input id="box" type="checkbox"></form></body>')
	element := document.get_element_by_id('box') or { panic('box') }
	form := document.get_element_by_id('form') or { panic('form') }
	mut seen := []string{}
	seen_ref := &seen
	for name in ['input', 'change'] {
		for owner in [element, form] {
			listener := dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn [seen_ref, owner] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					mut list := unsafe { seen_ref }
					list << '${event.type_name()}:${owner.get_attribute_value('id')}:${event.is_trusted()}:${event.bubbles()}:${event.composed()}'
					return dom.js_undefined()
				}
			})
			unsafe { &dom.EventTarget(owner.as_node()) }.add_event_listener_without_options(name, listener)
		}
	}
	html_element_click(unsafe { &dom.HTMLElement(element) })
	model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	assert model.checked()
	assert seen == ['input:box:true:true:true', 'input:form:true:true:true', 'change:box:true:true:false',
		'change:form:true:true:false']
	assert model.event_count('change') == 1
}

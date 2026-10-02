module html

import dom

@[heap]
struct FormSubmitEventObservation {
mut:
	count int
	submitter ?&dom.HTMLElement
}

fn form_submit_event_find(node &dom.Node, name string) &dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := form_submit_event_find_optional(child, name) {
			return element
		}
	}
	panic('Missing ${name}')
}

fn form_submit_event_find_optional(node &dom.Node, name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := form_submit_event_find_optional(child, name) {
			return element
		}
	}
	return none
}

fn test_form_request_submit_dispatches_submit_event_with_actual_submitter() {
	mut document := parse_document('<form><button>Send</button></form>')
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	form_element := form_submit_event_find(document.as_node(), 'form')
	button_element := form_submit_event_find(document.as_node(), 'button')
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut button := FormAssociatedElement.create(button_element)
	form.add_associated_element(mut button)
	observation := &FormSubmitEventObservation{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event.interface_ == .submit_event
			assert event.bubbles()
			assert event.cancelable()
			submit_event := unsafe { &dom.SubmitEvent(event) }
			mut recorded := unsafe { &FormSubmitEventObservation(observation) }
			recorded.count++
			recorded.submitter = submit_event.submitter()
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	})
	form.event_target().add_event_listener_without_options('submit', listener)
	form.request_submit(button)!
	assert observation.count == 1
	assert voidptr(observation.submitter or { panic('submitter') }) == voidptr(button_element)
	assert form.last_submission() == none
	form.request_submit(none)!
	assert observation.count == 2
	assert observation.submitter == none
	assert form.last_submission() == none
	form.submit()!
	assert observation.count == 2
}

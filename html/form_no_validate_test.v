module html

import dom
import platform

fn test_request_submit_without_button_honors_form_novalidate() {
	mut document := parse_document('<form novalidate><input required></form>')
	mut navigable := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	form_element := document.query_selector('form') or { panic('Missing form') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut calls := []int{len: 1}
	callback := fn [mut calls] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		calls[0]++
		mut mutable := unsafe { &dom.Event(event) }; mutable.prevent_default()
		return dom.js_undefined()
	}
	listener := dom.IDLEventListener.create(&dom.CallbackType{handle_event: callback})
	form.event_target().add_event_listener_without_options('submit', listener)
	defer {
		form.event_target().remove_event_listener('submit', listener, dom.EventListenerOptions{})
		platform.release_closure(voidptr(callback))
	}
	assert !form.check_validity()
	form.request_submit(none)!
	assert calls[0] == 1
}

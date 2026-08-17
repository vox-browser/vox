module fullscreen

import dom

fn fullscreen_test_document() &dom.Document {
	return dom.Document.create(dom.url_about_blank())
}

fn fullscreen_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('create_element_ns(${name}): ${err}')
	}
}

fn fullscreen_test_callback(event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
	_ = event
	_ = current_target
	return dom.js_undefined()
}

struct FullscreenEventObservation {
mut:
	change_count int
	error_count  int
}

fn test_document_attributes_and_legacy_setters() {
	mut document := fullscreen_test_document()
	assert !document_fullscreen_enabled(document)
	assert !document_fullscreen(document)
	assert document_fullscreen_element(document) == none
	assert document_fullscreen_is_unscopable()

	set_document_fullscreen_enabled(mut document, true)
	set_document_fullscreen(mut document, true)
	assert !document_fullscreen_enabled(document)
	assert !document_fullscreen(document)
}

fn test_document_and_element_event_handler_attributes() {
	mut document := fullscreen_test_document()
	element := fullscreen_test_element(document, 'div')
	handler := &dom.CallbackType{
		handle_event: fullscreen_test_callback
	}

	assert document_onfullscreenchange(document) == none
	assert document_onfullscreenerror(document) == none
	set_document_onfullscreenchange(mut document, handler)
	set_document_onfullscreenerror(mut document, handler)
	assert document_onfullscreenchange(document) or { panic('missing document change handler') } == handler
	assert document_onfullscreenerror(document) or { panic('missing document error handler') } == handler
	set_document_onfullscreenchange(mut document, none)
	set_document_onfullscreenerror(mut document, none)
	assert document_onfullscreenchange(document) == none
	assert document_onfullscreenerror(document) == none

	assert element_onfullscreenchange(element) == none
	assert element_onfullscreenerror(element) == none
	set_element_onfullscreenchange(element, handler)
	set_element_onfullscreenerror(element, handler)
	assert element_onfullscreenchange(element) or { panic('missing element change handler') } == handler
	assert element_onfullscreenerror(element) or { panic('missing element error handler') } == handler
	set_element_onfullscreenchange(element, none)
	set_element_onfullscreenerror(element, none)
	assert element_onfullscreenchange(element) == none
	assert element_onfullscreenerror(element) == none
}

fn test_document_event_handlers_participate_in_event_dispatch() {
	mut document := fullscreen_test_document()
	observation := &FullscreenEventObservation{}
	change_handler := &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			_ = event
			_ = current_target
			mut seen := unsafe { &FullscreenEventObservation(observation) }
			seen.change_count++
			return dom.js_undefined()
		}
	}
	error_handler := &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			_ = event
			_ = current_target
			mut seen := unsafe { &FullscreenEventObservation(observation) }
			seen.error_count++
			return dom.js_undefined()
		}
	}

	set_document_onfullscreenchange(mut document, change_handler)
	set_document_onfullscreenerror(mut document, error_handler)
	document.dispatch_event_simple('fullscreenchange', true)
	document.dispatch_event_simple('fullscreenerror', true)
	assert observation.change_count == 1
	assert observation.error_count == 1
}

fn test_fullscreen_element_binding_reflects_top_layer_state() {
	mut document := fullscreen_test_document()
	mut first := fullscreen_test_element(document, 'div')
	mut second := fullscreen_test_element(document, 'video')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(first.as_node()) or { panic('append first: ${err}') }
	first.append_child(second)

	document.fullscreen_element_within_doc(mut first)
	assert document_fullscreen(document)
	assert document_fullscreen_element(document) or { panic('missing first fullscreen element') } == first

	document.fullscreen_element_within_doc(mut second)
	assert document_fullscreen_element(document) or { panic('missing second fullscreen element') } == second

	document.unfullscreen()
	assert !document_fullscreen(document)
	assert document_fullscreen_element(document) == none
}

fn test_request_and_exit_reject_for_inactive_document() {
	mut document := fullscreen_test_document()
	mut element := fullscreen_test_element(document, 'div')

	request := element_request_fullscreen(mut element)
	assert request.state() == .rejected
	assert request.result().kind == .string
	assert request.result().string_data.contains('not fully active')

	exit := document_exit_fullscreen(mut document)
	assert exit.state() == .rejected
	assert exit.result().kind == .string
	assert exit.result().string_data.contains('not fully active')
}

fn test_rejected_exit_does_not_change_existing_fullscreen_state() {
	mut document := fullscreen_test_document()
	mut element := fullscreen_test_element(document, 'div')
	document.fullscreen_element_within_doc(mut element)

	exit := document_exit_fullscreen(mut document)
	assert exit.state() == .rejected
	assert exit.result().kind == .string
	assert document.fullscreen_element() or { panic('fullscreen state was cleared') } == element
	assert element.is_fullscreen_element()
	assert element.in_top_layer()
}

fn test_detached_shadow_root_has_no_fullscreen_element() {
	mut document := fullscreen_test_document()
	mut host := fullscreen_test_element(document, 'div')
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic('attach_shadow: ${err}') }
	assert shadow_root_fullscreen_element(shadow_root) == none
}

fn test_fullscreen_element_is_retargeted_across_a_shadow_boundary() {
	mut document := fullscreen_test_document()
	mut host := fullscreen_test_element(document, 'div')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic('append host: ${err}') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic('attach_shadow: ${err}') }
	mut inner := fullscreen_test_element(document, 'video')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(inner.as_node()) or { panic('append inner: ${err}') }

	document.fullscreen_element_within_doc(mut inner)
	assert document.fullscreen_element() or { panic('missing raw fullscreen element') } == inner
	assert document_fullscreen_element(document) or {
		panic('missing retargeted document fullscreen element')
	} == host
	assert shadow_root_fullscreen_element(shadow_root) or {
		panic('missing shadow-root fullscreen element')
	} == inner
}

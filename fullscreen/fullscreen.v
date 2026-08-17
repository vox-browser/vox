module fullscreen

import dom

// DocumentExtensions.idl

pub fn document_fullscreen_enabled(document &dom.Document) bool {
	return document.fullscreen_enabled()
}

pub fn document_fullscreen(document &dom.Document) bool {
	return document.fullscreen()
}

// LegacyLenientSetter makes writes observable as successful no-ops.
pub fn set_document_fullscreen_enabled(mut document dom.Document, value bool) {
	_ = document
	_ = value
}

// The historical fullscreen attribute is also LegacyLenientSetter and
// [Unscopable]. V has no with-environment lookup, so the unscopable marker is
// represented explicitly for binding generators.
pub fn set_document_fullscreen(mut document dom.Document, value bool) {
	_ = document
	_ = value
}

pub fn document_fullscreen_is_unscopable() bool {
	return true
}

pub fn document_exit_fullscreen(mut document dom.Document) &dom.Promise {
	return document.exit_fullscreen()
}

pub fn document_onfullscreenchange(document &dom.Document) ?&dom.CallbackType {
	handler := document.onfullscreenchange() or { return none }
	if handler == unsafe { nil } {
		return none
	}
	return handler
}

pub fn set_document_onfullscreenchange(mut document dom.Document, handler ?&dom.CallbackType) {
	document.set_onfullscreenchange(handler)
}

pub fn document_onfullscreenerror(document &dom.Document) ?&dom.CallbackType {
	handler := document.onfullscreenerror() or { return none }
	if handler == unsafe { nil } {
		return none
	}
	return handler
}

pub fn set_document_onfullscreenerror(mut document dom.Document, handler ?&dom.CallbackType) {
	document.set_onfullscreenerror(handler)
}

// DocumentOrShadowRootExtensions.idl

pub fn document_fullscreen_element(document &dom.Document) ?&dom.Element {
	return document.fullscreen_element_for_bindings()
}

pub fn shadow_root_fullscreen_element(shadow_root &dom.ShadowRoot) ?&dom.Element {
	return shadow_root.fullscreen_element_for_bindings()
}

// ElementExtensions.idl

pub fn element_request_fullscreen(mut element dom.Element) &dom.Promise {
	return element.request_fullscreen(.bindings)
}

pub fn element_onfullscreenchange(element &dom.Element) ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(element.as_node()) }.event_handler_attribute('fullscreenchange')
}

pub fn set_element_onfullscreenchange(element &dom.Element, handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(element.as_node()) }.set_event_handler_attribute('fullscreenchange',
		handler)
}

pub fn element_onfullscreenerror(element &dom.Element) ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(element.as_node()) }.event_handler_attribute('fullscreenerror')
}

pub fn set_element_onfullscreenerror(element &dom.Element, handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(element.as_node()) }.set_event_handler_attribute('fullscreenerror',
		handler)
}

// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLDialogElement.{h,cpp}, HTMLDetailsElement.{h,cpp}, and
// HTMLSummaryElement.{h,cpp}. Rendering/focus-policy effects stay in DOM host
// state; all observable attributes, events, modal top-layer state, commands,
// and details-name exclusivity are implemented here.
module html

import dom

fn dialog_dom_element(dialog &dom.HTMLDialogElement) &dom.Element {
	return unsafe { &dom.Element(dialog) }
}

fn details_dom_element(details &dom.HTMLDetailsElement) &dom.Element {
	return unsafe { &dom.Element(details) }
}

fn dispatch_toggle(element &dom.Element, event_name string, old_state string, new_state string, cancelable bool, source ?&dom.Element) bool {
	event := dom.ToggleEvent.create(event_name, dom.ToggleEventInit{
		EventInit: dom.EventInit{
			cancelable: cancelable
		}
		old_state: old_state
		new_state: new_state
		source:    source
	})
	return unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(unsafe { &dom.Event(event) })
}

fn dispatch_plain_event(element &dom.Element, name string, cancelable bool) bool {
	event := dom.Event.create(name, dom.EventInit{
		cancelable: cancelable
	})
	return unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event)
}

pub fn html_dialog_element_return_value(dialog &dom.HTMLDialogElement) string {
	return dialog.return_value_
}

pub fn set_html_dialog_element_return_value(mut dialog dom.HTMLDialogElement, value string) {
	dialog.return_value_ = value
}

pub fn html_dialog_element_is_modal(dialog &dom.HTMLDialogElement) bool {
	return dialog.is_modal_
}

pub fn show_html_dialog_element(mut dialog dom.HTMLDialogElement) ! {
	mut element := dialog_dom_element(&dialog)
	if element.has_attribute('open') {
		if dialog.is_modal_ {
			return error('InvalidStateError: dialog is already open as a modal dialog')
		}
		return
	}
	if !dispatch_toggle(element, 'beforetoggle', 'closed', 'open', true, none) {
		return
	}
	if element.has_attribute('open') {
		return
	}
	element.set_attribute_value('open', '')
	dialog.is_modal_ = false
	dispatch_toggle(element, 'toggle', 'closed', 'open', false, none)
}

pub fn show_modal_html_dialog_element(mut dialog dom.HTMLDialogElement) ! {
	mut element := dialog_dom_element(&dialog)
	if element.has_attribute('open') {
		if dialog.is_modal_ {
			return
		}
		return error('InvalidStateError: dialog is already open')
	}
	if !element.as_node().is_connected()
		|| (element.document().cached_navigable() != none && !element.document().is_fully_active()) {
		return error('InvalidStateError: modal dialog must be connected to a fully active document')
	}
	if unsafe { &dom.HTMLElement(element) }.popover_visibility_state_ == .showing {
		return error('InvalidStateError: dialog is already open as a popover')
	}
	if !dispatch_toggle(element, 'beforetoggle', 'closed', 'open', true, none) {
		return
	}
	if element.has_attribute('open') || !element.as_node().is_connected() {
		return
	}
	element.set_attribute_value('open', '')
	dialog.is_modal_ = true
	mut document := element.document()
	document.add_an_element_to_the_top_layer(element)
	dispatch_toggle(element, 'toggle', 'closed', 'open', false, none)
}

pub fn close_html_dialog_element(mut dialog dom.HTMLDialogElement, result ?string, source ?&dom.Element) {
	mut element := dialog_dom_element(&dialog)
	if !element.has_attribute('open') {
		return
	}
	dispatch_toggle(element, 'beforetoggle', 'open', 'closed', false, source)
	if !element.has_attribute('open') {
		return
	}
	element.remove_attribute('open')
	if dialog.is_modal_ {
		mut document := element.document()
		document.request_an_element_to_be_remove_from_the_top_layer(element)
	}
	dialog.is_modal_ = false
	if value := result {
		dialog.return_value_ = value
	}
	dispatch_toggle(element, 'toggle', 'open', 'closed', false, source)
	dispatch_plain_event(element, 'close', false)
}

pub fn request_close_html_dialog_element(mut dialog dom.HTMLDialogElement, return_value ?string, source ?&dom.Element) {
	element := dialog_dom_element(&dialog)
	if !element.has_attribute('open') || !element.as_node().is_connected()
		|| (element.document().cached_navigable() != none && !element.document().is_fully_active()) {
		return
	}
	if !dispatch_plain_event(element, 'cancel', true) {
		return
	}
	close_html_dialog_element(mut dialog, return_value, source)
}

pub fn html_dialog_element_is_valid_command(command string) bool {
	return ascii_lowercase_string(command) in ['show-modal', 'close', 'request-close']
}

pub fn run_html_dialog_element_command(mut dialog dom.HTMLDialogElement, command string, source ?&dom.Element) ! {
	match ascii_lowercase_string(command) {
		'show-modal' { show_modal_html_dialog_element(mut dialog)! }
		'close' { close_html_dialog_element(mut dialog, none, source) }
		'request-close' { request_close_html_dialog_element(mut dialog, none, source) }
		else { return error('NotSupportedError: invalid dialog command') }
	}
}

fn collect_details_elements(node &dom.Node, mut output []&dom.Element) {
	if element := node.as_element() {
		if element.local_name() == 'details' {
			output << element
		}
	}
	for child in node.children_as_vector() {
		collect_details_elements(child, mut output)
	}
}

pub fn set_html_details_element_open(details &dom.HTMLDetailsElement, open bool) {
	mut element := details_dom_element(details)
	was_open := element.has_attribute('open')
	if was_open == open {
		return
	}
	if open {
		element.set_attribute_value('open', '')
		name := element.get_attribute_value('name')
		if name != '' {
			mut group := []&dom.Element{}
			collect_details_elements(element.as_node().root(), mut group)
			for candidate in group {
				if candidate != element && candidate.get_attribute_value('name') == name
					&& candidate.has_attribute('open') {
					mut other := unsafe { &dom.HTMLDetailsElement(candidate) }
					set_html_details_element_open(other, false)
				}
			}
		}
	} else {
		element.remove_attribute('open')
	}
	dispatch_toggle(element, 'toggle', if was_open { 'open' } else { 'closed' }, if open {
		'open'
	} else {
		'closed'
	}, false, none)
}

pub fn html_details_element_open(details &dom.HTMLDetailsElement) bool {
	return details_dom_element(details).has_attribute('open')
}

pub fn html_summary_element_is_summary_for_parent(summary &dom.HTMLSummaryElement) bool {
	element := unsafe { &dom.Element(summary) }
	parent := element.as_node().parent_element() or { return false }
	if parent.local_name() != 'details' {
		return false
	}
	for child in parent.as_node().children_as_vector() {
		if child_element := child.as_element() {
			if child_element.local_name() == 'summary' {
				return child_element == element
			}
		}
	}
	return false
}

pub fn activate_html_summary_element(summary &dom.HTMLSummaryElement) {
	if !html_summary_element_is_summary_for_parent(summary) {
		return
	}
	parent := unsafe { &dom.Element(summary) }.as_node().parent_element() or { return }
	mut details := unsafe { &dom.HTMLDetailsElement(parent) }
	set_html_details_element_open(details, !parent.has_attribute('open'))
}

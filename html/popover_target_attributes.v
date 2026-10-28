// Copyright (c) 2024, Nathan van der Kamp <nbvdkamp@gmail.com>
// Copyright (c) 2024, Tim Ledbetter <tim.ledbetter@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PopoverTargetAttributes.{h,cpp}.
module html

import dom

@[heap]
pub struct PopoverTargetAttributes {
mut:
	element &dom.Element
}

pub fn PopoverTargetAttributes.create(element &dom.Element) &PopoverTargetAttributes {
	return &PopoverTargetAttributes{
		element: element
	}
}

pub fn (attributes &PopoverTargetAttributes) popover_target_element() ?&dom.Element {
	return attributes.element.popover_target_element()
}

pub fn (mut attributes PopoverTargetAttributes) set_popover_target_element(value ?&dom.Element) {
	mut element := unsafe { &dom.Element(attributes.element) }
	element.set_popover_target_element(value)
}

pub fn (mut attributes PopoverTargetAttributes) associated_attribute_changed(name string, namespace_ ?string) {
	if name != 'popovertarget' || namespace_ != none {
		return
	}
	attributes.set_popover_target_element(none)
}

fn find_html_element_by_id(root &dom.Node, id string) ?&dom.HTMLElement {
	if element := root.as_element() {
		if element.id() or { '' } == id && element.is_html_element() {
			return unsafe { &dom.HTMLElement(element) }
		}
	}
	for child in root.children {
		if found := find_html_element_by_id(child, id) {
			return found
		}
	}
	return none
}

pub fn PopoverTargetAttributes.get_the_popover_target_element(node &dom.Node) ?&dom.HTMLElement {
	element := node.as_element() or { return none }
	mut control := FormAssociatedElement.create(element)
	if !control.is_button() || !control.enabled() {
		return none
	}
	control.reset_form_owner()
	if control.form() != none && control.is_submit_button() {
		return none
	}

	mut popover := ?&dom.HTMLElement(none)
	if explicit := element.popover_target_element() {
		if explicit.is_html_element() {
			popover = unsafe { &dom.HTMLElement(explicit) }
		}
	} else if target_id := element.get_attribute('popovertarget') {
		popover = find_html_element_by_id(node.root(), target_id)
	}
	target_element := popover or { return none }
	if html_element_popover(target_element) == none {
		return none
	}
	return target_element
}

pub fn PopoverTargetAttributes.popover_target_activation_behaviour(node &dom.Node, event_target &dom.Node) {
	popover := PopoverTargetAttributes.get_the_popover_target_element(node) or { return }
	popover_node := unsafe { &dom.Element(popover) }.as_node()
	if event_target.is_shadow_including_inclusive_descendant_of(popover_node) && popover_node.is_shadow_including_descendant_of(node) {
		return
	}
	element := node.as_element() or { return }
	action := ascii_lowercase_string(element.get_attribute_value('popovertargetaction'))
	if action == 'show' && popover.popover_visibility_state() == .showing {
		return
	}
	if action == 'hide' && popover.popover_visibility_state() == .hidden {
		return
	}
	if popover.popover_visibility_state() == .showing {
		html_element_hide_popover(popover, .yes, .yes, .no, .no, unsafe { &dom.HTMLElement(element) }) or {}
	} else if html_element_check_popover_validity(popover, .no, .no, none, .no) or {
		false} {
		html_element_show_popover(popover, .no, unsafe { &dom.HTMLElement(element) }) or {}
	}
}

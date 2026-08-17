// Copyright (c) 2024, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ElementInternals.{h,cpp}. The V port has no JS platform-object
// layer, so live values are exposed through ordinary V objects.
module html

import dom

pub struct ValidityStateFlags {
pub:
	value_missing    bool
	type_mismatch    bool
	pattern_mismatch bool
	too_long         bool
	too_short        bool
	range_underflow  bool
	range_overflow   bool
	step_mismatch    bool
	bad_input        bool
	custom_error     bool
}

pub fn (flags ValidityStateFlags) has_one_or_more_true_values() bool {
	return flags.value_missing || flags.type_mismatch || flags.pattern_mismatch || flags.too_long
		|| flags.too_short || flags.range_underflow || flags.range_overflow || flags.step_mismatch
		|| flags.bad_input || flags.custom_error
}

pub struct ElementInternalsFormData {
pub:
	entries []FormDataEntry
}

pub type ElementInternalsValue = ElementInternalsFormData | FormDataFile | string

fn clone_element_internals_value(value ElementInternalsValue) ElementInternalsValue {
	return match value {
		string {
			ElementInternalsValue(value)
		}
		FormDataFile {
			ElementInternalsValue(FormDataFile{
				name:      value.name
				mime_type: value.mime_type
				bytes:     value.bytes.clone()
			})
		}
		ElementInternalsFormData {
			ElementInternalsValue(ElementInternalsFormData{
				entries: value.entries.clone()
			})
		}
	}
}

@[heap]
pub struct ElementInternals {
pub:
	target_element &dom.HTMLElement
pub mut:
	control           &FormAssociatedElement
	submission_value  ?ElementInternalsValue
	state             ?ElementInternalsValue
	validation_anchor ?&dom.HTMLElement
}

pub fn ElementInternals.create(target_element &dom.HTMLElement) &ElementInternals {
	element := unsafe { &dom.Element(target_element) }
	mut control := FormAssociatedElement.create_custom(element)
	control.reset_form_owner()
	return &ElementInternals{
		target_element: target_element
		control:        control
	}
}

fn (internals &ElementInternals) require_form_associated() ! {
	element := unsafe { &dom.Element(internals.target_element) }
	if !element.is_form_associated_custom_element() {
		return error('NotSupportedError: element is not a form-associated custom element')
	}
}

pub fn (internals &ElementInternals) shadow_root() ?&dom.ShadowRoot {
	element := unsafe { &dom.Element(internals.target_element) }
	shadow := element.shadow_root() or { return none }
	if !shadow.available_to_element_internals() {
		return none
	}
	return shadow
}

pub fn (mut internals ElementInternals) set_form_value(value ElementInternalsValue, state ?ElementInternalsValue) ! {
	internals.require_form_associated()!
	internals.submission_value = clone_element_internals_value(value)
	if provided_state := state {
		internals.state = clone_element_internals_value(provided_state)
	} else {
		internals.state = clone_element_internals_value(value)
	}
}

pub fn (internals &ElementInternals) form() !&dom.HTMLFormElement {
	internals.require_form_associated()!
	return internals.control.form() or { unsafe { nil } }
}

pub fn (mut internals ElementInternals) set_validity(flags ValidityStateFlags, message ?string, anchor ?&dom.HTMLElement) ! {
	internals.require_form_associated()!
	if flags.has_one_or_more_true_values() && message or { '' } == '' {
		return error('TypeError: invalid flags require a non-empty message')
	}
	mut control := internals.control
	control.missing_ = flags.value_missing
	control.type_mismatch_ = flags.type_mismatch
	control.pattern_mismatch_ = flags.pattern_mismatch
	control.too_long_ = flags.too_long
	control.too_short_ = flags.too_short
	control.underflow_ = flags.range_underflow
	control.overflow_ = flags.range_overflow
	control.step_mismatch_ = flags.step_mismatch
	control.bad_input_ = flags.bad_input
	control.set_custom_validity(if flags.custom_error { message or { '' } } else { '' })
	actual_anchor := anchor or { internals.target_element }
	target_node := unsafe { &dom.Node(internals.target_element) }
	anchor_node := unsafe { &dom.Node(actual_anchor) }
	if !anchor_node.is_shadow_including_inclusive_descendant_of(target_node) {
		return error('NotFoundError: anchor is not a shadow-including inclusive descendant of the target element')
	}
	internals.validation_anchor = actual_anchor
}

pub fn (internals &ElementInternals) will_validate() !bool {
	internals.require_form_associated()!
	return internals.control.is_candidate_for_constraint_validation()
}

pub fn (internals &ElementInternals) validity() !&ValidityState {
	internals.require_form_associated()!
	return ValidityState.create(internals.control)
}

pub fn (internals &ElementInternals) validation_message() !string {
	internals.require_form_associated()!
	return internals.control.validation_message()
}

pub fn (internals &ElementInternals) check_validity() !bool {
	internals.require_form_associated()!
	return internals.control.check_validity()
}

pub fn (internals &ElementInternals) report_validity() !bool {
	internals.require_form_associated()!
	return internals.control.report_validity()
}

fn collect_element_internals_labels(node &dom.Node, target &dom.Element, mut labels []&dom.Element) {
	if element := node.as_element() {
		if element.is_html_element() && element.local_name() == 'label' {
			if for_value := element.get_attribute('for') {
				if target_id := target.id() {
					if for_value == target_id {
						labels << element
					}
				}
			} else if target.as_node().is_descendant_of(element.as_node()) {
				labels << element
			}
		}
	}
	for child in node.children {
		collect_element_internals_labels(child, target, mut labels)
	}
}

pub fn (internals &ElementInternals) labels() ![]&dom.Element {
	internals.require_form_associated()!
	target := unsafe { &dom.Element(internals.target_element) }
	mut labels := []&dom.Element{}
	collect_element_internals_labels(target.as_node().root(), target, mut labels)
	return labels
}

pub fn (mut internals ElementInternals) states() &dom.CustomStateSet_ {
	mut target := unsafe { &dom.Element(internals.target_element) }
	return target.ensure_custom_state_set()
}

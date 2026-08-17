// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// DOMString reflection surface from ARIAMixin.idl. Generated mechanically from
// the upstream ENUMERATE_ARIA_ATTRIBUTES table.
module aria

import dom

pub fn (mixin &ARIAMixin) role() ?string {
	return mixin.attribute('role')
}

pub fn (mixin &ARIAMixin) set_role(value ?string) {
	mixin.set_attribute('role', value)
}

pub fn (mixin &ARIAMixin) aria_active_descendant() ?string {
	return mixin.attribute('aria-activedescendant')
}

pub fn (mixin &ARIAMixin) set_aria_active_descendant(value ?string) {
	mixin.set_attribute('aria-activedescendant', value)
}

pub fn (mixin &ARIAMixin) aria_atomic() ?string {
	return mixin.attribute('aria-atomic')
}

pub fn (mixin &ARIAMixin) set_aria_atomic(value ?string) {
	mixin.set_attribute('aria-atomic', value)
}

pub fn (mixin &ARIAMixin) aria_auto_complete() ?string {
	return mixin.attribute('aria-autocomplete')
}

pub fn (mixin &ARIAMixin) set_aria_auto_complete(value ?string) {
	mixin.set_attribute('aria-autocomplete', value)
}

pub fn (mixin &ARIAMixin) aria_braille_label() ?string {
	return mixin.attribute('aria-braillelabel')
}

pub fn (mixin &ARIAMixin) set_aria_braille_label(value ?string) {
	mixin.set_attribute('aria-braillelabel', value)
}

pub fn (mixin &ARIAMixin) aria_braille_role_description() ?string {
	return mixin.attribute('aria-brailleroledescription')
}

pub fn (mixin &ARIAMixin) set_aria_braille_role_description(value ?string) {
	mixin.set_attribute('aria-brailleroledescription', value)
}

pub fn (mixin &ARIAMixin) aria_busy() ?string {
	return mixin.attribute('aria-busy')
}

pub fn (mixin &ARIAMixin) set_aria_busy(value ?string) {
	mixin.set_attribute('aria-busy', value)
}

pub fn (mixin &ARIAMixin) aria_checked() ?string {
	return mixin.attribute('aria-checked')
}

pub fn (mixin &ARIAMixin) set_aria_checked(value ?string) {
	mixin.set_attribute('aria-checked', value)
}

pub fn (mixin &ARIAMixin) aria_col_count() ?string {
	return mixin.attribute('aria-colcount')
}

pub fn (mixin &ARIAMixin) set_aria_col_count(value ?string) {
	mixin.set_attribute('aria-colcount', value)
}

pub fn (mixin &ARIAMixin) aria_col_index() ?string {
	return mixin.attribute('aria-colindex')
}

pub fn (mixin &ARIAMixin) set_aria_col_index(value ?string) {
	mixin.set_attribute('aria-colindex', value)
}

pub fn (mixin &ARIAMixin) aria_col_index_text() ?string {
	return mixin.attribute('aria-colindextext')
}

pub fn (mixin &ARIAMixin) set_aria_col_index_text(value ?string) {
	mixin.set_attribute('aria-colindextext', value)
}

pub fn (mixin &ARIAMixin) aria_col_span() ?string {
	return mixin.attribute('aria-colspan')
}

pub fn (mixin &ARIAMixin) set_aria_col_span(value ?string) {
	mixin.set_attribute('aria-colspan', value)
}

pub fn (mixin &ARIAMixin) aria_controls() ?string {
	return mixin.attribute('aria-controls')
}

pub fn (mixin &ARIAMixin) set_aria_controls(value ?string) {
	mixin.set_attribute('aria-controls', value)
}

pub fn (mixin &ARIAMixin) aria_current() ?string {
	return mixin.attribute('aria-current')
}

pub fn (mixin &ARIAMixin) set_aria_current(value ?string) {
	mixin.set_attribute('aria-current', value)
}

pub fn (mixin &ARIAMixin) aria_described_by() ?string {
	return mixin.attribute('aria-describedby')
}

pub fn (mixin &ARIAMixin) set_aria_described_by(value ?string) {
	mixin.set_attribute('aria-describedby', value)
}

pub fn (mixin &ARIAMixin) aria_description() ?string {
	return mixin.attribute('aria-description')
}

pub fn (mixin &ARIAMixin) set_aria_description(value ?string) {
	mixin.set_attribute('aria-description', value)
}

pub fn (mixin &ARIAMixin) aria_details() ?string {
	return mixin.attribute('aria-details')
}

pub fn (mixin &ARIAMixin) set_aria_details(value ?string) {
	mixin.set_attribute('aria-details', value)
}

pub fn (mixin &ARIAMixin) aria_drop_effect() ?string {
	return mixin.attribute('aria-dropeffect')
}

pub fn (mixin &ARIAMixin) set_aria_drop_effect(value ?string) {
	mixin.set_attribute('aria-dropeffect', value)
}

pub fn (mixin &ARIAMixin) aria_error_message() ?string {
	return mixin.attribute('aria-errormessage')
}

pub fn (mixin &ARIAMixin) set_aria_error_message(value ?string) {
	mixin.set_attribute('aria-errormessage', value)
}

pub fn (mixin &ARIAMixin) aria_disabled() ?string {
	return mixin.attribute('aria-disabled')
}

pub fn (mixin &ARIAMixin) set_aria_disabled(value ?string) {
	mixin.set_attribute('aria-disabled', value)
}

pub fn (mixin &ARIAMixin) aria_expanded() ?string {
	return mixin.attribute('aria-expanded')
}

pub fn (mixin &ARIAMixin) set_aria_expanded(value ?string) {
	mixin.set_attribute('aria-expanded', value)
}

pub fn (mixin &ARIAMixin) aria_flow_to() ?string {
	return mixin.attribute('aria-flowto')
}

pub fn (mixin &ARIAMixin) set_aria_flow_to(value ?string) {
	mixin.set_attribute('aria-flowto', value)
}

pub fn (mixin &ARIAMixin) aria_grabbed() ?string {
	return mixin.attribute('aria-grabbed')
}

pub fn (mixin &ARIAMixin) set_aria_grabbed(value ?string) {
	mixin.set_attribute('aria-grabbed', value)
}

pub fn (mixin &ARIAMixin) aria_has_popup() ?string {
	return mixin.attribute('aria-haspopup')
}

pub fn (mixin &ARIAMixin) set_aria_has_popup(value ?string) {
	mixin.set_attribute('aria-haspopup', value)
}

pub fn (mixin &ARIAMixin) aria_hidden() ?string {
	return mixin.attribute('aria-hidden')
}

pub fn (mixin &ARIAMixin) set_aria_hidden(value ?string) {
	mixin.set_attribute('aria-hidden', value)
}

pub fn (mixin &ARIAMixin) aria_invalid() ?string {
	return mixin.attribute('aria-invalid')
}

pub fn (mixin &ARIAMixin) set_aria_invalid(value ?string) {
	mixin.set_attribute('aria-invalid', value)
}

pub fn (mixin &ARIAMixin) aria_key_shortcuts() ?string {
	return mixin.attribute('aria-keyshortcuts')
}

pub fn (mixin &ARIAMixin) set_aria_key_shortcuts(value ?string) {
	mixin.set_attribute('aria-keyshortcuts', value)
}

pub fn (mixin &ARIAMixin) aria_label() ?string {
	return mixin.attribute('aria-label')
}

pub fn (mixin &ARIAMixin) set_aria_label(value ?string) {
	mixin.set_attribute('aria-label', value)
}

pub fn (mixin &ARIAMixin) aria_labelled_by() ?string {
	return mixin.attribute('aria-labelledby')
}

pub fn (mixin &ARIAMixin) set_aria_labelled_by(value ?string) {
	mixin.set_attribute('aria-labelledby', value)
}

pub fn (mixin &ARIAMixin) aria_level() ?string {
	return mixin.attribute('aria-level')
}

pub fn (mixin &ARIAMixin) set_aria_level(value ?string) {
	mixin.set_attribute('aria-level', value)
}

pub fn (mixin &ARIAMixin) aria_live() ?string {
	return mixin.attribute('aria-live')
}

pub fn (mixin &ARIAMixin) set_aria_live(value ?string) {
	mixin.set_attribute('aria-live', value)
}

pub fn (mixin &ARIAMixin) aria_modal() ?string {
	return mixin.attribute('aria-modal')
}

pub fn (mixin &ARIAMixin) set_aria_modal(value ?string) {
	mixin.set_attribute('aria-modal', value)
}

pub fn (mixin &ARIAMixin) aria_multi_line() ?string {
	return mixin.attribute('aria-multiline')
}

pub fn (mixin &ARIAMixin) set_aria_multi_line(value ?string) {
	mixin.set_attribute('aria-multiline', value)
}

pub fn (mixin &ARIAMixin) aria_multi_selectable() ?string {
	return mixin.attribute('aria-multiselectable')
}

pub fn (mixin &ARIAMixin) set_aria_multi_selectable(value ?string) {
	mixin.set_attribute('aria-multiselectable', value)
}

pub fn (mixin &ARIAMixin) aria_orientation() ?string {
	return mixin.attribute('aria-orientation')
}

pub fn (mixin &ARIAMixin) set_aria_orientation(value ?string) {
	mixin.set_attribute('aria-orientation', value)
}

pub fn (mixin &ARIAMixin) aria_owns() ?string {
	return mixin.attribute('aria-owns')
}

pub fn (mixin &ARIAMixin) set_aria_owns(value ?string) {
	mixin.set_attribute('aria-owns', value)
}

pub fn (mixin &ARIAMixin) aria_placeholder() ?string {
	return mixin.attribute('aria-placeholder')
}

pub fn (mixin &ARIAMixin) set_aria_placeholder(value ?string) {
	mixin.set_attribute('aria-placeholder', value)
}

pub fn (mixin &ARIAMixin) aria_pos_in_set() ?string {
	return mixin.attribute('aria-posinset')
}

pub fn (mixin &ARIAMixin) set_aria_pos_in_set(value ?string) {
	mixin.set_attribute('aria-posinset', value)
}

pub fn (mixin &ARIAMixin) aria_pressed() ?string {
	return mixin.attribute('aria-pressed')
}

pub fn (mixin &ARIAMixin) set_aria_pressed(value ?string) {
	mixin.set_attribute('aria-pressed', value)
}

pub fn (mixin &ARIAMixin) aria_read_only() ?string {
	return mixin.attribute('aria-readonly')
}

pub fn (mixin &ARIAMixin) set_aria_read_only(value ?string) {
	mixin.set_attribute('aria-readonly', value)
}

pub fn (mixin &ARIAMixin) aria_relevant() ?string {
	return mixin.attribute('aria-relevant')
}

pub fn (mixin &ARIAMixin) set_aria_relevant(value ?string) {
	mixin.set_attribute('aria-relevant', value)
}

pub fn (mixin &ARIAMixin) aria_required() ?string {
	return mixin.attribute('aria-required')
}

pub fn (mixin &ARIAMixin) set_aria_required(value ?string) {
	mixin.set_attribute('aria-required', value)
}

pub fn (mixin &ARIAMixin) aria_role_description() ?string {
	return mixin.attribute('aria-roledescription')
}

pub fn (mixin &ARIAMixin) set_aria_role_description(value ?string) {
	mixin.set_attribute('aria-roledescription', value)
}

pub fn (mixin &ARIAMixin) aria_row_count() ?string {
	return mixin.attribute('aria-rowcount')
}

pub fn (mixin &ARIAMixin) set_aria_row_count(value ?string) {
	mixin.set_attribute('aria-rowcount', value)
}

pub fn (mixin &ARIAMixin) aria_row_index() ?string {
	return mixin.attribute('aria-rowindex')
}

pub fn (mixin &ARIAMixin) set_aria_row_index(value ?string) {
	mixin.set_attribute('aria-rowindex', value)
}

pub fn (mixin &ARIAMixin) aria_row_index_text() ?string {
	return mixin.attribute('aria-rowindextext')
}

pub fn (mixin &ARIAMixin) set_aria_row_index_text(value ?string) {
	mixin.set_attribute('aria-rowindextext', value)
}

pub fn (mixin &ARIAMixin) aria_row_span() ?string {
	return mixin.attribute('aria-rowspan')
}

pub fn (mixin &ARIAMixin) set_aria_row_span(value ?string) {
	mixin.set_attribute('aria-rowspan', value)
}

pub fn (mixin &ARIAMixin) aria_selected() ?string {
	return mixin.attribute('aria-selected')
}

pub fn (mixin &ARIAMixin) set_aria_selected(value ?string) {
	mixin.set_attribute('aria-selected', value)
}

pub fn (mixin &ARIAMixin) aria_set_size() ?string {
	return mixin.attribute('aria-setsize')
}

pub fn (mixin &ARIAMixin) set_aria_set_size(value ?string) {
	mixin.set_attribute('aria-setsize', value)
}

pub fn (mixin &ARIAMixin) aria_sort() ?string {
	return mixin.attribute('aria-sort')
}

pub fn (mixin &ARIAMixin) set_aria_sort(value ?string) {
	mixin.set_attribute('aria-sort', value)
}

pub fn (mixin &ARIAMixin) aria_value_max() ?string {
	return mixin.attribute('aria-valuemax')
}

pub fn (mixin &ARIAMixin) set_aria_value_max(value ?string) {
	mixin.set_attribute('aria-valuemax', value)
}

pub fn (mixin &ARIAMixin) aria_value_min() ?string {
	return mixin.attribute('aria-valuemin')
}

pub fn (mixin &ARIAMixin) set_aria_value_min(value ?string) {
	mixin.set_attribute('aria-valuemin', value)
}

pub fn (mixin &ARIAMixin) aria_value_now() ?string {
	return mixin.attribute('aria-valuenow')
}

pub fn (mixin &ARIAMixin) set_aria_value_now(value ?string) {
	mixin.set_attribute('aria-valuenow', value)
}

pub fn (mixin &ARIAMixin) aria_value_text() ?string {
	return mixin.attribute('aria-valuetext')
}

pub fn (mixin &ARIAMixin) set_aria_value_text(value ?string) {
	mixin.set_attribute('aria-valuetext', value)
}

pub fn (mixin &ARIAMixin) aria_active_descendant_element() ?&dom.Element {
	return mixin.element_reference('aria-activedescendant')
}

pub fn (mut mixin ARIAMixin) set_aria_active_descendant_element(value ?&dom.Element) {
	mixin.set_element_reference('aria-activedescendant', value)
}

pub fn (mixin &ARIAMixin) aria_controls_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-controls')
}

pub fn (mut mixin ARIAMixin) set_aria_controls_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-controls', value)
}

pub fn (mixin &ARIAMixin) aria_described_by_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-describedby')
}

pub fn (mut mixin ARIAMixin) set_aria_described_by_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-describedby', value)
}

pub fn (mixin &ARIAMixin) aria_details_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-details')
}

pub fn (mut mixin ARIAMixin) set_aria_details_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-details', value)
}

pub fn (mixin &ARIAMixin) aria_error_message_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-errormessage')
}

pub fn (mut mixin ARIAMixin) set_aria_error_message_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-errormessage', value)
}

pub fn (mixin &ARIAMixin) aria_flow_to_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-flowto')
}

pub fn (mut mixin ARIAMixin) set_aria_flow_to_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-flowto', value)
}

pub fn (mixin &ARIAMixin) aria_labelled_by_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-labelledby')
}

pub fn (mut mixin ARIAMixin) set_aria_labelled_by_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-labelledby', value)
}

pub fn (mixin &ARIAMixin) aria_owns_elements() ?[]&dom.Element {
	return mixin.element_reference_list('aria-owns')
}

pub fn (mut mixin ARIAMixin) set_aria_owns_elements(value ?[]&dom.Element) {
	mixin.set_element_reference_list('aria-owns', value)
}

pub fn (mixin &ARIAMixin) cached_aria_controls_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-controls')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_controls_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-controls', value)
}

pub fn (mixin &ARIAMixin) cached_aria_described_by_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-describedby')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_described_by_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-describedby', value)
}

pub fn (mixin &ARIAMixin) cached_aria_details_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-details')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_details_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-details', value)
}

pub fn (mixin &ARIAMixin) cached_aria_error_message_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-errormessage')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_error_message_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-errormessage', value)
}

pub fn (mixin &ARIAMixin) cached_aria_flow_to_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-flowto')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_flow_to_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-flowto', value)
}

pub fn (mixin &ARIAMixin) cached_aria_labelled_by_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-labelledby')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_labelled_by_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-labelledby', value)
}

pub fn (mixin &ARIAMixin) cached_aria_owns_elements() ?[]&dom.Element {
	return mixin.cached_element_reference_list('aria-owns')
}

pub fn (mut mixin ARIAMixin) set_cached_aria_owns_elements(value ?[]&dom.Element) {
	mixin.set_cached_element_reference_list('aria-owns', value)
}

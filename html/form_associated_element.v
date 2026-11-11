// Copyright (c) 2021, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024-2026, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FormAssociatedElement.{h,cpp} and ValidityState.{h,cpp}.
module html

import dom
import editing

pub enum SelectionDirection {
	forward
	backward
	none
}

pub enum SelectionSource {
	ui
	dom
	value_change
}

pub enum SelectionMode {
	select
	start
	end
	preserve
}

fn selection_direction_from_string(value ?string) SelectionDirection {
	actual := value or { return .none }
	return match actual {
		'forward' { .forward }
		'backward' { .backward }
		else { .none }
	}
}

fn normalize_form_newlines(value string) string {
	return value.replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\r\n')
}

fn form_element_input_type(element &dom.Element) string {
	if element.local_name() != 'input' {
		return ''
	}
	return ascii_lowercase_string(element.get_attribute('type') or { 'text' })
}

fn form_element_nearest_ancestor(element &dom.Element, local_name string) ?&dom.Element {
	mut ancestor := element.as_node().parent()
	for ancestor != none {
		node := ancestor or { break }
		if candidate := node.as_element() {
			if candidate.is_html_element() && candidate.local_name() == local_name {
				return candidate
			}
		}
		ancestor = node.parent()
	}
	return none
}

fn form_element_find_first_html_element_by_id(root &dom.Node, id string) ?&dom.Element {
	if candidate := root.as_element() {
		if candidate.is_html_element() {
			if candidate_id := candidate.id() {
				if candidate_id == id {
					return candidate
				}
			}
		}
	}
	for child in root.children {
		if element := form_element_find_first_html_element_by_id(child, id) {
			return element
		}
	}
	return none
}

fn form_element_find_form_by_id(root &dom.Node, id string) ?&dom.HTMLFormElement {
	// FormAssociatedElement::reset_form_owner(), step 4: stop at the first
	// matching HTML element even when that element cannot own a form control.
	element := form_element_find_first_html_element_by_id(root, id) or { return none }
	if element.local_name() != 'form' {
		return none
	}
	return unsafe { &dom.HTMLFormElement(element) }
}

fn remove_associated_element_from_form(form &dom.HTMLFormElement, element &dom.Element) {
	mut mutable_form := unsafe { &dom.HTMLFormElement(form) }
	for index, candidate in mutable_form.associated_elements_ {
		if voidptr(candidate) == voidptr(element) {
			mutable_form.associated_elements_.delete(index)
			return
		}
	}
}

fn add_associated_element_to_form(form &dom.HTMLFormElement, element &dom.Element) {
	for candidate in form.associated_elements_ {
		if voidptr(candidate) == voidptr(element) {
			return
		}
	}
	mut mutable_form := unsafe { &dom.HTMLFormElement(form) }
	mutable_form.associated_elements_ << element
}

@[heap]
pub struct FormAssociatedElement {
	dom.FormAssociatedElement
pub:
	element &dom.Element
pub mut:
	form_                         ?&dom.HTMLFormElement
	parser_inserted               bool
	custom_validity_error_message string
	value_                        string
	missing_                      bool
	type_mismatch_                bool
	pattern_mismatch_             bool
	underflow_                    bool
	overflow_                     bool
	step_mismatch_                bool
	bad_input_                    bool
	too_long_                     bool
	too_short_                    bool
	mutable_                      bool = true
	custom_element_               bool
	user_validity_                bool
}

fn form_associated_element_id_changed_callback(target voidptr) {
	mut control := unsafe { &FormAssociatedElement(target) }
	control.element_id_changed()
}

fn form_associated_element_with_id_added_or_removed_callback(target voidptr) {
	mut control := unsafe { &FormAssociatedElement(target) }
	control.element_with_id_was_added_or_removed()
}

fn initialize_form_associated_element_dom_identity(mut control FormAssociatedElement) {
	control.FormAssociatedElement = dom.FormAssociatedElement{
		target: voidptr(&control)
		element_id_changed_callback: form_associated_element_id_changed_callback
		element_with_id_added_or_removed_callback: form_associated_element_with_id_added_or_removed_callback
	}
	if control.element.has_attribute('form') {
		mut document := control.element.document()
		document.add_form_associated_element_with_form_attribute(unsafe {
			&dom.FormAssociatedElement(&control)
		})
	}
}

pub fn FormAssociatedElement.create(element &dom.Element) &FormAssociatedElement {
	mut control := &FormAssociatedElement{
		element: element
	}
	initialize_form_associated_element_dom_identity(mut control)
	return control
}

pub fn FormAssociatedElement.create_custom(element &dom.Element) &FormAssociatedElement {
	mut control := &FormAssociatedElement{
		element: element
		custom_element_: true
	}
	initialize_form_associated_element_dom_identity(mut control)
	return control
}

pub fn (control &FormAssociatedElement) form() ?&dom.HTMLFormElement {
	return control.form_
}

pub fn (control &FormAssociatedElement) optional_value() ?string {
	return control.value_
}

pub fn (control &FormAssociatedElement) form_associated_element_to_html_element() &dom.HTMLElement {
	return unsafe { &dom.HTMLElement(control.element) }
}

pub fn (_ &FormAssociatedElement) form_associated_element_was_inserted() {}

pub fn (_ &FormAssociatedElement) form_associated_element_was_removed(_old_parent ?&dom.Node) {}

pub fn (_ &FormAssociatedElement) form_associated_element_was_moved(_old_parent ?&dom.Node) {}

pub fn (_ &FormAssociatedElement) form_associated_element_attribute_changed(_name string, _old_value ?string, _value ?string, _namespace ?string) {}

pub fn (mut control FormAssociatedElement) set_form(form ?&dom.HTMLFormElement) {
	if old_form := control.form_ {
		remove_associated_element_from_form(old_form, control.element)
	}
	control.form_ = form
	if new_form := form {
		add_associated_element_to_form(new_form, control.element)
	}
	// Form controls collections are live and their membership can change even
	// when the DOM tree itself does not. Invalidate the document's collection
	// generation for the form-owner transition.
	mut document := control.element.document()
	document.bump_dom_tree_version()
}

pub fn (control &FormAssociatedElement) enabled() bool {
	return !control.element.is_actually_disabled()
}

pub fn (mut control FormAssociatedElement) set_parser_inserted() {
	control.parser_inserted = true
}

pub fn (control &FormAssociatedElement) is_listed() bool {
	if control.custom_element_ {
		return true
	}
	return control.element.local_name() in ['button', 'fieldset', 'input', 'object', 'output',
		'select', 'textarea']
}

pub fn (control &FormAssociatedElement) is_submittable() bool {
	if control.custom_element_ {
		return true
	}
	return control.element.local_name() in ['button', 'input', 'object', 'select', 'textarea']
}

pub fn (control &FormAssociatedElement) is_resettable() bool {
	if control.custom_element_ {
		return true
	}
	return control.element.local_name() in ['input', 'output', 'select', 'textarea']
}

pub fn (control &FormAssociatedElement) is_autocapitalize_and_autocorrect_inheriting() bool {
	return control.element.local_name() in ['button', 'fieldset', 'input', 'output', 'select',
		'textarea']
}

pub fn (control &FormAssociatedElement) is_button() bool {
	if control.element.local_name() == 'button' {
		return true
	}
	return form_element_input_type(control.element) in ['button', 'image', 'reset', 'submit']
}

pub fn (control &FormAssociatedElement) is_submit_button() bool {
	if control.element.local_name() == 'button' {
		return ascii_lowercase_string(control.element.get_attribute('type') or { 'submit' }) == 'submit'
	}
	return form_element_input_type(control.element) in ['image', 'submit']
}

pub fn (mut control FormAssociatedElement) form_node_was_inserted() {
	if !control.parser_inserted {
		control.reset_form_owner()
	}
}

pub fn (mut control FormAssociatedElement) form_node_was_removed() {
	if form := control.form_ {
		if control.element.as_node().root() != unsafe { &dom.Element(form) }.as_node().root() {
			control.reset_form_owner()
		}
	}
}

pub fn (mut control FormAssociatedElement) form_node_was_moved() {
	control.form_node_was_removed()
}

pub fn (mut control FormAssociatedElement) form_node_attribute_changed(name string) {
	if name == 'form' {
		mut document := control.element.document()
		dom_control := unsafe { &dom.FormAssociatedElement(&control) }
		if control.element.has_attribute('form') {
			document.add_form_associated_element_with_form_attribute(dom_control)
		} else {
			document.remove_form_associated_element_with_form_attribute(dom_control)
		}
		control.reset_form_owner()
	}
}

pub fn (mut control FormAssociatedElement) element_id_changed() {
	control.reset_form_owner()
}

pub fn (mut control FormAssociatedElement) element_with_id_was_added_or_removed() {
	control.reset_form_owner()
}

// The form owner the reset the form owner algorithm gives a listed element
// that keeps no form-associated state of its own, such as a fieldset.
pub fn computed_listed_element_form_owner(element &dom.Element) ?&dom.HTMLFormElement {
	if element.has_attribute('form') {
		if !element.is_connected() {
			return none
		}
		form_id := element.get_attribute('form') or { return none }
		return form_element_find_form_by_id(element.as_node().root(), form_id)
	}
	ancestor := form_element_nearest_ancestor(element, 'form') or { return none }
	return unsafe { &dom.HTMLFormElement(ancestor) }
}

pub fn (mut control FormAssociatedElement) reset_form_owner() {
	control.parser_inserted = false
	if current_form := control.form_ {
		if !control.is_listed() || !control.element.has_attribute('form') {
			if ancestor := form_element_nearest_ancestor(control.element, 'form') {
				if voidptr(ancestor) == voidptr(current_form) {
					return
				}
			}
		}
	}
	control.set_form(none)
	if control.is_listed() && control.element.has_attribute('form') && control.element.is_connected() {
		form_id := control.element.get_attribute('form') or { return }
		if form := form_element_find_form_by_id(control.element.as_node().root(), form_id) {
			control.set_form(form)
		}
		return
	}
	if ancestor := form_element_nearest_ancestor(control.element, 'form') {
		control.set_form(unsafe { &dom.HTMLFormElement(ancestor) })
	}
}

pub fn (mut control FormAssociatedElement) reset_algorithm() {
	if value := reset_form_associated_dom_element(control.element) {
		control.value_ = value
	}
}

fn reset_form_associated_dom_element(element &dom.Element) ?string {
	// The upstream call is virtual. Recover the concrete, cached control
	// model from its DOM identity rather than resetting only this base record.
	match element.local_name() {
		'input' {
			mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			model.reset_algorithm()
			return model.value()
		}
		'textarea' {
			mut model := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
			model.reset_algorithm()
			return model.value()
		}
		'select' {
			mut model := HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
			model.reset_algorithm()
			return html_select_element_value(model.element)
		}
		'output' {
			mut model := HTMLOutputElementModel.create(unsafe { &dom.HTMLOutputElement(element) })
			model.reset_algorithm()
			return model.value()
		}
		else {
			if element.is_form_associated_custom_element() {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.enqueue_a_custom_element_callback_reaction('formResetCallback', [])
			}
		}
	}
	return none
}

pub fn (mut control FormAssociatedElement) clear_algorithm() {
	control.reset_algorithm()
}

pub fn (control &FormAssociatedElement) form_action() string {
	attribute := control.element.get_attribute('formaction') or {
		return control.element.document().url_string()
	}
	if attribute == '' {
		return control.element.document().url_string()
	}
	url := dom.dom_url_parse(attribute, control.element.document().base_url(), 'UTF-8') or {
		return ''
	}
	return url.to_string()
}

pub fn (mut control FormAssociatedElement) set_form_action(value string) {
	mut element := unsafe { &dom.Element(control.element) }
	element.set_attribute_value('formaction', value)
}

pub fn (control &FormAssociatedElement) report_validity() bool {
	return control.report_validity_steps()
}

pub fn (control &FormAssociatedElement) check_validity() bool {
	return control.check_validity_steps()
}

pub fn (control &FormAssociatedElement) will_validate() bool {
	return control.is_candidate_for_constraint_validation()
}

pub fn (control &FormAssociatedElement) validation_message() string {
	if !control.is_candidate_for_constraint_validation() || control.satisfies_its_constraints() {
		return ''
	}
	if control.suffering_from_a_custom_error() {
		return control.custom_validity_error_message
	}
	return 'Invalid form'
}

pub fn (control &FormAssociatedElement) check_validity_steps() bool {
	if control.is_candidate_for_constraint_validation() && !control.satisfies_its_constraints() {
		event := dom.Event.create('invalid', dom.EventInit{ cancelable: true })
		control.element.as_node().dispatch_event(event)
		return false
	}
	return true
}

pub fn (control &FormAssociatedElement) report_validity_steps() bool {
	// Reporting UI is host-specific, but the required validation event and
	// return value are identical to check-validity.
	return control.check_validity_steps()
}

pub fn (control &FormAssociatedElement) is_candidate_for_constraint_validation() bool {
	if !control.is_submittable() || !control.enabled() {
		return false
	}
	if form_element_nearest_ancestor(control.element, 'datalist') != none {
		return false
	}
	if control.element.local_name() == 'input' {
		if form_element_input_type(control.element) in ['hidden', 'reset', 'button'] || control.element.has_attribute('readonly') {
			return false
		}
	}
	if control.element.local_name() == 'button' && !control.is_submit_button() {
		return false
	}
	if control.element.local_name() == 'textarea' && control.element.has_attribute('readonly') {
		return false
	}
	return true
}

pub fn (control &FormAssociatedElement) satisfies_its_constraints() bool {
	return !(control.suffering_from_being_missing() || control.suffering_from_a_type_mismatch() || control.suffering_from_a_pattern_mismatch() || control.suffering_from_being_too_long() || control.suffering_from_being_too_short() || control.suffering_from_an_underflow() || control.suffering_from_an_overflow() || control.suffering_from_a_step_mismatch() || control.suffering_from_bad_input() || control.suffering_from_a_custom_error())
}

pub fn (control &FormAssociatedElement) novalidate_state() bool {
	if !control.is_submit_button() {
		return false
	}
	if control.element.has_attribute('formnovalidate') {
		return true
	}
	if form := control.form_ {
		return unsafe { &dom.Element(form) }.has_attribute('novalidate')
	}
	return false
}

pub fn (control &FormAssociatedElement) suffering_from_being_missing() bool {
	return control.missing_
}

pub fn (control &FormAssociatedElement) suffering_from_a_type_mismatch() bool {
	return control.type_mismatch_
}

pub fn (control &FormAssociatedElement) suffering_from_a_pattern_mismatch() bool {
	return control.pattern_mismatch_
}

pub fn (control &FormAssociatedElement) suffering_from_being_too_long() bool {
	return control.too_long_
}

pub fn (control &FormAssociatedElement) suffering_from_being_too_short() bool {
	return control.too_short_
}

pub fn (control &FormAssociatedElement) suffering_from_an_underflow() bool {
	return control.underflow_
}

pub fn (control &FormAssociatedElement) suffering_from_an_overflow() bool {
	return control.overflow_
}

pub fn (control &FormAssociatedElement) suffering_from_a_step_mismatch() bool {
	return control.step_mismatch_
}

pub fn (control &FormAssociatedElement) suffering_from_bad_input() bool {
	return control.bad_input_
}

pub fn (control &FormAssociatedElement) suffering_from_a_custom_error() bool {
	return control.custom_validity_error_message != ''
}

pub fn (control &FormAssociatedElement) value() string {
	return control.value_
}

pub fn (control &FormAssociatedElement) is_mutable() bool {
	return control.mutable_
}

pub fn (mut control FormAssociatedElement) set_custom_validity(message string) {
	control.custom_validity_error_message = normalize_form_newlines(message)
}

@[heap]
pub struct ValidityState {
	control &FormAssociatedElement
}

pub fn ValidityState.create(control &FormAssociatedElement) &ValidityState {
	return &ValidityState{
		control: control
	}
}

pub fn (state &ValidityState) value_missing() bool {
	return state.control.suffering_from_being_missing()
}

pub fn (state &ValidityState) type_mismatch() bool {
	return state.control.suffering_from_a_type_mismatch()
}

pub fn (state &ValidityState) pattern_mismatch() bool {
	return state.control.suffering_from_a_pattern_mismatch()
}

pub fn (state &ValidityState) too_long() bool {
	return state.control.suffering_from_being_too_long()
}

pub fn (state &ValidityState) too_short() bool {
	return state.control.suffering_from_being_too_short()
}

pub fn (state &ValidityState) range_underflow() bool {
	return state.control.suffering_from_an_underflow()
}

pub fn (state &ValidityState) range_overflow() bool {
	return state.control.suffering_from_an_overflow()
}

pub fn (state &ValidityState) step_mismatch() bool {
	return state.control.suffering_from_a_step_mismatch()
}

pub fn (state &ValidityState) bad_input() bool {
	return state.control.suffering_from_bad_input()
}

pub fn (state &ValidityState) custom_error() bool {
	return state.control.suffering_from_a_custom_error()
}

pub fn (state &ValidityState) valid() bool {
	return state.control.satisfies_its_constraints()
}

fn form_string_to_utf16(value string) []u16 {
	mut units := []u16{}
	for rune_ in value.runes() {
		point := u32(rune_)
		if point <= 0xffff {
			units << u16(point)
		} else {
			adjusted := point - 0x10000
			units << u16(0xd800 + (adjusted >> 10))
			units << u16(0xdc00 + (adjusted & 0x3ff))
		}
	}
	return units
}

fn form_utf16_to_string(units []u16) string {
	mut runes := []rune{}
	mut index := 0
	for index < units.len {
		first := units[index]
		if first >= 0xd800 && first <= 0xdbff && index + 1 < units.len {
			second := units[index + 1]
			if second >= 0xdc00 && second <= 0xdfff {
				point := u32(0x10000) + ((u32(first) - 0xd800) << 10) + (u32(second) - 0xdc00)
				runes << rune(point)
				index += 2
				continue
			}
		}
		runes << rune(first)
		index++
	}
	return runes.string()
}

@[heap]
pub struct FormAssociatedTextControlElement {
	dom.InputEventsTarget
pub:
	control &FormAssociatedElement
pub mut:
	relevant_value_                     string
	dirty_value_flag                    bool
	selection_start_                    u32
	selection_end_                      u32
	selection_end_affinity_             dom.TextAffinity = .downstream
	selection_direction_                SelectionDirection
	has_scheduled_selectionchange_event bool
	text_node_                          ?&dom.Text
	did_edit_target_                    voidptr
	did_edit_callback_                  ?fn (voidptr, string, ?string)
	deferred_cursor_scroll_depth_       int
	has_deferred_cursor_scroll_         bool
}

fn form_associated_text_control_defer_cursor_scroll(target voidptr, defer_scroll bool) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	if defer_scroll {
		text.deferred_cursor_scroll_depth_++
	} else {
		assert text.deferred_cursor_scroll_depth_ > 0
		text.deferred_cursor_scroll_depth_--
	}
}

fn form_associated_text_control_flush_deferred_cursor_scroll(target voidptr, allow_scroll bool) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	if !text.has_deferred_cursor_scroll_ { return }
	text.has_deferred_cursor_scroll_ = false
	if allow_scroll { text.scroll_cursor_into_view() }
}

fn form_associated_text_control_cursor_position(target voidptr) ?&dom.Position {
	text := unsafe { &FormAssociatedTextControlElement(target) }
	return text.cursor_position()
}

fn form_associated_text_control_handle_insert(target voidptr, input_type string, value string) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.handle_insert(input_type, value) or {}
}

fn form_associated_text_control_handle_return(target voidptr, input_type string) dom.EventResult {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	element := text.control.element
	if element.local_name() == 'textarea' {
		mut model := html_text_area_element_model_for_dom_element(unsafe {
			&dom.HTMLTextAreaElement(element)
		})
		model.handle_return_key(input_type) or { return .dropped }
		return .handled
	}
	if element.local_name() == 'input' {
		mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		model.handle_return_key(input_type) or { return .dropped }
		return .handled
	}
	return .dropped
}

fn form_associated_text_control_navigate(target voidptr, action dom.InputEventsTargetNavigationAction, collapse dom.CollapseSelection) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	match action {
		.start, .document_start, .previous_page { text.move_cursor_to_start(collapse) }
		.end, .document_end, .next_page { text.move_cursor_to_end(collapse) }
		.line_start { text.move_cursor_to_start_of_current_line(collapse) }
		.line_end { text.move_cursor_to_end_of_current_line(collapse) }
		.previous_character { text.decrement_cursor_position_offset(collapse) }
		.next_character { text.increment_cursor_position_offset(collapse) }
		.previous_word { text.decrement_cursor_position_to_previous_word(collapse) }
		.next_word { text.increment_cursor_position_to_next_word(collapse) }
		.previous_line { text.decrement_cursor_position_to_previous_line(collapse) }
		.next_line { text.increment_cursor_position_to_next_line(collapse) }
	}
}

fn form_associated_text_control_mouse_selection_scope(target voidptr) ?&dom.Node {
	text := unsafe { &FormAssociatedTextControlElement(target) }
	text_node := text.text_node_ or { return none }
	return text_node.as_node()
}

fn form_associated_text_control_set_selection_anchor(target voidptr, node &dom.Node, offset int, affinity dom.TextAffinity) {
	if offset < 0 {
		return
	}
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.set_selection_anchor(node, uint(offset), affinity)
}

fn form_associated_text_control_set_selection_focus(target voidptr, node &dom.Node, offset int, affinity dom.TextAffinity) {
	if offset < 0 {
		return
	}
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.set_selection_focus(node, uint(offset), affinity)
}

fn form_associated_text_control_handle_delete(target voidptr, input_type string) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.handle_delete(input_type) or {}
}

fn form_associated_text_control_select_all(target voidptr) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.select_all()
}

fn form_associated_text_control_selection(target voidptr) dom.TextControlSelectionSnapshot {
	text := unsafe { &FormAssociatedTextControlElement(target) }
	return dom.TextControlSelectionSnapshot{
		start: text.selection_start()
		end: text.selection_end()
		direction: match text.selection_direction_state() {
			.forward { .forward }
			.backward { .backward }
			.none { .none }
		}
	}
}

fn form_associated_text_control_set_selection(target voidptr, start u32, end u32, direction dom.TextControlSelectionDirection) {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.set_the_selection_range(start, end, match direction {
		.forward { .forward }
		.backward { .backward }
		.none { .none }
	}, .value_change)
}

fn form_associated_text_control_relevant_value(target voidptr) string {
	text := unsafe { &FormAssociatedTextControlElement(target) }
	return text.relevant_value()
}

fn form_associated_text_control_replace_range(target voidptr, replacement string, start u32, end u32) bool {
	mut text := unsafe { &FormAssociatedTextControlElement(target) }
	text.set_range_text_with_source(replacement, start, end, .preserve, .value_change) or { return false }
	if mut text_node := text.text_node_ {
		text_node.set_data(text.relevant_value())
	}
	return true
}

pub fn FormAssociatedTextControlElement.create(control &FormAssociatedElement, value string) &FormAssociatedTextControlElement {
	mut text := &FormAssociatedTextControlElement{
		control: control
		relevant_value_: value
	}
	text.InputEventsTarget = dom.InputEventsTarget{
		target: voidptr(text)
		cursor_position_callback: form_associated_text_control_cursor_position
		handle_insert_callback: form_associated_text_control_handle_insert
		handle_return_callback: form_associated_text_control_handle_return
		navigate_callback: form_associated_text_control_navigate
		mouse_selection_scope_callback: form_associated_text_control_mouse_selection_scope
		set_selection_anchor_callback: form_associated_text_control_set_selection_anchor
		set_selection_focus_callback: form_associated_text_control_set_selection_focus
		handle_delete_callback: form_associated_text_control_handle_delete
		select_all_callback: form_associated_text_control_select_all
		selection_callback: form_associated_text_control_selection
		set_selection_callback: form_associated_text_control_set_selection
		relevant_value_callback: form_associated_text_control_relevant_value
		replace_range_callback: form_associated_text_control_replace_range
		defer_cursor_scroll_callback: form_associated_text_control_defer_cursor_scroll
		flush_deferred_cursor_scroll_callback: form_associated_text_control_flush_deferred_cursor_scroll
	}
	return text
}

pub fn (text &FormAssociatedTextControlElement) relevant_value() string {
	return text.relevant_value_
}

pub fn (text &FormAssociatedTextControlElement) selection_direction_state() SelectionDirection {
	return text.selection_direction_
}

pub fn (text &FormAssociatedTextControlElement) has_scheduled_selectionchange_event() bool {
	return text.has_scheduled_selectionchange_event
}

pub fn (mut text FormAssociatedTextControlElement) set_scheduled_selectionchange_event(value bool) {
	text.has_scheduled_selectionchange_event = value
}

pub fn (text &FormAssociatedTextControlElement) form_associated_element_to_text_node() ?&dom.Text {
	return text.text_node_
}

pub fn (mut text FormAssociatedTextControlElement) set_relevant_value(value string) {
	text.relevant_value_ = value
	mut control := text.control
	control.value_ = value
	text.relevant_value_was_changed()
}

pub fn (mut text FormAssociatedTextControlElement) relevant_value_was_changed() {
	length := u32(form_string_to_utf16(text.relevant_value_).len)
	text.selection_start_ = if text.selection_start_ > length {
		length
	} else {
		text.selection_start_
	}
	text.selection_end_ = if text.selection_end_ > length { length } else { text.selection_end_ }
}

fn (text &FormAssociatedTextControlElement) selection_or_range_applies() bool {
	if text.control.element.local_name() != 'input' {
		return true
	}
	return form_element_input_type(text.control.element) in ['text', 'search', 'tel', 'url',
		'password']
}

pub fn (mut text FormAssociatedTextControlElement) select() {
	if !text.selection_or_range_applies() {
		return
	}
	text.set_the_selection_range(0, max_u32, .none, .dom)
}

pub fn (text &FormAssociatedTextControlElement) selection_start_binding() ?u32 {
	if !text.selection_or_range_applies() {
		return none
	}
	return text.selection_start()
}

pub fn (text &FormAssociatedTextControlElement) selection_start() u32 {
	return if text.selection_start_ < text.selection_end_ {
		text.selection_start_
	} else {
		text.selection_end_
	}
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_start_binding(value ?u32) ! {
	if !text.selection_or_range_applies() {
		return error('InvalidStateError: selectionStart does not apply')
	}
	mut end := text.selection_end_
	if actual := value {
		if end < actual {
			end = actual
		}
	}
	text.set_the_selection_range(value or { 0 }, end, text.selection_direction_, .dom)
}

pub fn (text &FormAssociatedTextControlElement) selection_end_binding() ?u32 {
	if !text.selection_or_range_applies() {
		return none
	}
	return text.selection_end()
}

pub fn (text &FormAssociatedTextControlElement) selection_end() u32 {
	return if text.selection_start_ < text.selection_end_ {
		text.selection_end_
	} else {
		text.selection_start_
	}
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_end_binding(value ?u32) ! {
	if !text.selection_or_range_applies() {
		return error('InvalidStateError: selectionEnd does not apply')
	}
	text.set_the_selection_range(text.selection_start_, value or { 0 }, text.selection_direction_, .dom)
}

pub fn (text &FormAssociatedTextControlElement) selection_direction() ?string {
	if !text.selection_or_range_applies() {
		return none
	}
	return match text.selection_direction_ {
		.forward { 'forward' }
		.backward { 'backward' }
		.none { 'none' }
	}
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_direction(direction ?string) {
	text.selection_direction_ = selection_direction_from_string(direction)
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_direction_binding(direction ?string) ! {
	if !text.selection_or_range_applies() {
		return error('InvalidStateError: selectionDirection does not apply')
	}
	text.set_the_selection_range(text.selection_start_, text.selection_end_, selection_direction_from_string(direction), .dom)
}

pub fn (mut text FormAssociatedTextControlElement) set_range_text(replacement string, start u32, end u32, selection_mode SelectionMode) ! {
	text.set_range_text_with_source(replacement, start, end, selection_mode, .dom)!
}

pub fn (mut text FormAssociatedTextControlElement) set_range_text_with_source(replacement string, start u32, end u32, selection_mode SelectionMode, source SelectionSource) ! {
	if !text.selection_or_range_applies() {
		return error('InvalidStateError: setRangeText does not apply')
	}
	if start > end {
		return error('IndexSizeError: start must be less than or equal to end')
	}
	text.dirty_value_flag = true
	mut value_units := form_string_to_utf16(text.relevant_value_)
	replacement_units := form_string_to_utf16(replacement)
	actual_start := if int(start) > value_units.len { value_units.len } else { int(start) }
	actual_end := if int(end) > value_units.len { value_units.len } else { int(end) }
	old_selection_start := int(text.selection_start())
	old_selection_end := int(text.selection_end())
	mut result := value_units[..actual_start].clone()
	result << replacement_units
	result << value_units[actual_end..]
	text.relevant_value_ = form_utf16_to_string(result)
	mut control := text.control
	control.value_ = text.relevant_value_
	new_end := actual_start + replacement_units.len
	mut selection_start := old_selection_start
	mut selection_end := old_selection_end
	match selection_mode {
		.select {
			selection_start = actual_start
			selection_end = new_end
		}
		.start {
			selection_start = actual_start
			selection_end = actual_start
		}
		.end {
			selection_start = new_end
			selection_end = new_end
		}
		.preserve {
			delta := replacement_units.len - (actual_end - actual_start)
			if selection_start > actual_end {
				selection_start += delta
			} else if selection_start > actual_start {
				selection_start = actual_start
			}
			if selection_end > actual_end {
				selection_end += delta
			} else if selection_end > actual_start {
				selection_end = new_end
			}
		}
	}
	text.set_the_selection_range(u32(selection_start), u32(selection_end), .none, source)
	if source == .dom {
		text.control.element.document().notify_editing_history_selection_changed()
	}
}

pub fn (mut text FormAssociatedTextControlElement) set_range_text_at_selection(replacement string) ! {
	text.set_range_text(replacement, text.selection_start(), text.selection_end(), .preserve)!
}

// The two upstream WebIDL overloads converge on the explicit-range overload
// in V; set_range_text_at_selection() carries the one-argument overload.
pub fn (mut text FormAssociatedTextControlElement) set_range_text_binding(replacement string, start u32, end u32, selection_mode SelectionMode) ! {
	text.set_range_text(replacement, start, end, selection_mode)!
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_range(start ?u32, end ?u32, direction ?string) ! {
	if !text.selection_or_range_applies() {
		return error('InvalidStateError: setSelectionRange does not apply')
	}
	text.set_the_selection_range(start or { 0 }, end or { 0 }, selection_direction_from_string(direction), .dom)
}

pub fn (mut text FormAssociatedTextControlElement) set_the_selection_range(start u32, end u32, direction SelectionDirection, source SelectionSource) {
	length := u32(form_string_to_utf16(text.relevant_value_).len)
	actual_start := if start > length { length } else { start }
	actual_end := if end > length { length } else { end }
	new_selection_start := if actual_start < actual_end { actual_start } else { actual_end }
	was_modified := text.selection_start_ != new_selection_start || text.selection_end_ != actual_end || text.selection_direction_ != direction
	text.selection_start_ = new_selection_start
	text.selection_end_ = actual_end
	text.selection_end_affinity_ = .downstream
	text.selection_direction_ = direction
	if was_modified {
		if source == .dom || (source == .ui && text.selection_start_ != text.selection_end_) {
			element := text.control.element
			document := element.document()
			queue_a_task(.user_interaction, main_thread_event_loop(), document, fn [element] () {
				select_event := dom.Event.create('select', dom.EventInit{ bubbles: true })
				unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(select_event)
			})
		}
		text.control.element.document().notify_editing_history_selection_changed()
		text.selection_was_changed(source)
	}
}

pub fn (text &FormAssociatedTextControlElement) selected_text_for_stringifier() ?string {
	start := int(text.selection_start())
	end := int(text.selection_end())
	if start >= end {
		return none
	}
	units := form_string_to_utf16(text.relevant_value_)
	return form_utf16_to_string(units[start..end])
}

pub fn (mut text FormAssociatedTextControlElement) handle_insert(input_type string, data string) ! {
	if !text.control.is_mutable() || text.control.element.is_actually_disabled()
		|| text.control.element.has_attribute('readonly') {
		return
	}
	mut text_node := text.text_node_ or { return }
	mut data_for_insertion := data
	if max_length := text_node.max_length() {
		remaining_length := max_length - text_node.length()
		units := form_string_to_utf16(data)
		if remaining_length < units.len {
			data_for_insertion = if remaining_length <= 0 {
				''
			} else {
				form_utf16_to_string(units[..remaining_length])
			}
		}
	}
	selection_start := text.selection_start()
	selection_end := text.selection_end()
	element := text.control.element
	history_pointer := editing.install_editing_history(element.document())
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	category := if input_type == dom.input_type_insert_from_paste {
		editing.UndoStepCategory.other
	} else {
		editing.UndoStepCategory.insertion
	}
	history.begin_recording(element.as_node(), category)
	old_units := form_string_to_utf16(text.relevant_value())
	clamped_start := if int(selection_start) > old_units.len {
		old_units.len
	} else {
		int(selection_start)
	}
	clamped_end := if int(selection_end) > old_units.len {
		old_units.len
	} else {
		int(selection_end)
	}
	removed_data := form_utf16_to_string(old_units[clamped_start..clamped_end])
	history.begin_proxy_mutation()
	text.set_range_text_with_source(data_for_insertion, selection_start, selection_end, .end, .value_change) or {
		history.end_proxy_mutation()
		history.end_recording()
		return err
	}
	text_node.set_data(text.relevant_value_)
	history.end_proxy_mutation()
	if step_pointer := history.undo_step_being_recorded() {
		mut step := unsafe { &editing.UndoStep(step_pointer) }
		if removed_data != data_for_insertion {
			step.add_command(editing.new_replace_data_command(&text_node.CharacterData, clamped_start, removed_data, data_for_insertion))
		}
		if input_type in [dom.input_type_insert_line_break, dom.input_type_insert_paragraph] {
			step.set_closes_after_next_merge()
		}
	}
	history.end_recording()
	mut node := text_node.as_node()
	node.invalidate_style(.style_change)
	input_data := if input_type in [dom.input_type_insert_text,
		dom.input_type_insert_composition_text, dom.input_type_insert_from_paste] {
		?string(data_for_insertion)
	} else {
		none
	}
	text.did_edit_text_node(input_type, input_data)
	text.scroll_cursor_into_view()
}

pub fn (mut text FormAssociatedTextControlElement) handle_delete(input_type string) ! {
	if !text.control.is_mutable() || text.control.element.is_actually_disabled()
		|| text.control.element.has_attribute('readonly') {
		return
	}
	mut text_node := text.text_node_ or { return }
	mut start := text.selection_start()
	mut end := text.selection_end()
	if start == end {
		if input_type == 'deleteContentBackward' {
			start = u32(text_node.grapheme_segmenter().previous_boundary(int(text.selection_end_)) or {
				int(start)
			})
		} else {
			end = u32(text_node.grapheme_segmenter().next_boundary(int(text.selection_end_)) or {
				int(end)
			})
		}
	}
	element := text.control.element
	history_pointer := editing.install_editing_history(element.document())
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	category := if input_type == dom.input_type_delete_content_backward {
		editing.UndoStepCategory.backward_deletion
	} else if input_type == dom.input_type_delete_content_forward {
		editing.UndoStepCategory.forward_deletion
	} else {
		editing.UndoStepCategory.other
	}
	history.begin_recording(element.as_node(), category)
	old_units := form_string_to_utf16(text.relevant_value())
	clamped_start := if int(start) > old_units.len { old_units.len } else { int(start) }
	clamped_end := if int(end) > old_units.len { old_units.len } else { int(end) }
	removed_data := form_utf16_to_string(old_units[clamped_start..clamped_end])
	history.begin_proxy_mutation()
	text.set_range_text_with_source('', start, end, .end, .value_change) or {
		history.end_proxy_mutation()
		history.end_recording()
		return err
	}
	text_node.set_data(text.relevant_value_)
	history.end_proxy_mutation()
	if removed_data != '' {
		if step_pointer := history.undo_step_being_recorded() {
			mut step := unsafe { &editing.UndoStep(step_pointer) }
			step.add_command(editing.new_replace_data_command(&text_node.CharacterData, clamped_start, removed_data, ''))
		}
	}
	history.end_recording()
	mut node := text_node.as_node()
	node.invalidate_style(.style_change)
	text.did_edit_text_node(input_type, none)
	text.scroll_cursor_into_view()
}

pub fn (mut text FormAssociatedTextControlElement) select_all() {
	text_node := text.text_node_ or { return }
	text.set_the_selection_range(0, u32(text_node.length()), .none, .dom)
	text.selection_was_changed(.ui)
}

fn (mut text FormAssociatedTextControlElement) did_edit_text_node(input_type string, data ?string) {
	callback := text.did_edit_callback_ or { return }
	callback(text.did_edit_target_, input_type, data)
}

pub fn (mut text FormAssociatedTextControlElement) collapse_selection_to_offset(position uint) {
	text.move_selection_end_to(position, .downstream, .yes)
}

fn (mut text FormAssociatedTextControlElement) move_selection_end_to(offset uint,
	affinity dom.TextAffinity, collapse dom.CollapseSelection) {
	if collapse == .yes {
		text.selection_start_ = u32(offset)
	}
	text.selection_end_ = u32(offset)
	text.selection_end_affinity_ = affinity
	text.control.element.document().notify_editing_history_selection_changed()
}

pub fn (text &FormAssociatedTextControlElement) scroll_cursor_into_view() {
	if text.text_node_ == none {
		return
	}
	if text.deferred_cursor_scroll_depth_ > 0 {
		mut mutable_text := unsafe { &FormAssociatedTextControlElement(text) }
		mutable_text.has_deferred_cursor_scroll_ = true
		return
	}
	mut document := text.control.element.document()
	document.update_layout(.scroll_cursor_into_view)
	// The layout bridge materializes the control's anonymous editing text rather
	// than exposing the UA-shadow Text node as its principal paintable. Route
	// through the host paintable while preserving the same selection offset.
	paintable := text.control.element.as_node().paintable() or { return }
	paintable.scroll_ancestor_to_offset_into_view(int(text.selection_end_))
}

pub fn (mut text FormAssociatedTextControlElement) selection_was_changed(source SelectionSource) {
	if !text.has_scheduled_selectionchange_event {
		text.has_scheduled_selectionchange_event = true
		text_pointer := voidptr(&text)
		element := text.control.element
		document := element.document()
		queue_a_task(.user_interaction, main_thread_event_loop(), document, fn [text_pointer, element] () {
			mut mutable_text := unsafe { &FormAssociatedTextControlElement(text_pointer) }
			mutable_text.has_scheduled_selectionchange_event = false
			event := dom.Event.create('selectionchange', dom.EventInit{ bubbles: true })
			unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event)
		})
	}
	if text_node := text.text_node_ {
		mut node := text_node.as_node()
		node.set_needs_repaint(.paint_commands)
		if text.selection_start_ == text.selection_end_ {
			mut document := text.control.element.document()
			document.reset_cursor_blink_cycle()
		}
	}
	if source == .ui {
		text.scroll_cursor_into_view()
	}
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_anchor(anchor_node &dom.Node,
	anchor_offset uint, affinity dom.TextAffinity) {
	mut manager := text.control.element.document().editing_host_manager()
	manager.set_selection_anchor_with_affinity(anchor_node, int(anchor_offset), affinity)
	text_node := text.text_node_ or { return }
	if voidptr(anchor_node) != voidptr(text_node.as_node()) {
		return
	}
	text.move_selection_end_to(anchor_offset, affinity, .yes)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) set_selection_focus(focus_node &dom.Node,
	focus_offset uint, affinity dom.TextAffinity) {
	mut manager := text.control.element.document().editing_host_manager()
	manager.set_selection_focus_with_affinity(focus_node, int(focus_offset), affinity)
	text_node := text.text_node_ or { return }
	if voidptr(focus_node) != voidptr(text_node.as_node()) {
		return
	}
	text.move_selection_end_to(focus_offset, affinity, .no)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) move_cursor_to_start(collapse dom.CollapseSelection) {
	if text.text_node_ == none {
		return
	}
	text.move_selection_end_to(0, .downstream, collapse)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) move_cursor_to_end(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	end := uint(text_node.length())
	text.move_selection_end_to(end, .downstream, collapse)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) move_cursor_to_start_of_current_line(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	new_offset := dom.find_visual_line_start(text_node, int(text.selection_end_),
		text.selection_end_affinity_)
	text.move_selection_end_to(uint(new_offset), .downstream, collapse)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) move_cursor_to_end_of_current_line(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	new_position := dom.find_visual_line_end(text_node, int(text.selection_end_),
		text.selection_end_affinity_)
	text.move_selection_end_to(uint(new_position.offset), new_position.affinity, collapse)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) increment_cursor_position_offset(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	if collapse == .yes && text.selection_start_ != text.selection_end_ {
		end := if text.selection_start_ > text.selection_end_ {
			text.selection_start_
		} else {
			text.selection_end_
		}
		text.collapse_selection_to_offset(uint(end))
	} else if position := dom.compute_cursor_position_on_next_character(text_node,
		int(text.selection_end_), text.selection_end_affinity_) {
		text.move_selection_end_to(uint(position.offset), position.affinity, collapse)
	}
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) decrement_cursor_position_offset(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	if collapse == .yes && text.selection_start_ != text.selection_end_ {
		start := if text.selection_start_ < text.selection_end_ {
			text.selection_start_
		} else {
			text.selection_end_
		}
		text.collapse_selection_to_offset(uint(start))
	} else if position := dom.compute_cursor_position_on_previous_character(text_node,
		int(text.selection_end_), text.selection_end_affinity_) {
		text.move_selection_end_to(uint(position.offset), position.affinity, collapse)
	}
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) increment_cursor_position_to_next_word(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	for {
		offset := text_node.word_segmenter().next_boundary(int(text.selection_end_)) or { break }
		units := form_string_to_utf16(text_node.data())
		word := form_utf16_to_string(units[int(text.selection_end_)..offset])
		text.move_selection_end_to(uint(offset), .downstream, collapse)
		if !dom.segmenter_should_continue_beyond_word(word) {
			break
		}
	}
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) decrement_cursor_position_to_previous_word(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	for {
		offset := text_node.word_segmenter().previous_boundary(int(text.selection_end_)) or { break }
		units := form_string_to_utf16(text_node.data())
		word := form_utf16_to_string(units[offset..int(text.selection_end_)])
		text.move_selection_end_to(uint(offset), .downstream, collapse)
		if !dom.segmenter_should_continue_beyond_word(word) {
			break
		}
	}
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) increment_cursor_position_to_next_line(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	position := dom.compute_cursor_position_on_next_line(text_node, int(text.selection_end_),
		text.selection_end_affinity_) or {
		return
	}
	text.move_selection_end_to(uint(position.offset), position.affinity, collapse)
	text.selection_was_changed(.ui)
}

pub fn (mut text FormAssociatedTextControlElement) decrement_cursor_position_to_previous_line(collapse dom.CollapseSelection) {
	text_node := text.text_node_ or { return }
	position := dom.compute_cursor_position_on_previous_line(text_node, int(text.selection_end_),
		text.selection_end_affinity_) or {
		return
	}
	text.move_selection_end_to(uint(position.offset), position.affinity, collapse)
	text.selection_was_changed(.ui)
}

pub fn (text &FormAssociatedTextControlElement) cursor_position() ?&dom.Position {
	text_node := text.text_node_ or { return none }
	if text.selection_start_ != text.selection_end_ {
		return none
	}
	return dom.Position.create(text_node.as_node(), int(text.selection_start_))
}

pub fn (text &FormAssociatedTextControlElement) as_cell() &dom.Element {
	return text.control.element
}

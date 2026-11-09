// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLTextAreaElement.{h,cpp}, HTMLButtonElement.{h,cpp}, and
// the DOM-observable portion of HTMLFormElement.{h,cpp}. Navigation is exposed
// as a host submission hook after the spec request has been constructed.
module html

import dom

fn form_control_selected_text_callback(element &dom.Element) ?string {
	if !element.is_html_element() {
		return none
	}
	if element.local_name() == 'input' {
		input := unsafe { &dom.HTMLInputElement(element) }
		model := HTMLInputElementModel.create(input)
		if !model.selection_or_range_applies() {
			return none
		}
		return model.selected_text_for_stringifier()
	}
	if element.local_name() == 'textarea' {
		textarea := unsafe { &dom.HTMLTextAreaElement(element) }
		return html_text_area_element_model_for_dom_element(textarea).text.selected_text_for_stringifier()
	}
	return none
}

fn form_control_input_events_target_callback(node &dom.Node) ?&dom.InputEventsTarget {
	mut candidate := unsafe { node }
	if shadow_root := node.root().as_shadow_root() {
		if host := shadow_root.host() {
			candidate = host.as_node()
		}
	}
	element := candidate.as_element() or { return none }
	if !element.is_html_element() {
		return none
	}
	if element.local_name() == 'input' {
		input := unsafe { &dom.HTMLInputElement(element) }
		model := HTMLInputElementModel.create(input)
		if !model.selection_or_range_applies() {
			return none
		}
		return unsafe { &dom.InputEventsTarget(model.text_control) }
	}
	if element.local_name() == 'textarea' {
		textarea := unsafe { &dom.HTMLTextAreaElement(element) }
		model := html_text_area_element_model_for_dom_element(textarea)
		return unsafe { &dom.InputEventsTarget(model.text) }
	}
	return none
}

fn install_form_control_selected_text_callback(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_form_control_selected_text_callback(form_control_selected_text_callback)
	mutable_document.set_form_control_input_events_target_callback(form_control_input_events_target_callback)
}

@[heap]
pub struct HTMLTextAreaElementModel {
pub:
	element &dom.HTMLTextAreaElement
pub mut:
	control                &FormAssociatedElement
	text                   &FormAssociatedTextControlElement
	dirty_value            bool
	// Whether the value was last changed by a user edit rather than by script.
	value_user_edited      bool
	user_validity          bool
	placeholder_element_   ?&dom.Element
	placeholder_text_node_ ?&dom.Text
	inner_text_element_    ?&dom.Element
	text_node_             ?&dom.Text
}

fn textarea_element(model &HTMLTextAreaElementModel) &dom.Element {
	return unsafe { &dom.Element(model.element) }
}

pub fn HTMLTextAreaElementModel.create(element &dom.HTMLTextAreaElement) &HTMLTextAreaElementModel {
	if element.text_area_element_model_ != unsafe { nil } {
		return unsafe { &HTMLTextAreaElementModel(element.text_area_element_model_) }
	}
	dom_element := unsafe { &dom.Element(element) }
	default_value := dom_element.as_node().child_text_content()
	control := FormAssociatedElement.create(dom_element)
	mut text := FormAssociatedTextControlElement.create(control, default_value)
	text.set_the_selection_range(u32(form_string_to_utf16(default_value).len), u32(form_string_to_utf16(default_value).len), .none, .dom)
	mut model := &HTMLTextAreaElementModel{
		element: element
		control: control
		text: text
	}
	model.text.did_edit_target_ = voidptr(model)
	model.text.did_edit_callback_ = html_text_area_element_did_edit_callback
	mut mutable_element := unsafe { &dom.HTMLTextAreaElement(element) }
	mutable_element.text_area_element_model_ = voidptr(model)
	install_form_control_selected_text_callback(dom_element.document())
	return model
}

pub fn html_text_area_element_model_for_dom_element(element &dom.HTMLTextAreaElement) &HTMLTextAreaElementModel {
	return HTMLTextAreaElementModel.create(element)
}

fn normalize_textarea_api_newlines(value string) string {
	return value.replace('\r\n', '\n').replace('\r', '\n')
}

pub fn (model &HTMLTextAreaElementModel) default_value() string {
	return textarea_element(model).as_node().child_text_content()
}

pub fn (mut model HTMLTextAreaElementModel) set_default_value(value string) {
	mut node := textarea_element(&model).as_node()
	node.string_replace_all(value)
	if !model.dirty_value {
		model.set_raw_value(value)
		model.sync_text_node_to_raw_value()
	}
}

pub fn (model &HTMLTextAreaElementModel) value() string {
	return normalize_textarea_api_newlines(model.text.relevant_value())
}

pub fn (mut model HTMLTextAreaElementModel) set_value(value string) {
	old_value := model.value()
	model.set_raw_value(value)
	model.text.dirty_value_flag = true
	model.dirty_value = true
	model.value_user_edited = false
	if model.value() != old_value {
		model.sync_text_node_to_raw_value()
		length := u32(form_string_to_utf16(model.value()).len)
		model.text.set_the_selection_range(length, length, .none, .dom)
	}
	model.update_placeholder_visibility()
	model.update_validity()
}

pub fn (model &HTMLTextAreaElementModel) text_length() u32 {
	return u32(form_string_to_utf16(model.value()).len)
}

fn limited_nonnegative_attribute(element &dom.Element, name string) i32 {
	value := element.get_attribute(name) or { return -1 }
	parsed := parse_non_negative_integer(value) or { return -1 }
	if parsed > 2147483647 {
		return -1
	}
	return i32(parsed)
}

pub fn (model &HTMLTextAreaElementModel) max_length() i32 {
	return limited_nonnegative_attribute(textarea_element(model), 'maxlength')
}

pub fn (mut model HTMLTextAreaElementModel) set_max_length(value i32) ! {
	if value < 0 {
		return error('IndexSizeError: maxLength must be non-negative')
	}
	mut element := textarea_element(&model)
	element.set_attribute_value('maxlength', value.str())
	model.update_validity()
}

pub fn (model &HTMLTextAreaElementModel) min_length() i32 {
	return limited_nonnegative_attribute(textarea_element(model), 'minlength')
}

pub fn (mut model HTMLTextAreaElementModel) set_min_length(value i32) ! {
	if value < 0 {
		return error('IndexSizeError: minLength must be non-negative')
	}
	mut element := textarea_element(&model)
	element.set_attribute_value('minlength', value.str())
	model.update_validity()
}

pub fn (model &HTMLTextAreaElementModel) cols() u32 {
	value := limited_nonnegative_attribute(textarea_element(model), 'cols')
	return if value > 0 { u32(value) } else { u32(20) }
}

pub fn (mut model HTMLTextAreaElementModel) set_cols(value u64) {
	actual := if value == 0 || value > 2147483647 { u64(20) } else { value }
	mut element := textarea_element(&model)
	element.set_attribute_value('cols', actual.str())
}

pub fn (model &HTMLTextAreaElementModel) rows() u32 {
	value := limited_nonnegative_attribute(textarea_element(model), 'rows')
	return if value > 0 { u32(value) } else { u32(2) }
}

pub fn (mut model HTMLTextAreaElementModel) set_rows(value u64) {
	actual := if value == 0 || value > 2147483647 { u64(2) } else { value }
	mut element := textarea_element(&model)
	element.set_attribute_value('rows', actual.str())
}

pub fn (model &HTMLTextAreaElementModel) placeholder_value() ?string {
	text_node := model.text_node_ or { return none }
	if text_node.data() != '' {
		return none
	}
	return textarea_element(model).get_attribute('placeholder')
}

pub fn (model &HTMLTextAreaElementModel) placeholder_visible() bool {
	return model.value() == '' && model.placeholder_value() or { '' } != ''
}

pub fn (mut model HTMLTextAreaElementModel) update_validity() {
	length := i32(model.text_length())
	model.control.missing_ = model.suffering_from_being_missing()
	max_length := model.max_length()
	min_length := model.min_length()
	user_edited := model.dirty_value && model.value_user_edited
	model.control.too_long_ = user_edited && max_length >= 0 && length > max_length
	model.control.too_short_ = user_edited && model.value() != '' && min_length >= 0 && length < min_length
}

pub fn (mut model HTMLTextAreaElementModel) reset() {
	model.reset_algorithm()
}

pub fn (mut model HTMLTextAreaElementModel) clear() {
	model.clear_algorithm()
}

pub enum HTMLButtonTypeState {
	submit
	reset
	button
	auto
}

fn button_element(button &dom.HTMLButtonElement) &dom.Element {
	return unsafe { &dom.Element(button) }
}

pub fn html_button_element_type_state(button &dom.HTMLButtonElement) HTMLButtonTypeState {
	return match ascii_lowercase_string(button_element(button).get_attribute_value('type')) {
		'submit' { .submit }
		'reset' { .reset }
		'button' { .button }
		'auto' { .auto }
		else { .auto }
	}
}

pub fn html_button_element_is_submit_button(button &dom.HTMLButtonElement) bool {
	state := html_button_element_type_state(button)
	if state == .submit {
		return true
	}
	element := button_element(button)
	return state == .auto && !element.has_attribute('command') && !element.has_attribute('commandfor')
}

pub fn html_button_element_type(button &dom.HTMLButtonElement) string {
	if html_button_element_is_submit_button(button) {
		return 'submit'
	}
	return match html_button_element_type_state(button) {
		.reset { 'reset' }
		else { 'button' }
	}
}

pub fn html_button_element_type_for_bindings(button &dom.HTMLButtonElement) string {
	return html_button_element_type(button)
}

pub fn set_html_button_element_type(button &dom.HTMLButtonElement, value string) {
	mut element := button_element(button)
	element.set_attribute_value('type', value)
}

pub fn set_html_button_element_type_for_bindings(button &dom.HTMLButtonElement, value string) {
	set_html_button_element_type(button, value)
}

pub fn html_button_element_value(button &dom.HTMLButtonElement) string {
	return button_element(button).get_attribute_value('value')
}

pub fn html_button_element_optional_value(button &dom.HTMLButtonElement) ?string {
	return button_element(button).get_attribute('value')
}

pub fn html_button_element_command(button &dom.HTMLButtonElement) string {
	command := button_element(button).get_attribute('command') or { return '' }
	if command.starts_with('--') {
		return command
	}
	lower := ascii_lowercase_string(command)
	return if lower in ['toggle-popover', 'show-popover', 'hide-popover', 'close', 'request-close',
		'show-modal'] {
		lower
	} else {
		''
	}
}

pub fn set_html_button_element_command(button &dom.HTMLButtonElement, value string) {
	mut element := button_element(button)
	element.set_attribute_value('command', value)
}

@[heap]
pub struct HTMLButtonElementModel {
pub:
	element &dom.HTMLButtonElement
	control &FormAssociatedElement
pub mut:
	command_for_element_ ?&dom.Element
}

pub fn HTMLButtonElementModel.create(element &dom.HTMLButtonElement) &HTMLButtonElementModel {
	if element.button_element_model_ != unsafe { nil } {
		return unsafe { &HTMLButtonElementModel(element.button_element_model_) }
	}
	mut control := FormAssociatedElement.create(button_element(element))
	control.reset_form_owner()
	model := &HTMLButtonElementModel{
		element: element
		control: control
	}
	mut mutable_element := unsafe { &dom.HTMLButtonElement(element) }
	mutable_element.button_element_model_ = voidptr(model)
	if form := control.form() {
		if form_model := html_form_element_model_for(form) {
			mut mutable_form_model := unsafe { &HTMLFormElementModel(form_model) }
			mutable_form_model.add_control(mut control)
		}
	}
	return model
}

pub fn (model &HTMLButtonElementModel) type_for_bindings() string {
	return html_button_element_type_for_bindings(model.element)
}

pub fn (mut model HTMLButtonElementModel) form_associated_element_attribute_changed(name string, _ ?string, _ ?string, namespace_ ?string) {
	mut attributes := PopoverTargetAttributes.create(button_element(model.element))
	attributes.associated_attribute_changed(name, namespace_)
}

pub fn (model &HTMLButtonElementModel) default_tab_index_value() i32 {
	return 0
}

pub fn (model &HTMLButtonElementModel) has_activation_behavior() bool {
	return true
}

fn (mut model HTMLButtonElementModel) command_for_element() ?&dom.Element {
	if target := model.command_for_element_ {
		return target
	}
	if target := model.element.command_for_element_ {
		model.command_for_element_ = target
		return target
	}
	target_id := button_element(model.element).get_attribute('commandfor') or { return none }
	target := find_html_element_by_id(button_element(model.element).as_node().root(), target_id) or {
		return none
	}
	element := unsafe { &dom.Element(target) }
	model.command_for_element_ = element
	return element
}

pub fn (mut model HTMLButtonElementModel) activation_behavior(event &dom.Event) {
	if !model.control.enabled() || !button_element(model.element).document().is_fully_active() {
		return
	}
	if form := model.control.form() {
		mut mutable_form_model := HTMLFormElementModel.create(form)
		if html_button_element_is_submit_button(model.element) {
			mutable_form_model.submit_form(model.control, SubmitFormOptions{
				user_involvement: user_navigation_involvement(event)
			}) or {}
			return
		}
		if html_button_element_type_state(model.element) == .reset {
			mutable_form_model.reset_form()
			return
		}
		if html_button_element_type_state(model.element) == .auto {
			return
		}
	}
	target_element := model.command_for_element() or {
		PopoverTargetAttributes.popover_target_activation_behaviour(button_element(model.element).as_node(), button_element(model.element).as_node())
		return
	}
	if !target_element.is_html_element() {
		return
	}
	command := html_button_element_command(model.element)
	if command == '' {
		return
	}
	target := unsafe { &dom.HTMLElement(target_element) }
	is_popover := html_element_popover(target) != none
	is_custom := command.starts_with('--')
	if !is_popover && !is_custom {
		if target_element.local_name() != 'dialog' || !html_dialog_element_is_valid_command(command) {
			return
		}
	}
	command_event := dom.CommandEvent.create('command', dom.CommandEventInit{
		cancelable: true
		command: command
		source: button_element(model.element)
	})
	base_event := unsafe { &dom.Event(command_event) }
	if !unsafe { &dom.EventTarget(target_element.as_node()) }.dispatch_event(base_event) {
		return
	}
	if !target_element.as_node().is_connected() || is_custom {
		return
	}
	match command {
		'hide-popover' {
			if html_element_check_popover_validity(target, .yes, .no, none, .no) or { false } {
				html_element_hide_popover(target, .yes, .yes, .no, .no, unsafe {
					&dom.HTMLElement(button_element(model.element))
				}) or {}
			}
		}
		'toggle-popover' {
			if html_element_check_popover_validity(target, .no, .no, none, .no) or { false } {
				html_element_show_popover(target, .no, unsafe {
					&dom.HTMLElement(button_element(model.element))
				}) or {}
			} else if html_element_check_popover_validity(target, .yes, .no, none, .no) or {
				false} {
				html_element_hide_popover(target, .yes, .yes, .no, .no, unsafe {
					&dom.HTMLElement(button_element(model.element))
				}) or {}
			}
		}
		'show-popover' {
			if html_element_check_popover_validity(target, .no, .no, none, .no) or { false } {
				html_element_show_popover(target, .no, unsafe {
					&dom.HTMLElement(button_element(model.element))
				}) or {}
			}
		}
		else {
			if target_element.local_name() == 'dialog' {
				mut dialog := unsafe { &dom.HTMLDialogElement(target_element) }
				run_html_dialog_element_command(mut dialog, command, button_element(model.element)) or {}
			}
		}
	}
}

// HTMLButtonElement::is_focusable(), which DOM's Element::is_focusable() dispatch translates.
pub fn (model &HTMLButtonElementModel) is_focusable() bool {
	return button_element(model.element).is_focusable()
}

pub enum FormMethodState {
	get
	post
	dialog
}

pub enum FormEncodingType {
	url_encoded
	multipart
	plain_text
}

pub struct FormSubmission {
pub:
	url              dom.URL
	method           FormMethodState
	encoding         FormEncodingType
	entries          []FormDataEntry
	body             []u8
	content_type     string
	referrer_policy  string
	user_involvement UserNavigationInvolvement
}

pub type FormSubmissionHook = fn(FormSubmission) !

@[heap]
pub struct HTMLFormElementModel {
pub:
	element &dom.HTMLFormElement
mut:
	controls_                 []&FormAssociatedElement
	event_target_             &dom.EventTarget = unsafe { nil }
	submission_hook_          ?FormSubmissionHook
	elements_                 ?&HTMLFormControlsCollection
	rel_list_                 ?&dom.DOMTokenList
	past_names_map_           map[string]&dom.Element
	past_names_age_           map[string]u64
	next_past_name_age_       u64
	constructing_entry_list_  bool
	firing_submission_events_ bool
	locked_for_reset_         bool
	last_submission_          ?FormSubmission
}

__global html_form_element_models []&HTMLFormElementModel

pub fn HTMLFormElementModel.create(element &dom.HTMLFormElement) &HTMLFormElementModel {
	if existing := html_form_element_model_for(element) {
		return existing
	}
	model := &HTMLFormElementModel{
		element: element
		event_target_: unsafe { &dom.EventTarget(element) }
	}
	html_form_element_models << model
	return model
}

pub fn (form &HTMLFormElementModel) constructing_entry_list() bool {
	return form.constructing_entry_list_
}

pub fn (mut form HTMLFormElementModel) set_constructing_entry_list(value bool) {
	form.constructing_entry_list_ = value
}

fn html_form_element_model_for(element &dom.HTMLFormElement) ?&HTMLFormElementModel {
	for model in html_form_element_models {
		if voidptr(model.element) == voidptr(element) {
			return model
		}
	}
	return none
}

fn form_model_element(form &HTMLFormElementModel) &dom.Element {
	return unsafe { &dom.Element(form.element) }
}

pub fn (mut form HTMLFormElementModel) add_control(mut control FormAssociatedElement) {
	control.set_form(form.element)
	if control !in form.controls_ {
		form.controls_ << control
	}
}

pub fn (mut form HTMLFormElementModel) remove_control(control &FormAssociatedElement) {
	form.controls_ = form.controls_.filter(it != control)
	mut mutable_control := unsafe { &FormAssociatedElement(control) }
	mutable_control.set_form(none)
}

pub fn (form &HTMLFormElementModel) controls() []&FormAssociatedElement {
	return form.controls_.clone()
}

pub fn (form &HTMLFormElementModel) length() u32 {
	mut count := 0
	for control in form.controls_ {
		if control.is_listed() && !(control.element.local_name() == 'input' && form_element_input_type(control.element) == 'image') {
			count++
		}
	}
	return u32(count)
}

pub fn (mut form HTMLFormElementModel) set_submission_hook(hook ?FormSubmissionHook) {
	form.submission_hook_ = hook
}

pub fn (form &HTMLFormElementModel) has_submission_hook() bool {
	return form.submission_hook_ != none
}

pub fn (form &HTMLFormElementModel) method_state(submitter ?&FormAssociatedElement) FormMethodState {
	element := if control := submitter { control.element } else { form_model_element(form) }
	value := if control := submitter {
		if control.is_submit_button() && element.has_attribute('formmethod') {
			element.get_attribute_value('formmethod')
		} else {
			form_model_element(form).get_attribute_value('method')
		}
	} else {
		form_model_element(form).get_attribute_value('method')
	}
	return match ascii_lowercase_string(value) {
		'post' { .post }
		'dialog' { .dialog }
		else { .get }
	}
}

pub fn (form &HTMLFormElementModel) encoding_type(submitter ?&FormAssociatedElement) FormEncodingType {
	mut value := form_model_element(form).get_attribute_value('enctype')
	if control := submitter {
		if control.is_submit_button() && control.element.has_attribute('formenctype') {
			value = control.element.get_attribute_value('formenctype')
		}
	}
	return match ascii_lowercase_string(value) {
		'multipart/form-data' { .multipart }
		'text/plain' { .plain_text }
		else { .url_encoded }
	}
}

fn (form &HTMLFormElementModel) parsed_action_from_form_element(submitter ?&FormAssociatedElement) dom.URL {
	mut value := form_model_element(form).get_attribute_value('action')
	if control := submitter {
		if control.is_submit_button() && control.element.has_attribute('formaction') {
			value = control.element.get_attribute_value('formaction')
		}
	}
	if value == '' {
		return dom.URL{
			value: form_model_element(form).document().url_string()
		}
	}
	return dom.dom_url_parse(value, form_model_element(form).document().base_url(), 'UTF-8') or {
		dom.URL{
			value: form_model_element(form).document().url_string()
		}
	}
}

fn form_url_encode_component(value string) string {
	mut output := ''
	for byte in value.bytes() {
		if (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`) || (byte >= `0` && byte <= `9`) || byte in [
			`-`,
			`_`,
			`.`,
			`*`,
		] {
			output += byte.ascii_str()
		} else if byte == ` ` {
			output += '+'
		} else {
			output += '%${byte.hex().to_upper()}'
		}
	}
	return output
}

pub fn (form &HTMLFormElementModel) construct_entry_list(submitter ?&FormAssociatedElement) []FormDataEntry {
	// Compatibility for callers expecting an array. Source-aware callers use
	// the nullable operation below so recursive construction remains observable.
	return form.construct_entry_list_with_encoding(submitter, none) or { []FormDataEntry{} }
}

pub fn (form &HTMLFormElementModel) check_validity() bool {
	return form.statically_validate_constraints().result
}

pub fn (mut form HTMLFormElementModel) reset() {
	if form.locked_for_reset_ {
		return
	}
	form.locked_for_reset_ = true
	form.reset_form()
	form.locked_for_reset_ = false
}

pub fn (mut form HTMLFormElementModel) reset_form() {
	event := dom.Event.create('reset', dom.EventInit{ bubbles: true, cancelable: true })
	if form.event_target_.dispatch_event(event) {
		// Reset algorithms can mutate form ownership. The upstream loop holds
		// a copy so every member present after the reset event is visited once.
		associated_elements := form.element.associated_elements_.clone()
		for element in associated_elements {
			if element.local_name() !in ['input', 'output', 'select', 'textarea']
				&& !element.is_form_associated_custom_element() {
				continue
			}
			value := reset_form_associated_dom_element(element)
			// Older API callers may retain a separately created base record.
			// Keep that record's value synchronized with its concrete model.
			for control in form.controls_ {
				if voidptr(control.element) == voidptr(element) {
					if reset_value := value {
						mut mutable_control := unsafe { &FormAssociatedElement(control) }
						mutable_control.value_ = reset_value
					}
				}
			}
		}
	}
}

pub fn (mut form HTMLFormElementModel) submit_form(submitter ?&FormAssociatedElement, options SubmitFormOptions) ! {
	element := form_model_element(&form)
	if element.cannot_navigate() || form.constructing_entry_list_ {
		return
	}
	if element.document().active_sandboxing_flag_set().sandboxed_forms {
		return
	}
	if !options.from_submit_binding {
		if form.firing_submission_events_ {
			return
		}
		form.firing_submission_events_ = true
		for control in form.get_submittable_elements() {
			mut mutable_control := unsafe { &FormAssociatedElement(control) }
			mutable_control.user_validity_ = true
		}
		should_validate := if control := submitter { !control.novalidate_state() } else { true }
		if should_validate && !form.interactively_validate_constraints() {
			form.firing_submission_events_ = false
			return
		}
		// HTMLFormElement::submit_form(), steps 5 and 6: the form itself
		// has no submitter button; requestSubmit(button) retains that button.
		submitter_button := if control := submitter {
			?&dom.HTMLElement(unsafe { &dom.HTMLElement(control.element) })
		} else {
			?&dom.HTMLElement(none)
		}
		event := dom.SubmitEvent.create('submit', dom.SubmitEventInit{
			submitter: submitter_button
			bubbles: true
			cancelable: true
		})
		continue_ := form.event_target_.dispatch_event(&event.Event)
		form.firing_submission_events_ = false
		if !continue_ || element.cannot_navigate() {
			return
		}
	}
	encoding_name := form.pick_an_encoding()
	entries := form.construct_entry_list_with_encoding(submitter, encoding_name) or { return }
	if element.cannot_navigate() {
		return
	}
	method := form.method_state_from_form_element(submitter)
	if method == .dialog {
		if dialog_element := form_element_nearest_ancestor(element, 'dialog') {
			mut dialog := unsafe { &dom.HTMLDialogElement(dialog_element) }
			result := if control := submitter {
				if control.is_submit_button() { control.value() } else { '' }
			} else {
				''
			}
			if control := submitter {
				close_html_dialog_element(mut dialog, result, control.element)
			} else {
				close_html_dialog_element(mut dialog, result, none)
			}
		}
		return
	}
	mut action := form.action_from_form_element(submitter)
	if action == '' {
		action = element.document().url_string()
	}
	parsed_action := element.document().encoding_parse_url(action) or { return }
	encoding_type := form.encoding_type_state_from_form_element(submitter)
	scheme := parsed_action.scheme()
	if scheme in ['http', 'https'] {
		if method == .get {
			form.mutate_action_url(parsed_action, entries, encoding_name, options.user_involvement)!
		} else {
			form.submit_as_entity_body(parsed_action, entries, encoding_type, encoding_name, options.user_involvement)!
		}
	} else if scheme in ['ftp', 'javascript'] {
		form.get_action_url(parsed_action, entries, options.user_involvement)!
	} else if scheme in ['data', 'file'] {
		if method == .get {
			form.mutate_action_url(parsed_action, entries, encoding_name, options.user_involvement)!
		} else {
			form.get_action_url(parsed_action, entries, options.user_involvement)!
		}
	} else if scheme == 'mailto' {
		if method == .get {
			form.mail_with_headers(parsed_action, entries, encoding_name, options.user_involvement)!
		} else {
			form.mail_as_body(parsed_action, entries, encoding_type, encoding_name, options.user_involvement)!
		}
	}
}

pub fn (form &HTMLFormElementModel) last_submission() ?FormSubmission {
	return form.last_submission_
}

pub fn (form &HTMLFormElementModel) event_target() &dom.EventTarget {
	return form.event_target_
}

// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLTextAreaElement.{h,cpp}, HTMLButtonElement.{h,cpp}, and
// the DOM-observable portion of HTMLFormElement.{h,cpp}. Navigation is exposed
// as a host submission hook after the spec request has been constructed.
module html

import dom

@[heap]
pub struct HTMLTextAreaElementModel {
pub:
	element &dom.HTMLTextAreaElement
pub mut:
	control       &FormAssociatedElement
	text          &FormAssociatedTextControlElement
	dirty_value   bool
	user_validity bool
}

fn textarea_element(model &HTMLTextAreaElementModel) &dom.Element {
	return unsafe { &dom.Element(model.element) }
}

pub fn HTMLTextAreaElementModel.create(element &dom.HTMLTextAreaElement) &HTMLTextAreaElementModel {
	dom_element := unsafe { &dom.Element(element) }
	default_value := dom_element.as_node().child_text_content()
	control := FormAssociatedElement.create(dom_element)
	mut text := FormAssociatedTextControlElement.create(control, default_value)
	text.set_the_selection_range(u32(form_string_to_utf16(default_value).len),
		u32(form_string_to_utf16(default_value).len), .none, .dom)
	return &HTMLTextAreaElementModel{
		element: element
		control: control
		text:    text
	}
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
		model.text.set_relevant_value(normalize_textarea_api_newlines(value))
	}
}

pub fn (model &HTMLTextAreaElementModel) value() string {
	return normalize_textarea_api_newlines(model.text.relevant_value())
}

pub fn (mut model HTMLTextAreaElementModel) set_value(value string) {
	old_value := model.value()
	normalized := normalize_textarea_api_newlines(value)
	model.text.set_relevant_value(normalized)
	model.text.dirty_value_flag = true
	model.dirty_value = true
	if normalized != old_value {
		length := u32(form_string_to_utf16(normalized).len)
		model.text.set_the_selection_range(length, length, .none, .dom)
	}
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
	value := textarea_element(model).get_attribute('placeholder') or { return none }
	return value.replace('\r\n', '\n').replace('\r', '\n').split('\n')[0]
}

pub fn (model &HTMLTextAreaElementModel) placeholder_visible() bool {
	return model.value() == '' && model.placeholder_value() or { '' } != ''
}

pub fn (mut model HTMLTextAreaElementModel) update_validity() {
	length := i32(model.text_length())
	model.control.missing_ = textarea_element(&model).has_attribute('required')
		&& model.value() == ''
	max_length := model.max_length()
	min_length := model.min_length()
	model.control.too_long_ = model.dirty_value && max_length >= 0 && length > max_length
	model.control.too_short_ = model.dirty_value && model.value() != '' && min_length >= 0
		&& length < min_length
}

pub fn (mut model HTMLTextAreaElementModel) reset() {
	model.dirty_value = false
	model.text.dirty_value_flag = false
	model.text.set_relevant_value(normalize_textarea_api_newlines(model.default_value()))
	model.user_validity = false
	model.update_validity()
}

pub fn (mut model HTMLTextAreaElementModel) clear() {
	model.dirty_value = false
	model.text.dirty_value_flag = false
	model.text.set_relevant_value('')
	model.update_validity()
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
	return state == .auto && !element.has_attribute('command')
		&& !element.has_attribute('commandfor')
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

pub fn set_html_button_element_type(button &dom.HTMLButtonElement, value string) {
	mut element := button_element(button)
	element.set_attribute_value('type', value)
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
	url          dom.URL
	method       FormMethodState
	encoding     FormEncodingType
	entries      []FormDataEntry
	body         []u8
	content_type string
}

pub type FormSubmissionHook = fn (FormSubmission) !

@[heap]
pub struct HTMLFormElementModel {
pub:
	element &dom.HTMLFormElement
mut:
	controls_                 []&FormAssociatedElement
	event_target_             &dom.EventTarget = unsafe { nil }
	submission_hook_          ?FormSubmissionHook
	constructing_entry_list_  bool
	firing_submission_events_ bool
	locked_for_reset_         bool
	last_submission_          ?FormSubmission
}

pub fn HTMLFormElementModel.create(element &dom.HTMLFormElement) &HTMLFormElementModel {
	return &HTMLFormElementModel{
		element:       element
		event_target_: dom.EventTarget.new()
	}
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
		if control.is_listed() && !(control.element.local_name() == 'input'
			&& form_element_input_type(control.element) == 'image') {
			count++
		}
	}
	return u32(count)
}

pub fn (mut form HTMLFormElementModel) set_submission_hook(hook ?FormSubmissionHook) {
	form.submission_hook_ = hook
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

pub fn (form &HTMLFormElementModel) action(submitter ?&FormAssociatedElement) dom.URL {
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
		if (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
			|| (byte >= `0` && byte <= `9`) || byte in [`-`, `_`, `.`, `*`] {
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
	mut entries := []FormDataEntry{}
	for control in form.controls_ {
		if !control.enabled() || !control.is_submittable()
			|| control.element.get_attribute_value('name') == '' {
			continue
		}
		if control.is_button() && (submitter == none || submitter or { continue } != control) {
			continue
		}
		entries << create_form_data_string_entry(control.element.get_attribute_value('name'),
			control.value())
	}
	return entries
}

pub fn (form &HTMLFormElementModel) check_validity() bool {
	mut valid := true
	for control in form.controls_ {
		if !control.check_validity() {
			valid = false
		}
	}
	return valid
}

pub fn (mut form HTMLFormElementModel) reset() {
	if form.locked_for_reset_ {
		return
	}
	form.locked_for_reset_ = true
	event := dom.Event.create('reset', dom.EventInit{ bubbles: true, cancelable: true })
	if form.event_target_.dispatch_event(event) {
		for control in form.controls_ {
			if control.is_resettable() {
				mut mutable_control := unsafe { &FormAssociatedElement(control) }
				mutable_control.reset_algorithm()
			}
		}
	}
	form.locked_for_reset_ = false
}

pub fn (mut form HTMLFormElementModel) submit(submitter ?&FormAssociatedElement, from_submit_binding bool) ! {
	if form.firing_submission_events_ {
		return
	}
	if !from_submit_binding {
		if !form.check_validity() {
			return error('InvalidStateError: form constraints are not satisfied')
		}
		form.firing_submission_events_ = true
		event := dom.Event.create('submit', dom.EventInit{ bubbles: true, cancelable: true })
		continue_ := form.event_target_.dispatch_event(event)
		form.firing_submission_events_ = false
		if !continue_ {
			return
		}
	}
	entries := form.construct_entry_list(submitter)
	method := form.method_state(submitter)
	encoding := form.encoding_type(submitter)
	mut url := form.action(submitter)
	mut body := []u8{}
	mut content_type := ''
	if method == .get {
		mut fields := []string{}
		for entry in entries {
			if entry.value is string {
				fields << '${form_url_encode_component(entry.name)}=${form_url_encode_component(entry.value as string)}'
			}
		}
		separator := if url.serialize().contains('?') { '&' } else { '?' }
		url = dom.URL{
			value: '${url.serialize()}${if fields.len > 0 {
				separator + fields.join('&')
			} else {
				''
			}}'
		}
	} else if method == .post {
		match encoding {
			.multipart {
				serialized := serialize_to_multipart_form_data(entries)
				body = serialized.serialized_data.clone()
				content_type = 'multipart/form-data; boundary=${serialized.boundary}'
			}
			.plain_text {
				mut lines := []string{}
				for entry in entries {
					if entry.value is string {
						lines << '${entry.name}=${entry.value as string}'
					}
				}
				body = '${lines.join('\r\n')}\r\n'.bytes()
				content_type = 'text/plain'
			}
			.url_encoded {
				mut fields := []string{}
				for entry in entries {
					if entry.value is string {
						fields << '${form_url_encode_component(entry.name)}=${form_url_encode_component(entry.value as string)}'
					}
				}
				body = fields.join('&').bytes()
				content_type = 'application/x-www-form-urlencoded'
			}
		}
	}
	submission := FormSubmission{
		url:          url
		method:       method
		encoding:     encoding
		entries:      entries
		body:         body
		content_type: content_type
	}
	form.last_submission_ = submission
	if hook := form.submission_hook_ {
		hook(submission)!
	}
}

pub fn (form &HTMLFormElementModel) last_submission() ?FormSubmission {
	return form.last_submission_
}

pub fn (form &HTMLFormElementModel) event_target() &dom.EventTarget {
	return form.event_target_
}

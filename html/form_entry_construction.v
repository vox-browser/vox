// Copyright (c) 2023-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// HTML/FormControlInfrastructure.cpp: construct_face_entry/construct_entry_list.
module html

import dom
import fileapi

fn form_entry_is_submitter(control &FormAssociatedElement, submitter ?&FormAssociatedElement) bool {
	if button := submitter {
		return voidptr(control.element) == voidptr(button.element)
	}
	return false
}

fn form_entry_control_value(control &FormAssociatedElement) string {
	element := control.element
	match element.local_name() {
		'input' {
			input := unsafe { &dom.HTMLInputElement(element) }
			if input.input_element_model_ != unsafe { nil } {
				return unsafe { &HTMLInputElementModel(input.input_element_model_) }.value()
			}
		}
		'textarea' {
			return HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) }).value()
		}
		'button' {
			// Older typed callers retain a separate base record. Its value is
			// used only until the actual button model has been materialized.
			button := unsafe { &dom.HTMLButtonElement(element) }
			if button.button_element_model_ != unsafe { nil } {
				return html_button_element_value(button)
			}
		}
		else {}
	}
	return control.value()
}

fn construct_form_associated_custom_entry(element &dom.Element, mut entries []FormDataEntry) {
	target := unsafe { &dom.HTMLElement(element) }
	if target.attached_internals_handle() == unsafe { nil } {
		return
	}
	internals := unsafe { &ElementInternals(target.attached_internals_handle()) }
	value := internals.submission_value or { return }
	if value is ElementInternalsFormData {
		entries << value.entries
		return
	}
	name := element.get_attribute_value('name')
	if name == '' {
		return
	}
	match value {
		string { entries << create_form_data_string_entry(name, value) }
		FormDataFile { entries << create_form_data_file_entry(name, value, none) }
		ElementInternalsFormData {}
	}
}

pub fn (form &HTMLFormElementModel) construct_entry_list_with_encoding(submitter ?&FormAssociatedElement, encoding ?string) ?[]FormDataEntry {
	mut mutable_form := unsafe { &HTMLFormElementModel(form) }
	if mutable_form.constructing_entry_list_ {
		return none
	}
	mutable_form.constructing_entry_list_ = true
	controls := form.get_submittable_elements()
	mut entries := []FormDataEntry{}
	for control in controls {
		element := control.element
		if form_element_nearest_ancestor(element, 'datalist') != none
			|| element.is_actually_disabled() || (control.is_button()
			&& !form_entry_is_submitter(control, submitter)) {
			continue
		}
		state := if element.local_name() == 'input' {
			parse_html_input_type(element.get_attribute_value('type'))
		} else {
			HTMLInputTypeState.text
		}
		is_input := element.local_name() == 'input'
		if is_input && state in [.checkbox, .radio_button]
			&& !unsafe { &dom.HTMLInputElement(element) }.checked() {
			continue
		}
		if is_input && state == .image_button {
			if !form_entry_is_submitter(control, submitter) {
				continue
			}
			name := element.get_attribute_value('name')
			prefix := if name == '' { '' } else { '${name}.' }
			input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			coordinate := input.selected_coordinate()
			entries << create_form_data_string_entry('${prefix}x', coordinate.x.str())
			entries << create_form_data_string_entry('${prefix}y', coordinate.y.str())
			continue
		}
		if element.is_form_associated_custom_element() {
			construct_form_associated_custom_entry(element, mut entries)
			continue
		}
		name := element.get_attribute_value('name')
		if name == '' {
			continue
		}
		if element.local_name() == 'select' {
			select_ := unsafe { &dom.HTMLSelectElement(element) }
			for option in html_select_element_list_of_options(select_) {
				if html_option_element_selected(option) && !html_option_element_disabled(option) {
					entries << create_form_data_string_entry(name, html_option_element_value(option))
				}
			}
		} else if is_input && state in [.checkbox, .radio_button] {
			value := element.get_attribute_value('value')
			entries << create_form_data_string_entry(name, if value == '' { 'on' } else { value })
		} else if is_input && state == .file_upload {
			mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			files := input.file_list() or { panic('file input must expose a FileList') }
			if files.length() == 0 {
				file := fileapi.File.construct([], '', fileapi.FilePropertyBag{
					type_: 'application/octet-stream'
				})
				entries << create_form_data_native_file_entry(name, file)
			} else {
				for file in files.files() {
					entries << create_form_data_native_file_entry(name, file)
				}
			}
		} else if is_input && state == .hidden && ascii_lowercase_string(name) == '_charset_' {
			entries << create_form_data_string_entry(name, encoding or { 'UTF-8' })
		} else {
			entries << create_form_data_string_entry(name, form_entry_control_value(control))
		}
		dirname := element.get_attribute_value('dirname')
		if dirname != '' && element.is_auto_directionality_form_associated_element() {
			entries << create_form_data_string_entry(dirname,
				if element.directionality() == .ltr { 'ltr' } else { 'rtl' })
		}
	}
	data := FormData.create(entries)
	mut event := FormDataEvent.construct_impl('formdata', FormDataEventInit{
		form_data: data
		bubbles:   true
	}) or { panic(err) }
	event.set_is_trusted(true)
	form.event_target_.dispatch_event(unsafe { &dom.Event(event) })
	mutable_form.constructing_entry_list_ = false
	return data.entries()
}

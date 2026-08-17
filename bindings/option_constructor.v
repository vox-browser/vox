// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/OptionConstructor.{h,cpp}.
module bindings

import dom
import html
import math

@[heap]
pub struct OptionConstructor {
pub:
	document &dom.Document
}

pub fn OptionConstructor.create(document &dom.Document) &OptionConstructor {
	return &OptionConstructor{
		document: document
	}
}

pub fn (_ &OptionConstructor) metadata() ConstructorMetadata {
	return ConstructorMetadata{
		name:           'Option'
		length:         0
		prototype_name: 'HTMLOptionElement'
	}
}

pub fn (_ &OptionConstructor) call() !dom.JSValue {
	return error("TypeError: Constructor Option requires 'new'")
}

fn js_value_to_boolean(value dom.JSValue) bool {
	return match value.kind {
		.undefined, .null_ { false }
		.boolean { value.boolean_data }
		.number { value.number_data != 0 && !math.is_nan(value.number_data) }
		.string { value.string_data.len > 0 }
		.object { true }
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option
pub fn (constructor &OptionConstructor) construct(text ?dom.JSValue, value ?dom.JSValue, default_selected ?dom.JSValue, selected ?dom.JSValue) !&dom.HTMLOptionElement {
	mut element := dom.create_element(constructor.document, 'option', html_namespace, none, none,
		false)!
	option := unsafe { &dom.HTMLOptionElement(element) }

	mut text_value := dom.js_string('')
	if supplied_text := text {
		text_value = supplied_text
	}
	text_string := if text_value.is_undefined() { '' } else { text_value.to_string_value() }
	if text_string.len > 0 {
		text_node := dom.new_text_node(constructor.document, text_string)
		mut option_node := element.as_node()
		option_node.append_child(text_node.as_node())!
	}

	if option_value := value {
		if !option_value.is_undefined() {
			element.set_attribute_value('value', option_value.to_string_value())
		}
	}
	if default_value := default_selected {
		if js_value_to_boolean(default_value) {
			element.set_attribute_value('selected', '')
		}
	}
	mut selected_value := dom.js_undefined()
	if supplied_selected := selected {
		selected_value = supplied_selected
	}
	html.html_option_element_set_selected_internal(option, js_value_to_boolean(selected_value))
	return option
}

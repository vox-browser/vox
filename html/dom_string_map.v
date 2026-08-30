// Copyright (c) 2021-2023, Luke Wilde <lukew@serenityos.org>
// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/DOMStringMap.cpp.
module html

import dom

pub struct DOMStringMapNameValuePair {
pub:
	name  string
	value string
}

@[heap]
pub struct DOMStringMap {
	associated_element &dom.Element
}

pub fn DOMStringMap.create(element &dom.Element) &DOMStringMap {
	return &DOMStringMap{
		associated_element: element
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#concept-domstringmap-pairs
pub fn (string_map &DOMStringMap) get_name_value_pairs() []DOMStringMapNameValuePair {
	mut list := []DOMStringMapNameValuePair{}
	for attribute_name in string_map.associated_element.get_attribute_names() {
		if !attribute_name.starts_with('data-') {
			continue
		}
		name_after_data := attribute_name[5..]
		mut contains_ascii_upper_alpha := false
		for character in name_after_data.bytes() {
			if character >= `A` && character <= `Z` {
				contains_ascii_upper_alpha = true
				break
			}
		}
		if contains_ascii_upper_alpha {
			continue
		}
		mut name := []u8{}
		mut index := 0
		for index < name_after_data.len {
			character := name_after_data[index]
			if index + 1 < name_after_data.len && character == `-`
				&& name_after_data[index + 1] >= `a` && name_after_data[index + 1] <= `z` {
				name << name_after_data[index + 1] - 0x20
				index += 2
				continue
			}
			name << character
			index++
		}
		list << DOMStringMapNameValuePair{
			name:  name.bytestr()
			value: string_map.associated_element.get_attribute(attribute_name) or { '' }
		}
	}
	return list
}

pub fn (string_map &DOMStringMap) supported_property_names() []string {
	return string_map.get_name_value_pairs().map(it.name)
}

pub fn (string_map &DOMStringMap) determine_value_of_named_property(name string) string {
	for pair in string_map.get_name_value_pairs() {
		if pair.name == name {
			return pair.value
		}
	}
	panic('name is not a supported DOMStringMap property')
}

fn dom_string_map_attribute_name(name string, reject_hyphen_lowercase bool) !string {
	mut data_name := 'data-'.bytes()
	mut index := 0
	for index < name.len {
		character := name[index]
		if reject_hyphen_lowercase && character == `-` && index + 1 < name.len
			&& name[index + 1] >= `a` && name[index + 1] <= `z` {
			return error("Name cannot contain a '-' followed by a lowercase character.")
		}
		if character >= `A` && character <= `Z` {
			data_name << `-`
			data_name << character + 0x20
		} else {
			data_name << character
		}
		index++
	}
	result := data_name.bytestr()
	if !dom.is_valid_attribute_local_name(result) {
		return error('Name is not a valid attribute local name.')
	}
	return result
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-domstringmap-setitem
pub fn (mut string_map DOMStringMap) set_value_of_named_property(name string, value string) ! {
	data_name := dom_string_map_attribute_name(name, true)!
	mut element := string_map.associated_element
	element.set_attribute_value(data_name, value)
}

pub fn (mut string_map DOMStringMap) set_value_of_new_named_property(name string, unconverted_value dom.JSValue) ! {
	string_map.set_value_of_named_property(name, unconverted_value.to_string_value())!
}

pub fn (mut string_map DOMStringMap) set_value_of_existing_named_property(name string, value dom.JSValue) ! {
	string_map.set_value_of_new_named_property(name, value)!
}

pub fn (string_map &DOMStringMap) named_item_value(name string) dom.JSValue {
	return dom.js_string(string_map.determine_value_of_named_property(name))
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-domstringmap-removeitem
pub fn (mut string_map DOMStringMap) delete_value(name string) {
	data_name := dom_string_map_attribute_name(name, false) or { return }
	mut element := string_map.associated_element
	element.remove_attribute(data_name)
}

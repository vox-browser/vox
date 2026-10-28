// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Typed structured-clone value used by the standalone V translation.
module indexeddb

import math

pub enum ValueType {
	undefined
	null_
	boolean
	number
	date
	string_
	binary
	array
	object
	blob
	file
}

pub struct Value {
pub mut:
	kind   ValueType
	bool_  bool
	number f64
	text   string
	bytes  []u8
	items  []Value
	fields map[string]Value
	blob_size     u64
	mime_type     string
	file_name     string
	last_modified f64
}

pub fn undefined_value() Value {
	return Value{
		kind: .undefined
	}
}

pub fn null_value() Value {
	return Value{
		kind: .null_
	}
}

pub fn bool_value(value bool) Value {
	return Value{
		kind: .boolean
		bool_: value
	}
}

pub fn number_value(value f64) Value {
	return Value{
		kind: .number
		number: value
	}
}

pub fn date_value(value f64) Value {
	return Value{
		kind: .date
		number: value
	}
}

pub fn string_value(value string) Value {
	return Value{
		kind: .string_
		text: value
	}
}

pub fn binary_value(value []u8) Value {
	return Value{
		kind: .binary
		bytes: value.clone()
	}
}

pub fn array_value(value []Value) Value {
	return Value{
		kind: .array
		items: clone_values(value)
	}
}

pub fn object_value(value map[string]Value) Value {
	return Value{
		kind: .object
		fields: clone_fields(value)
	}
}

pub fn blob_value(size u64, mime_type string) Value {
	return Value{
		kind: .blob
		blob_size: size
		mime_type: mime_type
	}
}

pub fn file_value(name string, size u64, mime_type string, last_modified f64) Value {
	return Value{
		kind: .file
		blob_size: size
		mime_type: mime_type
		file_name: name
		last_modified: last_modified
	}
}

pub fn (value Value) clone() Value {
	return Value{
		kind: value.kind
		bool_: value.bool_
		number: value.number
		text: value.text
		bytes: value.bytes.clone()
		items: clone_values(value.items)
		fields: clone_fields(value.fields)
		blob_size: value.blob_size
		mime_type: value.mime_type
		file_name: value.file_name
		last_modified: value.last_modified
	}
}

fn clone_values(values []Value) []Value {
	mut working_copy := []Value{cap: values.len}
	for value in values {
		working_copy << value.clone()
	}
	return working_copy
}

fn clone_fields(fields map[string]Value) map[string]Value {
	mut working_copy := map[string]Value{}
	for name, value in fields {
		working_copy[name] = value.clone()
	}
	return working_copy
}

pub fn value_to_key(value Value) Key {
	return match value.kind {
		.number {
			if math.is_nan(value.number) {
				invalid_key()
			} else {
				number_key(value.number)
			}
		}
		.date {
			date_key(value.number)
		}
		.string_ {
			string_key(value.text)
		}
		.binary {
			binary_key(value.bytes)
		}
		.array {
			mut keys := []Key{cap: value.items.len}
			for child in value.items {
				key := value_to_key(child)
				if !key.is_valid() {
					return invalid_key()
				}
				keys << key
			}
			array_key(keys)
		}
		else {
			invalid_key()
		}
	}
}

pub fn key_to_value(key Key) !Value {
	if !key.is_valid() {
		return error('DataError: invalid IndexedDB key')
	}
	return match key.kind {
		.number {
			number_value(key.number)
		}
		.date {
			date_value(key.number)
		}
		.string_ {
			string_value(key.text)
		}
		.binary {
			binary_value(key.bytes)
		}
		.array {
			mut values := []Value{cap: key.items.len}
			for child in key.items {
				values << key_to_value(child)!
			}
			array_value(values)
		}
		.invalid {
			return error('DataError: invalid IndexedDB key')
		}
	}
}

pub type KeyPath = []string | string

pub fn is_valid_key_path(path KeyPath) bool {
	return match path {
		string { true }
		[]string { path.len > 0 }
	}
}

fn evaluate_string_key_path(value Value, path string) ?Value {
	if path == '' {
		return value.clone()
	}
	mut current := value
	for component in path.split('.') {
		if component == 'length' && current.kind == .string_ {
			current = number_value(f64(utf16_code_units(current.text).len))
			continue
		}
		if component == 'length' && current.kind == .array {
			current = number_value(f64(current.items.len))
			continue
		}
		if property := key_path_value_for_blob_or_file(current, component) {
			current = property
			continue
		}
		if current.kind != .object || component !in current.fields {
			return none
		}
		current = current.fields[component]
	}
	return current.clone()
}

// https://w3c.github.io/IndexedDB/#evaluate-a-key-path-on-a-value
pub fn evaluate_key_path(value Value, path KeyPath) ?Key {
	match path {
		string {
			found := evaluate_string_key_path(value, path) or { return none }
			key := value_to_key(found)
			if key.is_valid() {
				return key
			}
		}
		[]string {
			mut keys := []Key{cap: path.len}
			for component in path {
				found := evaluate_string_key_path(value, component) or { return none }
				key := value_to_key(found)
				if !key.is_valid() {
					return none
				}
				keys << key
			}
			return array_key(keys)
		}
	}
	return none
}

// Injects a generated key into an object at a dotted key path. Intermediate
// objects are created, as required by the IndexedDB injection algorithm.
pub fn inject_key(value Value, path string, key Key) !Value {
	if path == '' || value.kind != .object {
		return error('DataError: key path cannot be populated')
	}
	components := path.split('.')
	return inject_key_components(value, components, key_to_value(key)!)
}

fn inject_key_components(value Value, components []string, key_value Value) !Value {
	mut result := value.clone()
	if result.kind != .object || components.len == 0 || components[0] == '' {
		return error('DataError: key path cannot be populated')
	}
	if components.len == 1 {
		result.fields[components[0]] = key_value
		return result
	}
	mut child := if components[0] in result.fields {
		result.fields[components[0]].clone()
	} else {
		object_value(map[string]Value{})
	}
	if child.kind != .object {
		return error('DataError: key path cannot be populated')
	}
	child = inject_key_components(child, components[1..], key_value)!
	result.fields[components[0]] = child
	return result
}

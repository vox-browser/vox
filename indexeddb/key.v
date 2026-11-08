// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IndexedDB/Internal/Key.{h,cpp} and the key conversion
// portions of Internal/Algorithms.{h,cpp}.
module indexeddb

import libjs

import math

pub enum KeyType {
	invalid
	number
	date
	string_
	binary
	array
}

// Key uses separate fields rather than a recursive sum type.  This mirrors the
// tagged KeyValue variant upstream while remaining straightforward to clone.
pub struct Key {
pub:
	kind   KeyType
	number f64
	text   string
	bytes  []u8
	items  []Key
}

pub fn invalid_key() Key {
	return Key{
		kind: .invalid
	}
}

pub fn number_key(value f64) Key {
	if math.is_nan(value) {
		return invalid_key()
	}
	return Key{
		kind: .number
		number: value
	}
}

pub fn date_key(milliseconds f64) Key {
	if math.is_nan(milliseconds) || math.is_inf(milliseconds, 0) {
		return invalid_key()
	}
	return Key{
		kind: .date
		number: milliseconds
	}
}

pub fn string_key(value string) Key {
	return Key{
		kind: .string_
		text: value
	}
}

pub fn binary_key(value []u8) Key {
	return Key{
		kind: .binary
		bytes: value.clone()
	}
}

pub fn array_key(value []Key) Key {
	mut working_copy := []Key{cap: value.len}
	for key in value {
		if !key.is_valid() {
			return invalid_key()
		}
		working_copy << key.clone()
	}
	return Key{
		kind: .array
		items: working_copy
	}
}

pub fn (key Key) is_valid() bool {
	return key.kind != .invalid
}

pub fn (key Key) clone() Key {
	mut items := []Key{cap: key.items.len}
	for child in key.items {
		items << child.clone()
	}
	return Key{
		kind: key.kind
		number: key.number
		text: key.text
		bytes: key.bytes.clone()
		items: items
	}
}

fn key_type_order(kind KeyType) int {
	return match kind {
		.number { 0 }
		.date { 1 }
		.string_ { 2 }
		.binary { 3 }
		.array { 4 }
		.invalid { -1 }
	}
}

fn compare_bytes(a []u8, b []u8) int {
	length := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. length {
		if a[i] < b[i] {
			return -1
		}
		if a[i] > b[i] {
			return 1
		}
	}
	return compare_int(a.len, b.len)
}

// Infra's "code unit less than" compares DOM strings as sequences of UTF-16
// code units, not UTF-8 bytes or Unicode scalar values. This distinction is
// observable when a supplementary-plane character is compared with a BMP
// character above the surrogate range.
fn utf16_code_units(value string) []u16 {
	return libjs.utf16_string_from_utf8_without_validation(value).code_units()
}

fn compare_utf16_code_units(a string, b string) int {
	a_units := utf16_code_units(a)
	b_units := utf16_code_units(b)
	length := if a_units.len < b_units.len { a_units.len } else { b_units.len }
	for index in 0 .. length {
		if a_units[index] < b_units[index] {
			return -1
		}
		if a_units[index] > b_units[index] {
			return 1
		}
	}
	return compare_int(a_units.len, b_units.len)
}

fn sort_name_list(mut names []string) {
	names.sort_with_compare(fn (a &string, b &string) int {
		return compare_utf16_code_units(*a, *b)
	})
}

fn compare_int(a int, b int) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

// https://w3c.github.io/IndexedDB/#compare-two-keys
pub fn compare_two_keys(a Key, b Key) !int {
	if !a.is_valid() || !b.is_valid() {
		return error('DataError: invalid IndexedDB key')
	}
	if a.kind != b.kind {
		return compare_int(key_type_order(a.kind), key_type_order(b.kind))
	}
	return match a.kind {
		.number, .date {
			if a.number < b.number {
				-1
			} else if a.number > b.number {
				1
			} else {
				0
			}
		}
		.string_ {
			compare_utf16_code_units(a.text, b.text)
		}
		.binary {
			compare_bytes(a.bytes, b.bytes)
		}
		.array {
			mut result := 0
			length := if a.items.len < b.items.len { a.items.len } else { b.items.len }
			for i in 0 .. length {
				result = compare_two_keys(a.items[i], b.items[i])!
				if result != 0 {
					break
				}
			}
			if result == 0 {
				result = compare_int(a.items.len, b.items.len)
			}
			result
		}
		.invalid {
			return error('DataError: invalid IndexedDB key')
		}
	}
}

pub fn keys_equal(a Key, b Key) bool {
	return compare_two_keys(a, b) or { return false } == 0
}

pub fn (key Key) str() string {
	return match key.kind {
		.invalid { '<invalid>' }
		.number { '${key.number}' }
		.date { 'Date(${key.number})' }
		.string_ { '"${key.text}"' }
		.binary { '0x${key.bytes.hex()}' }
		.array { '[${key.items.map(it.str()).join(', ')}]' }
	}
}

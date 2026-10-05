// Copyright (c) 2021, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/DOMURL/URLSearchParams.cpp — the WHATWG URL
// `application/x-www-form-urlencoded` parser/serializer and the URLSearchParams API. The
// percent-encode/decode and the urlencoded percent-encode set (normally from LibURL) are
// translated inline; only UTF-8 is supported (the encoding argument defaults to UTF-8).
// update() writes back to an owning DOMURL when present.
// https://url.spec.whatwg.org/#interface-urlsearchparams
module domurl

import encoding

// https://url.spec.whatwg.org/#concept-urlencoded-tuple
pub struct QueryParam {
pub mut:
	name  string
	value string
}

pub type URLSearchParamsInit = [][]string | map[string]string | string

// --- percent-encoding ---

const hex_upper = '0123456789ABCDEF'

fn is_ascii_alphanumeric(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
}

fn is_hex_digit(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)
}

fn hex_value(ch u8) u8 {
	if ch >= `0` && ch <= `9` {
		return ch - `0`
	}
	if ch >= `a` && ch <= `f` {
		return ch - `a` + 10
	}
	return ch - `A` + 10
}

fn percent_encode_byte(byte u8) string {
	return '%' + hex_upper[byte >> 4].ascii_str() + hex_upper[byte & 0x0F].ascii_str()
}

// The application/x-www-form-urlencoded percent-encode set: everything except ASCII alphanumeric
// and U+002A (*), U+002D (-), U+002E (.), U+005F (_) is encoded.
fn is_urlencoded_kept_as_is(byte u8) bool {
	return is_ascii_alphanumeric(byte) || byte == `*` || byte == `-` || byte == `.` || byte == `_`
}

// percent-encode after encoding, with the urlencoded set and spaceAsPlus = true.
fn percent_encode_form_urlencoded(input string) string {
	mut output := ''
	for byte in input.bytes() {
		if byte == 0x20 {
			// spaceAsPlus: U+0020 SPACE → "+".
			output += '+'
		} else if is_urlencoded_kept_as_is(byte) {
			output += byte.ascii_str()
		} else {
			output += percent_encode_byte(byte)
		}
	}
	return output
}

// https://url.spec.whatwg.org/#percent-decode — UTF-8 decode of the percent-decoding of input.
fn percent_decode(input string) string {
	bytes := input.bytes()
	mut output := []u8{}
	mut i := 0
	for i < bytes.len {
		byte := bytes[i]
		if byte != `%` || i + 2 >= bytes.len || !is_hex_digit(bytes[i + 1])
			|| !is_hex_digit(bytes[i + 2]) {
			output << byte
			i++
		} else {
			output << hex_value(bytes[i + 1]) * 16 + hex_value(bytes[i + 2])
			i += 3
		}
	}
	// Source URLSearchParams::url_decode uses UTF-8 decode without BOM
	// handling. Each tuple's leading U+FEFF remains part of its name/value.
	decoder := encoding.TextDecoder.construct('utf-8', encoding.TextDecoderOptions{
		ignore_bom: true
	}) or { panic(err) }
	return decoder.decode(output, encoding.TextDecodeOptions{}) or { '�' }
}

// https://url.spec.whatwg.org/#concept-urlencoded-serializer
pub fn url_encode(tuples []QueryParam) string {
	// 2. Let output be the empty string.
	mut output := ''
	// 3. For each tuple:
	for tuple in tuples {
		name := percent_encode_form_urlencoded(tuple.name)
		value := percent_encode_form_urlencoded(tuple.value)
		// 4. If output is not empty, append "&".
		if output.len != 0 {
			output += '&'
		}
		// 5. Append name "=" value.
		output += '${name}=${value}'
	}
	// 4. Return output.
	return output
}

// https://url.spec.whatwg.org/#concept-urlencoded-parser
pub fn url_decode(input string) []QueryParam {
	// 1. Split input on 0x26 (&).
	// 2. Let output be an empty list.
	mut output := []QueryParam{}
	// 3. For each byte sequence bytes:
	for bytes in input.split('&') {
		// 1. If bytes is empty, continue.
		if bytes.len == 0 {
			continue
		}
		mut name := ''
		mut value := ''
		// 2. If bytes contains a 0x3D (=), split on the first one.
		index := bytes.index_u8(`=`)
		if index >= 0 {
			name = bytes[..index]
			value = bytes[index + 1..]
		} else {
			// 3. Otherwise, name is bytes and value is empty.
			name = bytes
			value = ''
		}
		// 4. Replace 0x2B (+) with 0x20 (SP) in name and value.
		space_decoded_name := name.replace('+', ' ')
		space_decoded_value := value.replace('+', ' ')
		// 5. UTF-8 decode the percent-decoding of name and value.
		output << QueryParam{
			name: percent_decode(space_decoded_name)
			value: percent_decode(space_decoded_value)
		}
	}
	return output
}

// Infra: code-unit-less-than compares two strings by their UTF-16 code units.
fn to_utf16_code_units(input string) []u16 {
	mut units := []u16{}
	for rune_ in input.runes() {
		code_point := u32(rune_)
		if code_point <= 0xFFFF {
			units << u16(code_point)
		} else {
			c := code_point - 0x10000
			units << u16(0xD800 + (c >> 10))
			units << u16(0xDC00 + (c & 0x3FF))
		}
	}
	return units
}

fn code_unit_less_than(a string, b string) bool {
	a_units := to_utf16_code_units(a)
	b_units := to_utf16_code_units(b)
	mut i := 0
	for i < a_units.len && i < b_units.len {
		if a_units[i] != b_units[i] {
			return a_units[i] < b_units[i]
		}
		i++
	}
	return a_units.len < b_units.len
}

// --- URLSearchParams ---

// https://url.spec.whatwg.org/#interface-urlsearchparams
@[heap]
pub struct URLSearchParams {
mut:
	list []QueryParam
	url_ ?&DOMURL
}

pub fn URLSearchParams.create(list []QueryParam) &URLSearchParams {
	return &URLSearchParams{
		list: list.clone()
	}
}

// https://url.spec.whatwg.org/#urlsearchparams-initialize (string init)
pub fn URLSearchParams.from_string(init string) &URLSearchParams {
	// 1. If init starts with U+003F (?), remove the first code point.
	stripped_init := if init.starts_with('?') { init[1..] } else { init }
	// b. Set list to the result of parsing init.
	return URLSearchParams.create(url_decode(stripped_init))
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-urlsearchparams (sequence init)
pub fn URLSearchParams.from_sequence(init [][]string) !&URLSearchParams {
	mut list := []QueryParam{}
	for pair in init {
		// a. If pair does not contain exactly two items, throw a TypeError.
		if pair.len != 2 {
			return error('Expected only 2 items in pair, got ${pair.len}')
		}
		// b. Append a name-value pair.
		list << QueryParam{
			name: pair[0]
			value: pair[1]
		}
	}
	return URLSearchParams.create(list)
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-urlsearchparams (record init)
pub fn URLSearchParams.from_record(init map[string]string) &URLSearchParams {
	mut list := []QueryParam{}
	for name, value in init {
		list << QueryParam{
			name: name
			value: value
		}
	}
	return URLSearchParams.create(list)
}

pub fn URLSearchParams.construct_impl(init URLSearchParamsInit) !&URLSearchParams {
	return URLSearchParams.create_from_init(init)
}

pub fn URLSearchParams.create_from_init(init URLSearchParamsInit) !&URLSearchParams {
	match init {
		[][]string {
			return URLSearchParams.from_sequence(init)
		}
		map[string]string {
			return URLSearchParams.from_record(init)
		}
		string {
			return URLSearchParams.from_string(init)
		}
	}
}

// https://url.spec.whatwg.org/#concept-urlsearchparams-update
fn (mut params URLSearchParams) update() {
	mut url := params.url_ or { return }
	serialized := params.to_string()
	if serialized == '' {
		url.set_query_from_params(none)
	} else {
		url.set_query_from_params(serialized)
	}
}

fn (mut params URLSearchParams) bind_url(url &DOMURL) {
	params.url_ = url
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-size
pub fn (params &URLSearchParams) size() int {
	return params.list.len
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-append
pub fn (mut params URLSearchParams) append(name string, value string) {
	// 1. Append a new name-value pair to list.
	params.list << QueryParam{
		name: name
		value: value
	}
	// 2. Update this.
	params.update()
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-delete
pub fn (mut params URLSearchParams) delete(name string, value ?string) {
	params.delete_(name, value)
}

pub fn (mut params URLSearchParams) delete_(name string, value ?string) {
	// 1/2. Remove all tuples matching name (and value, if given).
	if v := value {
		params.list = params.list.filter(!(it.name == name && it.value == v))
	} else {
		params.list = params.list.filter(it.name != name)
	}
	// 3. Update this.
	params.update()
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-get
pub fn (params &URLSearchParams) get(name string) ?string {
	// Return the value of the first pair whose name is name, or null.
	for entry in params.list {
		if entry.name == name {
			return entry.value
		}
	}
	return none
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-getall
pub fn (params &URLSearchParams) get_all(name string) []string {
	mut values := []string{}
	for entry in params.list {
		if entry.name == name {
			values << entry.value
		}
	}
	return values
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-has
pub fn (params &URLSearchParams) has(name string, value ?string) bool {
	for entry in params.list {
		if v := value {
			if entry.name == name && entry.value == v {
				return true
			}
		} else if entry.name == name {
			return true
		}
	}
	return false
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-set
pub fn (mut params URLSearchParams) set(name string, value string) {
	// 1. If any pair has this name, set the first one's value and remove the others.
	mut found := false
	mut new_list := []QueryParam{}
	for entry in params.list {
		if entry.name == name {
			if !found {
				new_list << QueryParam{
					name: name
					value: value
				}
				found = true
			}
			// Otherwise drop the duplicate.
		} else {
			new_list << entry
		}
	}
	// 2. Otherwise append a new pair.
	if !found {
		new_list << QueryParam{
			name: name
			value: value
		}
	}
	params.list = new_list
	// 3. Update this.
	params.update()
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-sort
pub fn (mut params URLSearchParams) sort() {
	// 1. Sort in ascending order by code-unit-less-than of the name (a stable insertion sort,
	//    matching the C++ insertion_sort, so equal names keep their relative order).
	mut list := params.list.clone()
	for i := 1; i < list.len; i++ {
		key := list[i]
		mut j := i - 1
		for j >= 0 && code_unit_less_than(key.name, list[j].name) {
			list[j + 1] = list[j]
			j--
		}
		list[j + 1] = key
	}
	params.list = list
	// 2. Update this.
	params.update()
}

// https://url.spec.whatwg.org/#dom-urlsearchparams-tostring
pub fn (params &URLSearchParams) to_string() string {
	return params.serialize_to_byte_string()
}

pub fn (params &URLSearchParams) serialize_to_byte_string() string {
	return url_encode(params.list)
}

// The name-value pairs, in list order (for iteration / entries()).
pub fn (params &URLSearchParams) params() []QueryParam {
	return params.list.clone()
}

pub type URLSearchParamsForEachCallback = fn (value string, name string) !

// The index-based loop intentionally observes appends/deletes performed by the
// callback, matching the upstream iterator semantics.
pub fn (params &URLSearchParams) for_each(callback URLSearchParamsForEachCallback) ! {
	mut index := 0
	for index < params.list.len {
		entry := params.list[index]
		callback(entry.value, entry.name)!
		index++
	}
}

pub enum URLSearchParamsIteratorKind {
	key
	value
	key_value
}

pub struct URLSearchParamsIteratorValue {
pub:
	done  bool
	key   string
	value string
}

@[heap]
pub struct URLSearchParamsIterator {
	params &URLSearchParams
	kind   URLSearchParamsIteratorKind
pub mut:
	index int
}

pub fn URLSearchParamsIterator.create(params &URLSearchParams, kind URLSearchParamsIteratorKind) &URLSearchParamsIterator {
	iterator := &URLSearchParamsIterator{
		params: params
		kind: kind
	}
	return set_url_search_params_iterator_prototype(iterator)
}

// The C++ binding assigns a realm-specific JS prototype here. V iterators are
// statically typed, so creation itself establishes the equivalent interface.
fn set_url_search_params_iterator_prototype(iterator &URLSearchParamsIterator) &URLSearchParamsIterator {
	return iterator
}

pub fn (mut iterator URLSearchParamsIterator) next() URLSearchParamsIteratorValue {
	if iterator.index >= iterator.params.list.len {
		return URLSearchParamsIteratorValue{
			done: true
		}
	}
	entry := iterator.params.list[iterator.index]
	iterator.index++
	return match iterator.kind {
		.key {
			URLSearchParamsIteratorValue{
				key: entry.name
			}
		}
		.value {
			URLSearchParamsIteratorValue{
				value: entry.value
			}
		}
		.key_value {
			URLSearchParamsIteratorValue{
				key: entry.name
				value: entry.value
			}
		}
	}
}

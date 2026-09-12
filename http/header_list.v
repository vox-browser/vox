// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Fetch header list from Libraries/LibHTTP/HeaderList.cpp and Header.cpp — a
// list of (name, value) header pairs with byte-case-insensitive lookup, the combining get(), and
// the quoted-string-aware "get, decode, and split" algorithm. Header names/values are byte
// strings; isomorphic decoding of a V string is the identity, so values are used directly.
// https://fetch.spec.whatwg.org/#concept-header-list
module http

// LibHTTP: HTTP_TAB_OR_SPACE = "\t ".
const http_tab_or_space = '\t '

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

fn equals_ignoring_ascii_case(a string, b string) bool {
	return ascii_lowercase(a) == ascii_lowercase(b)
}

// https://fetch.spec.whatwg.org/#concept-header
pub struct Header {
pub mut:
	name  string
	value string
}

// https://fetch.spec.whatwg.org/#concept-header-list
@[heap]
pub struct HeaderList {
mut:
	headers []Header
}

pub fn HeaderList.create() &HeaderList {
	return &HeaderList{}
}

pub fn (list &HeaderList) is_empty() bool {
	return list.headers.len == 0
}

pub fn (list &HeaderList) headers() []Header {
	return list.headers.clone()
}

// https://fetch.spec.whatwg.org/#header-list-contains
pub fn (list &HeaderList) contains(name string) bool {
	for header in list.headers {
		if equals_ignoring_ascii_case(header.name, name) {
			return true
		}
	}
	return false
}

// https://fetch.spec.whatwg.org/#concept-header-list-append
pub fn (mut list HeaderList) append(header Header) {
	mut to_append := header
	// 1. If list contains name, reuse the casing of the first matching header's name.
	for existing in list.headers {
		if equals_ignoring_ascii_case(existing.name, header.name) {
			to_append.name = existing.name
			break
		}
	}
	// 2. Append (name, value) to list.
	list.headers << to_append
}

// https://fetch.spec.whatwg.org/#concept-header-list-get
pub fn (list &HeaderList) get(name string) ?string {
	// 1. If list does not contain name, return null.
	if !list.contains(name) {
		return none
	}
	// 2. Return all matching values joined by 0x2C 0x20 (", "), in order.
	mut parts := []string{}
	for header in list.headers {
		if equals_ignoring_ascii_case(header.name, name) {
			parts << header.value
		}
	}
	return parts.join(', ')
}

// https://fetch.spec.whatwg.org/#concept-header-list-get-decode-split
pub fn (list &HeaderList) get_decode_and_split(name string) ?[]string {
	// 1. Let value be the result of getting name from list.
	value := list.get(name) or { return none }
	// 3. Return the result of getting, decoding, and splitting value.
	return get_decode_and_split_header_value(value)
}

// https://fetch.spec.whatwg.org/#extract-header-list-values
pub fn (list &HeaderList) extract_header_list_values(name string) ![]string {
	if !list.contains(name) {
		return []string{}
	}
	mut values := []string{}
	for header in list.headers {
		if !equals_ignoring_ascii_case(header.name, name) {
			continue
		}
		extracted := header.extract_header_values() or {
			return error('Failed to parse ${name} header values')
		}
		values << extracted
	}
	return values
}

// --- Header-value splitting (GenericLexer + collect an HTTP quoted string) ---

struct Lexer {
	input string
mut:
	position int
}

fn (l &Lexer) is_eof() bool {
	return l.position >= l.input.len
}

fn (l &Lexer) tell() int {
	return l.position
}

fn (l &Lexer) peek() u8 {
	return if l.position < l.input.len { l.input[l.position] } else { u8(0) }
}

fn (mut l Lexer) ignore(count int) {
	l.position += count
	if l.position > l.input.len {
		l.position = l.input.len
	}
}

fn (mut l Lexer) consume() u8 {
	ch := l.peek()
	l.position++
	return ch
}

fn (mut l Lexer) consume_until_any(delimiters []u8) string {
	start := l.position
	for l.position < l.input.len && l.input[l.position] !in delimiters {
		l.position++
	}
	return l.input[start..l.position]
}

fn (mut l Lexer) consume_until_pred(pred fn (u8) bool) string {
	start := l.position
	for l.position < l.input.len && !pred(l.input[l.position]) {
		l.position++
	}
	return l.input[start..l.position]
}

// LibHTTP: collect an HTTP quoted string (extract-value flag unset — returns the raw quoted run).
fn collect_an_http_quoted_string(mut lexer Lexer) string {
	position_start := lexer.tell()
	lexer.ignore(1) // past the opening '"'
	for {
		lexer.consume_until_pred(fn (ch u8) bool {
			return ch == `"` || ch == `\\`
		})
		if lexer.is_eof() {
			break
		}
		quote_or_backslash := lexer.consume()
		if quote_or_backslash == `\\` {
			if lexer.is_eof() {
				break
			}
			lexer.consume()
		} else {
			break
		}
	}
	// extract-value unset: return the code points from positionStart to position, inclusive.
	return lexer.input[position_start..lexer.tell()]
}

// https://fetch.spec.whatwg.org/#header-value-get-decode-and-split
pub fn get_decode_and_split_header_value(value string) []string {
	// 1. Let input be the isomorphic decoding of value (identity for a V string).
	mut lexer := Lexer{
		input: value
	}
	// 3. Let values be « ».
	mut values := []string{}
	// 4. Let temporaryValue be the empty string.
	mut temporary_value := ''
	// 5. While true:
	for {
		// 1. Collect code points that are not '"' or ','.
		temporary_value += lexer.consume_until_any([u8(`"`), `,`])
		// 2. If not past the end and the code point is '"':
		if !lexer.is_eof() && lexer.peek() == `"` {
			// 1. Collect an HTTP quoted string, appending it to temporaryValue.
			temporary_value += collect_an_http_quoted_string(mut lexer)
			// 2. If not past the end, continue.
			if !lexer.is_eof() {
				continue
			}
		}
		// 3. Trim HTTP tab or space from both ends of temporaryValue.
		values << temporary_value.trim(http_tab_or_space)
		// 4-5. Append and reset temporaryValue.
		temporary_value = ''
		// 6. If past the end, return values.
		if lexer.is_eof() {
			return values
		}
		// 7-8. The code point is ','; advance past it.
		lexer.ignore(1)
	}
	return values
}

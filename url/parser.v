// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibURL/Parser.cpp's basic URL parser.
// https://url.spec.whatwg.org/#concept-basic-url-parser
module url

import strconv
import strings

enum ParserState {
	scheme_start
	scheme
	no_scheme
	special_relative_or_authority
	path_or_authority
	relative
	relative_slash
	special_authority_slashes
	special_authority_ignore_slashes
	authority
	file
	file_slash
	file_host
	path_start
	path
	opaque_path
	query
	fragment
}

const parser_eof = u32(0xffffffff)

fn parser_is_ascii_alpha(code_point u32) bool {
	return (code_point >= `A` && code_point <= `Z`) || (code_point >= `a` && code_point <= `z`)
}

fn parser_is_ascii_digit(code_point u32) bool {
	return code_point >= `0` && code_point <= `9`
}

fn parser_is_ascii_alphanumeric(code_point u32) bool {
	return parser_is_ascii_alpha(code_point) || parser_is_ascii_digit(code_point)
}

fn parser_ascii_lower(code_point u32) u32 {
	return if code_point >= `A` && code_point <= `Z` { code_point + 0x20 } else { code_point }
}

fn parser_append_code_point(output string, code_point u32) string {
	return output + rune(code_point).str()
}

fn parser_append_percent_encoded(output string, code_point u32, set PercentEncodeSet) string {
	return output + percent_encode(rune(code_point).str(), set, false)
}

fn parser_copy_url(source &URL) URL {
	return URL{
		scheme: source.scheme
		username: source.username
		password: source.password
		host: source.host
		port: source.port
		paths: source.paths.clone()
		query: source.query
		fragment: source.fragment
		has_an_opaque_path: source.has_an_opaque_path
		blob_url_entry_: source.blob_url_entry()
	}
}

fn parser_is_windows_drive_letter(input string) bool {
	return input.len == 2 && parser_is_ascii_alpha(input[0]) && (input[1] == `:` || input[1] == `|`)
}

fn parser_is_normalized_windows_drive_letter(input string) bool {
	return input.len == 2 && parser_is_ascii_alpha(input[0]) && input[1] == `:`
}

fn parser_starts_with_windows_drive_letter(code_points []rune, index int) bool {
	if index + 1 >= code_points.len || !parser_is_ascii_alpha(u32(code_points[index]))
		|| (code_points[index + 1] != `:` && code_points[index + 1] != `|`) {
		return false
	}
	if index + 2 == code_points.len {
		return true
	}
	return code_points[index + 2] in [`/`, `\\`, `?`, `#`]
}

fn parser_is_single_dot_path_segment(input string) bool {
	lower := input.to_lower()
	return input == '.' || lower == '%2e'
}

fn parser_is_double_dot_path_segment(input string) bool {
	lower := input.to_lower()
	return input == '..' || lower in ['.%2e', '%2e.', '%2e%2e']
}

fn parser_shorten_path(mut record URL) {
	if record.scheme == 'file' && record.paths.len == 1
		&& parser_is_normalized_windows_drive_letter(record.paths[0]) {
		return
	}
	if record.paths.len > 0 {
		record.paths.delete_last()
	}
}

fn parser_processed_input(raw_input string) []rune {
	mut input := raw_input.runes()
	mut start := 0
	mut end := input.len
	for start < end && u32(input[start]) <= 0x20 {
		start++
	}
	for end > start && u32(input[end - 1]) <= 0x20 {
		end--
	}
	if !retain_url_input_copy {
		length := compact_url_input(mut input, start, end)
		input.trim(length)
		return input
	}
	mut output := []rune{cap: end - start}
	for index := start; index < end; index++ {
		if input[index] !in [`\t`, `\n`, `\r`] {
			output << input[index]
		}
	}
	return output
}

// When basic_parse is invoked with an existing URL and a state override, the
// URL Standard does not trim leading or trailing C0 controls/spaces. It still
// removes ASCII tabs and newlines.
fn parser_processed_override_input(raw_input string) []rune {
	if !retain_url_input_copy {
		mut input := raw_input.runes()
		length := compact_url_input(mut input, 0, input.len)
		input.trim(length)
		return input
	}
	mut output := []rune{cap: raw_input.len}
	for code_point in raw_input.runes() {
		if code_point !in [`\t`, `\n`, `\r`] {
			output << code_point
		}
	}
	return output
}

fn parser_runes_to_string(input []rune, start int, end int) string {
	mut output := ''
	for index := start; index < end; index++ {
		output += input[index].str()
	}
	return output
}

struct ParserPortResult {
	port ?u16
}

fn parser_parse_port(input string, scheme string) ?ParserPortResult {
	if input == '' {
		return ParserPortResult{}
	}
	for character in input.bytes() {
		if character < `0` || character > `9` {
			return none
		}
	}
	value := strconv.parse_uint(input, 10, 16) or { return none }
	port := u16(value)
	if default := default_port_for_scheme(scheme) {
		if port == default {
			return ParserPortResult{}
		}
	}
	return ParserPortResult{ port: port }
}

fn parser_encode_userinfo(input string) string {
	mut output := ''
	for code_point in input.runes() {
		if code_point == `@` {
			output += '%40'
		} else {
			output += percent_encode(code_point.str(), .userinfo, false)
		}
	}
	return output
}

// Parse an authority in one batch. This is equivalent to the upstream
// Authority/Host/Port states, which batch-process the authority for speed.
fn parser_parse_authority(mut record URL, authority string) bool {
	mut host_and_port := authority
	if at := authority.last_index('@') {
		if at + 1 >= authority.len {
			return false
		}
		userinfo := authority[..at]
		host_and_port = authority[at + 1..]
		if colon := userinfo.index(':') {
			record.username = parser_encode_userinfo(userinfo[..colon])
			record.password = parser_encode_userinfo(userinfo[colon + 1..])
		} else {
			record.username = parser_encode_userinfo(userinfo)
		}
	}
	mut host_input := host_and_port
	mut port_input := ?string(none)
	if host_and_port.starts_with('[') {
		closing := host_and_port.index(']') or { return false }
		host_input = host_and_port[..closing + 1]
		if closing + 1 < host_and_port.len {
			if host_and_port[closing + 1] != `:` {
				return false
			}
			port_input = host_and_port[closing + 2..]
		}
	} else if colon := host_and_port.last_index(':') {
		host_input = host_and_port[..colon]
		port_input = host_and_port[colon + 1..]
	}
	if record.is_special() && host_input == '' {
		return false
	}
	host := parse_host(host_input, !record.is_special()) or { return false }
	record.host = host
	if raw_port := port_input {
		if raw_port == '' {
			record.port = none
		} else {
			parsed_port := parser_parse_port(raw_port, record.scheme) or { return false }
			record.port = parsed_port.port
		}
	}
	return true
}

// Parse a URL string against an optional base URL.
pub fn basic_parse(input string, base ?&URL) ?URL {
	$if prealloc { return parse_url_in_workspace(input, base) }
	return basic_parse_in_workspace(input, base)
}

fn basic_parse_in_workspace(input string, base ?&URL) ?URL {
	code_points := parser_processed_input(input)
	mut record := URL{}
	mut state := ParserState.scheme_start
	mut buffer := ''
	// Opaque paths include embedded image payloads. Retain one growing buffer
	// rather than copying the complete path after every code point.
	mut opaque_path := strings.new_builder(0)
	defer { unsafe { opaque_path.free() } }
	mut index := 0
	mut reconsume := false

	for {
		code_point := if index < code_points.len { u32(code_points[index]) } else { parser_eof }
		reconsume = false
		match state {
			.scheme_start {
				if parser_is_ascii_alpha(code_point) {
					buffer = parser_append_code_point(buffer, parser_ascii_lower(code_point))
					state = .scheme
				} else {
					state = .no_scheme
					reconsume = true
				}
			}
			.scheme {
				if parser_is_ascii_alphanumeric(code_point) || code_point in [`+`, `-`, `.`] {
					buffer = parser_append_code_point(buffer, parser_ascii_lower(code_point))
				} else if code_point == `:` {
					record.scheme = buffer
					buffer = ''
					if record.scheme == 'file' {
						state = .file
					} else if record.is_special() {
						if base_record := base {
							if base_record.scheme == record.scheme {
								state = .special_relative_or_authority
							} else {
								state = .special_authority_slashes
							}
						} else {
							state = .special_authority_slashes
						}
					} else if index + 1 < code_points.len && code_points[index + 1] == `/` {
						state = .path_or_authority
						index++
					} else {
						record.has_an_opaque_path = true
						record.paths = ['']
						state = .opaque_path
					}
				} else {
					buffer = ''
					state = .no_scheme
					index = 0
					reconsume = true
				}
			}
			.no_scheme {
				base_record := base or { return none }
				if base_record.has_an_opaque_path {
					if code_point != `#` {
						return none
					}
					record.scheme = base_record.scheme
					record.paths = base_record.paths.clone()
					record.query = base_record.query
					record.fragment = ''
					record.has_an_opaque_path = true
					state = .fragment
				} else if base_record.scheme != 'file' {
					state = .relative
					reconsume = true
				} else {
					state = .file
					reconsume = true
				}
			}
			.special_relative_or_authority {
				if code_point == `/` && index + 1 < code_points.len && code_points[index + 1] == `/` {
					state = .special_authority_ignore_slashes
					index++
				} else {
					state = .relative
					reconsume = true
				}
			}
			.path_or_authority {
				if code_point == `/` {
					state = .authority
				} else {
					state = .path
					reconsume = true
				}
			}
			.relative {
				base_record := base or { return none }
				record.scheme = base_record.scheme
				if code_point == `/` || (record.is_special() && code_point == `\\`) {
					state = .relative_slash
				} else {
					record.username = base_record.username
					record.password = base_record.password
					record.host = base_record.host
					record.port = base_record.port
					record.paths = base_record.paths.clone()
					record.query = base_record.query
					if code_point == `?` {
						record.query = ''
						state = .query
					} else if code_point == `#` {
						record.fragment = ''
						state = .fragment
					} else if code_point != parser_eof {
						record.query = none
						parser_shorten_path(mut record)
						state = .path
						reconsume = true
					}
				}
			}
			.relative_slash {
				base_record := base or { return none }
				if record.is_special() && (code_point == `/` || code_point == `\\`) {
					state = .special_authority_ignore_slashes
				} else if code_point == `/` {
					state = .authority
				} else {
					record.username = base_record.username
					record.password = base_record.password
					record.host = base_record.host
					record.port = base_record.port
					state = .path
					reconsume = true
				}
			}
			.special_authority_slashes {
				if code_point == `/` && index + 1 < code_points.len && code_points[index + 1] == `/` {
					state = .special_authority_ignore_slashes
					index++
				} else {
					state = .special_authority_ignore_slashes
					reconsume = true
				}
			}
			.special_authority_ignore_slashes {
				if code_point != `/` && code_point != `\\` {
					state = .authority
					reconsume = true
				}
			}
			.authority {
				mut authority_end := index
				for authority_end < code_points.len {
					candidate := code_points[authority_end]
					if candidate in [`/`, `?`, `#`] || (record.is_special() && candidate == `\\`) {
						break
					}
					authority_end++
				}
				authority := parser_runes_to_string(code_points, index, authority_end)
				if !parser_parse_authority(mut record, authority) {
					return none
				}
				index = authority_end
				state = .path_start
				reconsume = true
			}
			.file {
				record.scheme = 'file'
				record.host = Host.from_string('')
				if code_point == `/` || code_point == `\\` {
					state = .file_slash
				} else if base_record := base {
					if base_record.scheme == 'file' {
						record.host = base_record.host
						record.paths = base_record.paths.clone()
						record.query = base_record.query
						if code_point == `?` {
							record.query = ''
							state = .query
						} else if code_point == `#` {
							record.fragment = ''
							state = .fragment
						} else if code_point != parser_eof {
							record.query = none
							if !parser_starts_with_windows_drive_letter(code_points, index) {
								parser_shorten_path(mut record)
							} else {
								record.paths.clear()
							}
							state = .path
							reconsume = true
						}
					} else {
						state = .path
						reconsume = true
					}
				} else {
					state = .path
					reconsume = true
				}
			}
			.file_slash {
				if code_point == `/` || code_point == `\\` {
					state = .file_host
				} else {
					if base_record := base {
						if base_record.scheme == 'file' {
							record.host = base_record.host
							if !parser_starts_with_windows_drive_letter(code_points, index)
								&& base_record.paths.len > 0
								&& parser_is_normalized_windows_drive_letter(base_record.paths[0]) {
								record.paths << base_record.paths[0]
							}
						}
					}
					state = .path
					reconsume = true
				}
			}
			.file_host {
				if code_point == parser_eof || code_point in [`/`, `\\`, `?`, `#`] {
					if parser_is_windows_drive_letter(buffer) {
						state = .path
					} else if buffer == '' {
						record.host = Host.from_string('')
						state = .path_start
					} else {
						host := parse_host(buffer, false) or { return none }
						record.host = if host is string && host == 'localhost' {
							Host.from_string('')
						} else {
							host
						}
						buffer = ''
						state = .path_start
					}
					reconsume = true
				} else {
					buffer = parser_append_code_point(buffer, code_point)
				}
			}
			.path_start {
				if record.is_special() {
					state = .path
					if code_point != `/` && code_point != `\\` {
						reconsume = true
					}
				} else if code_point == `?` {
					record.query = ''
					state = .query
				} else if code_point == `#` {
					record.fragment = ''
					state = .fragment
				} else if code_point != parser_eof {
					state = .path
					if code_point != `/` {
						reconsume = true
					}
				}
			}
			.path {
				if code_point == parser_eof || code_point == `/`
					|| (record.is_special() && code_point == `\\`) || code_point in [`?`, `#`] {
					if parser_is_double_dot_path_segment(buffer) {
						parser_shorten_path(mut record)
						if code_point != `/` && !(record.is_special() && code_point == `\\`) {
							record.paths << ''
						}
					} else if parser_is_single_dot_path_segment(buffer) {
						if code_point != `/` && !(record.is_special() && code_point == `\\`) {
							record.paths << ''
						}
					} else {
						if record.scheme == 'file' && record.paths.len == 0
							&& parser_is_windows_drive_letter(buffer) {
							buffer = '${buffer[0].ascii_str()}:'
						}
						record.paths << buffer
					}
					buffer = ''
					if code_point == `?` {
						record.query = ''
						state = .query
					} else if code_point == `#` {
						record.fragment = ''
						state = .fragment
					}
				} else {
					buffer = parser_append_percent_encoded(buffer, code_point, .path)
				}
			}
			.opaque_path {
				if code_point == `?` {
					record.paths[0] = opaque_path.str()
					record.query = ''
					state = .query
				} else if code_point == `#` {
					record.paths[0] = opaque_path.str()
					record.fragment = ''
					state = .fragment
				} else if code_point == parser_eof {
					record.paths[0] = opaque_path.str()
				} else if code_point == ` ` && index + 1 < code_points.len
					&& code_points[index + 1] in [`?`, `#`] {
					opaque_path.write_string('%20')
				} else if code_point >= 0x20 && code_point <= 0x7e {
					opaque_path.write_u8(u8(code_point))
				} else {
					opaque_path.write_string(percent_encode_code_point(code_point))
				}
			}
			.query {
				if code_point == `#` || code_point == parser_eof {
					record.query = percent_encode(buffer, if record.is_special() {
						PercentEncodeSet.special_query
					} else {
						PercentEncodeSet.query
					}, false)
					buffer = ''
					if code_point == `#` {
						record.fragment = ''
						state = .fragment
					}
				} else {
					buffer = parser_append_code_point(buffer, code_point)
				}
			}
			.fragment {
				if code_point == parser_eof {
					record.fragment = percent_encode(buffer, .fragment, false)
				} else {
					buffer = parser_append_code_point(buffer, code_point)
				}
			}
		}
		if code_point == parser_eof && !reconsume {
			break
		}
		if !reconsume {
			index++
		}
	}
	return record
}

pub fn parse(input string) ?URL {
	return basic_parse(input, none)
}

pub fn parse_with_base(input string, base &URL) ?URL {
	return basic_parse(input, base)
}

pub fn (record &URL) with_scheme(input string) URL {
	mut scheme := input
	if scheme.ends_with(':') {
		scheme = scheme[..scheme.len - 1]
	}
	if scheme == '' || !parser_is_ascii_alpha(scheme[0]) {
		return parser_copy_url(record)
	}
	for character in scheme.bytes()[1..] {
		if !parser_is_ascii_alphanumeric(character) && character !in [`+`, `-`, `.`] {
			return parser_copy_url(record)
		}
	}
	scheme = scheme.to_lower()
	host_is_empty := if host := record.host { host.is_empty_host() } else { false }
	if record.is_special() != is_special_scheme(scheme)
		|| ((record.includes_credentials() || record.port != none) && scheme == 'file')
		|| (record.scheme == 'file' && record.host != none && host_is_empty) {
		return parser_copy_url(record)
	}
	mut result := parser_copy_url(record)
	result.scheme = scheme
	default_port := default_port_for_scheme(scheme)
	if result.port == default_port {
		result.port = none
	}
	return result
}

pub fn (record &URL) with_username(input string) URL {
	mut result := parser_copy_url(record)
	if result.cannot_have_a_username_or_password_or_port() {
		return result
	}
	result.username = percent_encode(input, .userinfo, false)
	return result
}

pub fn (record &URL) with_password(input string) URL {
	mut result := parser_copy_url(record)
	if result.cannot_have_a_username_or_password_or_port() {
		return result
	}
	result.password = percent_encode(input, .userinfo, false)
	return result
}

pub fn (record &URL) with_host(input string, hostname_only bool) URL {
	mut result := parser_copy_url(record)
	if result.has_an_opaque_path {
		return result
	}
	code_points := parser_processed_override_input(input)
	// A host-state override for file URLs immediately switches to file-host.
	if result.scheme == 'file' {
		mut buffer := ''
		for code_point in code_points {
			if code_point in [`/`, `\\`, `?`, `#`] {
				break
			}
			buffer += code_point.str()
		}
		if buffer == '' {
			result.host = Host.from_string('')
			return result
		}
		host := parse_host(buffer, false) or { return result }
		result.host = if host is string && host == 'localhost' {
			Host.from_string('')
		} else {
			host
		}
		return result
	}

	mut buffer := ''
	mut inside_brackets := false
	mut index := 0
	for index <= code_points.len {
		code_point := if index < code_points.len { code_points[index] } else { rune(parser_eof) }
		if code_point == `:` && !inside_brackets {
			if buffer == '' || hostname_only {
				return result
			}
			host := parse_host(buffer, !result.is_special()) or { return result }
			result.host = host
			index++
			break
		}
		if u32(code_point) == parser_eof || code_point in [`/`, `?`, `#`]
			|| (result.is_special() && code_point == `\\`) {
			if (result.is_special() && buffer == '')
				|| (buffer == '' && (result.includes_credentials() || result.port != none)) {
				return result
			}
			host := parse_host(buffer, !result.is_special()) or { return result }
			result.host = host
			return result
		}
		if code_point == `[` {
			inside_brackets = true
		} else if code_point == `]` {
			inside_brackets = false
		}
		buffer += code_point.str()
		index++
	}

	// Port state with an override consumes the leading run of ASCII digits and
	// returns as soon as it encounters anything else. An empty/invalid port is
	// a parse failure, but the host mutation above is intentionally retained.
	mut port_buffer := ''
	for index < code_points.len && parser_is_ascii_digit(u32(code_points[index])) {
		port_buffer += code_points[index].str()
		index++
	}
	if port_buffer != '' {
		if port := parser_parse_port(port_buffer, result.scheme) {
			result.port = port.port
		}
	}
	return result
}

pub fn (record &URL) with_port(input string) URL {
	mut result := parser_copy_url(record)
	if result.cannot_have_a_username_or_password_or_port() {
		return result
	}
	if input == '' {
		result.port = none
		return result
	}
	processed := parser_processed_override_input(input)
	mut leading_digits := ''
	for code_point in processed {
		if !parser_is_ascii_digit(u32(code_point)) {
			break
		}
		leading_digits += code_point.str()
	}
	if leading_digits == '' {
		return result
	}
	port := parser_parse_port(leading_digits, result.scheme) or { return result }
	result.port = port.port
	return result
}

pub fn (record &URL) with_path(input string) URL {
	mut result := parser_copy_url(record)
	if result.has_an_opaque_path {
		return result
	}
	result.paths.clear()
	code_points := parser_processed_override_input(input)
	mut index := 0
	// Path-start state consumes one leading slash (or reverse solidus for a
	// special URL); otherwise path state reconsumes the first code point.
	if code_points.len > 0 {
		if code_points[0] == `/` || (result.is_special() && code_points[0] == `\\`) {
			index = 1
		}
	} else if !result.is_special() && result.host == none {
		result.paths << ''
		return result
	}
	mut buffer := ''
	for index <= code_points.len {
		code_point := if index < code_points.len { u32(code_points[index]) } else { parser_eof }
		if code_point == parser_eof || code_point == `/`
			|| (result.is_special() && code_point == `\\`) {
			if parser_is_double_dot_path_segment(buffer) {
				parser_shorten_path(mut result)
				if code_point != `/` && !(result.is_special() && code_point == `\\`) {
					result.paths << ''
				}
			} else if parser_is_single_dot_path_segment(buffer) {
				if code_point != `/` && !(result.is_special() && code_point == `\\`) {
					result.paths << ''
				}
			} else {
				if result.scheme == 'file' && result.paths.len == 0
					&& parser_is_windows_drive_letter(buffer) {
					buffer = '${buffer[0].ascii_str()}:'
				}
				result.paths << buffer
			}
			buffer = ''
		} else {
			buffer = parser_append_percent_encoded(buffer, code_point, .path)
		}
		index++
	}
	return result
}

pub fn (record &URL) with_query(input ?string) URL {
	mut result := parser_copy_url(record)
	if value := input {
		result.query = percent_encode(value, if result.is_special() {
			PercentEncodeSet.special_query
		} else {
			PercentEncodeSet.query
		}, false)
	} else {
		result.query = none
	}
	return result
}

pub fn (record &URL) with_fragment(input ?string) URL {
	mut result := parser_copy_url(record)
	if value := input {
		result.fragment = percent_encode(value, .fragment, false)
	} else {
		result.fragment = none
	}
	return result
}

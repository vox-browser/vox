// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the generated LibURL/PublicSuffixData.cpp and the public
// suffix helpers in LibURL/URL.cpp. The embedded input is the identical PSL
// snapshot used by the upstream checkout.
module url

import platform

const public_suffix_list_reversed = platform.embedded_text($embed_file('public_suffix_list_reversed.dat'))

// PublicSuffixData::is_public_suffix() receives the generated table's reversed
// representation. Keep that representation at this private boundary so the
// search below is a direct translation of the generated C++ algorithm.
fn is_reversed_public_suffix(value string) bool {
	if value == '' || value.contains('\n') || value.contains('\r') {
		return false
	}
	// The generated C++ uses binary_search over this same sorted sequence.
	// Search the embedded newline-delimited form without constructing a 10k
	// element V array at process startup.
	mut lower := 0
	mut upper := public_suffix_list_reversed.len
	for lower < upper {
		midpoint := lower + (upper - lower) / 2
		mut line_start := midpoint
		if line_start > lower {
			for line_start > 0 && public_suffix_list_reversed[line_start - 1] != `\n` {
				line_start--
			}
		}
		mut line_end := line_start
		for line_end < public_suffix_list_reversed.len
			&& public_suffix_list_reversed[line_end] != `\n` {
			line_end++
		}
		candidate := public_suffix_list_reversed[line_start..line_end]
		if candidate == value {
			return true
		}
		if candidate < value {
			lower = if line_end < public_suffix_list_reversed.len { line_end + 1 } else { line_end }
		} else {
			upper = line_start
		}
	}
	return false
}

// PublicSuffixData::get_public_suffix().
pub fn get_public_suffix(input_string string) ?string {
	mut input := input_string.split('.')
	input.reverse_in_place()
	mut matched_parts := []string{}
	mut overall_search_string := ''
	for part in input {
		search_string := overall_search_string + part
		if is_reversed_public_suffix(search_string) {
			matched_parts << part
			overall_search_string += part + '.'
			continue
		}
		// Preserve the generated Ladybird lookup exactly. This probes the
		// wildcard entry at the current reversed-label prefix.
		if is_reversed_public_suffix(overall_search_string + '.') {
			matched_parts << part
			overall_search_string += part + '.'
			continue
		}
		break
	}
	matched_parts.reverse_in_place()
	result := matched_parts.join('.')
	return if result == '' { none } else { result }
}

// LibURL's generated public API performs membership against its reversed
// sorted table.
pub fn is_public_suffix(host string) bool {
	return is_reversed_public_suffix(host)
}

// https://github.com/publicsuffix/list/wiki/Format#algorithm
pub fn get_registrable_domain(host string) ?string {
	public_suffix := get_public_suffix(host) or { return none }
	if !host.ends_with(public_suffix) || host == public_suffix {
		return none
	}
	mut subhost := host[..host.len - public_suffix.len].trim_right('.')
	if subhost == '' {
		return none
	}
	start_index := subhost.last_index('.') or { -1 }
	return host[start_index + 1..]
}

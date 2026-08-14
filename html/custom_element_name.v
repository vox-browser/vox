// Copyright (c) 2023, Srikavin Ramkumar <me@srikavin.me>
// Copyright (c) 2025, Sam Atkins <sam@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/CustomElements/CustomElementName.cpp.
module html

import dom

const invalid_custom_element_names = ['annotation-xml', 'color-profile', 'font-face', 'font-face-src',
	'font-face-uri', 'font-face-format', 'font-face-name', 'missing-glyph']

// https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name
pub fn is_valid_custom_element_name(name string) bool {
	if !dom.is_valid_element_local_name(name) {
		return false
	}
	code_points := name.runes()
	if code_points.len == 0 || code_points[0] < `a` || code_points[0] > `z` {
		return false
	}
	mut contains_hyphen := false
	for code_point in code_points {
		if code_point >= `A` && code_point <= `Z` {
			return false
		}
		if code_point == `-` {
			contains_hyphen = true
		}
	}
	if !contains_hyphen || name in invalid_custom_element_names {
		return false
	}
	return true
}

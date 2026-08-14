// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/TokenizedFeatures.cpp.
module html

import strconv

pub enum TokenizedFeature {
	no
	yes
}

fn normalize_feature_name(name string) string {
	return match name {
		'screenx' { 'left' }
		'screeny' { 'top' }
		'innerwidth' { 'width' }
		'innerheight' { 'height' }
		else { name }
	}
}

fn is_feature_separator(character u8) bool {
	return is_number_ascii_whitespace(character) || character == `=` || character == `,`
}

fn ascii_lowercase_string(input string) string {
	mut result := []u8{cap: input.len}
	for character in input.bytes() {
		result << if character >= `A` && character <= `Z` {
			character + 0x20
		} else {
			character
		}
	}
	return result.bytestr()
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-window-open-features-tokenize
pub fn tokenize_open_features(features string) map[string]string {
	mut tokenized_features := map[string]string{}
	mut position := 0
	for position < features.len {
		for position < features.len && is_feature_separator(features[position]) {
			position++
		}

		name_start := position
		for position < features.len && !is_feature_separator(features[position]) {
			position++
		}
		name := normalize_feature_name(ascii_lowercase_string(features[name_start..position]))

		for position < features.len && is_number_ascii_whitespace(features[position]) {
			position++
		}
		for position < features.len
			&& (is_number_ascii_whitespace(features[position]) || features[position] == `=`) {
			position++
		}

		value_start := position
		for position < features.len && !is_feature_separator(features[position]) {
			position++
		}
		value := ascii_lowercase_string(features[value_start..position])
		if name != '' {
			tokenized_features[name] = value
		}
	}
	return tokenized_features
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-window-open-features-parse-boolean
pub fn parse_boolean_feature(value string) TokenizedFeature {
	if value == '' || value == 'yes' || value == 'true' {
		return .yes
	}
	parsed := strconv.parse_int(value, 10, 64) or { i64(0) }
	return if parsed == 0 { .no } else { .yes }
}

fn window_feature_or_default(tokenized_features map[string]string, feature_name string, default_value TokenizedFeature) TokenizedFeature {
	if feature_name in tokenized_features {
		return parse_boolean_feature(tokenized_features[feature_name])
	}
	return default_value
}

// https://html.spec.whatwg.org/multipage/window-object.html#popup-window-is-requested
pub fn check_if_a_popup_window_is_requested(tokenized_features map[string]string) TokenizedFeature {
	if tokenized_features.len == 0 {
		return .no
	}
	if 'popup' in tokenized_features {
		return parse_boolean_feature(tokenized_features['popup'])
	}

	location := window_feature_or_default(tokenized_features, 'location', .no)
	toolbar := window_feature_or_default(tokenized_features, 'toolbar', .no)
	if location == .no && toolbar == .no {
		return .yes
	}
	menubar := window_feature_or_default(tokenized_features, 'menubar', .no)
	if menubar == .no {
		return .yes
	}
	resizable := window_feature_or_default(tokenized_features, 'resizable', .yes)
	if resizable == .no {
		return .yes
	}
	scrollbars := window_feature_or_default(tokenized_features, 'scrollbars', .no)
	if scrollbars == .no {
		return .yes
	}
	status := window_feature_or_default(tokenized_features, 'status', .no)
	if status == .no {
		return .yes
	}
	return .no
}

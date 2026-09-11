// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TrustedHTML, TrustedScript and TrustedScriptURL.
module trustedtypes

pub struct TrustedHTML {
pub:
	data string
}

pub fn (value TrustedHTML) to_string() string {
	return value.data
}

pub fn (value TrustedHTML) to_json() string {
	return value.data
}

pub struct TrustedScript {
pub:
	data string
}

pub fn (value TrustedScript) to_string() string {
	return value.data
}

pub fn (value TrustedScript) to_json() string {
	return value.data
}

pub struct TrustedScriptURL {
pub:
	data string
}

pub fn (value TrustedScriptURL) to_string() string {
	return value.data
}

pub fn (value TrustedScriptURL) to_json() string {
	return value.data
}

pub type TrustedType = TrustedHTML | TrustedScript | TrustedScriptURL

pub type TrustedTypeOrString = TrustedHTML | TrustedScript | TrustedScriptURL | string

pub enum TrustedTypeName {
	trusted_html
	trusted_script
	trusted_script_url
}

pub fn trusted_type_name_string(name TrustedTypeName) string {
	return match name {
		.trusted_html { 'TrustedHTML' }
		.trusted_script { 'TrustedScript' }
		.trusted_script_url { 'TrustedScriptURL' }
	}
}

pub fn stringify(value TrustedTypeOrString) string {
	return match value {
		TrustedHTML { value.data }
		TrustedScript { value.data }
		TrustedScriptURL { value.data }
		string { value }
	}
}

pub fn trusted_type_matches(value TrustedTypeOrString, expected TrustedTypeName) bool {
	return match value {
		TrustedHTML { expected == .trusted_html }
		TrustedScript { expected == .trusted_script }
		TrustedScriptURL { expected == .trusted_script_url }
		string { false }
	}
}

// The C++ binding layer unwraps the implementation object from JS::Value. The
// V binding boundary is already a tagged sum, so these helpers perform the
// equivalent checked extraction without relying on wrapper object identity.
pub fn trusted_html_from_value(value TrustedTypeOrString) ?TrustedHTML {
	if value is TrustedHTML {
		return value
	}
	return none
}

pub fn trusted_script_from_value(value TrustedTypeOrString) ?TrustedScript {
	if value is TrustedScript {
		return value
	}
	return none
}

pub fn trusted_script_url_from_value(value TrustedTypeOrString) ?TrustedScriptURL {
	if value is TrustedScriptURL {
		return value
	}
	return none
}

pub fn is_trusted_html_value(value TrustedTypeOrString) bool {
	return trusted_html_from_value(value) != none
}

pub fn is_trusted_script_value(value TrustedTypeOrString) bool {
	return trusted_script_from_value(value) != none
}

pub fn is_trusted_script_url_value(value TrustedTypeOrString) bool {
	return trusted_script_url_from_value(value) != none
}

pub fn trusted_script_value_matches(value TrustedTypeOrString, expected string) bool {
	trusted_script := trusted_script_from_value(value) or { return false }
	return trusted_script.to_string() == expected
}

pub fn trusted_script_values_match(values []TrustedTypeOrString, expected []string) bool {
	if values.len != expected.len {
		return false
	}
	for index, value in values {
		if !trusted_script_value_matches(value, expected[index]) {
			return false
		}
	}
	return true
}

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

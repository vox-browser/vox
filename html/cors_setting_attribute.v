// Copyright (c) 2023, Srikavin Ramkumar <me@srikavin.me>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/CORSSettingAttribute.cpp.
module html

pub enum CORSSettingAttribute {
	no_cors
	anonymous
	use_credentials
}

pub enum CredentialsMode {
	same_origin
	include
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attributes
pub fn cors_setting_attribute_from_keyword(keyword ?string) CORSSettingAttribute {
	value := keyword or { return .no_cors }
	if ascii_lowercase_string(value) == 'use-credentials' {
		return .use_credentials
	}
	return .anonymous
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attribute-credentials-mode
pub fn cors_settings_attribute_credentials_mode(attribute CORSSettingAttribute) CredentialsMode {
	return match attribute {
		.no_cors, .anonymous { .same_origin }
		.use_credentials { .include }
	}
}

/*
 * Copyright (c) 2018-2026, Ladybird contributors
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// Translated from:
// - Libraries/LibWeb/CSS/SystemColor.cpp/.h
// - Libraries/LibWeb/CSS/URL.cpp/.h
module css

import fetch

// https://www.w3.org/TR/css-color-4/#css-system-colors
pub struct SystemColor {}

pub fn SystemColor.accent_color(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(61, 174, 233)
}

pub fn SystemColor.accent_color_text(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(0, 0, 0)
}

pub fn SystemColor.active_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(213, 97, 82)
	}
	return Color.rgb(255, 0, 0)
}

pub fn SystemColor.button_border(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(72, 72, 72)
	}
	return Color.rgb(128, 128, 128)
}

pub fn SystemColor.button_face(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(32, 29, 25)
	}
	return Color.rgb(212, 208, 200)
}

pub fn SystemColor.button_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(235, 235, 235)
	}
	return Color.rgb(0, 0, 0)
}

pub fn SystemColor.canvas(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(20, 20, 20)
	}
	return Color.rgb(255, 255, 255)
}

pub fn SystemColor.canvas_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(235, 235, 235)
	}
	return Color.rgb(0, 0, 0)
}

pub fn SystemColor.field(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(32, 29, 25)
	}
	return Color.rgb(255, 255, 255)
}

pub fn SystemColor.field_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(235, 235, 235)
	}
	return Color.rgb(0, 0, 0)
}

pub fn SystemColor.gray_text(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(128, 128, 128)
}

pub fn SystemColor.highlight(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgba(61, 174, 233, 128)
}

pub fn SystemColor.highlight_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(20, 20, 20)
	}
	return Color.rgb(255, 255, 255)
}

pub fn SystemColor.link_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(100, 149, 237)
	}
	return Color.rgb(0, 0, 238)
}

pub fn SystemColor.mark(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(255, 255, 0)
}

pub fn SystemColor.mark_text(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(0, 0, 0)
}

pub fn SystemColor.selected_item(scheme PreferredColorScheme) Color {
	_ = scheme
	return Color.rgb(61, 174, 233)
}

pub fn SystemColor.selected_item_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(20, 20, 20)
	}
	return Color.rgb(255, 255, 255)
}

pub fn SystemColor.visited_text(scheme PreferredColorScheme) Color {
	if scheme == .dark {
		return Color.rgb(156, 113, 212)
	}
	return Color.rgb(85, 26, 139)
}

// https://drafts.csswg.org/css-values-5/#request-url-modifiers
pub enum RequestURLModifierType {
	cross_origin
	integrity
	referrer_policy
}

pub enum CrossOriginModifierValue {
	anonymous
	use_credentials
}

pub fn (value CrossOriginModifierValue) to_string() string {
	return match value {
		.anonymous { 'anonymous' }
		.use_credentials { 'use-credentials' }
	}
}

pub enum ReferrerPolicyModifierValue {
	no_referrer
	no_referrer_when_downgrade
	same_origin
	origin
	strict_origin
	origin_when_cross_origin
	strict_origin_when_cross_origin
	unsafe_url
}

pub fn (value ReferrerPolicyModifierValue) to_string() string {
	return match value {
		.no_referrer { 'no-referrer' }
		.no_referrer_when_downgrade { 'no-referrer-when-downgrade' }
		.same_origin { 'same-origin' }
		.origin { 'origin' }
		.strict_origin { 'strict-origin' }
		.origin_when_cross_origin { 'origin-when-cross-origin' }
		.strict_origin_when_cross_origin { 'strict-origin-when-cross-origin' }
		.unsafe_url { 'unsafe-url' }
	}
}

// Staging projection used while applying CSS <request-url-modifier> values. It is
// converted to Fetch::Request by fetch_a_style_resource() before dispatch.
pub enum CSSRequestMode {
	cors
	no_cors
}

pub enum CSSRequestCredentialsMode {
	include
	same_origin
}

pub enum CSSRequestDestination {
	empty
	image
	font
	style
}

pub enum CSSRequestInitiatorType {
	css
	script
}

pub enum CSSReferrerPolicy {
	no_referrer
	no_referrer_when_downgrade
	same_origin
	origin
	strict_origin
	origin_when_cross_origin
	strict_origin_when_cross_origin
	unsafe_url
}

pub struct CSSRequest {
pub mut:
	mode                ?CSSRequestMode
	credentials_mode    ?CSSRequestCredentialsMode
	integrity_metadata  string
	referrer_policy     ?CSSReferrerPolicy
	url                 string
	destination         CSSRequestDestination
	origin              string
	use_url_credentials bool
	client_base_url     string
	client ?fetch.RequestClient
	referrer            string
	initiator_type      ?CSSRequestInitiatorType
}

pub type RequestURLModifierValue = CrossOriginModifierValue
	| ReferrerPolicyModifierValue
	| string

pub struct RequestURLModifier {
pub mut:
	type_  RequestURLModifierType
	value_ RequestURLModifierValue
}

pub fn RequestURLModifier.create_cross_origin(value CrossOriginModifierValue) RequestURLModifier {
	return RequestURLModifier{
		type_: .cross_origin
		value_: value
	}
}

pub fn RequestURLModifier.create_integrity(value string) RequestURLModifier {
	return RequestURLModifier{
		type_: .integrity
		value_: value
	}
}

pub fn RequestURLModifier.create_referrer_policy(value ReferrerPolicyModifierValue) RequestURLModifier {
	return RequestURLModifier{
		type_: .referrer_policy
		value_: value
	}
}

pub fn (modifier RequestURLModifier) type_() RequestURLModifierType {
	return modifier.type_
}

pub fn (modifier RequestURLModifier) modify_request(mut request CSSRequest) {
	match modifier.type_ {
		.cross_origin {
			// https://drafts.csswg.org/css-values-5/#typedef-request-url-modifier-crossorigin-modifier
			// The URL request modifier steps for this modifier given request req are:

			// 1. Set req's mode to "cors".
			request.mode = .cors

			// 2. If the given value is use-credentials, set req's credentials mode to "include".
			value := modifier.value_ as CrossOriginModifierValue
			if value == .use_credentials {
				request.credentials_mode = .include
			} else {
				// 3. Otherwise, set req's credentials mode to "same-origin".
				request.credentials_mode = .same_origin
			}
		}
		.integrity {
			// https://drafts.csswg.org/css-values-5/#typedef-request-url-modifier-integrity-modifier

			// The URL request modifier steps for this modifier given request req are to set request's integrity metadata to
			// the given <string>.
			request.integrity_metadata = modifier.value_ as string
		}
		.referrer_policy {
			// https://drafts.csswg.org/css-values-5/#typedef-request-url-modifier-referrerpolicy-modifier
			// The URL request modifier steps for this modifier given request req are to set request's referrer policy to the
			// ReferrerPolicy that matches the given value.
			value := modifier.value_ as ReferrerPolicyModifierValue
			request.referrer_policy = match value {
				.no_referrer { CSSReferrerPolicy.no_referrer }
				.no_referrer_when_downgrade { CSSReferrerPolicy.no_referrer_when_downgrade }
				.same_origin { CSSReferrerPolicy.same_origin }
				.origin { CSSReferrerPolicy.origin }
				.strict_origin { CSSReferrerPolicy.strict_origin }
				.origin_when_cross_origin { CSSReferrerPolicy.origin_when_cross_origin }
				.strict_origin_when_cross_origin {
					CSSReferrerPolicy.strict_origin_when_cross_origin
				}
				.unsafe_url { CSSReferrerPolicy.unsafe_url }
			}
		}
	}
}

// RequestURLModifier::operator== is defaulted in C++; compare the stored type
// and the matching variant value.
pub fn (modifier RequestURLModifier) equals(other RequestURLModifier) bool {
	if modifier.type_ != other.type_ {
		return false
	}
	return match modifier.type_ {
		.cross_origin {
			(modifier.value_ as CrossOriginModifierValue) == (other.value_ as CrossOriginModifierValue)
		}
		.integrity {
			(modifier.value_ as string) == (other.value_ as string)
		}
		.referrer_policy {
			(modifier.value_ as ReferrerPolicyModifierValue) == (other.value_ as ReferrerPolicyModifierValue)
		}
	}
}

pub fn (modifier RequestURLModifier) to_string() string {
	return match modifier.type_ {
		.cross_origin {
			value := modifier.value_ as CrossOriginModifierValue
			'cross-origin(${value})'
		}
		.integrity {
			value := modifier.value_ as string
			'integrity(${serialize_a_string(value)})'
		}
		.referrer_policy {
			value := modifier.value_ as ReferrerPolicyModifierValue
			'referrer-policy(${value})'
		}
	}
}

// https://drafts.csswg.org/css-values-4/#urls
pub enum URLType {
	url
	src
}

pub struct URL {
pub mut:
	type_                 URLType
	url_                  string
	request_url_modifiers []RequestURLModifier
}

pub fn URL.new(url string, type_ URLType, request_url_modifiers []RequestURLModifier) URL {
	return URL{
		type_: type_
		url_: url
		request_url_modifiers: request_url_modifiers
	}
}

pub fn URL.from_url(url string) URL {
	return URL.new(url, .url, []RequestURLModifier{})
}

pub fn URL.from_src(url string, request_url_modifiers []RequestURLModifier) URL {
	return URL.new(url, .src, request_url_modifiers)
}

pub fn (url URL) url() string {
	return url.url_
}

pub fn (url URL) request_url_modifiers() []RequestURLModifier {
	return url.request_url_modifiers
}

fn request_url_modifier_lists_equal(left []RequestURLModifier, right []RequestURLModifier) bool {
	if left.len != right.len {
		return false
	}
	for i, modifier in left {
		if !modifier.equals(right[i]) {
			return false
		}
	}
	return true
}

// URL::operator== is defaulted in C++; compare the type, URL string, and
// request URL modifiers in order.
pub fn (url URL) equals(other URL) bool {
	return url.type_ == other.type_ && url.url_ == other.url_ && request_url_modifier_lists_equal(url.request_url_modifiers, other.request_url_modifiers)
}

// https://drafts.csswg.org/cssom-1/#serialize-a-url
pub fn (url URL) to_string() string {
	// To serialize a URL means to create a string represented by "url(", followed by the serialization of the URL as a
	// string, followed by ")".
	// AD-HOC: Serialize as src() if it was declared as that.
	mut serialized := match url.type_ {
		.url { 'url(' }
		.src { 'src(' }
	}

	serialized += serialize_a_string(url.url_)

	// AD-HOC: Serialize the RequestURLModifiers
	// Spec issue: https://github.com/w3c/csswg-drafts/issues/12057
	for modifier in url.request_url_modifiers {
		serialized += ' ${modifier}'
	}

	serialized += ')'
	return serialized
}

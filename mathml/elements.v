// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MathMLElement.cpp, MathMLMiElement.cpp, and
// MathMLMspaceElement.cpp. The DOM binding layer is represented by a typed
// element record; the observable presentational-hint algorithms are complete.
module mathml

import css
import dom

pub enum MathDepthKind {
	absolute
	add
}

pub struct MathDepthHint {
pub:
	kind  MathDepthKind
	value int
}

pub struct PresentationalHints {
pub mut:
	direction        ?string
	color            ?string
	background_color ?string
	font_size        ?string
	math_style       ?string
	math_depth       ?MathDepthHint
	text_transform   ?string
	width            ?string
	height           ?string
}

@[heap]
pub struct MathMLElement {
pub:
	local_name string
pub mut:
	attributes map[string]string
mut:
	cryptographic_nonce_       string
	event_target_              &dom.EventTarget = unsafe { nil }
	browsing_context_connected bool
	has_header_delivered_csp   bool
}

pub fn MathMLElement.create(local_name string) &MathMLElement {
	return &MathMLElement{
		local_name: local_name
		attributes: map[string]string{}
		event_target_: &dom.EventTarget{}
	}
}

pub fn (mut element MathMLElement) set_attribute(name string, value string) {
	old_value := element.attributes[name]
	element.attributes[name] = value
	element.attribute_changed(name, old_value, value, none)
}

pub fn (mut element MathMLElement) remove_attribute(name string) {
	old_value := element.attributes[name]
	element.attributes.delete(name)
	element.attribute_changed(name, old_value, none, none)
}

pub fn (element &MathMLElement) attribute(name string) ?string {
	return element.attributes[name]
}

// HTMLOrSVGElement's nonce attribute-change steps.
pub fn (mut element MathMLElement) attribute_changed(local_name string, _ ?string, value ?string, namespace_ ?string) {
	if local_name != 'nonce' || namespace_ != none {
		return
	}
	element.cryptographic_nonce_ = value or { '' }
}

pub fn (element &MathMLElement) cloned(mut copy MathMLElement, _ bool) ! {
	copy.cryptographic_nonce_ = element.cryptographic_nonce_
}

// These two values come from the element's shadow-including root in C++.
pub fn (mut element MathMLElement) set_insertion_policy_state(browsing_context_connected bool, has_header_delivered_csp bool) {
	element.browsing_context_connected = browsing_context_connected
	element.has_header_delivered_csp = has_header_delivered_csp
}

pub fn (mut element MathMLElement) inserted() {
	if !element.browsing_context_connected || !element.has_header_delivered_csp || 'nonce' !in element.attributes {
		return
	}
	nonce := element.cryptographic_nonce_
	element.set_attribute('nonce', '')
	element.cryptographic_nonce_ = nonce
}

pub fn (element &MathMLElement) nonce() string {
	return element.cryptographic_nonce_
}

pub fn (mut element MathMLElement) set_nonce(nonce string) {
	element.cryptographic_nonce_ = nonce
}

pub fn (element &MathMLElement) global_event_handlers_to_event_target(_ string) &dom.EventTarget {
	return element.event_target_
}

// https://www.w3.org/TR/html-aria/#el-math
pub fn (element &MathMLElement) default_role() ?string {
	if element.local_name == 'math' {
		return 'math'
	}
	return none
}

pub fn (element &MathMLElement) is_presentational_hint(name string) bool {
	return name in ['dir', 'mathcolor', 'mathbackground', 'mathsize', 'displaystyle', 'scriptlevel']
}

fn ascii_lower(value string) string {
	mut bytes := value.bytes()
	for mut byte in bytes {
		if byte >= `A` && byte <= `Z` {
			byte += 32
		}
	}
	return bytes.bytestr()
}

fn parse_script_level(value string) ?MathDepthHint {
	if value.len == 0 {
		return none
	}
	mut offset := 0
	for offset < value.len && value[offset] in [`\t`, `\n`, `\f`, `\r`, ` `] {
		offset++
	}
	if offset == value.len {
		return none
	}
	mut kind := MathDepthKind.absolute
	mut sign := 1
	if value[offset] == `+` || value[offset] == `-` {
		kind = .add
		if value[offset] == `-` {
			sign = -1
		}
		offset++
	}
	if offset == value.len {
		return none
	}
	mut number := i64(0)
	mut digit_count := 0
	for byte in value[offset..] {
		if byte < `0` || byte > `9` {
			break
		}
		digit_count++
		number = number * 10 + i64(byte - `0`)
		if number > 2147483648 {
			return none
		}
	}
	if digit_count == 0 {
		return none
	}
	signed := number * sign
	if signed < -2147483648 || signed > 2147483647 {
		return none
	}
	return MathDepthHint{
		kind: kind
		value: int(signed)
	}
}

fn has_css_length_unit(value string) bool {
	lower := ascii_lower(value)
	for unit in ['px', 'cm', 'mm', 'q', 'in', 'pc', 'pt', 'em', 'rem', 'ex', 'rex', 'cap', 'rcap',
		'ch', 'rch', 'ic', 'ric', 'lh', 'rlh', 'vw', 'svw', 'lvw', 'dvw', 'vh', 'svh', 'lvh', 'dvh',
		'vi', 'svi', 'lvi', 'dvi', 'vb', 'svb', 'lvb', 'dvb', 'vmin', 'svmin', 'lvmin', 'dvmin',
		'vmax', 'svmax', 'lvmax', 'dvmax'] {
		if lower.ends_with(unit) {
			return true
		}
	}
	return false
}

fn is_zero_number(value string) bool {
	if value.len == 0 {
		return false
	}
	mut saw_digit := false
	for index, byte in value {
		is_leading_sign := (byte == `+` || byte == `-`) && index == 0
		if byte >= `0` && byte <= `9` {
			saw_digit = true
			if byte != `0` {
				return false
			}
		} else if byte == `.` || is_leading_sign {
			continue
		} else {
			return false
		}
	}
	return saw_digit
}

fn has_length_syntax(value string, percentages bool) bool {
	trimmed := value.trim_space()
	lower := ascii_lower(trimmed)
	if lower.starts_with('calc(') || lower.starts_with('min(') || lower.starts_with('max(') || lower.starts_with('clamp(') {
		return percentages || !lower.contains('%')
	}
	if trimmed.ends_with('%') {
		return percentages
	}
	return has_css_length_unit(trimmed) || is_zero_number(trimmed)
}

fn parse_length_hint(value string, property css.PropertyID, percentages bool) ?string {
	parsed := css.parse_css_value(css.ParsingParams{}, value, property) or { return none }
	if !has_length_syntax(value, percentages) {
		return none
	}
	return parsed.css_text
}

pub fn (element &MathMLElement) apply_presentational_hints() PresentationalHints {
	mut hints := PresentationalHints{}
	for name, value in element.attributes {
		match name {
			'dir' {
				lower := ascii_lower(value)
				if lower == 'ltr' || lower == 'rtl' {
					hints.direction = lower
				}
			}
			'mathcolor' {
				if parsed := css.parse_css_value(css.ParsingParams{}, value, .color) {
					hints.color = parsed.css_text
				}
			}
			'mathbackground' {
				if parsed := css.parse_css_value(css.ParsingParams{}, value, .background_color) {
					hints.background_color = parsed.css_text
				}
			}
			'mathsize' {
				if parsed := parse_length_hint(value, .font_size, true) {
					hints.font_size = parsed
				}
			}
			'displaystyle' {
				lower := ascii_lower(value)
				if lower == 'true' {
					hints.math_style = 'normal'
				} else if lower == 'false' {
					hints.math_style = 'compact'
				}
			}
			'scriptlevel' {
				hints.math_depth = parse_script_level(value)
			}
			else {}
		}
	}
	return hints
}

@[heap]
pub struct MathMLMiElement {
	MathMLElement
}

pub fn MathMLMiElement.create() &MathMLMiElement {
	return &MathMLMiElement{
		MathMLElement: MathMLElement{
			local_name: 'mi'
			attributes: map[string]string{}
			event_target_: &dom.EventTarget{}
		}
	}
}

pub fn (element &MathMLMiElement) is_presentational_hint(name string) bool {
	return element.MathMLElement.is_presentational_hint(name) || name == 'mathvariant'
}

pub fn (element &MathMLMiElement) apply_presentational_hints() PresentationalHints {
	mut hints := element.MathMLElement.apply_presentational_hints()
	if value := element.attributes['mathvariant'] {
		if ascii_lower(value) == 'normal' {
			hints.text_transform = 'none'
		}
	}
	return hints
}

@[heap]
pub struct MathMLMspaceElement {
	MathMLElement
}

pub fn MathMLMspaceElement.create() &MathMLMspaceElement {
	return &MathMLMspaceElement{
		MathMLElement: MathMLElement{
			local_name: 'mspace'
			attributes: map[string]string{}
			event_target_: &dom.EventTarget{}
		}
	}
}

pub fn (element &MathMLMspaceElement) is_presentational_hint(name string) bool {
	return element.MathMLElement.is_presentational_hint(name) || name in ['width', 'height', 'depth']
}

pub fn (element &MathMLMspaceElement) apply_presentational_hints() PresentationalHints {
	mut hints := element.MathMLElement.apply_presentational_hints()
	mut height := ?string(none)
	mut depth := ?string(none)
	if value := element.attributes['width'] {
		hints.width = parse_length_hint(value, .width, false)
	}
	if value := element.attributes['height'] {
		height = parse_length_hint(value, .height, false)
	}
	if value := element.attributes['depth'] {
		depth = parse_length_hint(value, .height, false)
	}
	if height_value := height {
		if depth_value := depth {
			combined := 'calc(${height_value} + ${depth_value})'
			if parsed := css.parse_css_value(css.ParsingParams{}, combined, .height) {
				hints.height = parsed.css_text
			}
		} else {
			hints.height = height_value
		}
	} else if depth_value := depth {
		hints.height = depth_value
	}
	// Upstream also leaves requested line-ascent as FIXME.
	return hints
}

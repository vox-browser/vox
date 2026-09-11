// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MathMLElement.cpp, MathMLAnchorElement.cpp,
// MathMLMiElement.cpp, and MathMLMspaceElement.cpp. The DOM binding layer is
// represented by typed element records; the observable element algorithms are
// complete.
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

// MathMLAnchorElement includes HTML's HyperlinkElementUtils mixin. Keep its URL
// record next to the typed MathML element while sharing the translated DOM URL
// parser and component operations with HTML anchors.
@[heap]
pub struct MathMLAnchorElement {
	MathMLElement
mut:
	document_url_ dom.URL
	url_          ?dom.URL
}

pub fn MathMLAnchorElement.create(document_url dom.URL) &MathMLAnchorElement {
	return &MathMLAnchorElement{
		MathMLElement: MathMLElement{
			local_name: 'a'
			attributes: map[string]string{}
			event_target_: &dom.EventTarget{}
		}
		document_url_: document_url
	}
}

pub fn (mut element MathMLAnchorElement) set_attribute(name string, value string) {
	element.MathMLElement.set_attribute(name, value)
	if name == 'href' {
		element.url_ = none
	}
}

pub fn (mut element MathMLAnchorElement) remove_attribute(name string) {
	element.MathMLElement.remove_attribute(name)
	if name == 'href' {
		element.url_ = none
	}
}

pub fn (mut element MathMLAnchorElement) set_document_url(document_url dom.URL) {
	element.document_url_ = document_url
	element.url_ = none
}

// The two const/non-const C++ overloads collapse into this V entry point.
pub fn (element &MathMLAnchorElement) hyperlink_element_utils_element() &MathMLElement {
	return &element.MathMLElement
}

pub fn (mut element MathMLAnchorElement) reinitialize_url() {
	if url := element.url_ {
		if url.scheme() == 'blob' && url.has_an_opaque_path() {
			return
		}
	}
	element.set_the_url()
}

// https://w3c.github.io/mathml-core/#dfn-set-the-url
pub fn (mut element MathMLAnchorElement) set_the_url() {
	element.url_ = none
	href := element.attributes['href'] or { return }
	if url := dom.dom_url_parse(href, element.document_url_, 'UTF-8') {
		element.url_ = url
	}
}

// https://w3c.github.io/mathml-core/#dfn-update-href
pub fn (mut element MathMLAnchorElement) update_href() {
	url := element.url_ or { return }
	element.MathMLElement.set_attribute('href', url.serialize())
}

fn (mut element MathMLAnchorElement) current_url() ?dom.URL {
	element.reinitialize_url()
	return element.url_
}

fn (mut element MathMLAnchorElement) replace_url(url dom.URL) {
	element.url_ = url
	element.update_href()
}

// https://w3c.github.io/mathml-core/#dom-mathmlanchorelement-href
pub fn (mut element MathMLAnchorElement) href() string {
	url := element.current_url() or { return element.attributes['href'] or { '' } }
	return url.serialize()
}

pub fn (mut element MathMLAnchorElement) set_href(href string) {
	element.set_attribute('href', href)
}

pub fn (mut element MathMLAnchorElement) origin() string {
	url := element.current_url() or { return '' }
	return url.origin().serialize()
}

pub fn (mut element MathMLAnchorElement) protocol() string {
	url := element.current_url() or { return ':' }
	return '${url.scheme()}:'
}

pub fn (mut element MathMLAnchorElement) set_protocol(protocol string) {
	url := element.current_url() or { return }
	element.replace_url(url.with_protocol(protocol))
}

pub fn (mut element MathMLAnchorElement) username() string {
	url := element.current_url() or { return '' }
	return url.username()
}

pub fn (mut element MathMLAnchorElement) set_username(username string) {
	url := element.current_url() or { return }
	if !url.cannot_have_a_username_or_password_or_port() {
		element.replace_url(url.with_username(username))
	}
}

pub fn (mut element MathMLAnchorElement) password() string {
	url := element.current_url() or { return '' }
	return url.password()
}

pub fn (mut element MathMLAnchorElement) set_password(password string) {
	url := element.current_url() or { return }
	if !url.cannot_have_a_username_or_password_or_port() {
		element.replace_url(url.with_password(password))
	}
}

pub fn (mut element MathMLAnchorElement) host() string {
	url := element.current_url() or { return '' }
	if url.host() == none {
		return ''
	}
	port := url.port() or { return url.serialized_host() }
	return '${url.serialized_host()}:${port}'
}

pub fn (mut element MathMLAnchorElement) set_host(host string) {
	url := element.current_url() or { return }
	if !url.has_an_opaque_path() {
		element.replace_url(url.with_host(host))
	}
}

pub fn (mut element MathMLAnchorElement) hostname() string {
	url := element.current_url() or { return '' }
	return if url.host() == none { '' } else { url.serialized_host() }
}

pub fn (mut element MathMLAnchorElement) set_hostname(hostname string) {
	url := element.current_url() or { return }
	if !url.has_an_opaque_path() {
		element.replace_url(url.with_hostname(hostname))
	}
}

pub fn (mut element MathMLAnchorElement) port() string {
	url := element.current_url() or { return '' }
	port := url.port() or { return '' }
	return port.str()
}

pub fn (mut element MathMLAnchorElement) set_port(port string) {
	url := element.current_url() or { return }
	if !url.cannot_have_a_username_or_password_or_port() {
		element.replace_url(url.with_port(port))
	}
}

pub fn (mut element MathMLAnchorElement) pathname() string {
	url := element.current_url() or { return '' }
	return url.serialize_path()
}

pub fn (mut element MathMLAnchorElement) set_pathname(pathname string) {
	url := element.current_url() or { return }
	if !url.has_an_opaque_path() {
		element.replace_url(url.with_pathname(pathname))
	}
}

pub fn (mut element MathMLAnchorElement) search() string {
	url := element.current_url() or { return '' }
	query := url.query() or { return '' }
	return if query == '' { '' } else { '?${query}' }
}

pub fn (mut element MathMLAnchorElement) set_search(search string) {
	url := element.current_url() or { return }
	if search == '' {
		element.replace_url(url.with_query(none))
		return
	}
	input := if search.starts_with('?') { search#[1..] } else { search }
	element.replace_url(url.with_query(input))
}

pub fn (mut element MathMLAnchorElement) hash() string {
	url := element.current_url() or { return '' }
	fragment := url.fragment() or { return '' }
	return if fragment == '' { '' } else { '#${fragment}' }
}

pub fn (mut element MathMLAnchorElement) set_hash(hash string) {
	mut url := element.current_url() or { return }
	if hash == '' {
		url.set_fragment(none)
	} else {
		input := if hash.starts_with('#') { hash#[1..] } else { hash }
		url.set_fragment(input)
	}
	element.replace_url(url)
}

pub fn (element &MathMLAnchorElement) target() string {
	return element.attributes['target'] or { '' }
}

pub fn (mut element MathMLAnchorElement) set_target(target string) {
	element.set_attribute('target', target)
}

pub fn (element &MathMLAnchorElement) hreflang() string {
	return element.attributes['hreflang'] or { '' }
}

pub fn (mut element MathMLAnchorElement) set_hreflang(hreflang string) {
	element.set_attribute('hreflang', hreflang)
}

pub fn (element &MathMLAnchorElement) type_() string {
	return element.attributes['type'] or { '' }
}

pub fn (mut element MathMLAnchorElement) set_type(type_ string) {
	element.set_attribute('type', type_)
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

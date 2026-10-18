// Copyright (c) 2020, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/HTMLHyperlinkElementUtils.cpp.
//
// In C++ this is a mixin with a cached m_url (Optional<URL::URL>). The V DOM's
// HTMLElement base stores that per-element URL record so anchors and areas run
// the same reinitialization and component-setter algorithms.
module html

import dom

fn hyperlink_html_element(element &dom.Element) &dom.HTMLElement {
	return unsafe { &dom.HTMLElement(element) }
}

// https://html.spec.whatwg.org/multipage/links.html#concept-hyperlink-url-set
pub fn html_hyperlink_element_utils_set_the_url(element &dom.Element) {
	mut html_element := unsafe { &dom.HTMLElement(hyperlink_html_element(element)) }
	html_element.initialize_null_hyperlink_url_cache()
	href := element.get_attribute(attr_href) or { return }
	if url := element.document().encoding_parse_url(href) {
		html_element.set_hyperlink_url_cache(url)
	}
}

// https://html.spec.whatwg.org/multipage/links.html#reinitialise-url
pub fn html_hyperlink_element_utils_reinitialize_url(element &dom.Element) {
	// The serialized href is the stable V boundary for DOM URLs. Reparse it on
	// reinitialization instead of binding Optional<URL> out of an embedded
	// HTMLElement; that optional struct binding can retain a dangling copy of
	// URL.value after the element's attribute storage changes.
	html_hyperlink_element_utils_set_the_url(element)
}

fn hyperlink_url(element &dom.Element) ?dom.URL {
	html_hyperlink_element_utils_reinitialize_url(element)
	href := element.get_attribute(attr_href) or { return none }
	return element.document().encoding_parse_url(href)
}

// https://html.spec.whatwg.org/multipage/links.html#update-href
pub fn html_hyperlink_element_utils_update_href(element &dom.Element) {
	url := hyperlink_url(element) or { return }
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_attribute_value(attr_href, url.serialize())
}

fn hyperlink_update_href(mut element dom.Element, url dom.URL) {
	mut html_element := unsafe { &dom.HTMLElement(hyperlink_html_element(&element)) }
	html_element.set_hyperlink_url_cache(url)
	element.set_attribute_value(attr_href, url.serialize())
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-origin
pub fn hyperlink_origin(element &dom.Element) string {
	return html_hyperlink_element_utils_origin(element)
}

pub fn html_hyperlink_element_utils_origin(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.origin().serialize()
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
pub fn hyperlink_href(element &dom.Element) string {
	return html_hyperlink_element_utils_href(element)
}

pub fn html_hyperlink_element_utils_href(element &dom.Element) string {
	url := hyperlink_url(element) or {
		// url is null: return the href content attribute's value, or the empty string.
		return element.get_attribute(attr_href) or { '' }
	}
	return url.serialize()
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
pub fn set_hyperlink_href(mut element dom.Element, href string) {
	html_hyperlink_element_utils_set_href(&element, href)
}

pub fn html_hyperlink_element_utils_set_href(element &dom.Element, href string) {
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_attribute_value(attr_href, href)
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-protocol
pub fn hyperlink_protocol(element &dom.Element) string {
	return html_hyperlink_element_utils_protocol(element)
}

pub fn html_hyperlink_element_utils_protocol(element &dom.Element) string {
	url := hyperlink_url(element) or { return ':' }
	return '${url.scheme()}:'
}

pub fn set_hyperlink_protocol(mut element dom.Element, protocol string) {
	html_hyperlink_element_utils_set_protocol(&element, protocol)
}

pub fn html_hyperlink_element_utils_set_protocol(element &dom.Element, protocol string) {
	url := hyperlink_url(element) or { return }
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_protocol(protocol))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-username
pub fn hyperlink_username(element &dom.Element) string {
	return html_hyperlink_element_utils_username(element)
}

pub fn html_hyperlink_element_utils_username(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.username()
}

pub fn set_hyperlink_username(mut element dom.Element, username string) {
	html_hyperlink_element_utils_set_username(&element, username)
}

pub fn html_hyperlink_element_utils_set_username(element &dom.Element, username string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_username(username))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-password
pub fn hyperlink_password(element &dom.Element) string {
	return html_hyperlink_element_utils_password(element)
}

pub fn html_hyperlink_element_utils_password(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.password()
}

pub fn set_hyperlink_password(mut element dom.Element, password string) {
	html_hyperlink_element_utils_set_password(&element, password)
}

pub fn html_hyperlink_element_utils_set_password(element &dom.Element, password string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_password(password))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-host
pub fn hyperlink_host(element &dom.Element) string {
	return html_hyperlink_element_utils_host(element)
}

pub fn html_hyperlink_element_utils_host(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	if url.host() == none {
		return ''
	}
	port := url.port() or { return url.serialized_host() }
	return '${url.serialized_host()}:${port}'
}

pub fn set_hyperlink_host(mut element dom.Element, host string) {
	html_hyperlink_element_utils_set_host(&element, host)
}

pub fn html_hyperlink_element_utils_set_host(element &dom.Element, host string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_host(host))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hostname
pub fn hyperlink_hostname(element &dom.Element) string {
	return html_hyperlink_element_utils_hostname(element)
}

pub fn html_hyperlink_element_utils_hostname(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	if url.host() == none {
		return ''
	}
	return url.serialized_host()
}

pub fn set_hyperlink_hostname(mut element dom.Element, hostname string) {
	html_hyperlink_element_utils_set_hostname(&element, hostname)
}

pub fn html_hyperlink_element_utils_set_hostname(element &dom.Element, hostname string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_hostname(hostname))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-port
pub fn hyperlink_port(element &dom.Element) string {
	return html_hyperlink_element_utils_port(element)
}

pub fn html_hyperlink_element_utils_port(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	port := url.port() or { return '' }
	return port.str()
}

pub fn set_hyperlink_port(mut element dom.Element, port string) {
	html_hyperlink_element_utils_set_port(&element, port)
}

pub fn html_hyperlink_element_utils_set_port(element &dom.Element, port string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	// An empty value clears the port; otherwise parse with port state as state override.
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_port(port))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-pathname
pub fn hyperlink_pathname(element &dom.Element) string {
	return html_hyperlink_element_utils_pathname(element)
}

pub fn html_hyperlink_element_utils_pathname(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.serialize_path()
}

pub fn set_hyperlink_pathname(mut element dom.Element, pathname string) {
	html_hyperlink_element_utils_set_pathname(&element, pathname)
}

pub fn html_hyperlink_element_utils_set_pathname(element &dom.Element, pathname string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	hyperlink_update_href(mut mutable_element, url.with_pathname(pathname))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-search
pub fn hyperlink_search(element &dom.Element) string {
	return html_hyperlink_element_utils_search(element)
}

pub fn html_hyperlink_element_utils_search(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	query := url.query() or { return '' }
	if query.len == 0 {
		return ''
	}
	return '?${query}'
}

pub fn set_hyperlink_search(mut element dom.Element, search string) {
	html_hyperlink_element_utils_set_search(&element, search)
}

pub fn html_hyperlink_element_utils_set_search(element &dom.Element, search string) {
	url := hyperlink_url(element) or { return }
	mut mutable_element := unsafe { &dom.Element(element) }
	if search.len == 0 {
		hyperlink_update_href(mut mutable_element, url.with_query(none))
		return
	}
	// Remove a single leading "?", then parse with query state as state override.
	input := if search.starts_with('?') { search#[1..] } else { search }
	hyperlink_update_href(mut mutable_element, url.with_query(input))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hash
pub fn hyperlink_hash(element &dom.Element) string {
	return html_hyperlink_element_utils_hash(element)
}

pub fn html_hyperlink_element_utils_hash(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	fragment := url.fragment() or { return '' }
	if fragment.len == 0 {
		return ''
	}
	return '#${fragment}'
}

pub fn set_hyperlink_hash(mut element dom.Element, hash string) {
	html_hyperlink_element_utils_set_hash(&element, hash)
}

pub fn html_hyperlink_element_utils_set_hash(element &dom.Element, hash string) {
	mut url := hyperlink_url(element) or { return }
	mut mutable_element := unsafe { &dom.Element(element) }
	if hash.len == 0 {
		url.set_fragment(none)
		hyperlink_update_href(mut mutable_element, url)
		return
	}
	// Remove a single leading "#", then parse with fragment state as state override.
	input := if hash.starts_with('#') { hash#[1..] } else { hash }
	url.set_fragment(input)
	hyperlink_update_href(mut mutable_element, url)
}

pub fn html_hyperlink_element_utils_extract_an_origin(element &dom.Element) ?dom.Origin {
	url := hyperlink_html_element(element).cached_hyperlink_url() or { return none }
	return url.origin()
}

pub fn html_hyperlink_element_utils_hyperlink_element_utils_extract_an_origin(element &dom.Element) ?dom.Origin {
	return html_hyperlink_element_utils_extract_an_origin(element)
}

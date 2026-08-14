// Copyright (c) 2020, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/HTMLHyperlinkElementUtils.cpp.
//
// In C++ this is a mixin with a cached m_url (Optional<URL::URL>); reinitialize_url() recomputes
// it from the element's href content attribute. This port has no place to cache per-element state,
// so the URL is derived fresh from the href attribute on each access (matching reinitialize_url's
// set-the-url step, minus the blob-opaque-path early return). The component setters delegate to
// dom.URL's urllib-backed setters (which approximate URL::Parser::basic_parse with state override).
module html

import dom

// reinitialize url + set the url: parse the href content attribute relative to the node document.
// Returns none when there is no href attribute or it fails to parse.
fn hyperlink_url(element &dom.Element) ?dom.URL {
	href := element.get_attribute(attr_href) or { return none }
	return element.document().encoding_parse_url(href)
}

// https://html.spec.whatwg.org/multipage/links.html#update-href
fn hyperlink_update_href(mut element dom.Element, url dom.URL) {
	element.set_attribute_value(attr_href, url.serialize())
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-origin
pub fn hyperlink_origin(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.origin().serialize()
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
pub fn hyperlink_href(element &dom.Element) string {
	url := hyperlink_url(element) or {
		// url is null: return the href content attribute's value, or the empty string.
		return element.get_attribute(attr_href) or { '' }
	}
	return url.serialize()
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
pub fn set_hyperlink_href(mut element dom.Element, href string) {
	element.set_attribute_value(attr_href, href)
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-protocol
pub fn hyperlink_protocol(element &dom.Element) string {
	url := hyperlink_url(element) or { return ':' }
	return '${url.scheme()}:'
}

pub fn set_hyperlink_protocol(mut element dom.Element, protocol string) {
	url := hyperlink_url(element) or { return }
	// Basic URL parse "<protocol>:" with scheme start state as state override.
	hyperlink_update_href(mut element, url.with_protocol(protocol))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-username
pub fn hyperlink_username(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.username()
}

pub fn set_hyperlink_username(mut element dom.Element, username string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	hyperlink_update_href(mut element, url.with_username(username))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-password
pub fn hyperlink_password(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.password()
}

pub fn set_hyperlink_password(mut element dom.Element, password string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	hyperlink_update_href(mut element, url.with_password(password))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-host
pub fn hyperlink_host(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	if url.host() == none {
		return ''
	}
	port := url.port() or { return url.serialized_host() }
	return '${url.serialized_host()}:${port}'
}

pub fn set_hyperlink_host(mut element dom.Element, host string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	hyperlink_update_href(mut element, url.with_host(host))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hostname
pub fn hyperlink_hostname(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	if url.host() == none {
		return ''
	}
	return url.serialized_host()
}

pub fn set_hyperlink_hostname(mut element dom.Element, hostname string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	hyperlink_update_href(mut element, url.with_hostname(hostname))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-port
pub fn hyperlink_port(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	port := url.port() or { return '' }
	return port.str()
}

pub fn set_hyperlink_port(mut element dom.Element, port string) {
	url := hyperlink_url(element) or { return }
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	// An empty value clears the port; otherwise parse with port state as state override.
	hyperlink_update_href(mut element, url.with_port(port))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-pathname
pub fn hyperlink_pathname(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	return url.serialize_path()
}

pub fn set_hyperlink_pathname(mut element dom.Element, pathname string) {
	url := hyperlink_url(element) or { return }
	if url.has_an_opaque_path() {
		return
	}
	hyperlink_update_href(mut element, url.with_pathname(pathname))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-search
pub fn hyperlink_search(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	query := url.query() or { return '' }
	if query.len == 0 {
		return ''
	}
	return '?${query}'
}

pub fn set_hyperlink_search(mut element dom.Element, search string) {
	url := hyperlink_url(element) or { return }
	if search.len == 0 {
		hyperlink_update_href(mut element, url.with_query(none))
		return
	}
	// Remove a single leading "?", then parse with query state as state override.
	input := if search.starts_with('?') { search#[1..] } else { search }
	hyperlink_update_href(mut element, url.with_query(input))
}

// https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hash
pub fn hyperlink_hash(element &dom.Element) string {
	url := hyperlink_url(element) or { return '' }
	fragment := url.fragment() or { return '' }
	if fragment.len == 0 {
		return ''
	}
	return '#${fragment}'
}

pub fn set_hyperlink_hash(mut element dom.Element, hash string) {
	mut url := hyperlink_url(element) or { return }
	if hash.len == 0 {
		url.set_fragment(none)
		hyperlink_update_href(mut element, url)
		return
	}
	// Remove a single leading "#", then parse with fragment state as state override.
	input := if hash.starts_with('#') { hash#[1..] } else { hash }
	url.set_fragment(input)
	hyperlink_update_href(mut element, url)
}

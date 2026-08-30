// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/ProxyMappings.{h,cpp}.
module loader

import dom

pub enum ProxyType {
	http
	https
	socks5
}

pub struct ProxyData {
pub:
	type_    ProxyType
	host     string
	port     u16
	username string
	password string
}

pub struct ProxyMapping {
pub:
	pattern     string
	proxy_index usize
}

pub struct ProxyMappings {
mut:
	proxies  []string
	mappings []ProxyMapping
}

pub fn ProxyMappings.create() &ProxyMappings {
	return &ProxyMappings{}
}

pub fn ProxyMappings.the() &ProxyMappings {
	if loader_global_proxy_mappings == unsafe { nil } {
		loader_global_proxy_mappings = ProxyMappings.create()
	}
	return loader_global_proxy_mappings
}

pub fn (mut mappings ProxyMappings) set_mappings(proxies []string, rules []ProxyMapping) {
	mappings.proxies = proxies.clone()
	mappings.mappings = rules.clone()
}

// ByteString::matches accepts shell-style '*' and '?' wildcards. This byte
// implementation keeps matching deterministic and ASCII-compatible.
fn wildcard_matches(text string, pattern string) bool {
	mut text_index := 0
	mut pattern_index := 0
	mut star_index := -1
	mut retry_text_index := 0
	for text_index < text.len {
		if pattern_index < pattern.len
			&& (pattern[pattern_index] == `?` || pattern[pattern_index] == text[text_index]) {
			text_index++
			pattern_index++
		} else if pattern_index < pattern.len && pattern[pattern_index] == `*` {
			star_index = pattern_index
			pattern_index++
			retry_text_index = text_index
		} else if star_index >= 0 {
			pattern_index = star_index + 1
			retry_text_index++
			text_index = retry_text_index
		} else {
			return false
		}
	}
	for pattern_index < pattern.len && pattern[pattern_index] == `*` {
		pattern_index++
	}
	return pattern_index == pattern.len
}

fn parse_proxy_url(value string) ?ProxyData {
	url := dom.dom_url_parse(value, dom.url_about_blank(), 'UTF-8') or { return none }
	type_ := match url.scheme() {
		'http' { ProxyType.http }
		'https' { ProxyType.https }
		'socks5', 'socks5h' { ProxyType.socks5 }
		else { return none }
	}
	host := url.serialized_host()
	if host == '' {
		return none
	}
	port := url.port() or {
		match type_ {
			.http { u16(80) }
			.https { u16(443) }
			.socks5 { u16(1080) }
		}
	}
	return ProxyData{
		type_:    type_
		host:     host
		port:     port
		username: url.username()
		password: url.password()
	}
}

pub fn (mappings &ProxyMappings) proxy_for_url(url dom.URL) ?ProxyData {
	serialized := url.to_string()
	for mapping in mappings.mappings {
		if wildcard_matches(serialized, mapping.pattern) {
			if mapping.proxy_index >= usize(mappings.proxies.len) {
				continue
			}
			if proxy := parse_proxy_url(mappings.proxies[mapping.proxy_index]) {
				return proxy
			}
		}
	}
	return none
}

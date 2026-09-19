// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Parser/SpeculativeHTMLParser.cpp and
// SpeculativeMockElement.cpp. Network I/O remains a host boundary; the parser
// supplies fully resolved potential-CORS requests to that boundary.
module html

import dom

pub type SpeculativeFetchHook = fn (PotentialCORSRequest)

pub struct SpeculativeMockElement {
pub:
	local_name     string
	attribute_list []Attribute
}

pub fn (element &SpeculativeMockElement) attribute(name string) ?string {
	for attribute in element.attribute_list {
		if attribute.local_name == name {
			return attribute.value
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/parsing.html#create-a-speculative-mock-element
pub fn create_a_speculative_mock_element(tag_name string, attributes []Attribute) SpeculativeMockElement {
	return SpeculativeMockElement{
		local_name: tag_name
		attribute_list: attributes.clone()
	}
}

@[heap]
pub struct SpeculativeHTMLParser {
mut:
	document       &dom.Document = unsafe { nil }
	input          string
	tokenizer      HTMLTokenizer
	base_url       dom.URL
	fetch_hook     ?SpeculativeFetchHook
	template_depth u32
	foreign_depth  u32
	stopped        bool
}

pub fn SpeculativeHTMLParser.create(document &dom.Document, pending_input string, base_url dom.URL, fetch_hook ?SpeculativeFetchHook) &SpeculativeHTMLParser {
	return &SpeculativeHTMLParser{
		document: document
		input: pending_input
		tokenizer: HTMLTokenizer.new(pending_input)
		base_url: base_url
		fetch_hook: fetch_hook
	}
}

pub fn (parser &SpeculativeHTMLParser) is_stopped() bool {
	return parser.stopped
}

pub fn (mut parser SpeculativeHTMLParser) stop() {
	parser.stopped = true
	parser.tokenizer.abort()
}

pub fn (mut parser SpeculativeHTMLParser) run() {
	if parser.stopped {
		return
	}
	for !parser.stopped {
		token := parser.tokenizer.next_token() or { break }
		if token.is_start_tag() {
			parser.process_start_tag(token)
		} else if token.is_end_tag() {
			parser.process_end_tag(token)
		} else if token.is_end_of_file() {
			break
		}
	}
}

fn speculative_rel_contains_keyword(rel string, keyword string) bool {
	for token in rel.fields() {
		if ascii_lowercase_string(token) == keyword {
			return true
		}
	}
	return false
}

struct SpeculativePreloadDestinationResult {
	destination ?RequestDestination
}

fn speculative_preload_destination(value string) ?SpeculativePreloadDestinationResult {
	translated := translate_a_preload_destination(value) or { return none }
	if translated == '' {
		return SpeculativePreloadDestinationResult{}
	}
	destination := match translated {
		'font' { RequestDestination.font }
		'image' { RequestDestination.image }
		'script' { RequestDestination.script }
		'style' { RequestDestination.style }
		'track' { RequestDestination.track }
		else {
			return none
		}
	}
	return SpeculativePreloadDestinationResult{
		destination: destination
	}
}

fn (mut parser SpeculativeHTMLParser) issue_speculative_fetch(url dom.URL, destination ?RequestDestination, cors_setting CORSSettingAttribute) {
	if parser.document.has_speculative_fetch_url(url) {
		return
	}
	mut document := unsafe { &dom.Document(parser.document) }
	document.add_speculative_fetch_url(url)
	if hook := parser.fetch_hook {
		hook(create_potential_cors_request(url, destination, cors_setting, .no))
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#speculative-fetch
fn (mut parser SpeculativeHTMLParser) speculative_fetch(element SpeculativeMockElement) {
	if element.local_name == 'base' {
		href := element.attribute('href') or { return }
		if href == '' {
			return
		}
		if parsed := parser.document.encoding_parse_url(href) {
			parser.base_url = parsed
		}
		return
	}

	mut source := ''
	mut destination := ?RequestDestination(none)
	if element.local_name == 'script' {
		source = element.attribute('src') or { return }
		destination = .script
	} else if element.local_name == 'link' {
		source = element.attribute('href') or { return }
		rel := element.attribute('rel') or { return }
		if speculative_rel_contains_keyword(rel, 'stylesheet') {
			destination = .style
		} else if speculative_rel_contains_keyword(rel, 'preload') {
			translated := speculative_preload_destination(element.attribute('as') or { return }) or {
				return
			}
			destination = translated.destination
		} else {
			return
		}
	} else if element.local_name == 'img' {
		source = element.attribute('src') or { return }
		destination = .image
	} else {
		return
	}
	if source == '' {
		return
	}
	url := dom.dom_url_parse(source, parser.base_url, 'UTF-8') or { return }
	parser.issue_speculative_fetch(url, destination, cors_setting_attribute_from_keyword(element.attribute('crossorigin')))
}

fn (mut parser SpeculativeHTMLParser) process_start_tag(token HTMLToken) {
	if token.tag_name == 'template' {
		parser.template_depth++
		return
	}
	if token.tag_name in ['svg', 'math'] {
		parser.foreign_depth++
		return
	}
	if parser.template_depth > 0 || parser.foreign_depth > 0 {
		return
	}
	if token.tag_name !in ['script', 'link', 'img', 'base'] {
		return
	}
	parser.speculative_fetch(create_a_speculative_mock_element(token.tag_name, token.tag_attributes()))
}

fn (mut parser SpeculativeHTMLParser) process_end_tag(token HTMLToken) {
	if token.tag_name == 'template' && parser.template_depth > 0 {
		parser.template_depth--
	} else if token.tag_name in ['svg', 'math'] && parser.foreign_depth > 0 {
		parser.foreign_depth--
	}
}

// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ClipboardSanitizer.{h,cpp}.
module editing

import dom

fn is_active_element(element &dom.Element) bool {
	return element.local_name() in ['base', 'embed', 'iframe', 'link', 'meta', 'object',
		'script', 'style', 'template']
}

fn is_url_attribute(attribute &dom.Attr_) bool {
	return attribute.local_name() in ['action', 'background', 'cite', 'data', 'formaction',
		'href', 'poster', 'src']
}

fn is_unsafe_attribute(element &dom.Element, attribute &dom.Attr_) bool {
	if attribute.local_name().starts_with('on') || attribute.local_name() == 'srcdoc' {
		return true
	}
	if !is_url_attribute(attribute) {
		return false
	}
	url := element.document().encoding_parse_url(attribute.value()) or { return false }
	return url.scheme() == 'javascript'
}

fn append_clipboard_element(elements &[]&dom.Element, element &dom.Element) {
	unsafe {
		mut mutable_elements := *elements
		mutable_elements << element
		*elements = mutable_elements
	}
}

pub fn sanitize_clipboard_html(range &dom.Range, html string) !string {
	fragment := range.create_contextual_fragment(html)!
	mut active_elements := []&dom.Element{}
	active_elements_pointer := &active_elements
	mut fragment_node := fragment.as_node()
	fragment_node.visit_subtree(fn [active_elements_pointer] (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		if is_active_element(element) {
			append_clipboard_element(active_elements_pointer, element)
			return .@continue
		}

		for attribute_name in element.get_attribute_names() {
			attribute := element.get_attribute_node(attribute_name) or { continue }
			if is_unsafe_attribute(element, attribute) {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.remove_attribute(attribute.name())
			}
		}
		return .@continue
	})

	for index := active_elements.len; index > 0; index-- {
		mut node := unsafe { &dom.Node(active_elements[index - 1]) }
		node.remove(false)
	}
	return fragment_node.serialize_fragment(.no, .inner)
}

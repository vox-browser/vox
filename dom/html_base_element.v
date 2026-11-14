// Copyright (c) 2020, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

module dom

// HTML/HTMLBaseElement.cpp:26–40. Node's virtual lifecycle dispatch reaches
// the concrete object allocated by create_html_element().
pub fn (mut base HTMLBaseElement) inserted() {
	mut element := unsafe { &Element(&base) }
	element.inserted()
	mut document := unsafe { &Document(element.document()) }
	old_base_url := document.base_url()
	document.update_base_element()
	if first := document.first_base_element_with_href_in_tree_order() {
		if voidptr(first) == voidptr(&base) {
			base.set_the_frozen_base_url(old_base_url)
		}
	}
}

// HTML/HTMLBaseElement.cpp:42–55. Preserve the metadata passed to the parent.
pub fn (mut base HTMLBaseElement) removed_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	mut element := unsafe { &Element(&base) }
	element.removed_from_with_context(is_subtree_root, old_ancestor, old_root)
	mut document := unsafe { &Document(element.document()) }
	old_first := document.first_base_element_with_href_in_tree_order()
	old_base_url := document.base_url()
	document.update_base_element()
	if first := document.first_base_element_with_href_in_tree_order() {
		if old := old_first {
			if voidptr(first) == voidptr(old) {
				return
			}
		}
		mut mutable_first := unsafe { &HTMLBaseElement(first) }
		mutable_first.set_the_frozen_base_url(old_base_url)
	}
}

// Only the null-namespace HTML href attribute changes the frozen base URL.
pub fn (mut base HTMLBaseElement) attribute_changed(name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &Element(&base) }
	element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none || name != 'href' {
		return
	}
	mut document := unsafe { &Document(element.document()) }
	old_base_url := document.base_url()
	document.update_base_element()
	if first := document.first_base_element_with_href_in_tree_order() {
		if voidptr(first) == voidptr(&base) {
			base.set_the_frozen_base_url(old_base_url)
		}
	}
}

// HTML/HTMLBaseElement.cpp:77–110. HTML supplies the actual settings-owned CSP
// call through the existing Document module boundary.
pub fn (mut base HTMLBaseElement) set_the_frozen_base_url(old_base_url URL) {
	element := unsafe { &Element(&base) }
	document := element.document()
	fallback := document.fallback_base_url()
	frozen := dom_url_parse(element.get_attribute_ns(none, 'href') or { '' }, fallback, document.encoding_or_default()) or {
		base.frozen_base_url_ = fallback
		base.frozen_base_url_initialized_ = true
		return
	}
	if frozen.scheme() in ['data', 'javascript'] || !document.is_base_allowed_by_csp(frozen) {
		base.frozen_base_url_ = fallback
		base.frozen_base_url_initialized_ = true
		return
	}
	base.frozen_base_url_ = frozen
	base.frozen_base_url_initialized_ = true
	mut mutable_document := unsafe { &Document(document) }
	mutable_document.respond_to_base_url_changes(document.url, old_base_url)
}

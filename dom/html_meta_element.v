// Copyright (c) 2020, the SerenityOS developers.
// Copyright (c) 2023, Luke Wilde <lukew@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause

module dom

pub enum MetaHttpEquivState {
	encoding_declaration
	refresh
	set_cookie
	x_ua_compatible
	content_language
	content_security_policy
	default_style
}

// HTML/HTMLMetaElement.cpp:34–46 and HTMLMetaElement.h:22–28.
pub fn meta_http_equiv_state(value string) ?MetaHttpEquivState {
	return match to_ascii_lowercase(value) {
		'content-type' { .encoding_declaration }
		'refresh' { .refresh }
		'set-cookie' { .set_cookie }
		'x-ua-compatible' { .x_ua_compatible }
		'content-language' { .content_language }
		'content-security-policy' { .content_security_policy }
		'default-style' { .default_style }
		else { none }
	}
}

pub fn (meta &HTMLMetaElement) http_equiv_state() ?MetaHttpEquivState {
	return meta_http_equiv_state(unsafe { &Element(meta) }.get_attribute_ns(none, 'http-equiv') or { '' })
}

// The existing HTML metadata body needs HTML's ReferrerPolicy type. The
// actual Window/parser installs its typed implementation on the Document.
pub fn (meta &HTMLMetaElement) update_metadata(old_name ?string) {
	meta.document().update_meta_element_metadata(meta, old_name)
}

// HTML/HTMLMetaElement.cpp:112–228. Parent insertion precedes metadata and
// pragma processing, and a connected shadow tree is not a Document tree.
pub fn (mut meta HTMLMetaElement) inserted() {
	mut element := unsafe { &Element(&meta) }
	element.inserted()
	meta.update_metadata(none)
	if !element.as_node().in_a_document_tree() {
		return
	}
	state := meta.http_equiv_state() or { return }
	mut document := unsafe { &Document(element.document()) }
	match state {
		.refresh {
			input := element.get_attribute('content') or { return }
			if input != '' {
				document.shared_declarative_refresh_steps_for_meta(input)
			}
		}
		.content_language {
			input := element.get_attribute('content') or { return }
			if input.contains(',') {
				return
			}
			mut position := 0
			for position < input.len && is_ascii_whitespace(input[position]) {
				position++
			}
			start := position
			for position < input.len && !is_ascii_whitespace(input[position]) {
				position++
			}
			candidate := input[start..position]
			if candidate != '' {
				document.set_pragma_set_default_language(candidate)
				// HTMLMetaElement.cpp:190–191 publishes the changed default
				// language through the actual document element's subtree.
				root := document.document_element() or {
					panic('Meta in a Document tree requires its actual root Element')
				}
				mut mutable_root := unsafe { &Element(root) }
				mutable_root.invalidate_style_after_language_change()
			}
		}
		.content_security_policy {
			parent := element.as_node().parent() or { return }
			if !parent.is_html_head_element() {
				return
			}
			input := element.get_attribute_value('content')
			if input != '' {
				document.enforce_meta_csp_from_element(input)
			}
		}
		.encoding_declaration, .set_cookie, .x_ua_compatible {}
		.default_style {
			// Source retains its default-style pragma implementation FIXME.
		}
	}
}

// HTML/HTMLMetaElement.cpp:232–237.
pub fn (mut meta HTMLMetaElement) removed_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	mut element := unsafe { &Element(&meta) }
	element.removed_from_with_context(is_subtree_root, old_ancestor, old_root)
	meta.update_metadata(none)
}

// HTML/HTMLMetaElement.cpp:239–248. Attribute mutation updates metadata;
// the Source CSP append belongs only to inserted().
pub fn (mut meta HTMLMetaElement) attribute_changed(local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &Element(&meta) }
	element.attribute_changed(local_name, old_value, value, namespace_)
	if namespace_ != none { return }
	meta.update_metadata(if local_name == 'name' { old_value } else { none })
}

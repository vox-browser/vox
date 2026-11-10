// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module dom

// Ladybird 786ea690c1a419593e7b22d353ea8057f1ddad67.
fn test_foreign_raw_text_names_escape_text_during_html_serialization() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	for namespace_ in [namespace_html_uri, namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		for name in ['style', 'script', 'xmp', 'iframe', 'noembed', 'noframes', 'plaintext'] {
			mut element := document.create_element_ns(namespace_, name)!
			mut node := element.as_node()
			node.append_child(document.create_text_node('</svg><img>').as_node())!
			expected := if namespace_ == namespace_html_uri { '</svg><img>' } else { '&lt;/svg&gt;&lt;img&gt;' }
			assert element.inner_html()! == expected
			assert element.outer_html()! == '<${name}>${expected}</${name}>'
		}
	}
}

fn test_foreign_noscript_escapes_text_regardless_of_scripting_state() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	for namespace_ in [namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		mut element := document.create_element_ns(namespace_, 'noscript')!
		mut node := element.as_node()
		node.append_child(document.create_text_node('</svg><img>').as_node())!
		assert element.outer_html()! == '<noscript>&lt;/svg&gt;&lt;img&gt;</noscript>'
	}
}

fn test_foreign_void_names_keep_children_and_end_tags() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	for namespace_ in [namespace_html_uri, namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		for name in ['link', 'input', 'br', 'img', 'basefont', 'bgsound', 'frame', 'keygen'] {
			mut element := document.create_element_ns(namespace_, name)!
			mut node := element.as_node()
			node.append_child(document.create_text_node('text').as_node())!
			expected := if namespace_ == namespace_html_uri { '<${name}>' } else { '<${name}>text</${name}>' }
			assert element.outer_html()! == expected
		}
	}
}

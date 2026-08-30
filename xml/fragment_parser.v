// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XML/XMLFragmentParser.{h,cpp}.
module xml

import dom
import html

// Implements the XHTML fragment algorithm by wrapping the input in the
// context element with every in-scope namespace, parsing a temporary XML
// document, then cloning the wrapper's children into the context document.
pub fn parse_fragment(context &dom.Element, input string, allow_declarative_shadow_roots bool) ![]&dom.Node {
	return html.parse_xml_fragment_with_options(context, input, allow_declarative_shadow_roots)
}

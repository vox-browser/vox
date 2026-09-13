// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module svg

import dom

// SVG 2 leaves the behavior undefined; SVGStyleElement follows the shared
// StyleElementBase behavior used by HTMLStyleElement.
pub fn svg_style_element_disabled(style &dom.SVGStyleElement) bool {
	return unsafe { &dom.Element(style) }.style_element_disabled()
}

pub fn set_svg_style_element_disabled(style &dom.SVGStyleElement, disabled bool) {
	mut element := unsafe { &dom.Element(style) }
	element.set_style_element_disabled(disabled)
}

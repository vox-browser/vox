// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module svg

import dom

// SVG 2 leaves the behavior undefined; SVGStyleElement follows the shared
// StyleElementBase behavior used by HTMLStyleElement.
pub fn svg_style_element_disabled(style &dom.SVGStyleElement) bool {
	base := unsafe { &dom.Element(style) }.style_element_base() or { return false }
	return base.disabled()
}

pub fn set_svg_style_element_disabled(style &dom.SVGStyleElement, disabled bool) {
	mut base := unsafe { &dom.Element(style) }.style_element_base() or { return }
	base.set_disabled(disabled)
}

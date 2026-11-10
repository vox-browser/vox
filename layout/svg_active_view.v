// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom
import svg

// The active view belongs to the SVG document root. Read the current fragment
// and attributes at the same boundary as ordinary viewBox facts, so both
// layout and natural image sizing see the same view.
fn active_svg_view_box(element &dom.Element) ?svg.ViewBox {
	document := element.document()
	if root := document.document_element() {
		if voidptr(root) == voidptr(element) && element.is_svg_element() {
			if encoded := document.url.fragment() {
				fragment := svg.decode_fragment_identifier(encoded)
				if specification := svg.parse_view_specification(fragment) {
					if box := specification.view_box { return box }
				} else if view := document.get_element_by_id(fragment) {
					if view.is_svg_element() && view.local_name() == 'view' {
						if box := svg.parse_viewbox(view.get_attribute_value('viewBox')) { return box }
					}
				}
			}
		}
	}
	return svg.parse_viewbox(element.get_attribute_value('viewBox'))
}

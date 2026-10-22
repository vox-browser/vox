// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translations of file-local helpers from Libraries/LibWeb/DOM/Document.cpp
// and Libraries/LibWeb/DOM/Element.cpp. These live outside document.v only to
// keep that generated-sized implementation navigable.
module dom

// https://drafts.csswg.org/css-scrollbars/#scrollbar-width
pub fn propagate_scrollbar_width_to_viewport(root_element &Element, mut viewport LayoutViewport) {
	// Called while constructing the layout tree, after the root element's
	// computed values have been installed.
	properties := root_element.el_computed_properties() or { return }
	viewport.scrollbar_width = properties.scrollbar_width()
}

// https://drafts.csswg.org/resize-observer-1/#calculate-depth-for-node
pub fn calculate_depth_for_node(node &Node) int {
	mut depth := 0
	mut current := ?&Node(node)
	for {
		candidate := current or { break }
		depth++
		current = candidate.parent()
	}
	return depth
}

fn find_style_sheet_with_url(url string, style_sheet &CSSStyleSheet) ?&CSSStyleSheet {
	if style_sheet.url == url {
		return style_sheet
	}
	for imported_style_sheet in style_sheet.imported_style_sheets {
		if found := find_style_sheet_with_url(url, imported_style_sheet) {
			return found
		}
	}
	return none
}

// Element.cpp's helper walks typed values and asks abstract images to load
// their resources. CSS owns those values in V, so its installed callback
// performs that same walk without introducing a DOM -> CSS import cycle.
pub fn prefetch_inline_style_image_resources(style &CSSStyleProperties_, document &Document) {
	if style.prefetch_resources != unsafe { nil } {
		style.prefetch_resources(style.prefetch_resources_target, document)
	}
}

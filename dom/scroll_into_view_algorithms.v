// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module dom

// https://drafts.csswg.org/cssom-view-1/#determine-the-scroll-into-view-position
pub fn determine_the_scroll_into_view_position(target &Element, block ScrollLogicalPosition, inline_ ScrollLogicalPosition, scrolling_box &Node) CSSPixelPoint_ {
	// Current upstream only supports a viewport as the scrolling box here.
	if !scrolling_box.is_document() {
		return CSSPixelPoint_{}
	}

	mut target_rect := target.get_bounding_client_rect()
	// AD-HOC: CSSOM View illustrates scroll-margin affecting this box but does
	// not yet place the adjustment in the numbered algorithm.
	scroll_margin := target.document().scroll_margin_for_element(target)
	target_rect.x -= scroll_margin.left
	target_rect.y -= scroll_margin.top
	target_rect.width += scroll_margin.left + scroll_margin.right
	target_rect.height += scroll_margin.top + scroll_margin.bottom
	scrolling_rect := scrolling_box.document().viewport_rect()
	element_edge_a := target_rect.y
	element_edge_b := target_rect.y + target_rect.height
	element_edge_c := target_rect.x
	element_edge_d := target_rect.x + target_rect.width
	scrolling_height := scrolling_rect.height
	scrolling_width := scrolling_rect.width
	mut x := 0.0
	mut y := 0.0

	match block {
		.start {
			y = element_edge_a
		}
		.end_ {
			y = element_edge_a + target_rect.height - scrolling_height
		}
		.center {
			y = element_edge_a + target_rect.height / 2.0 - scrolling_height / 2.0
		}
		.nearest {
			if element_edge_a <= 0 && element_edge_b >= scrolling_height {
				// The element covers the scrolling box; do nothing.
			} else if (element_edge_a <= 0 && target_rect.height < scrolling_height) || (element_edge_b >= scrolling_height && target_rect.height > scrolling_height) {
				y = element_edge_a
			} else if (element_edge_b >= scrolling_height && target_rect.height < scrolling_height) || (element_edge_a <= 0 && target_rect.height > scrolling_height) {
				y = element_edge_a + target_rect.height - scrolling_height
			}
		}
	}

	match inline_ {
		.start {
			x = element_edge_c
		}
		.end_ {
			x = element_edge_d + target_rect.width - scrolling_width
		}
		.center {
			x = element_edge_c + target_rect.width / 2.0 - scrolling_width / 2.0
		}
		.nearest {
			if element_edge_c <= 0 && element_edge_d >= scrolling_width {
				// The element covers the scrolling box; do nothing.
			} else if (element_edge_c <= 0 && target_rect.width < scrolling_width) || (element_edge_d >= scrolling_width && target_rect.width > scrolling_width) {
				x = element_edge_c
			} else if (element_edge_d >= scrolling_width && target_rect.width < scrolling_width) || (element_edge_c <= 0 && target_rect.width > scrolling_width) {
				x = element_edge_d + target_rect.width - scrolling_width
			}
		}
	}

	return CSSPixelPoint_{
		x_: x
		y_: y
	}
}

// https://drafts.csswg.org/cssom-view-1/#scroll-a-target-into-view
pub fn scroll_an_element_into_view(target &Element, behavior ScrollBehavior, block ScrollLogicalPosition, inline_ ScrollLogicalPosition, container ?&Element) &Promise {
	mut scrolling_boxes := []&Node{}
	mut ancestor := target.as_node().parent()
	for ancestor != none {
		scrolling_box := ancestor or { break }
		if paintable_box := scrolling_box.paintable_box() {
			if paintable_box.has_scrollable_overflow() {
				scrolling_boxes << scrolling_box
			}
		}
		ancestor = scrolling_box.parent()
	}

	for scrolling_box in scrolling_boxes {
		if target.document().origin() != scrolling_box.document().origin() {
			break
		}

		mut position := determine_the_scroll_into_view_position(target, block, inline_, scrolling_box)
		// Upstream has not implemented scrolling element-associated boxes yet.
		if scrolling_box.is_document() {
			document := scrolling_box.document()
			_ = behavior
			position.set_y(position.y() + document.viewport_rect().y)
			if navigable := document.navigable() {
				_ = navigable.perform_a_scroll_of_the_viewport(position)
			} else if document.window != unsafe { nil } {
				mut window := unsafe { &Window(document.window) }
				window.scroll(position.x(), position.y())
			}
		}

		if stop_at := container {
			if scrolling_box.is_shadow_including_inclusive_ancestor_of(stop_at.as_node()) {
				break
			}
		}
	}

	return Promise.resolved(js_undefined())
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module dom

// https://www.w3.org/TR/intersection-observer/#compute-the-intersection
pub fn compute_intersection(target &Element, target_rect Rect, observer &IntersectionObserver, _ ?&PaintableBox, root_bounds Rect) Rect {
	mut intersection := target_rect
	root_node := if observer.root_node != unsafe { nil } {
		observer.root_node(observer.target)
	} else {
		?&Node(none)
	}
	root_layout_node := if node := root_node { node.layout_node() } else { ?&LayoutNode(none) }
	target_layout_node := target.as_node().layout_node() or {
		return intersection_rect(intersection, root_bounds)
	}
	scroll_margins := if observer.scroll_margins != unsafe { nil } {
		observer.scroll_margins(observer.target)
	} else {
		[]IntersectionObserverMarginValue{}
	}

	// getBoundingClientRect() and the retained border boxes are already
	// viewport-relative, matching the no-op mapping steps in current Ladybird.
	mut containing_block := target_layout_node.containing_block_
	for containing_block != none {
		container := containing_block or { break }
		if root_layout := root_layout_node {
			if voidptr(container) == voidptr(root_layout) {
				break
			}
		}
		container_node := container.dom_node() or {
			containing_block = container.containing_block_
			continue
		}
		if node := root_node {
			if voidptr(container_node) == voidptr(node) {
				break
			}
		}
		if element := container_node.as_element() {
			if computed := element.el_computed_properties() {
				has_content_clip := computed.overflow_x() != .visible
					|| computed.overflow_y() != .visible
				if has_content_clip {
					border_rect := element.bounding_client_rect_assuming_layout_clean()
					layout_node := element.as_node().layout_node()
					mut clip_rect := if layout := layout_node {
						Rect{
							x: border_rect.x + layout.box_model().border_left
							y: border_rect.y + layout.box_model().border_top
							width: border_rect.width - layout.box_model().border_left - layout.box_model().border_right
							height: border_rect.height - layout.box_model().border_top - layout.box_model().border_bottom
						}
					} else {
						border_rect
					}
					if element.is_scroll_container() && scroll_margins.len == 4 {
						top := resolve_intersection_observer_margin(scroll_margins[0], clip_rect.height)
						right := resolve_intersection_observer_margin(scroll_margins[1], clip_rect.width)
						bottom := resolve_intersection_observer_margin(scroll_margins[2], clip_rect.height)
						left := resolve_intersection_observer_margin(scroll_margins[3], clip_rect.width)
						clip_rect = Rect{
							x: clip_rect.x - left
							y: clip_rect.y - top
							width: clip_rect.width + left + right
							height: clip_rect.height + top + bottom
						}
					}
					intersection = intersection_rect(intersection, clip_rect)
				}
			}
		}
		containing_block = container.containing_block_
	}
	return intersection_rect(intersection, root_bounds)
}

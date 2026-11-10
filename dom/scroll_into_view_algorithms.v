// Copyright (c) 2026, Ladybird contributors.
//
// SPDX-License-Identifier: BSD-2-Clause
module dom

import math
import webidl

// Concrete Painting/VisualViewport inputs to the source alignment algorithm.
// The committed painting bridge supplies these records without a DOM import
// cycle through Layout, Painting, CSS, and HTML.
pub struct ScrollIntoViewGeometry {
pub:
	scrollport              Rect
	current_scroll_position CSSPixelPoint_
}

// PixelUnits.h::CSSPixelFraction -> CSSPixels truncates the fixed-point
// quotient before the center-alignment sum. Keep its 6 fractional bits at
// this DOM boundary, whose rectangle fields otherwise transport doubles.
fn scroll_into_view_half(value f64) f64 {
	return f64(i64(value * 64.0) / 2) / 64.0
}

fn scroll_into_view_geometry(scrolling_box &Node) ?ScrollIntoViewGeometry {
	document := scrolling_box.document()
	if paintable := document.unsafe_paintable() {
		if paintable.target != unsafe { nil }
			&& paintable.scroll_into_view_geometry_callback != unsafe { nil } {
			return paintable.scroll_into_view_geometry_callback(paintable.target, scrolling_box)
		}
	}
	// Existing DOM-only adapters have a layout viewport but no HTML visual
	// viewport record. Preserve their unzoomed viewport state explicitly.
	if !scrolling_box.is_document() { return none }
	viewport := document.viewport_rect()
	padding := document.scroll_padding_for_scrolling_box(scrolling_box)
	return ScrollIntoViewGeometry{
		scrollport:              Rect{
			x:      padding.left
			y:      padding.top
			width:  viewport.width - padding.left - padding.right
			height: viewport.height - padding.top - padding.bottom
		}
		current_scroll_position: CSSPixelPoint_{
			x_: viewport.x
			y_: viewport.y
		}
	}
}

// Convenience entry point for callers that have not retained the target box.
pub fn determine_the_scroll_into_view_position(target &Element, block ScrollLogicalPosition,
	inline_ ScrollLogicalPosition, scrolling_box &Node) CSSPixelPoint_ {
	return determine_the_scroll_into_view_position_from_rect(target,
		target.get_bounding_client_rect(), block, inline_, scrolling_box)
}

// Element.cpp::determine_the_scroll_into_view_position. The source caller
// passes the target border box once and projects it outward after each scroll.
pub fn determine_the_scroll_into_view_position_from_rect(target &Element, target_bounding_border_box Rect,
	block ScrollLogicalPosition, inline_ ScrollLogicalPosition, scrolling_box &Node) CSSPixelPoint_ {
	return determine_scroll_into_view_position_with_margin(target_bounding_border_box,
		target.document().scroll_margin_for_element(target), block, inline_, scrolling_box)
}

fn determine_scroll_into_view_position_with_margin(target_bounding_border_box Rect, margin ScrollMarginData,
	block ScrollLogicalPosition, inline_ ScrollLogicalPosition, scrolling_box &Node) CSSPixelPoint_ {
	geometry := scroll_into_view_geometry(scrolling_box) or { return CSSPixelPoint_{} }
	mut target_rect := target_bounding_border_box
	// FIXME: The pinned source does not yet implement other block/inline directions.
	// AD-HOC: Source applies scroll-margin to the passed target border box.
	target_rect.x -= margin.left
	target_rect.y -= margin.top
	target_rect.width += margin.left + margin.right
	target_rect.height += margin.top + margin.bottom
	scrollport := geometry.scrollport
	element_edge_a := target_rect.y
	element_edge_b := target_rect.y + target_rect.height
	element_edge_c := target_rect.x
	element_edge_d := target_rect.x + target_rect.width
	scrolling_box_edge_a := scrollport.y
	scrolling_box_edge_b := scrollport.y + scrollport.height
	scrolling_box_edge_c := scrollport.x
	scrolling_box_edge_d := scrollport.x + scrollport.width
	element_height := element_edge_b - element_edge_a
	scrolling_height := scrolling_box_edge_b - scrolling_box_edge_a
	element_width := element_edge_d - element_edge_c
	scrolling_width := scrolling_box_edge_d - scrolling_box_edge_c
	mut x := geometry.current_scroll_position.x()
	mut y := geometry.current_scroll_position.y()
	match block {
		.start {
			y += element_edge_a - scrolling_box_edge_a
		}
		.end_ {
			y += element_edge_b - scrolling_box_edge_b
		}
		.center {
			y += (element_edge_a + scroll_into_view_half(element_height)) - (scrolling_box_edge_a +
				scroll_into_view_half(scrolling_height))
		}
		.nearest {
			if element_edge_a <= scrolling_box_edge_a && element_edge_b >= scrolling_box_edge_b {
				// Do nothing.
			} else if (element_edge_a <= scrolling_box_edge_a && element_height < scrolling_height)
				|| (element_edge_b >= scrolling_box_edge_b && element_height > scrolling_height) {
				y += element_edge_a - scrolling_box_edge_a
			} else if (element_edge_b >= scrolling_box_edge_b && element_height < scrolling_height)
				|| (element_edge_a <= scrolling_box_edge_a && element_height > scrolling_height) {
				y += element_edge_b - scrolling_box_edge_b
			}
		}
	}

	match inline_ {
		.start {
			x += element_edge_c - scrolling_box_edge_c
		}
		.end_ {
			x += element_edge_d - scrolling_box_edge_d
		}
		.center {
			x += (element_edge_c + scroll_into_view_half(element_width)) - (scrolling_box_edge_c +
				scroll_into_view_half(scrolling_width))
		}
		.nearest {
			if element_edge_c <= scrolling_box_edge_c && element_edge_d >= scrolling_box_edge_d {
				// Do nothing.
			} else if (element_edge_c <= scrolling_box_edge_c && element_width < scrolling_width)
				|| (element_edge_d >= scrolling_box_edge_d && element_width > scrolling_width) {
				x += element_edge_c - scrolling_box_edge_c
			} else if (element_edge_d >= scrolling_box_edge_d && element_width < scrolling_width)
				|| (element_edge_c <= scrolling_box_edge_c && element_width > scrolling_width) {
				x += element_edge_d - scrolling_box_edge_d
			}
		}
	}

	// FIXME: The pinned source does not yet snap to the target's scroll-snap positions.
	return CSSPixelPoint_{
		x_: x
		y_: y
	}
}

// https://drafts.csswg.org/cssom-view-1/#scroll-a-target-into-view
pub fn scroll_an_element_into_view(target &Element, behavior ScrollBehavior, block ScrollLogicalPosition, inline_ ScrollLogicalPosition, container ?&Element) &Promise {
	if target.document().relevant_settings_object() == unsafe { nil } {
		return scroll_an_element_into_view_standalone(target, behavior, block, inline_, container)
	}
	native := webidl.create_promise_for(target.document().relevant_realm_promise_context())
	scroll_an_element_into_view_with_promise(target, behavior, block, inline_, container, native)
	return Promise.from_webidl(native)
}

// LibGfx/Rect.h::intersected(), transported through DOM's rectangle ABI.
fn scroll_into_view_intersection(first Rect, second Rect) Rect {
	left := math.max(first.x, second.x)
	right := math.min(first.x + first.width, second.x + second.width)
	top := math.max(first.y, second.y)
	bottom := math.min(first.y + first.height, second.y + second.height)
	if left > right || top > bottom { return Rect{} }
	return Rect{left, top, right - left, bottom - top}
}

// Element.cpp's ad-hoc destination projection. Smooth scrolling has not moved
// the box yet; use the committed clamped destination for the outer iteration.
fn scroll_into_view_project_target(target Rect, scrolling_box &Node, position CSSPixelPoint_) Rect {
	layout_node := scrolling_box.layout_node() or { return target }
	if !layout_node.has_geometry_ { return target }
	box := scrolling_box.paintable_box() or { return target }
	current := box.scroll_offset()
	destination := box.clamp_scroll_offset(position)
	mut projected := Rect{
		x:      target.x + current.x() - destination.x()
		y:      target.y + current.y() - destination.y()
		width:  target.width
		height: target.height
	}
	viewport := scrolling_box.document().unsafe_paintable() or {
		panic('VERIFY(committed viewport paintable)')
	}
	// The retained transform excludes the visual viewport transform, matching
	// the pinned source's IncludeVisualViewportTransform::No.
	rects := viewport.transform_client_rects(scrolling_box, [CSSPixelRect_{
		x_:      box.padding_box_x_
		y_:      box.padding_box_y_
		width_:  box.padding_box_width_
		height_: box.padding_box_height_
	}])
	assert rects.len == 1
	visible := scroll_into_view_intersection(projected,
		Rect{rects[0].x_, rects[0].y_, rects[0].width(), rects[0].height()})
	if visible.width > 0 && visible.height > 0 { projected = visible }
	return projected
}

// Element.cpp:4498–4581. The caller supplies its optional real capability;
// each ancestor operation retains its own actual Navigable capability.
pub fn scroll_an_element_into_view_with_promise(target &Element, behavior ScrollBehavior,
	block ScrollLogicalPosition, inline_ ScrollLogicalPosition, container ?&Element,
	promise ?&webidl.Promise) {
	scroll_target_rect_into_view(target.document(), target.as_node().parent(),
		target.get_bounding_client_rect(), target.document().scroll_margin_for_element(target),
		behavior, block, inline_, container, promise)
}

// Find-in-page and text fragments scroll to the beginning of their range.
// A containing element or the union of a long passage can span the viewport
// while the beginning of the actual match is still outside it.
pub fn scroll_a_range_into_view(target &Range, behavior ScrollBehavior,
	block ScrollLogicalPosition, inline_ ScrollLogicalPosition) {
	rects := target.get_client_rects()
	first := rects.item(0) or { return }
	scroll_target_rect_into_view(target.start_container().document(), target.common_ancestor_container(),
		Rect{first.x, first.y, first.width, first.height}, ScrollMarginData{},
		behavior, block, inline_, none, none)
}

fn scroll_target_rect_into_view(document &Document, first_ancestor ?&Node, initial_rect Rect,
	margin ScrollMarginData, behavior ScrollBehavior, block ScrollLogicalPosition,
	inline_ ScrollLogicalPosition, container ?&Element, promise ?&webidl.Promise) {
	mut scrolling_boxes := []&Node{}
	mut ancestor := first_ancestor
	for ancestor != none {
		scrolling_box := ancestor or { break }
		if layout_node := scrolling_box.layout_node() {
			if layout_node.has_geometry_ {
				if box := scrolling_box.paintable_box() {
					if box.has_scrollable_overflow() { scrolling_boxes << scrolling_box }
				}
			}
		}
		ancestor = scrolling_box.parent()
	}
	mut target_rect := initial_rect
	mut ancestor_promises := []&webidl.Promise{}
	for scrolling_box in scrolling_boxes {
		if document.origin() != scrolling_box.document().origin() { break }
		position := determine_scroll_into_view_position_with_margin(target_rect, margin,
			block, inline_, scrolling_box)
		if !scrolling_box.is_document() {
			target_rect = scroll_into_view_project_target(target_rect, scrolling_box, position)
		}
		// FIXME: The pinned source does not yet check whether position changed
		// or whether this scrolling box has an ongoing smooth scroll.
		if element := scrolling_box.as_element() {
			if navigable := element.document().navigable() {
				scroll := navigable.perform_a_scroll_of_an_element(element, position, behavior,
					ScrollSnapSelectionStrategy_{})
				ancestor_promises << scroll.webidl_promise() or {
					panic('VERIFY(owning element scroll capability)')
				}
			}
		} else if scrolling_box.is_document() {
			// FIXME: The pinned caller has not wired root-element association;
			// the existing Navigable viewport operation owns that source boundary.
			navigable := scrolling_box.document().navigable() or { panic('VERIFY(viewport navigable)') }
			scroll := navigable.perform_a_scroll_of_the_viewport_with_options(position, behavior,
				ScrollSnapSelectionStrategy_{})
			ancestor_promises << scroll.webidl_promise() or {
				panic('VERIFY(owning viewport scroll capability)')
			}
		}
		if stop_at := container {
			if scrolling_box.is_shadow_including_inclusive_ancestor_of(stop_at.as_node()) { break }
		}
	}
	if pointer := promise {
		mut all := webidl.get_promise_for_wait_for_all_for(webidl.promise_context(pointer), ancestor_promises)
		completion := all.upon_fulfillment(fn (_ webidl.Value) !webidl.Value {
			return webidl.undefined_value()
		})
		mut caller := unsafe { &webidl.Promise(pointer) }
		caller.resolve(webidl.promise_value(completion))
	}
}

// Explicit preexisting DOM-only adapter: no owning Window/Painting realm.
fn scroll_an_element_into_view_standalone(target &Element, behavior ScrollBehavior,
	block ScrollLogicalPosition, inline_ ScrollLogicalPosition, container ?&Element) &Promise {
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

		position := determine_the_scroll_into_view_position(target, block, inline_, scrolling_box)
		// Preserve the old standalone viewport path until it has an HTML owner.
		if scrolling_box.is_document() {
			document := scrolling_box.document()
			_ = behavior
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

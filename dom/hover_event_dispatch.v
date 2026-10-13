// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// DOM/Document.cpp: set_hovered_node. Boundary geometry is frozen before dispatch.
module dom

pub struct HoverEventData {
pub:
	screen_position   CSSPixelPoint_
	page_offset       CSSPixelPoint_
	viewport_position CSSPixelPoint_
	movement          CSSPixelPoint_
	button            MouseButton = .none
	buttons           u16
	modifiers         u32
}

struct HoverEventTarget {
	node   &Node
	offset CSSPixelPoint_
}

fn hover_target(node &Node, data ?HoverEventData) HoverEventTarget {
	mut offset := CSSPixelPoint_{}
	if geometry := data {
		offset = geometry.viewport_position
		if paintable := node.unsafe_paintable() {
			local := paintable.inverse_transform_point(geometry.page_offset)
			origin := paintable.box_type_agnostic_position()
			offset = CSSPixelPoint_{ x_: local.x() - origin.x(), y_: local.y() - origin.y() }
		}
	}
	return HoverEventTarget{node, offset}
}

fn hover_dispatch(name string, target HoverEventTarget, related ?&Node, data ?HoverEventData,
	view voidptr, transition bool) {
	geometry := data or { HoverEventData{} }
	related_target := if node := related {
		?&EventTarget(unsafe { &EventTarget(node) })
	} else {
		?&EventTarget(none)
	}
	mut event := if name.starts_with('pointer') {
		pointer := PointerEvent.create_from_platform_event(view, name, geometry.screen_position,
			geometry.page_offset, geometry.viewport_position, target.offset, geometry.movement,
			geometry.button, geometry.buttons, geometry.modifiers)
		unsafe { &Event(pointer) }
	} else {
		mouse := MouseEvent.create_from_platform_event(view, name, geometry.screen_position,
			geometry.page_offset, geometry.viewport_position, target.offset, geometry.movement,
			geometry.button, geometry.buttons, geometry.modifiers, 0)
		unsafe { &Event(mouse) }
	}
	event.related_target_ = related_target
	event.bubbles_ = transition
	event.cancelable_ = transition
	event.composed_ = transition
	event.set_is_trusted(data != none)
	event_target_dispatch_event(unsafe { &EventTarget(target.node) }, event)
}

pub fn (mut document Document) set_hovered_node_with_data(node ?&Node, data ?HoverEventData) {
	new_node := node or { unsafe { nil } }
	if voidptr(document.hovered_node) == voidptr(new_node) { return }
	old := if document.hovered_node != unsafe { nil } {
		?&Node(document.hovered_node)
	} else {
		?&Node(none)
	}
	common := find_common_ancestor(old, node)
	common_ptr := common or { unsafe { nil } }
	old_target := if value := old {
		?HoverEventTarget(hover_target(value, data))
	} else {
		?HoverEventTarget(none)
	}
	new_target := if value := node {
		?HoverEventTarget(hover_target(value, data))
	} else {
		?HoverEventTarget(none)
	}
	mut pointer_leave := []HoverEventTarget{}
	mut mouse_leave := []HoverEventTarget{}
	mut enter := []HoverEventTarget{}
	if previous := old {
		if new_node == unsafe { nil } || !new_node.is_descendant_of(previous) {
			mut current := old
			for current != none {
				value := current or { break }
				if voidptr(value) == voidptr(common_ptr) { break }
				pointer_leave << hover_target(value, data)
				current = value.parent()
			}
			current = old
			for current != none {
				value := current or { break }
				if voidptr(value) == voidptr(common_ptr) { break }
				mouse_leave << hover_target(value, data)
				current = value.parent_or_shadow_host()
			}
		}
	}
	if value := node {
		previous := old or { unsafe { nil } }
		if previous == unsafe { nil } || !value.is_ancestor_of(previous) {
			mut current := node
			for current != none {
				ancestor := current or { break }
				if voidptr(ancestor) == voidptr(common_ptr) { break }
				enter << hover_target(ancestor, data)
				current = ancestor.parent_or_shadow_host()
			}
		}
	}
	if previous := old {
		document.invalidate_style_for_elements_affected_by_pseudo_class_change(.hover, previous.root(), node)
	}
	if value := node {
		document.invalidate_style_for_elements_affected_by_pseudo_class_change(.hover, value.root(), node)
	}
	document.hovered_node = new_node
	mut view := voidptr(unsafe { nil })
	if proxy := unsafe { &Node(document) }.active_window_proxy() {
		view = voidptr(proxy)
	} else if window := document.get_window() {
		view = voidptr(window)
	}
	if target := old_target {
		hover_dispatch('pointerout', target, node, data, view, true)
		hover_dispatch('mouseout', target, node, data, view, true)
	}
	for target in pointer_leave { hover_dispatch('pointerleave', target, node, data, view, false) }
	for target in mouse_leave { hover_dispatch('mouseleave', target, node, data, view, false) }
	if target := new_target {
		hover_dispatch('pointerover', target, old, data, view, true)
		hover_dispatch('mouseover', target, old, data, view, true)
	}
	for i := enter.len - 1; i >= 0; i-- {
		hover_dispatch('pointerenter', enter[i], old, data, view, false)
		hover_dispatch('mouseenter', enter[i], old, data, view, false)
	}
}

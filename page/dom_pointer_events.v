// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Page/EventHandler.cpp: hover-capable pointer mapping and click dispatch.
module page

import dom

pub fn InputTarget.from_node(node &dom.Node) InputTarget {
	return InputTarget.from_node_and_chrome_widget(node, '')
}

pub fn InputTarget.from_node_and_chrome_widget(node &dom.Node, chrome_widget string) InputTarget {
	return InputTarget{
		id:                    node.unique_id().value().str()
		node:                  node
		chrome_widget_id:      chrome_widget
		is_editable:           node.is_editable_or_editing_host()
		is_focusable:          unsafe { &dom.EventTarget(node) }.is_focusable()
		is_link:               node.enclosing_link_element() != none
		committed_layout_node: node.unsafe_layout_node() or { unsafe { nil } }
	}
}

pub fn (mut handler EventHandler) handle_platform_pointer_event(name string, target ?InputTarget,
	client PixelPoint, screen PixelPoint, button u32, buttons u32, modifiers u32, click_count int) EventResult {
	handler.platform_mouse_position_ = client
	handler.platform_mouse_screen_ = screen
	handler.platform_mouse_button_ = button
	handler.platform_mouse_buttons_ = buttons
	handler.platform_mouse_modifiers_ = modifiers
	handler.record_last_known_mouse_position(client, screen, buttons, modifiers)
	if value := target {
		if node := value.node {
			handler.pointed_document_ = node.document()
		}
	}
	return match name {
		'pointerdown' {
			result := handler.handle_mousedown_with_button_and_modifiers(target, client, button, modifiers, click_count, false)
			handler.platform_mouse_screen_ = screen
			result
		}
		'pointerup' { handler.handle_mouseup_with_button(target, button) }
		'pointermove' { handler.handle_mousemove(target, screen) }
		'pointercancel' { handler.dispatch_hover_pointer_event(name, target) }
		else { .dropped }
	}
}

pub fn (handler &EventHandler) last_click_allowed() bool { return handler.last_click_allowed_ }

// The compact adapter must replay at the dispatched click target, which may
// be an ancestor of the release target. Do not consume the media receipt.
pub fn (handler &EventHandler) last_click_target_node() ?&dom.Node {
	event := handler.last_click_event_ or { return none }
	target := event.target() or { return none }
	// dispatch_click_events only creates a receipt for a DOM Node target.
	return unsafe { &dom.Node(target) }
}

fn (handler &EventHandler) click_target_for_mouseup(released InputTarget) ?InputTarget {
	pressed := handler.mousedown_node_ or { return none }
	node := released.node or { return none }
	if !pressed.is_connected() || voidptr(pressed.document()) != voidptr(node.document()) {
		return none
	}
	if voidptr(pressed) == voidptr(node) { return released }
	if released.chrome_widget_id != '' || handler.has_captured_chrome_widget() { return none }
	// Use the flat tree so slotted nodes and shadow hosts share the same click
	// target selection as ordinary descendants.
	mut ancestors := map[i64]bool{}
	for current := ?&dom.Node(pressed); current != none; {
		ancestor := current or { break }
		ancestors[ancestor.unique_id().value()] = true
		current = ancestor.flat_tree_parent()
	}
	for current := ?&dom.Node(node); current != none; {
		ancestor := current or { break }
		if ancestor.unique_id().value() in ancestors { return InputTarget.from_node(ancestor) }
		current = ancestor.flat_tree_parent()
	}
	return none
}

// One native release supplies one receipt to the compact engine replay adapter.
pub fn (mut handler EventHandler) take_last_click_event() ?&dom.Event {
	event := handler.last_click_event_
	handler.last_click_event_ = none
	return event
}

// parent_element_for_event_dispatch() rejects a disabled form-associated
// element anywhere above the hit target before dispatching platform input.
fn input_target_is_enabled(target InputTarget) bool {
	mut ancestor := target.node
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.is_html_element() && element.local_name() in ['button', 'fieldset', 'input',
				'object', 'output', 'select', 'textarea'] && element.is_actually_disabled() {
				return false
			}
		}
		ancestor = current.parent()
	}
	return true
}

fn pixel_point(point PixelPoint) dom.CSSPixelPoint_ {
	return dom.CSSPixelPoint_{ x_: point.x, y_: point.y }
}

fn platform_button(button u32) dom.MouseButton {
	return match button {
		0 { .primary }
		1 { .middle }
		2 { .secondary }
		3 { .backward }
		4 { .forward }
		else { .none }
	}
}

fn (handler &EventHandler) coordinates_for_node(node &dom.Node) MouseEventCoordinates {
	page_position := handler.compute_mouse_event_page_offset(handler.platform_mouse_position_)
	mut offset := handler.platform_mouse_position_
	if paintable := node.unsafe_paintable() {
		position := paintable.inverse_transform_point(pixel_point(page_position))
		origin := paintable.box_type_agnostic_position()
		offset = PixelPoint{position.x() - origin.x(), position.y() - origin.y()}
	}
	return MouseEventCoordinates{
		client:   handler.platform_mouse_position_
		page:     page_position
		offset:   offset
		movement: handler.compute_mouse_event_movement(handler.platform_mouse_screen_)
	}
}

fn node_view(node &dom.Node) voidptr {
	if proxy := node.active_window_proxy() { return voidptr(proxy) }
	if window := node.document().get_window() { return voidptr(window) }
	return unsafe { nil }
}

fn (handler &EventHandler) create_mouse_event(name string, node &dom.Node,
	coordinates MouseEventCoordinates, movement ?dom.CSSPixelPoint_) &dom.MouseEvent {
	return dom.MouseEvent.create_from_platform_event(node_view(node), name,
		pixel_point(handler.platform_mouse_screen_), pixel_point(coordinates.page),
		pixel_point(coordinates.client), pixel_point(coordinates.offset), movement,
		platform_button(handler.platform_mouse_button_), u16(handler.platform_mouse_buttons_),
		handler.platform_mouse_modifiers_, handler.mousedown_click_count)
}

fn (mut handler EventHandler) dispatch_hover_pointer_event(name string, target ?InputTarget) EventResult {
	value := target or { return .dropped }
	handler.log(name, value)
	node := value.node or { return if value.cancel_pointer { .cancelled } else { .handled } }
	handler.pointed_document_ = node.document()
	coordinates := handler.coordinates_for_node(node)
	handler.platform_mouse_coordinates_ = coordinates
	pointer := dom.PointerEvent.create_from_platform_event(node_view(node), name,
		pixel_point(handler.platform_mouse_screen_), pixel_point(coordinates.page),
		pixel_point(coordinates.client), pixel_point(coordinates.offset), pixel_point(coordinates.movement),
		platform_button(handler.platform_mouse_button_), u16(handler.platform_mouse_buttons_), handler.platform_mouse_modifiers_)
	mut document := node.document()
	if name in ['pointerdown', 'pointerup', 'pointermove'] {
		document.set_hovered_node_with_data(node, dom.HoverEventData{
			screen_position:   pixel_point(handler.platform_mouse_screen_)
			page_offset:       pixel_point(coordinates.page)
			viewport_position: pixel_point(coordinates.client)
			movement:          pixel_point(coordinates.movement)
			button:            platform_button(handler.platform_mouse_button_)
			buttons:           u16(handler.platform_mouse_buttons_)
			modifiers:         handler.platform_mouse_modifiers_
		})
	}
	if handler.platform_mouse_button_ == 0 && name != 'pointermove' {
		if name == 'pointerdown' {
			set_node_and_ancestors_being_activated(mut handler, value, true)
		} else if pressed := handler.mousedown_node_ {
			set_node_and_ancestors_being_activated(mut handler, InputTarget.from_node(pressed), false)
		}
	}
	handler.update_hovered_chrome_widget(value.chrome_widget_id)
	if value.chrome_widget_id != '' || handler.has_captured_chrome_widget() {
		document.update_layout(.event_handler_dispatch_chrome_widget_event)
	}
	if !handler.dispatch_chrome_widget_pointer_event(value.chrome_widget_id, name,
		int(handler.platform_mouse_button_), handler.platform_mouse_position_) {
		return .dropped
	}
	dom.run_pointer_light_dismiss(pointer, node)
	pointer_allowed := dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) }, unsafe { &dom.Event(pointer) })
	if name == 'pointerdown' && !pointer_allowed { handler.prevent_mouse_event = true }
	mut mouse_allowed := false
	if !handler.prevent_mouse_event {
		mouse_name := match name {
			'pointerdown' { 'mousedown' }
			'pointerup', 'pointercancel' { 'mouseup' }
			else { 'mousemove' }
		}
		handler.log(mouse_name, value)
		mouse := handler.create_mouse_event(mouse_name, node, coordinates, pixel_point(coordinates.movement))
		if name == 'pointercancel' {
			if window := document.get_window() {
				mouse_allowed = dom.event_target_dispatch_event(unsafe { &dom.EventTarget(window) }, unsafe { &dom.Event(mouse) })
			}
		} else {
			mouse_allowed = dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) }, unsafe { &dom.Event(mouse) })
		}
	}
	if name in ['pointerup', 'pointercancel'] { handler.prevent_mouse_event = false }
	return if mouse_allowed { .handled } else { .cancelled }
}

fn (mut handler EventHandler) dispatch_click_events(target InputTarget) EventResult {
	handler.last_click_event_ = none
	name := if handler.platform_mouse_button_ == 0 { 'click' } else { 'auxclick' }
	handler.log(name, target)
	node := target.node or { return .handled }
	coordinates := handler.coordinates_for_node(node)
	click := handler.create_mouse_event(name, node, coordinates, none)
	allowed := dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) }, unsafe { &dom.Event(click) })
	if handler.platform_mouse_button_ == 0 && handler.mousedown_click_count == 2 {
		handler.log('dblclick', target)
		double := handler.create_mouse_event('dblclick', node, coordinates, none)
		dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) }, unsafe { &dom.Event(double) })
	}
	// Publish the outer event after dispatch: a nested click must not replace
	// the receipt used for this release's later compact replay.
	if name == 'click' {
		handler.last_click_event_ = unsafe { &dom.Event(click) }
	}
	return if allowed { .handled } else { .cancelled }
}

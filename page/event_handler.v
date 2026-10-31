// Copyright (c) 2020-2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/EventHandler.{h,cpp}. Painting hit testing is supplied as
// a typed InputTarget; dispatch/default-action ordering remains observable.
module page

import dom
import painting

pub type ChromeWidgetPointerEventCallback = fn (voidptr, string, string, int, PixelPoint) painting.MouseAction

pub type ChromeWidgetHoverCallback = fn (voidptr, string, bool)

pub type HistoryActionCallback = fn (voidptr, bool) EventResult

pub type SelectAllCallback = fn (voidptr) EventResult

pub type ClipboardInsertCallback = fn (voidptr, string, ?string) EventResult

pub type EditingKeyActionCallback = fn (voidptr, int, u32, u32) bool

pub enum SelectionMode {
	none
	character
	word
	paragraph
}

pub struct InputTarget {
pub:
	id                     string
	node                   ?&dom.Node
	chrome_widget_id       string
	is_editable            bool
	is_focusable           bool
	is_link                bool
	cancel_pointer         bool
	cancel_mouse           bool
	cancel_drag_start      bool
	cancel_keyboard        bool
	has_scrollable_box     bool
	layout_is_up_to_date   bool = true
	has_document_paintable bool = true
	committed_layout_node  &dom.LayoutNode = unsafe { nil }
}

// Resolve the target's layout node only while the hit-test arena that produced
// it is still the document's committed paint tree.
pub fn (target &InputTarget) layout_node() ?&dom.LayoutNode {
	if !target.layout_is_up_to_date || !target.has_document_paintable
		|| target.committed_layout_node == unsafe { nil } {
		return none
	}
	return target.committed_layout_node
}

// A DOM/painting hit retained across event dispatch. The source Target stores
// an arena slot; V's DOM bridge exposes the corresponding committed layout
// placeholder directly on the hit node.
pub struct Target {
pub:
	hit_node     &dom.Node = unsafe { nil }
	dom_node     &dom.Node = unsafe { nil }
	is_committed bool = true
}

pub fn Target.from_hit_test_result(hit dom.HitTestResult) ?Target {
	node := if hit.node != unsafe { nil } {
		hit.node
	} else if hit.element != unsafe { nil } {
		hit.element.as_node()
	} else {
		return none
	}
	return Target{
		hit_node: node
		dom_node: node
	}
}

pub fn (target &Target) layout_node() ?&dom.LayoutNode {
	if !target.is_committed || target.hit_node == unsafe { nil } {
		return none
	}
	return target.hit_node.layout_node()
}

pub struct InputDispatch {
pub:
	name          string
	target        string
	input_type    string
	data          ?string
	target_ranges []SelectionRange
}

@[heap]
pub struct EventHandler {
pub mut:
	drag_and_drop DragAndDropEventHandler
	auto_scroll   AutoScrollHandler
	event_log     []InputDispatch
mut:
	middle_button_scroll_handler_        ?&MiddleButtonScrollHandler
	active_document                      bool = true
	paint_root_available                 bool = true
	selection_mode_                      SelectionMode
	mousedown_target_                    string
	mousedown_node_                      ?&dom.Node
	pointed_document_                    ?&dom.Document
	platform_mouse_button_               u32
	platform_mouse_position_             PixelPoint
	platform_mouse_screen_               PixelPoint
	platform_mouse_buttons_              u32
	platform_mouse_modifiers_            u32
	platform_mouse_coordinates_          ?MouseEventCoordinates
	last_click_allowed_                  bool
	last_click_event_                    ?&dom.Event
	mousedown_visual_viewport_position_  ?PixelPoint
	mousedown_click_count                int
	mousedown_target_is_drag_candidate_  bool
	mousedown_preserved_selection_       bool
	prevent_mouse_event                  bool
	previous_screen                      ?PixelPoint
	focused_target_                      string
	focused_target_state                 ?InputTarget
	hovered_chrome_widget                string
	captured_chrome_widget               string
	chrome_widget_callback_target        voidptr = unsafe { nil }
	chrome_widget_pointer_event_callback ChromeWidgetPointerEventCallback = unsafe { nil }
	chrome_widget_hover_callback         ChromeWidgetHoverCallback = unsafe { nil }
	current_cursor                       string = 'arrow'
	selection_anchor                     PixelPoint
	selection_extent                     PixelPoint
	input_selection_range_               ?SelectionRange
	selection_boundary_                  ?dom.BoundaryPoint
	last_known_mouse_visual_position_    ?PixelPoint
	last_known_mouse_screen_position_    ?PixelPoint
	last_known_mouse_buttons_            u32
	last_known_mouse_modifiers_          u32
	last_known_mouse_target_             ?InputTarget
	last_wheel_event_                    ?WheelEventData
	client_                              ?&PageClient
	selected_text_                       string
	selected_html_                       string
	pasted_text_                         string
	pasted_html_                         ?string
	clipboard_event_cancellations_       map[string]bool
	clipboard_event_items_               map[string][]ClipboardDataItem
	system_clipboard_items_              []ClipboardDataItem
	primary_paste_enabled_               bool = true
	history_action_target_               voidptr = unsafe { nil }
	history_action_callback_             HistoryActionCallback = unsafe { nil }
	select_all_target_                   voidptr = unsafe { nil }
	select_all_callback_                 SelectAllCallback = unsafe { nil }
	clipboard_insert_target_             voidptr = unsafe { nil }
	clipboard_insert_callback_           ClipboardInsertCallback = unsafe { nil }
	editing_key_action_target_           voidptr = unsafe { nil }
	editing_key_action_callback_         EditingKeyActionCallback = unsafe { nil }
}

pub fn (mut handler EventHandler) set_history_action_callback(target voidptr, callback HistoryActionCallback) {
	handler.history_action_target_ = target
	handler.history_action_callback_ = callback
}

pub fn (mut handler EventHandler) set_select_all_callback(target voidptr, callback SelectAllCallback) {
	handler.select_all_target_ = target
	handler.select_all_callback_ = callback
}

pub fn (mut handler EventHandler) set_clipboard_insert_callback(target voidptr, callback ClipboardInsertCallback) {
	handler.clipboard_insert_target_ = target
	handler.clipboard_insert_callback_ = callback
}

fn (mut handler EventHandler) insert_clipboard_content(plain_text string, html ?string) EventResult {
	if handler.clipboard_insert_target_ == unsafe { nil }
		|| handler.clipboard_insert_callback_ == unsafe { nil } {
		return .handled
	}
	return handler.clipboard_insert_callback_(handler.clipboard_insert_target_, plain_text,
		html)
}

pub fn (mut handler EventHandler) set_editing_key_action_callback(target voidptr, callback EditingKeyActionCallback) {
	handler.editing_key_action_target_ = target
	handler.editing_key_action_callback_ = callback
}

fn (handler &EventHandler) perform_editing_key_action(key int, code_point u32, modifiers u32) bool {
	if handler.editing_key_action_target_ == unsafe { nil }
		|| handler.editing_key_action_callback_ == unsafe { nil } {
		return false
	}
	return handler.editing_key_action_callback_(handler.editing_key_action_target_, key,
		code_point, modifiers)
}

fn platform_control_modifier() u32 {
	$if macos {
		return dom.modifier_super
	} $else {
		return dom.modifier_ctrl
	}
}

fn (mut handler EventHandler) perform_history_shortcut(redo bool) EventResult {
	if handler.history_action_target_ == unsafe { nil }
		|| handler.history_action_callback_ == unsafe { nil } {
		return .handled
	}
	return handler.history_action_callback_(handler.history_action_target_, redo)
}

fn (mut handler EventHandler) perform_select_all_shortcut() EventResult {
	if handler.select_all_target_ == unsafe { nil }
		|| handler.select_all_callback_ == unsafe { nil } {
		return .handled
	}
	return handler.select_all_callback_(handler.select_all_target_)
}

pub fn (mut handler EventHandler) set_document_state(active bool, has_paint_root bool) {
	handler.active_document = active
	handler.paint_root_available = has_paint_root
	if mut middle := handler.middle_button_scroll_handler_ {
		middle.set_document_layout_state(active && has_paint_root, has_paint_root)
	}
}

fn (mut handler EventHandler) clear_middle_button_scroll_handler() {
	if mut middle := handler.middle_button_scroll_handler_ {
		middle.close()
	}
	handler.middle_button_scroll_handler_ = none
}

pub fn (handler &EventHandler) is_handling_mouse_selection() bool {
	return handler.selection_mode_ != .none
}

pub fn (handler &EventHandler) middle_button_scroll_handler() ?&MiddleButtonScrollHandler {
	return handler.middle_button_scroll_handler_
}

pub fn (mut handler EventHandler) start_selection(mode SelectionMode) {
	handler.selection_mode_ = mode
}

pub fn (mut handler EventHandler) stop_updating_selection() {
	handler.selection_mode_ = .none
	handler.selection_anchor = PixelPoint{}
	handler.selection_extent = PixelPoint{}
	handler.auto_scroll.deactivate()
}

pub fn (mut handler EventHandler) clear_mousedown_tracking() {
	handler.mousedown_target_ = ''
	handler.mousedown_node_ = none
	handler.mousedown_visual_viewport_position_ = none
	handler.mousedown_click_count = 0
	handler.mousedown_target_is_drag_candidate_ = false
}

fn (handler &EventHandler) should_ignore_device_input_event() bool {
	return !handler.active_document || handler.drag_and_drop.has_ongoing_drag_and_drop_operation()
}

fn (mut handler EventHandler) log(name string, target ?InputTarget) {
	handler.event_log << InputDispatch{
		name: name
		target: if value := target { value.id } else { '' }
	}
}

pub fn (mut handler EventHandler) handle_mousedown(target ?InputTarget, click_count int) EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	value := target or { return .dropped }
	if !input_target_is_enabled(value) { return .dropped }
	handler.last_known_mouse_target_ = value
	// Upstream records the press target before pointer-event dispatch. A
	// cancelled pointerdown therefore still has a corresponding pointerup/click
	// target, even though compatibility mouse events and default actions are
	// suppressed.
	handler.mousedown_target_ = value.id
	handler.mousedown_node_ = value.node
	handler.mousedown_click_count = click_count
	if value.node != none {
		result := handler.dispatch_a_pointer_event_for_a_device_that_supports_hover('pointerdown', value)
		if result == .handled { return handler.run_mousedown_default_actions(value) }
		return result
	}
	handler.log('pointerdown', value)
	if value.cancel_pointer {
		handler.prevent_mouse_event = true
		return .cancelled
	}
	if !handler.prevent_mouse_event {
		handler.log('mousedown', value)
		if value.cancel_mouse {
			return .cancelled
		}
	}
	if value.is_focusable {
		handler.focused_target_ = value.id
		handler.focused_target_state = value
	}
	return .handled
}

pub fn (mut handler EventHandler) handle_mousedown_with_button(target ?InputTarget, position PixelPoint, button u32, click_count int, enable_autoscroll bool) EventResult {
	return handler.handle_mousedown_with_button_and_modifiers(target, position, button, 0, click_count, enable_autoscroll)
}

pub fn (mut handler EventHandler) handle_mousedown_with_button_and_modifiers(target ?InputTarget, position PixelPoint, button u32, modifiers u32, click_count int, enable_autoscroll bool) EventResult {
	if button == 0 {
		handler.clear_mousedown_tracking()
	}
	handler.platform_mouse_button_ = button
	handler.platform_mouse_position_ = position
	handler.platform_mouse_modifiers_ = modifiers
	result := handler.handle_mousedown(target, click_count)
	if result != .handled {
		return result
	}
	handler.mousedown_visual_viewport_position_ = position
	mut is_context_menu_trigger := button == 2
	$if macos {
		is_context_menu_trigger = is_context_menu_trigger
			|| (button == 0 && modifiers & dom.modifier_ctrl != 0)
	}
	if !is_context_menu_trigger {
		handler.mousedown_target_is_drag_candidate_ = button == 0
	}
	if handler.middle_button_scroll_handler_ != none {
		handler.clear_middle_button_scroll_handler()
		return result
	}
	if button != 1 || !enable_autoscroll {
		return result
	}
	value := target or { return result }
	if value.is_editable || value.is_link {
		return result
	}
	container := find_middle_button_scrollable_ancestor([value]) or { return result }
	handler.middle_button_scroll_handler_ = MiddleButtonScrollHandler.create(container, position)
	return result
}

pub fn (mut handler EventHandler) handle_mouseup(target ?InputTarget) EventResult {
	return handler.handle_mouseup_with_button(target, 0)
}

pub fn (mut handler EventHandler) handle_mouseup_with_button(target ?InputTarget, button u32) EventResult {
	handler.platform_mouse_button_ = button
	handler.last_click_allowed_ = false
	handler.last_click_event_ = none
	middle_button_autoscrolled := if middle := handler.middle_button_scroll_handler_ {
		middle.mouse_has_moved_beyond_dead_zone()
	} else {
		false
	}
	// The C++ ScopeGuard clears press/selection state on every exit, including
	// missing documents, paint roots and hit targets.
	defer {
		handler.clear_mousedown_tracking()
		handler.stop_updating_selection()
		if middle_button_autoscrolled && button == 1 {
			handler.clear_middle_button_scroll_handler()
		}
	}
	if handler.drag_and_drop.has_ongoing_drag_and_drop_operation()
		&& handler.mousedown_target_is_drag_candidate_ {
		if !handler.active_document || !handler.paint_root_available {
			return .dropped
		}
		return handler.drag_and_drop.handle_drag_end(false, false, .none)
	}
	if handler.should_ignore_device_input_event() || !handler.paint_root_available {
		return .dropped
	}
	if handler.mousedown_click_count <= 0 {
		return .dropped
	}
	if target == none {
		// Upstream still dispatches pointerup/mouseup at the document root after
		// a pressed pointer leaves the window, so pages can end a drag.
		if handler.mousedown_target_ == '' {
			return .dropped
		}
		fallback := InputTarget{ id: handler.mousedown_target_ }
		if document := handler.pointed_document_ {
			if root := document.document_element() {
				_ = handler.dispatch_a_pointer_event_for_a_device_that_supports_hover('pointerup', InputTarget.from_node(root.as_node()))
				return .handled
			}
		}
		handler.log('pointerup', fallback)
		if !handler.prevent_mouse_event {
			handler.log('mouseup', fallback)
		}
		handler.prevent_mouse_event = false
		return .handled
	}
	value := target
	if !input_target_is_enabled(value) { return .dropped }
	if value.node != none {
		_ = handler.dispatch_a_pointer_event_for_a_device_that_supports_hover('pointerup', value)
		if !middle_button_autoscrolled {
			if click_target := handler.click_target_for_mouseup(value) {
				handler.last_click_allowed_ = handler.fire_click_events(click_target) == .handled
				if handler.last_click_allowed_ && click_target.chrome_widget_id == '' && !handler.has_captured_chrome_widget() {
					mut document := (click_target.node or { return .handled }).document()
					document.update_layout(.event_handler_run_activation_behavior)
					_ = handler.run_activation_behavior(click_target)
				}
			}
		}
		return .handled
	}
	handler.log('pointerup', value)
	if !handler.prevent_mouse_event {
		handler.log('mouseup', value)
	}
	if handler.mousedown_target_ == value.id && !middle_button_autoscrolled {
		handler.log('click', value)
	}
	handler.prevent_mouse_event = false
	// EventHandler::handle_mouseup deliberately ignores cancellation of the
	// compatibility mouseup event once pointerup has been dispatched.
	return .handled
}

pub fn (mut handler EventHandler) handle_mousemove(target ?InputTarget, screen PixelPoint) EventResult {
	if handler.drag_and_drop.has_ongoing_drag_and_drop_operation()
		&& handler.mousedown_target_is_drag_candidate_ {
		if !handler.active_document || !handler.paint_root_available {
			return .dropped
		}
		return handler.drag_and_drop.handle_drag_move(input_target_to_drag_target(target), false, false, false, .none)
	}
	if handler.should_ignore_device_input_event() || !handler.paint_root_available {
		return .dropped
	}
	defer { handler.previous_screen = screen }
	handler.platform_mouse_screen_ = screen
	if mut middle := handler.middle_button_scroll_handler_ {
		middle.update_mouse_position(screen)
	}
	value := target or {
		// EventHandler.cpp delivers moves after a pressed pointer leaves the
		// hit-tested tree through the document element. Captured chrome still
		// receives that event before the ordinary DOM dispatch.
		if handler.mousedown_target_ != '' {
			if document := handler.pointed_document_ {
				if root := document.document_element() {
					return handler.dispatch_a_pointer_event_for_a_device_that_supports_hover('pointermove', InputTarget.from_node(root.as_node()))
				}
			}
		}
		return .dropped
	}
	if !input_target_is_enabled(value) { return .dropped }
	if value.node != none {
		return handler.dispatch_a_pointer_event_for_a_device_that_supports_hover('pointermove', value)
	}
	if handler.mousedown_target_is_drag_candidate_ {
		if origin := handler.mousedown_visual_viewport_position_ {
			delta_x := screen.x - origin.x
			delta_y := screen.y - origin.y
			if delta_x <= -5 || delta_x >= 5 || delta_y <= -5 || delta_y >= 5 {
				result := handler.drag_and_drop.handle_drag_start([], value.cancel_drag_start, .all)
				if result == .handled {
					handler.stop_updating_selection()
					return .handled
				}
				if result == .cancelled {
					handler.mousedown_target_is_drag_candidate_ = false
				}
			}
		}
	}
	handler.log('pointermove', value)
	if value.cancel_pointer {
		return .cancelled
	}
	if !handler.prevent_mouse_event {
		handler.log('mousemove', value)
	}
	return if value.cancel_mouse { .cancelled } else { .handled }
}

fn input_target_to_drag_target(target ?InputTarget) ?DragTarget {
	value := target or { return none }
	return DragTarget{
		id: value.id
		allows_text_drop: value.is_editable
	}
}

pub fn (mut handler EventHandler) handle_mouseleave() EventResult {
	if handler.drag_and_drop.has_ongoing_drag_and_drop_operation()
		&& handler.mousedown_target_is_drag_candidate_ {
		return handler.drag_and_drop.handle_drag_end(true, false, .none)
	}
	if handler.should_ignore_device_input_event() || !handler.paint_root_available {
		return .dropped
	}
	handler.update_hovered_chrome_widget('')
	handler.update_cursor('arrow')
	if handler.mousedown_target_ == '' {
		if mut document := handler.pointed_document_ { document.set_hovered_node_with_data(none, none) }
		handler.log('pointerout', none)
		handler.log('pointerleave', none)
		handler.previous_screen = none
	}
	return .handled
}

// Platform drag cancellation bypasses ordinary device-input suppression. It
// terminates the HTML drag operation and restores all pointer-selection state.
pub fn (mut handler EventHandler) cancel_drag_and_drop_event() EventResult {
	if !handler.active_document {
		return .dropped
	}
	result := handler.drag_and_drop.handle_drag_cancel()
	handler.update_cursor('arrow')
	handler.clear_mousedown_tracking()
	handler.stop_updating_selection()
	return result
}

pub fn (mut handler EventHandler) handle_mousewheel(target ?InputTarget) EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	value := target or { return .dropped }
	handler.last_known_mouse_target_ = value
	dispatch_result := handler.dispatch_wheel_event(value, PixelPoint{}, PixelPoint{}, 0, 0,
		0, 0, 0, true)
	if dispatch_result != .accepted {
		return dispatch_result
	}
	return if value.has_scrollable_box {
		.handled
	} else {
		.accepted
	}
}

pub fn (mut handler EventHandler) handle_keydown(key int, code_point u32, modifiers u32, repeat bool, cancelled bool) EventResult {
	if !handler.active_document {
		return .dropped
	}
	target := handler.focused_target()
	handler.log('keydown', target)
	if cancelled {
		return .cancelled
	}
	if !handler.dispatch_keyboard_event('keydown',target,key,code_point,modifiers,repeat) {
		return .cancelled
	}
	if key == 27 && handler.middle_button_scroll_handler_ != none {
		handler.clear_middle_button_scroll_handler()
		return .handled
	}
	platform_control := platform_control_modifier()
	if modifiers & platform_control != 0 && modifiers & dom.modifier_alt == 0 {
		if key == int(`A`) && modifiers & dom.modifier_shift == 0 {
			return handler.perform_select_all_shortcut()
		}
		if key == int(`C`) && modifiers & dom.modifier_shift == 0 {
			return handler.perform_copy_action()
		}
		if key == int(`X`) && modifiers & dom.modifier_shift == 0 {
			return handler.perform_cut_action()
		}
		if key == int(`V`) && modifiers & dom.modifier_shift == 0 {
			return handler.perform_paste_action()
		}
		if key == int(`Z`) && modifiers & dom.modifier_shift == 0 {
			return handler.perform_history_shortcut(false)
		}
		if key == int(`Z`) && modifiers & dom.modifier_shift != 0 {
			return handler.perform_history_shortcut(true)
		}
		$if !macos {
			if key == int(`Y`) && modifiers & dom.modifier_shift == 0 {
				return handler.perform_history_shortcut(true)
			}
		}
	}
	if produces_character_value(key, code_point)
		|| is_enter_key_or_interoperable_enter_key_combo(key, modifiers) {
		handler.log('keypress', target)
		if !handler.dispatch_keyboard_event('keypress',target,key,code_point,modifiers,repeat) {
			return .cancelled
		}
	}
	// Tab traversal is performed by the document-backed caller in upstream.
	if key == 9 && modifiers & dom.modifier_ctrl == 0 {
		return .handled
	}
	if focused := target {
		if focused.is_editable {
			if handler.perform_editing_key_action(key, code_point, modifiers) {
				if input_type := input_type_for_delete_key(key) {
					handler.log('beforeinput:${input_type}', focused)
				} else if key == 13 {
					input_type := if modifiers & dom.modifier_shift != 0 {
						dom.input_type_insert_line_break
					} else {
						dom.input_type_insert_paragraph
					}
					handler.log('beforeinput:${input_type}', focused)
					handler.log('input:${input_type}', focused)
				} else if !should_ignore_keydown_event(int(code_point), modifiers) {
					handler.log('beforeinput', focused)
					handler.log('input', focused)
				}
				return .handled
			}
			if input_type := input_type_for_delete_key(key) {
				handler.log('beforeinput:${input_type}', focused)
				return .handled
			}
			if key in [13, 35, 36, 37, 38, 39, 40] {
				return .handled
			}
			if !should_ignore_keydown_event(int(code_point), modifiers) {
				handler.log('beforeinput', focused)
				handler.log('input', focused)
				return .handled
			}
		}
	}
	// Without an editing target these keys perform viewport scrolling.
	if key in [35, 36] || (key in [33, 34, 37, 38, 39, 40] && modifiers == 0) {
		return .handled
	}
	return .accepted
}

fn (handler &EventHandler) focused_target() ?InputTarget {
	if target := handler.focused_target_state {
		if target.id == handler.focused_target_ {
			return target
		}
	}
	if handler.focused_target_ != '' {
		return InputTarget{ id: handler.focused_target_ }
	}
	return none
}

pub fn (mut handler EventHandler) handle_keyup(repeat bool, cancelled bool) EventResult {
	if !handler.active_document || repeat {
		return .dropped
	}
	handler.log('keyup', handler.focused_target())
	return if cancelled { .cancelled } else { .accepted }
}

pub fn (mut handler EventHandler) handle_paste(text string) EventResult {
	return handler.insert_pasted_content(text, none)
}

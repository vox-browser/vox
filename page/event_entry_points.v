// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// EventHandler, drag-and-drop, auto-scroll, and file-local helper entry points.
module page

import dom
import encoding.utf8
import painting

pub struct SelectionRange {
pub:
	start int
	end   int
}

pub type InputEventData = string | u32

pub struct MouseEventCoordinates {
pub:
	client   PixelPoint
	page     PixelPoint
	offset   PixelPoint
	movement PixelPoint
}

pub struct PositionedTarget {
pub:
	rect   PixelRect
	target InputTarget
}

pub fn compute_effective_auto_scroll_edge(scrollport PixelRect,
	viewport PixelRect) PixelRect {
	return effective_auto_scroll_edge(scrollport, viewport)
}

pub fn scrollport_rect_in_viewport(scrollport PixelRect) PixelRect {
	return scrollport
}

pub fn compute_auto_scroll_speed(mouse PixelPoint, edge PixelRect) PixelPoint {
	return auto_scroll_speed(mouse, edge)
}

pub fn is_in_form_associated_text_control(target InputTarget) bool {
	return target.is_editable
}

pub fn auto_scroll_paintable(target InputTarget) bool {
	return target.has_scrollable_box
}

pub fn containing_block_padding_box_size(rect PixelRect) PixelSize {
	return PixelSize{ width: rect.width, height: rect.height }
}

pub fn dom_node_for_event_dispatch(target InputTarget) string {
	return target.id
}

pub fn parent_element_for_event_dispatch(parent_id string) string {
	return parent_id
}

pub fn css_to_gfx_cursor(cursor string) string {
	return cursor
}

pub fn resolve_cursor(css_cursor string, fallback string) string {
	return if css_cursor == '' || css_cursor == 'auto' { fallback } else { css_cursor }
}

pub fn compute_mouse_event_offset(position PixelPoint, padding_origin PixelPoint) PixelPoint {
	return PixelPoint{ x: position.x - padding_origin.x, y: position.y - padding_origin.y }
}

pub fn dispatch_event_to_nested_navigable(mut handler EventHandler, target InputTarget,
	event_name string) EventResult {
	handler.log(event_name, target)
	return .handled
}

pub fn find_paragraph_range(text string, offset int) SelectionRange {
	clamped := if offset < 0 {
		0
	} else if offset > text.len { text.len } else { offset }
	mut start := clamped
	for start > 0 && text[start - 1] != `\n` {
		start--
	}
	mut end := clamped
	for end < text.len && text[end] != `\n` {
		end++
	}
	return SelectionRange{ start: start, end: end }
}

pub fn set_user_selection(mut handler EventHandler, mode SelectionMode) {
	handler.start_selection(mode)
}

pub fn light_dismiss_activities(mut handler EventHandler) {
	handler.log('light-dismiss', none)
}

pub fn set_node_and_ancestors_being_activated(mut handler EventHandler, target InputTarget,
	value bool) {
	handler.log(if value { 'activation-on' } else { 'activation-off' }, target)
	mut current := target.node
	for current != none {
		node := current or { break }
		if mut element := node.as_element() { element.set_being_activated(value) }
		current = node.parent()
	}
}

pub fn should_ignore_keydown_event(code_point int, modifiers u32) bool {
	return code_point == 0 || code_point == 27
		|| modifiers & (dom.modifier_ctrl | dom.modifier_alt | dom.modifier_super) != 0
}

pub fn produces_character_value(_ int, code_point u32) bool {
	character := rune(code_point)
	return code_point != 0 && !utf8.is_control(character) && !utf8.is_space(character)
}

pub fn is_enter_key_or_interoperable_enter_key_combo(key int, modifiers u32) bool {
	return key == 13
		&& (modifiers == 0 || modifiers & (dom.modifier_shift | dom.modifier_ctrl) != 0)
}

pub fn target_ranges_for_input_event(range ?SelectionRange) []SelectionRange {
	if actual := range {
		if actual.start != actual.end {
			return [actual]
		}
	}
	return []SelectionRange{}
}

pub fn (mut handler EventHandler) set_input_selection_range(range ?SelectionRange) {
	handler.input_selection_range_ = range
}

pub fn (mut handler EventHandler) input_event(event_name string, input_type string,
	code_point_or_string InputEventData) EventResult {
	if !handler.active_document {
		return .dropped
	}

	mut data := ?string(none)
	match code_point_or_string {
		u32 {
			if !utf8.is_control(rune(code_point_or_string)) {
				data = rune(code_point_or_string).str()
			}
		}
		string {
			data = code_point_or_string
		}
	}
	target := handler.focused_target()
	handler.event_log << InputDispatch{
		name:          event_name
		target:        if value := target { value.id } else { '' }
		input_type:    input_type
		data:          data
		target_ranges: target_ranges_for_input_event(handler.input_selection_range_)
	}
	if focused := target {
		if focused.cancel_keyboard {
			return .cancelled
		}
	}
	return .accepted
}

pub fn spin_event_loop_until_dialog_closed(p &Page) bool {
	return !p.has_pending_dialog()
}

pub fn copy_send_right(mut store SharedBackingStore) ![]u8 {
	return store.release()
}

pub fn (mut handler EventHandler) process_auto_scroll(scrollport PixelRect, viewport PixelRect,
	selecting bool, paintable bool, is_text_control bool) ?ScrollTick {
	if mut middle := handler.middle_button_scroll_handler_ {
		if tick := middle.perform_tick() {
			return tick
		}
	}
	return handler.auto_scroll.perform_tick(scrollport, viewport, selecting, paintable, is_text_control)
}

pub fn (mut handler EventHandler) update_mouse_selection(position PixelPoint) {
	handler.selection_extent = position
}

pub fn (mut handler EventHandler) apply_mouse_selection(anchor PixelPoint, extent PixelPoint) {
	handler.selection_anchor = anchor
	handler.selection_extent = extent
	handler.log('selection', none)
}

pub fn (handler &EventHandler) paint_root() bool {
	return handler.paint_root_available
}

pub fn (handler &EventHandler) mutable_paint_root() bool {
	return handler.paint_root_available
}

pub fn (mut handler EventHandler) install_chrome_widget_callbacks(target voidptr,
	pointer_event_callback ChromeWidgetPointerEventCallback,
	hover_callback ChromeWidgetHoverCallback) {
	handler.chrome_widget_callback_target = target
	handler.chrome_widget_pointer_event_callback = pointer_event_callback
	handler.chrome_widget_hover_callback = hover_callback
}

pub fn (handler &EventHandler) has_captured_chrome_widget() bool {
	return handler.captured_chrome_widget != ''
}

pub fn (mut handler EventHandler) update_hovered_chrome_widget(widget string) {
	if handler.hovered_chrome_widget == widget {
		return
	}
	if handler.hovered_chrome_widget != ''
		&& handler.chrome_widget_hover_callback != unsafe { nil } {
		handler.chrome_widget_hover_callback(handler.chrome_widget_callback_target, handler.hovered_chrome_widget, false)
	}
	handler.hovered_chrome_widget = widget
	if handler.hovered_chrome_widget != ''
		&& handler.chrome_widget_hover_callback != unsafe { nil } {
		handler.chrome_widget_hover_callback(handler.chrome_widget_callback_target, handler.hovered_chrome_widget, true)
	}
}

pub fn (handler &EventHandler) compute_mouse_event_coordinates(position PixelPoint,
	offset_origin PixelPoint) MouseEventCoordinates {
	return MouseEventCoordinates{
		client: position
		page: handler.compute_mouse_event_page_offset(position)
		offset: compute_mouse_event_offset(position, offset_origin)
		movement: handler.compute_mouse_event_movement(position)
	}
}

// Direct translation of EventHandler::dispatch_chrome_widget_pointer_event().
// A captured widget is offered the event before the current hit target. It
// keeps capture only while returning CaptureInput, and SwallowEvent controls
// whether DOM default behavior may continue.
pub fn (mut handler EventHandler) dispatch_chrome_widget_pointer_event(target string,
	event_type string, button int, visual_viewport_position PixelPoint) bool {
	mut allow_default_behavior := true
	if handler.captured_chrome_widget != '' {
		captured := handler.captured_chrome_widget
		action := if handler.chrome_widget_pointer_event_callback != unsafe { nil } {
			handler.chrome_widget_pointer_event_callback(handler.chrome_widget_callback_target, captured, event_type, button, visual_viewport_position)
		} else {
			painting.MouseAction.none
		}
		if action.swallows_event() {
			allow_default_behavior = false
		}
		if action.captures_input() {
			return allow_default_behavior
		}
		handler.captured_chrome_widget = ''
	}

	if target != '' {
		action := if handler.chrome_widget_pointer_event_callback != unsafe { nil } {
			handler.chrome_widget_pointer_event_callback(handler.chrome_widget_callback_target, target, event_type, button, visual_viewport_position)
		} else {
			painting.MouseAction.none
		}
		if action.swallows_event() {
			allow_default_behavior = false
		}
		if action.captures_input() {
			handler.captured_chrome_widget = target
		}
	}

	return allow_default_behavior
}

pub fn (mut handler EventHandler) dispatch_a_pointer_event_for_a_device_that_supports_hover(
	name string, target ?InputTarget) EventResult {
	return handler.dispatch_hover_pointer_event(name, target)
}

pub fn (mut handler EventHandler) track_the_effective_position_of_the_legacy_mouse_pointer(
	position PixelPoint) {
	handler.previous_screen = position
}

pub fn (mut handler EventHandler) update_cursor(cursor string) string {
	handler.current_cursor = cursor
	return cursor
}

pub fn (mut handler EventHandler) fire_click_events(target InputTarget) EventResult {
	return handler.dispatch_click_events(target)
}

pub fn (mut handler EventHandler) run_activation_behavior(target InputTarget) EventResult {
	handler.log('activate', target)
	if node := target.node {
		if link := node.enclosing_link_element() {
			element := unsafe { &dom.Element(link) }
			url := node.document().encoding_parse_url(element.get_attribute_value('href')) or { return .handled }
			if mut client := handler.client_ {
				if handler.platform_mouse_button_ == 0 && handler.platform_mouse_modifiers_ & platform_control_modifier() != 0 {
					client.page_did_click_link(url.serialize(), element.get_attribute_value('target'), handler.platform_mouse_modifiers_)
				} else if handler.platform_mouse_button_ == 1 {
					client.page_did_middle_click_link(url.serialize(), element.get_attribute_value('target'), handler.platform_mouse_modifiers_)
				}
			}
		}
	}
	return .handled
}

pub fn (mut handler EventHandler) maybe_show_context_menu(target ?InputTarget) EventResult {
	if target == none {
		return .dropped
	}
	handler.log('contextmenu', target)
	return .handled
}

pub fn (mut handler EventHandler) initiate_character_selection(position PixelPoint) {
	handler.selection_anchor = position
	handler.selection_extent = position
	handler.start_selection(.character)
}

pub fn (mut handler EventHandler) initiate_word_selection(position PixelPoint) {
	handler.selection_anchor = position
	handler.selection_extent = position
	handler.start_selection(.word)
}

pub fn (mut handler EventHandler) initiate_paragraph_selection(position PixelPoint) {
	handler.selection_anchor = position
	handler.selection_extent = position
	handler.start_selection(.paragraph)
}

pub fn (mut handler EventHandler) run_mousedown_default_actions(target InputTarget) EventResult {
	if handler.platform_mouse_button_ != 0 { return .handled }
	$if macos { if handler.platform_mouse_modifiers_ & dom.modifier_ctrl != 0 { return .handled } }
	mut focus_target := target
	if !focus_target.is_focusable {
		if node := target.node {
			mut candidate := node.parent_or_shadow_host()
			for candidate != none {
				ancestor := candidate or { break }
				if node_has_focus_behavior(ancestor) {
					focus_target = InputTarget.from_node(ancestor)
					break
				}
				candidate = ancestor.parent_or_shadow_host()
			}
		}
	}
	if focus_target.is_focusable {
		handler.focused_target_ = focus_target.id
		handler.focused_target_state = focus_target
		if node := focus_target.node { dom.run_focusing_steps_for_node(node, none, .click) }
	}
	return .handled
}

pub fn (mut handler EventHandler) handle_drag_and_drop_event(type_ PageDragEventType,
	target ?DragTarget, files []SelectedFile, cancelled bool,
	requested_effect DragEffect) EventResult {
	return match type_ {
		.start { handler.drag_and_drop.handle_drag_start(files, cancelled, requested_effect) }
		.move {
			handler.drag_and_drop.handle_drag_move(target, cancelled, false, false, requested_effect)
		}
		.end { handler.drag_and_drop.handle_drag_end(cancelled, false, requested_effect) }
	}
}

pub fn (mut handler EventHandler) handle_pinch_event(position PixelPoint, scale f64) EventResult {
	PinchEvent.decode(position, scale) or { return .dropped }
	handler.log('pinch', none)
	return .handled
}

pub fn (mut handler EventHandler) focus_next_element(candidates []InputTarget) bool {
	return handler.focus_candidate_for_position(candidates, 1)
}

pub fn (mut handler EventHandler) focus_previous_element(candidates []InputTarget) bool {
	return handler.focus_candidate_for_position(candidates, -1)
}

pub fn (mut handler EventHandler) focus_candidate_for_position(candidates []InputTarget,
	delta int) bool {
	if !handler.active_document {
		return false
	}
	mut focusable := []InputTarget{}
	for candidate in candidates {
		if candidate.is_focusable { focusable << candidate }
	}
	if focusable.len == 0 {
		return false
	}
	mut current_index := -1
	for i, candidate in focusable {
		if candidate.id == handler.focused_target_ {
			current_index = i
			break
		}
	}
	index := if current_index < 0 {
		if delta < 0 { focusable.len - 1 } else { 0 }
	} else {
		(current_index + delta % focusable.len + focusable.len) % focusable.len
	}
	handler.focused_target_ = focusable[index].id
	handler.focused_target_state = focusable[index]
	return true
}

pub fn (mut handler EventHandler) fire_keyboard_event(name string, key int,
	code_point u32, modifiers u32, repeat bool, cancelled bool) EventResult {
	return if name == 'keyup' {
		handler.handle_keyup(repeat, cancelled)
	} else {
		handler.handle_keydown(key, code_point, modifiers, repeat, cancelled)
	}
}

pub fn (mut handler EventHandler) handle_gamepad_connected(index u32) {
	handler.log('gamepad-connected:${index}', none)
}

pub fn (mut handler EventHandler) handle_gamepad_updated(index u32) {
	handler.log('gamepad-updated:${index}', none)
}

pub fn (mut handler EventHandler) handle_gamepad_disconnected(index u32) {
	handler.log('gamepad-disconnected:${index}', none)
}

pub fn (mut handler EventHandler) handle_sdl_input_events() {
	handler.log('poll-sdl-input-events', none)
}

pub fn (handler &EventHandler) compute_mouse_event_page_offset(position PixelPoint) PixelPoint {
	if document := handler.pointed_document_ {
		viewport := document.viewport_rect()
		return PixelPoint{position.x + viewport.x, position.y + viewport.y}
	}
	return position
}

pub fn (handler &EventHandler) compute_mouse_event_movement(position PixelPoint) PixelPoint {
	previous := handler.previous_screen or { return PixelPoint{} }
	return PixelPoint{ x: position.x - previous.x, y: position.y - previous.y }
}

pub fn (_ &EventHandler) target_for_mouse_position(position PixelPoint,
	targets []PositionedTarget) ?InputTarget {
	for candidate in targets {
		if candidate.rect.contains(position) {
			return candidate.target
		}
	}
	return none
}

pub fn (_ &EventHandler) target_node_for_mouse_position(document &dom.Document,
	position PixelPoint) ?&dom.Node {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.event_handler_handle_mouse_down)
	mutable_document.update_paint_and_hit_testing_properties_if_needed()
	paintable := document.paintable() or { return none }
	hit := paintable.hit_test(position.x, position.y, .exact) or { return none }
	target := Target.from_hit_test_result(hit) or { return none }
	return target.dom_node
}

pub fn (handler &EventHandler) has_committed_root_box(document &dom.Document) bool {
	viewport := document.layout_node() or { return false }
	return viewport.root_layout_node() != none && document.paintable() != none
}

fn dictionary_word_range(text string, index int) ?SelectionRange {
	if text.len == 0 {
		return none
	}
	mut offset := if index < 0 { 0 } else if index >= text.len { text.len - 1 } else { index }
	if !(text[offset].is_alnum() || text[offset] == `_`) && offset > 0
		&& (text[offset - 1].is_alnum() || text[offset - 1] == `_`) {
		offset--
	}
	if !(text[offset].is_alnum() || text[offset] == `_`) {
		return none
	}
	mut start := offset
	for start > 0 && (text[start - 1].is_alnum() || text[start - 1] == `_`) {
		start--
	}
	mut end := offset + 1
	for end < text.len && (text[end].is_alnum() || text[end] == `_`) {
		end++
	}
	return SelectionRange{start: start, end: end}
}

pub fn (mut handler EventHandler) select_word_at_position(document &dom.Document,
	position PixelPoint) bool {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.event_handler_handle_mouse_down)
	if !handler.has_committed_root_box(document) {
		return false
	}
	paintable := document.paintable() or { return false }
	hit := paintable.hit_test(position.x, position.y, .exact) or { return false }
	node := if hit.node != unsafe { nil } {
		hit.node
	} else if hit.element != unsafe { nil } {
		hit.element.as_node()
	} else {
		return false
	}
	text := node.text_content() or { return false }
	range := dictionary_word_range(text, hit.index_in_node) or { return false }
	handler.input_selection_range_ = range
	handler.selection_mode_ = .word
	handler.log('dictionary-selection', InputTarget{id: node.unique_id().value().str()})
	return true
}

pub fn (mut handler EventHandler) select_word_for_dictionary_lookup(document &dom.Document,
	position PixelPoint) bool {
	return handler.select_word_at_position(document, position)
}

pub fn (mut handler EventHandler) reset_mouse_input_tracking() {
	handler.clear_mousedown_tracking()
	handler.stop_updating_selection()
}

pub fn (mut handler EventHandler) record_last_known_mouse_position(visual_viewport_position PixelPoint,
	screen_position PixelPoint, buttons u32, modifiers u32) {
	handler.last_known_mouse_visual_position_ = visual_viewport_position
	handler.last_known_mouse_screen_position_ = screen_position
	handler.last_known_mouse_buttons_ = buttons
	handler.last_known_mouse_modifiers_ = modifiers
}

pub fn (mut handler EventHandler) clear_per_test_input_state() {
	handler.reset_mouse_input_tracking()
	handler.clear_middle_button_scroll_handler()
	handler.prevent_mouse_event = false
	handler.update_hovered_chrome_widget('')
	handler.captured_chrome_widget = ''
	handler.drag_and_drop.reset()
	handler.previous_screen = none
	handler.last_known_mouse_visual_position_ = none
	handler.last_known_mouse_screen_position_ = none
	handler.last_known_mouse_buttons_ = 0
	handler.last_known_mouse_modifiers_ = 0
	handler.last_known_mouse_target_ = none
	handler.last_wheel_event_ = none
}

pub fn (_ &EventHandler) word_segmenter() string {
	return 'unicode-word-segmenter'
}

pub fn (mut handler DragAndDropEventHandler) handle_drag_leave(target DragTarget) {
	handler.dispatch('dragleave', target, none, false, .none)
	if current := handler.current_target_ {
		if current == target {
			handler.current_target_ = none
		}
	}
}

pub fn (mut handler DragAndDropEventHandler) handle_drop(cancelled bool,
	requested_effect DragEffect) EventResult {
	return handler.handle_drag_end(false, cancelled, requested_effect)
}

pub fn (mut handler DragAndDropEventHandler) fire_a_drag_and_drop_event(name string,
	target ?DragTarget, related ?DragTarget, cancelled bool, requested_effect DragEffect) {
	handler.dispatch(name, target, related, cancelled, requested_effect)
}

pub fn (handler &DragAndDropEventHandler) allow_text_drop(target DragTarget) bool {
	return target.allows_text_drop && handler.has_text_item()
}

pub fn (_ &AutoScrollHandler) find_scrollable_ancestor(targets []InputTarget) ?InputTarget {
	for target in targets {
		if target.has_scrollable_box {
			return target
		}
	}
	return none
}

pub fn (mut handler AutoScrollHandler) activate(mouse PixelPoint, scrollport PixelRect,
	viewport PixelRect, is_text_control bool) PixelPoint {
	return handler.process(mouse, scrollport, viewport, is_text_control)
}

pub fn (mut store SharedBackingStore) release_iosurface_port() ![]u8 {
	return store.release()
}

pub fn (store &SharedBackingStore) bitmap() []u8 {
	return store.bytes()
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Upstream Actions.cpp surface over the portable synchronous dispatcher.
module webdriver

import x.json2

pub enum ActionFieldKind {
	pause
	key
	pointer_up_down
	pointer_move
	pointer_cancel
	scroll
}

pub struct PauseFields {
pub:
	duration ?u64
}

pub struct KeyFields {
pub:
	value ?string
}

pub struct PointerUpDownFields {
pub:
	pointer_type PointerSubtype
	button       ?u32
}

pub struct PointerMoveFields {
pub:
	pointer_type PointerSubtype
	duration     ?u64
	origin       string
	x            f64
	y            f64
}

pub struct PointerCancelFields {
pub:
	pointer_type PointerSubtype
}

pub struct ScrollFields {
pub:
	duration ?u64
	origin   string
	x        f64
	y        f64
	delta_x  i64
	delta_y  i64
}

pub fn action_object_subtype_from_string(value string) ?ActionSubtype {
	return subtype_from_string(value)
}

pub fn fields_from_subtype(subtype ActionSubtype) ActionFieldKind {
	return match subtype {
		.pause { .pause }
		.key_up, .key_down { .key }
		.pointer_up, .pointer_down { .pointer_up_down }
		.pointer_move { .pointer_move }
		.pointer_cancel { .pointer_cancel }
		.scroll { .scroll }
	}
}

pub fn (mut action ActionObject) set_pointer_type(pointer_type PointerSubtype) {
	action.pointer_type = pointer_type
}

pub fn (action &ActionObject) pause_fields() PauseFields {
	return PauseFields{duration: action.duration_ms}
}

pub fn (action &ActionObject) key_fields() KeyFields {
	return KeyFields{value: action.key}
}

pub fn (action &ActionObject) pointer_up_down_fields() PointerUpDownFields {
	return PointerUpDownFields{
		pointer_type: action.pointer_type
		button:       action.button
	}
}

pub fn (action &ActionObject) pointer_move_fields() PointerMoveFields {
	return PointerMoveFields{
		pointer_type: action.pointer_type
		duration:     action.duration_ms
		origin:       action.origin
		x:            action.x
		y:            action.y
	}
}

pub fn (action &ActionObject) pointer_cancel_fields() PointerCancelFields {
	return PointerCancelFields{pointer_type: action.pointer_type}
}

pub fn (action &ActionObject) scroll_fields() ScrollFields {
	return ScrollFields{
		duration: action.duration_ms
		origin:   action.origin
		x:        action.x
		y:        action.y
		delta_x:  action.delta_x
		delta_y:  action.delta_y
	}
}

pub fn determine_origin(object map[string]json2.Any, wheel bool) !string {
	return parse_origin(object, wheel)
}

pub struct CoordinateOffset {
pub:
	x f64
	y f64
}

pub fn get_parent_offset(parent_frames []Rect) CoordinateOffset {
	mut x := 0.0
	mut y := 0.0
	for frame in parent_frames {
		x += frame.x
		y += frame.y
	}
	return CoordinateOffset{x, y}
}

pub fn get_coordinates_relative_to_origin(source InputSource, offset CoordinateOffset, origin string, element_center ?CoordinateOffset, parent_offset CoordinateOffset) !CoordinateOffset {
	mut x := offset.x
	mut y := offset.y
	if origin == 'pointer' {
		x += source.x
		y += source.y
	} else if origin != 'viewport' {
		center := element_center or {
			return error(WebDriverError.from_code(.no_such_element,
				'Element origin was not found').msg())
		}
		x += center.x
		y += center.y
	}
	return CoordinateOffset{x + parent_offset.x, y + parent_offset.y}
}

pub fn process_pointer_parameters(value ?json2.Any) !PointerSubtype {
	actual := value or { return .mouse }
	if actual !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property 'parameters' is not an Object").msg())
	}
	object := actual as map[string]json2.Any
	pointer := object['pointerType'] or { return .mouse }
	if pointer !is string {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property 'pointerType' must be a string").msg())
	}
	return pointer_subtype_from_string(pointer as string) or {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property 'pointerType' must be mouse, pen, or touch").msg())
	}
}

pub fn process_pause_action(object map[string]json2.Any, mut action ActionObject) ! {
	duration := parse_duration(object)!
	action.duration_ms = duration_option(duration)
}

pub fn process_null_action(id string, object map[string]json2.Any) !ActionObject {
	return parse_action(id, .none, .mouse, object)
}

pub fn process_key_action(id string, object map[string]json2.Any) !ActionObject {
	return parse_action(id, .key, .mouse, object)
}

pub fn process_pointer_action_common(object map[string]json2.Any, mut action ActionObject) ! {
	parse_pointer_common(object, mut action)!
}

pub fn process_pointer_up_or_down_action(object map[string]json2.Any, mut action ActionObject) ! {
	button := integer_field(object, 'button', true, 0, 32_767)!
	action.button = u32(button.value)
	parse_pointer_common(object, mut action)!
}

pub fn process_pointer_move_action(id string, pointer_type PointerSubtype, object map[string]json2.Any) !ActionObject {
	return parse_action(id, .pointer, pointer_type, object)
}

pub fn process_pointer_action(id string, pointer_type PointerSubtype, object map[string]json2.Any) !ActionObject {
	return parse_action(id, .pointer, pointer_type, object)
}

pub fn process_wheel_action(id string, object map[string]json2.Any) !ActionObject {
	return parse_action(id, .wheel, .mouse, object)
}

pub fn process_input_source_action_sequence(mut state InputState, value json2.Any) ![]ActionObject {
	return process_action_sequence(mut state, value)
}

pub fn extract_an_action_sequence(mut state InputState, parameters json2.Any) ![][]ActionObject {
	return extract_action_sequence(mut state, parameters)
}

pub fn dispatch_pause_action() {}

pub fn normalized_key_value(key string) string {
	return match key {
		'\ue000' { 'Unidentified' }
		'\ue001' { 'Cancel' }
		'\ue002' { 'Help' }
		'\ue003' { 'Backspace' }
		'\ue004' { 'Tab' }
		'\ue005' { 'Clear' }
		'\ue006' { 'Return' }
		'\ue007' { 'Enter' }
		'\ue008' { 'Shift' }
		'\ue009' { 'Control' }
		'\ue00a' { 'Alt' }
		'\ue00b' { 'Pause' }
		'\ue00c' { 'Escape' }
		'\ue00d' { ' ' }
		'\ue00e' { 'PageUp' }
		'\ue00f' { 'PageDown' }
		'\ue010' { 'End' }
		'\ue011' { 'Home' }
		'\ue012' { 'ArrowLeft' }
		'\ue013' { 'ArrowUp' }
		'\ue014' { 'ArrowRight' }
		'\ue015' { 'ArrowDown' }
		'\ue016' { 'Insert' }
		'\ue017' { 'Delete' }
		'\ue03d' { 'Meta' }
		else { key }
	}
}

pub struct KeyCodeData {
pub:
	key  string
	code string
}

pub fn key_code_data(key string) KeyCodeData {
	normalized := normalized_key_value(key)
	return KeyCodeData{
		key:  normalized
		code: match normalized {
			'Shift' { 'ShiftLeft' }
			'Control' { 'ControlLeft' }
			'Alt' { 'AltLeft' }
			'Meta' { 'MetaLeft' }
			else { normalized }
		}
	}
}

pub fn is_shifted_character(character string) bool {
	if character.len != 1 {
		return false
	}
	return (character[0] >= `A` && character[0] <= `Z`) || character[0] in [`~`, `!`, `@`, `#`, `$`, `%`, `^`,
		`&`, `*`, `(`, `)`, `_`, `+`, `{`, `}`, `|`, `:`, `"`, `<`, `>`, `?`]
}

pub fn key_code_to_page_event(action ActionObject) DispatchedEvent {
	return DispatchedEvent{
		kind:      if action.subtype == .key_down { 'keyDown' } else { 'keyUp' }
		source_id: action.id
		key:       normalized_key_value(action.key or { '' })
	}
}

fn dispatch_one(mut state InputState, action ActionObject) ![]DispatchedEvent {
	return dispatch_tick_actions(mut state, [action])
}

pub fn dispatch_key_down_action(mut state InputState, action ActionObject) ![]DispatchedEvent {
	return dispatch_one(mut state, action)
}

pub fn dispatch_key_up_action(mut state InputState, action ActionObject) ![]DispatchedEvent {
	return dispatch_one(mut state, action)
}

pub fn dispatch_pointer_down_action(mut state InputState, action ActionObject) ![]DispatchedEvent {
	return dispatch_one(mut state, action)
}

pub fn dispatch_pointer_up_action(mut state InputState, action ActionObject) ![]DispatchedEvent {
	return dispatch_one(mut state, action)
}

pub fn perform_pointer_move(mut state InputState, action ActionObject, viewport ?Rect) ![]DispatchedEvent {
	if bounds := viewport {
		return dispatch_tick_actions_in_viewport(mut state, [action], bounds)
	}
	return dispatch_one(mut state, action)
}

pub fn dispatch_pointer_move_action(mut state InputState, action ActionObject, viewport ?Rect) ![]DispatchedEvent {
	return perform_pointer_move(mut state, action, viewport)
}

pub fn wait_for_an_action_queue_token(mut state InputState) {
	// Dispatch is synchronous in the portable model; acquiring and releasing a
	// token therefore completes within this call.
	state.actions_queue << 'webdriver-action-token'
	state.actions_queue.delete_last()
}

pub fn dispatch_actions(mut state InputState, ticks [][]ActionObject) ![]DispatchedEvent {
	mut events := []DispatchedEvent{}
	for tick in ticks {
		wait_for_an_action_queue_token(mut state)
		events << dispatch_tick_actions(mut state, tick)!
	}
	return events
}

pub fn dispatch_list_of_actions(mut state InputState, actions []ActionObject) ![]DispatchedEvent {
	return dispatch_actions(mut state, [actions])
}

pub fn dispatch_the_events_for_a_typeable_string(mut state InputState, input_id string, text string) ![]DispatchedEvent {
	return dispatch_actions_for_string(mut state, input_id, text)
}

pub fn dispatch_actions_for_a_string(mut state InputState, input_id string, text string) ![]DispatchedEvent {
	return dispatch_actions_for_string(mut state, input_id, text)
}

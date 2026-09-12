// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Actions.cpp algorithms over the portable synchronous dispatcher.
module webdriver

import x.json2

__global webdriver_action_token_counter u64

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
	pointer_type        PointerSubtype
	button              ?u32
	width               ?f64
	height              ?f64
	pressure            ?f64
	tangential_pressure ?f64
	tilt_x              ?i32
	tilt_y              ?i32
	twist               ?u32
	altitude_angle      ?f64
	azimuth_angle       ?f64
}

pub struct PointerMoveFields {
pub:
	pointer_type        PointerSubtype
	duration            ?u64
	origin              string
	x                   f64
	y                   f64
	width               ?f64
	height              ?f64
	pressure            ?f64
	tangential_pressure ?f64
	tilt_x              ?i32
	tilt_y              ?i32
	twist               ?u32
	altitude_angle      ?f64
	azimuth_angle       ?f64
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
	return PauseFields{ duration: action.duration_ms }
}

pub fn (action &ActionObject) key_fields() KeyFields {
	return KeyFields{ value: action.key }
}

pub fn (action &ActionObject) pointer_up_down_fields() PointerUpDownFields {
	return PointerUpDownFields{
		pointer_type: action.pointer_type
		button: action.button
		width: action.width
		height: action.height
		pressure: action.pressure
		tangential_pressure: action.tangential_pressure
		tilt_x: action.tilt_x
		tilt_y: action.tilt_y
		twist: action.twist
		altitude_angle: action.altitude_angle
		azimuth_angle: action.azimuth_angle
	}
}

pub fn (action &ActionObject) pointer_move_fields() PointerMoveFields {
	return PointerMoveFields{
		pointer_type: action.pointer_type
		duration: action.duration_ms
		origin: action.origin
		x: action.x
		y: action.y
		width: action.width
		height: action.height
		pressure: action.pressure
		tangential_pressure: action.tangential_pressure
		tilt_x: action.tilt_x
		tilt_y: action.tilt_y
		twist: action.twist
		altitude_angle: action.altitude_angle
		azimuth_angle: action.azimuth_angle
	}
}

pub fn (action &ActionObject) pointer_cancel_fields() PointerCancelFields {
	return PointerCancelFields{ pointer_type: action.pointer_type }
}

pub fn (action &ActionObject) scroll_fields() ScrollFields {
	return ScrollFields{
		duration: action.duration_ms
		origin: action.origin
		x: action.x
		y: action.y
		delta_x: action.delta_x
		delta_y: action.delta_y
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
			return error(WebDriverError.from_code(.no_such_element, 'Element origin was not found').msg())
		}
		x += center.x
		y += center.y
	}
	return CoordinateOffset{x + parent_offset.x, y + parent_offset.y}
}

pub fn process_pointer_parameters(value ?json2.Any) !PointerSubtype {
	actual := value or { return .mouse }
	if actual !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, "Property 'parameters' is not an Object").msg())
	}
	object := actual as map[string]json2.Any
	pointer := object['pointerType'] or { return .mouse }
	if pointer !is string {
		return error(WebDriverError.from_code(.invalid_argument, "Property 'pointerType' must be a string").msg())
	}
	return pointer_subtype_from_string(pointer as string) or {
		return error(WebDriverError.from_code(.invalid_argument, "Property 'pointerType' must be mouse, pen, or touch").msg())
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

// https://w3c.github.io/webdriver/#dfn-dispatch-a-scroll-action
// The browser embedder consumes the returned event as a discrete mouse-wheel
// input after this portable layer has resolved and validated its coordinates.
pub fn dispatch_scroll_action(action_object ActionObject, global_key_state GlobalKeyState, tick_duration u64, viewport Rect) !DispatchedEvent {
	_ = tick_duration
	if action_object.origin != 'viewport' {
		return error(WebDriverError.from_code(.unsupported_operation,
			'Element-origin scrolling requires a host origin resolver').msg())
	}
	coordinates := CoordinateOffset{
		x: action_object.x
		y: action_object.y
	}
	if coordinates.x < viewport.x || coordinates.x > viewport.x + viewport.width
		|| coordinates.y < viewport.y || coordinates.y > viewport.y + viewport.height {
		return error(WebDriverError.from_code(.move_target_out_of_bounds,
			'Coordinates (${coordinates.x}, ${coordinates.y}) are out of bounds').msg())
	}
	return DispatchedEvent{
		kind:       'scroll'
		source_id:  action_object.id
		modifiers:  global_key_state.modifiers()
		x:          coordinates.x
		y:          coordinates.y
		delta_x:    action_object.delta_x
		delta_y:    action_object.delta_y
	}
}

pub fn normalized_key_value(key string) string {
	return match key {
		'' { 'Unidentified' }
		'' { 'Cancel' }
		'' { 'Help' }
		'' { 'Backspace' }
		'' { 'Tab' }
		'' { 'Clear' }
		'' { 'Return' }
		'' { 'Enter' }
		'' { 'Shift' }
		'' { 'Control' }
		'' { 'Alt' }
		'' { 'Pause' }
		'' { 'Escape' }
		'' { ' ' }
		'' { 'PageUp' }
		'' { 'PageDown' }
		'' { 'End' }
		'' { 'Home' }
		'' { 'ArrowLeft' }
		'' { 'ArrowUp' }
		'' { 'ArrowRight' }
		'' { 'ArrowDown' }
		'' { 'Insert' }
		'' { 'Delete' }
		'' { ';' }
		'' { '=' }
		'' { '0' }
		'' { '1' }
		'' { '2' }
		'' { '3' }
		'' { '4' }
		'' { '5' }
		'' { '6' }
		'' { '7' }
		'' { '8' }
		'' { '9' }
		'' { '*' }
		'' { '+' }
		'' { ',' }
		'' { '-' }
		'' { '.' }
		'' { '/' }
		'' { 'F1' }
		'' { 'F2' }
		'' { 'F3' }
		'' { 'F4' }
		'' { 'F5' }
		'' { 'F6' }
		'' { 'F7' }
		'' { 'F8' }
		'' { 'F9' }
		'' { 'F10' }
		'' { 'F11' }
		'' { 'F12' }
		'' { 'Meta' }
		'' { 'ZenkakuHankaku' }
		'' { 'Shift' }
		'' { 'Control' }
		'' { 'Alt' }
		'' { 'Meta' }
		'' { 'PageUp' }
		'' { 'PageDown' }
		'' { 'End' }
		'' { 'Home' }
		'' { 'ArrowLeft' }
		'' { 'ArrowUp' }
		'' { 'ArrowRight' }
		'' { 'ArrowDown' }
		'' { 'Insert' }
		'' { 'Delete' }
		else { key }
	}
}

pub struct KeyCodeData {
pub:
	key           string
	alternate_key ?string
	code          string
	modifiers     u32
}

pub fn key_code_data(key string) KeyCodeData {
	keypad_rows := [
		KeyCodeData{ key: '', code: 'Equal', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit0', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit1', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit2', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit3', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit4', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Digit5', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit6', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit7', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit8', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Digit9', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Plus', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Comma', modifiers: 16 },
		KeyCodeData{ key: '', alternate_key: '', code: 'Period', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Slash', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Return', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Asterisk', modifiers: 16 },
		KeyCodeData{ key: '', code: 'Minus', modifiers: 16 },
	]
	for row in keypad_rows {
		if row.key == key {
			return row
		}
		if alternate := row.alternate_key {
			if alternate == key {
				return row
			}
		}
	}
	mut unshifted := key
	mut shifted := ?string(none)
	mut code := ''
	shift_pairs := {
		'`':  ['~', 'Backquote']
		'\\': ['|', 'Backslash']
		'[':  ['{', 'BracketLeft']
		']':  ['}', 'BracketRight']
		',':  ['<', 'Comma']
		'0':  [')', 'Digit0']
		'1':  ['!', 'Digit1']
		'2':  ['@', 'Digit2']
		'3':  ['#', 'Digit3']
		'4':  ['\$', 'Digit4']
		'5':  ['%', 'Digit5']
		'6':  ['^', 'Digit6']
		'7':  ['&', 'Digit7']
		'8':  ['*', 'Digit8']
		'9':  ['(', 'Digit9']
		'=':  ['+', 'Equal']
		'-':  ['_', 'Minus']
		'.':  ['>', 'Period']
		"'":  ['"', 'Quote']
		';':  [':', 'Semicolon']
		'/':  ['?', 'Slash']
	}
	for base, data in shift_pairs {
		if key == base || key == data[0] {
			unshifted = base
			shifted = data[0]
			code = data[1]
			break
		}
	}
	if key.runes().len == 1 {
		character := key.runes()[0]
		if code.len == 0 && character >= `a` && character <= `z` {
			unshifted = character.str()
			shifted = rune(character - 32).str()
			code = 'Key${shifted or { '' }}'
		} else if code.len == 0 && character >= `A` && character <= `Z` {
			unshifted = rune(character + 32).str()
			shifted = character.str()
			code = 'Key${character.str()}'
		}
	}
	if code.len == 0 {
		code = match key {
			' ' { 'Space' }
			'' { 'Backspace' }
			'' { 'Tab' }
			'' { 'Return' }
			'' { 'ShiftLeft' }
			'' { 'ControlLeft' }
			'' { 'AltLeft' }
			'' { 'Pause' }
			'' { 'Escape' }
			'' { 'Space' }
			'' { 'PageUp' }
			'' { 'PageDown' }
			'' { 'End' }
			'' { 'Home' }
			'' { 'ArrowLeft' }
			'' { 'ArrowUp' }
			'' { 'ArrowRight' }
			'' { 'ArrowDown' }
			'' { 'Insert' }
			'' { 'Delete' }
			'', '', '', '', '', '', '', '', '', '', '', '' {
				normalized_key_value(key)
			}
			'' { 'MetaLeft' }
			'' { 'ShiftRight' }
			'' { 'ControlRight' }
			'' { 'AltRight' }
			'' { 'MetaRight' }
			else { '' }
		}
	}
	return KeyCodeData{
		key: unshifted
		alternate_key: shifted
		code: code
	}
}

pub fn is_shifted_character(character string) bool {
	data := key_code_data(character)
	return data.alternate_key or { return false } == character
}

pub struct KeyPageEvent {
pub:
	code_point string
	modifiers  u32
}

pub fn key_code_to_page_event(raw_key string, initial_modifiers u32, code KeyCodeData) KeyPageEvent {
	mut code_point := if raw_key >= '' && raw_key <= '' {
		match raw_key {
			'' { '\b' }
			'' { '\t' }
			'' { '\n' }
			'' { ' ' }
			'' { ';' }
			'' { '=' }
			'' { '0' }
			'' { '1' }
			'' { '2' }
			'' { '3' }
			'' { '4' }
			'' { '5' }
			'' { '6' }
			'' { '7' }
			'' { '8' }
			'' { '9' }
			'' { '*' }
			'' { '+' }
			'' { ',' }
			'' { '-' }
			'' { '.' }
			'' { '/' }
			else { '' }
		}
	} else {
		raw_key
	}
	modifiers := initial_modifiers | code.modifiers
	if modifiers & 4 != 0 {
		if alternate := code.alternate_key {
			code_point = alternate
		}
	}
	return KeyPageEvent{
		code_point: code_point
		modifiers: modifiers
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
	webdriver_action_token_counter++
	state.actions_queue << 'webdriver-action-token-${webdriver_action_token_counter}'
	// The portable dispatcher is synchronous, so no other action can be ahead
	// of this token. dispatch_actions() removes it after the complete tick list.
	assert state.actions_queue.len == 1
}

pub fn dispatch_actions(mut state InputState, ticks [][]ActionObject) ![]DispatchedEvent {
	wait_for_an_action_queue_token(mut state)
	mut events := []DispatchedEvent{}
	for tick in ticks {
		tick_events := dispatch_tick_actions(mut state, tick) or {
			state.actions_queue.delete(0)
			return err
		}
		events << tick_events
	}
	state.actions_queue.delete(0)
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

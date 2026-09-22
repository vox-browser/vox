// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InputSource, InputState, and Actions.
module webdriver

import math
import x.json2

pub enum InputSourceType {
	none
	key
	pointer
	wheel
}

pub enum PointerSubtype {
	mouse
	pen
	touch
}

pub enum ActionSubtype {
	pause
	key_up
	key_down
	pointer_up
	pointer_down
	pointer_move
	pointer_cancel
	scroll
}

pub struct InputSource {
pub:
	type_           InputSourceType
	pointer_subtype PointerSubtype
	pointer_id      u32
pub mut:
	pressed_keys    []string
	alt             bool
	ctrl            bool
	meta            bool
	shift           bool
	pressed_buttons u32
	x               f64
	y               f64
}

pub struct ActionObject {
pub:
	id      string
	type_   InputSourceType
	subtype ActionSubtype
pub mut:
	duration_ms         ?u64
	key                 ?string
	pointer_type        PointerSubtype
	button              ?u32
	origin              string = 'viewport'
	x                   f64
	y                   f64
	delta_x             i64
	delta_y             i64
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

pub struct InputState {
pub mut:
	input_state_map   map[string]InputSource
	input_cancel_list []ActionObject
	actions_queue     []string
}

pub struct GlobalKeyState {
pub:
	pressed   []string
	alt_key   bool
	ctrl_key  bool
	meta_key  bool
	shift_key bool
}

pub fn input_source_type_from_string(value string) ?InputSourceType {
	return match value {
		'none' { .none }
		'key' { .key }
		'pointer' { .pointer }
		'wheel' { .wheel }
		else { none }
	}
}

pub fn pointer_subtype_from_string(value string) ?PointerSubtype {
	return match value {
		'mouse' { .mouse }
		'pen' { .pen }
		'touch' { .touch }
		else { none }
	}
}

fn next_pointer_id(state InputState, subtype PointerSubtype) u32 {
	mut id := if subtype == .mouse { u32(0) } else { u32(2) }
	for {
		mut used := false
		for _, source in state.input_state_map {
			if source.type_ == .pointer && source.pointer_id == id {
				used = true
				break
			}
		}
		if !used {
			return id
		}
		id++
	}
	return id
}

pub fn create_input_source(state InputState, type_ InputSourceType, subtype ?PointerSubtype) InputSource {
	pointer_type := subtype or { PointerSubtype.mouse }
	return InputSource{
		type_: type_
		pointer_subtype: pointer_type
		pointer_id: if type_ == .pointer { next_pointer_id(state, pointer_type) } else { 0 }
	}
}

pub fn (mut state InputState) get_or_create_input_source(type_ InputSourceType, id string, subtype ?PointerSubtype) !InputSource {
	if existing := state.input_state_map[id] {
		if existing.type_ != type_ {
			return error(WebDriverError.from_code(.invalid_argument, "Property 'type' does not match existing input source type").msg())
		}
		requested_subtype := subtype or { PointerSubtype.mouse }
		if type_ == .pointer && existing.pointer_subtype != requested_subtype {
			return error(WebDriverError.from_code(.invalid_argument, "Invalid 'pointerType' property").msg())
		}
		return existing
	}
	source := create_input_source(state, type_, subtype)
	state.input_state_map[id] = source
	return source
}

pub fn (mut state InputState) remove_input_source(id string) {
	state.input_cancel_list = state.input_cancel_list.filter(it.id != id)
	state.input_state_map.delete(id)
}

pub fn (state InputState) global_key_state() GlobalKeyState {
	mut keys := []string{}
	mut alt := false
	mut ctrl := false
	mut meta := false
	mut shift := false
	for _, source in state.input_state_map {
		if source.type_ != .key {
			continue
		}
		for key in source.pressed_keys {
			if key !in keys { keys << key }
		}
		alt = alt || source.alt
		ctrl = ctrl || source.ctrl
		meta = meta || source.meta
		shift = shift || source.shift
	}
	return GlobalKeyState{
		pressed: keys
		alt_key: alt
		ctrl_key: ctrl
		meta_key: meta
		shift_key: shift
	}
}

fn object_number(object map[string]json2.Any, key string, min ?f64, max ?f64) !f64 {
	value := object[key] or {
		return error(WebDriverError.from_code(.invalid_argument, "Missing property '${key}'").msg())
	}
	mut number := 0.0
	if value is f64 {
		number = value
	} else if value is i64 {
		number = f64(value)
	} else {
		return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' must be a number").msg())
	}
	if math.is_nan(number) || math.is_inf(number, 1) || math.is_inf(number, -1) || number < -f64(maximum_safe_integer) || number > f64(maximum_safe_integer) {
		return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' is outside the allowed range").msg())
	}
	if minimum := min {
		if number < minimum {
			return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' is outside the allowed range").msg())
		}
	}
	if maximum := max {
		if number > maximum {
			return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' is outside the allowed range").msg())
		}
	}
	return number
}

struct OptionalNumber {
	present bool
	value   f64
}

fn number_field(object map[string]json2.Any, key string, min ?f64, max ?f64) !OptionalNumber {
	if key !in object {
		return OptionalNumber{}
	}
	value := object_number(object, key, min, max)!
	return OptionalNumber{
		present: true
		value: value
	}
}

struct OptionalInteger {
	present bool
	value   i64
}

fn integer_field(object map[string]json2.Any, key string, required bool, min ?i64, max ?i64) !OptionalInteger {
	value := object[key] or {
		if required {
			return error(WebDriverError.from_code(.invalid_argument, "Missing property '${key}'").msg())
		}
		return OptionalInteger{}
	}
	mut number := i64(0)
	if value is i64 {
		number = value
	} else if value is f64 && (value as f64) == f64(i64(value as f64)) {
		number = i64(value as f64)
	} else {
		return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' must be an integer").msg())
	}
	if minimum := min {
		if number < minimum {
			return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' is outside the allowed range").msg())
		}
	}
	if maximum := max {
		if number > maximum {
			return error(WebDriverError.from_code(.invalid_argument, "Property '${key}' is outside the allowed range").msg())
		}
	}
	return OptionalInteger{
		present: true
		value: number
	}
}

fn subtype_from_string(value string) ?ActionSubtype {
	return match value {
		'pause' { .pause }
		'keyUp' { .key_up }
		'keyDown' { .key_down }
		'pointerUp' { .pointer_up }
		'pointerDown' { .pointer_down }
		'pointerMove' { .pointer_move }
		'pointerCancel' { .pointer_cancel }
		'scroll' { .scroll }
		else { none }
	}
}

struct DurationField {
	present bool
	value   u64
}

fn parse_duration(object map[string]json2.Any) !DurationField {
	duration := integer_field(object, 'duration', false, i64(0), i64(maximum_safe_integer))!
	return DurationField{
		present: duration.present
		value: u64(duration.value)
	}
}

fn duration_option(duration DurationField) ?u64 {
	if duration.present {
		return duration.value
	}
	return none
}

fn parse_origin(object map[string]json2.Any, wheel bool) !string {
	value := object['origin'] or { return 'viewport' }
	if value is string {
		if value == 'viewport' || (!wheel && value == 'pointer') {
			return value
		}
		return error(WebDriverError.from_code(.invalid_argument, "Property 'origin' has an invalid value").msg())
	}
	if value is map[string]json2.Any {
		if reference := value['element-6066-11e4-a52e-4f735466cecf'] {
			if reference is string {
				return reference
			}
		}
	}
	return error(WebDriverError.from_code(.invalid_argument, "Property 'origin' must identify the viewport, pointer, or an element").msg())
}

fn parse_pointer_common(object map[string]json2.Any, mut action ActionObject) ! {
	width := number_field(object, 'width', 0.0, none)!
	height := number_field(object, 'height', 0.0, none)!
	pressure := number_field(object, 'pressure', 0.0, 1.0)!
	tangential := number_field(object, 'tangentialPressure', -1.0, 1.0)!
	tilt_x := integer_field(object, 'tiltX', false, -90, 90)!
	tilt_y := integer_field(object, 'tiltY', false, -90, 90)!
	twist := integer_field(object, 'twist', false, 0, 359)!
	altitude := number_field(object, 'altitudeAngle', 0.0, math.pi / 2.0)!
	azimuth := number_field(object, 'azimuthAngle', 0.0, math.pi * 2.0)!
	if width.present {
		action.width = width.value
	}
	if height.present {
		action.height = height.value
	}
	if pressure.present {
		action.pressure = pressure.value
	}
	if tangential.present {
		action.tangential_pressure = tangential.value
	}
	if tilt_x.present {
		action.tilt_x = i32(tilt_x.value)
	}
	if tilt_y.present {
		action.tilt_y = i32(tilt_y.value)
	}
	if twist.present {
		action.twist = u32(twist.value)
	}
	if altitude.present {
		action.altitude_angle = altitude.value
	}
	if azimuth.present {
		action.azimuth_angle = azimuth.value
	}
}

fn parse_action(id string, type_ InputSourceType, pointer_type PointerSubtype, object map[string]json2.Any) !ActionObject {
	subtype_name := string_property(object, 'type')!
	subtype := subtype_from_string(subtype_name) or {
		return error(WebDriverError.from_code(.invalid_argument, "Unknown action subtype '${subtype_name}'").msg())
	}
	valid := match type_ {
		.none { subtype == .pause }
		.key { subtype in [.pause, .key_up, .key_down] }
		.pointer { subtype in [.pause, .pointer_up, .pointer_down, .pointer_move, .pointer_cancel] }
		.wheel { subtype in [.pause, .scroll] }
	}
	if !valid {
		return error(WebDriverError.from_code(.invalid_argument, "Action subtype '${subtype_name}' is invalid for this source").msg())
	}
	if subtype == .pointer_cancel {
		return error(WebDriverError.from_code(.unsupported_operation, 'pointerCancel events not implemented').msg())
	}
	mut action := ActionObject{
		id: id
		type_: type_
		subtype: subtype
		pointer_type: pointer_type
	}
	if subtype == .pause {
		action = ActionObject{
			...action
			duration_ms: duration_option(parse_duration(object)!)
		}
		return action
	}
	if subtype in [.key_up, .key_down] {
		key := string_property(object, 'value')!
		if key.runes().len != 1 {
			return error(WebDriverError.from_code(.invalid_argument, "Property 'value' must be a single code point").msg())
		}
		return ActionObject{
			...action
			key: key
		}
	}
	if subtype in [.pointer_up, .pointer_down] {
		button := integer_field(object, 'button', true, 0, 32_767)!
		action = ActionObject{
			...action
			button: u32(button.value)
		}
		parse_pointer_common(object, mut action)!
		return action
	}
	if subtype == .pointer_move {
		x := object_number(object, 'x', none, none)!
		y := object_number(object, 'y', none, none)!
		action = ActionObject{
			...action
			duration_ms: duration_option(parse_duration(object)!)
			origin: parse_origin(object, false)!
			x: x
			y: y
		}
		parse_pointer_common(object, mut action)!
		return action
	}
	safe_min := -i64(maximum_safe_integer)
	safe_max := i64(maximum_safe_integer)
	x := integer_field(object, 'x', true, safe_min, safe_max)!
	y := integer_field(object, 'y', true, safe_min, safe_max)!
	delta_x := integer_field(object, 'deltaX', true, safe_min, safe_max)!
	delta_y := integer_field(object, 'deltaY', true, safe_min, safe_max)!
	return ActionObject{
		...action
		duration_ms: duration_option(parse_duration(object)!)
		origin: parse_origin(object, true)!
		x: f64(x.value)
		y: f64(y.value)
		delta_x: delta_x.value
		delta_y: delta_y.value
	}
}

fn process_action_sequence(mut state InputState, value json2.Any) ![]ActionObject {
	if value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Action sequence is not an object').msg())
	}
	object := value as map[string]json2.Any
	type_name := string_property(object, 'type')!
	type_ := input_source_type_from_string(type_name) or {
		return error(WebDriverError.from_code(.invalid_argument, "Invalid input source type '${type_name}'").msg())
	}
	id := string_property(object, 'id')!
	mut pointer_type := PointerSubtype.mouse
	if type_ == .pointer {
		if parameters := object['parameters'] {
			if parameters !is map[string]json2.Any {
				return error(WebDriverError.from_code(.invalid_argument, "Property 'parameters' is not an Object").msg())
			}
			parameter_object := parameters as map[string]json2.Any
			if pointer := parameter_object['pointerType'] {
				if pointer !is string {
					return error(WebDriverError.from_code(.invalid_argument, "Property 'pointerType' must be a string").msg())
				}
				pointer_type = pointer_subtype_from_string(pointer as string) or {
					return error(WebDriverError.from_code(.invalid_argument, "Property 'pointerType' must be mouse, pen, or touch").msg())
				}
			}
		}
	}
	if type_ == .pointer {
		state.get_or_create_input_source(type_, id, pointer_type)!
	} else {
		state.get_or_create_input_source(type_, id, none)!
	}
	items := object['actions'] or {
		return error(WebDriverError.from_code(.invalid_argument, "Missing property 'actions'").msg())
	}
	if items !is []json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, "Property 'actions' must be an array").msg())
	}
	mut result := []ActionObject{}
	for item in items as []json2.Any {
		if item !is map[string]json2.Any {
			return error(WebDriverError.from_code(.invalid_argument, "Property 'actions' item is not an Object").msg())
		}
		result << parse_action(id, type_, pointer_type, item as map[string]json2.Any)!
	}
	return result
}

pub fn extract_action_sequence(mut state InputState, parameters json2.Any) ![][]ActionObject {
	if parameters !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, 'Parameters must be an object').msg())
	}
	outer := parameters as map[string]json2.Any
	actions := outer['actions'] or {
		return error(WebDriverError.from_code(.invalid_argument, "Missing property 'actions'").msg())
	}
	if actions !is []json2.Any {
		return error(WebDriverError.from_code(.invalid_argument, "Property 'actions' must be an array").msg())
	}
	mut ticks := [][]ActionObject{}
	for sequence in actions as []json2.Any {
		source_actions := process_action_sequence(mut state, sequence)!
		for index, action in source_actions {
			for ticks.len <= index {
				ticks << []ActionObject{}
			}
			ticks[index] << action
		}
	}
	return ticks
}

pub fn compute_tick_duration(actions []ActionObject) u64 {
	mut maximum := u64(0)
	for action in actions {
		if duration := action.duration_ms {
			if duration > maximum {
				maximum = duration
			}
		}
	}
	return maximum
}

pub struct DispatchedEvent {
pub:
	kind         string
	source_id    string
	key          string
	code         string
	code_point   string
	repeat       bool
	modifiers    u32
	x            f64
	y            f64
	button       u32
	buttons      u32
	pointer_id   u32
	pointer_type PointerSubtype
	delta_x      i64
	delta_y      i64
}

fn button_mask(button u32) u32 {
	return match button {
		0 { 1 }
		1 { 4 }
		2 { 2 }
		3 { 8 }
		4 { 16 }
		else { 0 }
	}
}

// DOM lookup remains a host responsibility. The embedder resolves an element
// reference to its in-view center and supplies the resulting action to the
// portable dispatcher.
pub fn resolve_pointer_move_element_origin(action ActionObject, center_x f64, center_y f64) ActionObject {
	return ActionObject{
		...action
		origin: 'viewport'
		x: center_x + action.x
		y: center_y + action.y
	}
}

pub fn resolve_scroll_element_origin(action ActionObject, center_x f64, center_y f64) ActionObject {
	return ActionObject{
		...action
		origin: 'viewport'
		x: center_x + action.x
		y: center_y + action.y
	}
}

pub fn dispatch_tick_actions(mut state InputState, actions []ActionObject) ![]DispatchedEvent {
	return dispatch_tick_actions_with_viewport(mut state, actions, none)
}

pub fn dispatch_tick_actions_in_viewport(mut state InputState, actions []ActionObject, viewport Rect) ![]DispatchedEvent {
	return dispatch_tick_actions_with_viewport(mut state, actions, viewport)
}

fn dispatch_tick_actions_with_viewport(mut state InputState, actions []ActionObject, viewport ?Rect) ![]DispatchedEvent {
	mut events := []DispatchedEvent{}
	for action in actions {
		if action.subtype == .pause {
			continue
		}
		mut source := state.input_state_map[action.id] or {
			return error(WebDriverError.from_code(.unknown_error, 'Input source is missing').msg())
		}
		match action.subtype {
			.key_down {
				raw_key := action.key or { '' }
				key := normalized_key_value(raw_key)
				repeat := key in source.pressed_keys
				mut modifiers := state.global_key_state().modifiers()
				if !repeat { source.pressed_keys << key }
				match key {
					'Shift' {
						modifiers |= 4
						source.shift = true
					}
					'Control' {
						modifiers |= 2
						source.ctrl = true
					}
					'Alt' {
						modifiers |= 1
						source.alt = true
					}
					'Meta' {
						modifiers |= 8
						source.meta = true
					}
					else {}
				}
				code := key_code_data(raw_key)
				page_event := key_code_to_page_event(raw_key, modifiers, code)
				events << DispatchedEvent{
					kind: 'keyDown'
					source_id: action.id
					key: key
					code: code.code
					code_point: page_event.code_point
					repeat: repeat
					modifiers: page_event.modifiers
				}
				state.input_cancel_list << ActionObject{
					id: action.id
					type_: .key
					subtype: .key_up
					key: raw_key
				}
			}
			.key_up {
				raw_key := action.key or { '' }
				key := normalized_key_value(raw_key)
				if key !in source.pressed_keys {
					continue
				}
				mut modifiers := state.global_key_state().modifiers()
				source.pressed_keys = source.pressed_keys.filter(it != key)
				match key {
					'Shift' {
						modifiers &= ~u32(4)
						source.shift = false
					}
					'Control' {
						modifiers &= ~u32(2)
						source.ctrl = false
					}
					'Alt' {
						modifiers &= ~u32(1)
						source.alt = false
					}
					'Meta' {
						modifiers &= ~u32(8)
						source.meta = false
					}
					else {}
				}
				code := key_code_data(raw_key)
				page_event := key_code_to_page_event(raw_key, modifiers, code)
				events << DispatchedEvent{
					kind: 'keyUp'
					source_id: action.id
					key: key
					code: code.code
					code_point: page_event.code_point
					modifiers: page_event.modifiers
				}
			}
			.pointer_down {
				button := action.button or { 0 }
				mask := button_mask(button)
				// Ladybird's enum has_flag() considers the zero/None mask present.
				already_pressed := mask == 0 || source.pressed_buttons & mask != 0
				if already_pressed {
					state.input_cancel_list << ActionObject{
						id: action.id
						type_: .pointer
						subtype: .pointer_up
						button: button
					}
					continue
				}
				source.pressed_buttons |= mask
				if source.pointer_subtype != .mouse {
					state.input_state_map[action.id] = source
					return error(WebDriverError.from_code(.unsupported_operation, 'Dispatching ${source.pointer_subtype} pointerDown is not implemented').msg())
				}
				events << DispatchedEvent{
					kind: 'pointerDown'
					source_id: action.id
					button: mask
					buttons: source.pressed_buttons
					pointer_id: source.pointer_id
					pointer_type: source.pointer_subtype
					modifiers: state.global_key_state().modifiers()
					x: source.x
					y: source.y
				}
				state.input_cancel_list << ActionObject{
					id: action.id
					type_: .pointer
					subtype: .pointer_up
					button: button
				}
			}
			.pointer_up {
				button := action.button or { 0 }
				mask := button_mask(button)
				is_pressed := mask == 0 || source.pressed_buttons & mask != 0
				if !is_pressed {
					continue
				}
				source.pressed_buttons &= ~mask
				if source.pointer_subtype != .mouse {
					state.input_state_map[action.id] = source
					return error(WebDriverError.from_code(.unsupported_operation, 'Dispatching ${source.pointer_subtype} pointerUp is not implemented').msg())
				}
				events << DispatchedEvent{
					kind: 'pointerUp'
					source_id: action.id
					button: mask
					buttons: source.pressed_buttons
					pointer_id: source.pointer_id
					pointer_type: source.pointer_subtype
					modifiers: state.global_key_state().modifiers()
					x: source.x
					y: source.y
				}
			}
			.pointer_move {
				if action.origin != 'viewport' && action.origin != 'pointer' {
					return error(WebDriverError.from_code(.unsupported_operation, 'Element-origin pointer movement requires a host origin resolver').msg())
				}
				new_x := if action.origin == 'pointer' { source.x + action.x } else { action.x }
				new_y := if action.origin == 'pointer' { source.y + action.y } else { action.y }
				if bounds := viewport {
					if new_x < bounds.x || new_x > bounds.x + bounds.width || new_y < bounds.y || new_y > bounds.y + bounds.height {
						return error(WebDriverError.from_code(.move_target_out_of_bounds, 'Coordinates (${new_x}, ${new_y}) are out of bounds').msg())
					}
				}
				if new_x == source.x && new_y == source.y {
					continue
				}
				if source.pointer_subtype != .mouse {
					return error(WebDriverError.from_code(.unsupported_operation, 'Dispatching ${source.pointer_subtype} pointerMove is not implemented').msg())
				}
				source.x = new_x
				source.y = new_y
				events << DispatchedEvent{
					kind: 'pointerMove'
					source_id: action.id
					buttons: source.pressed_buttons
					pointer_id: source.pointer_id
					pointer_type: source.pointer_subtype
					modifiers: state.global_key_state().modifiers()
					x: source.x
					y: source.y
				}
			}
			.scroll {
				bounds := viewport or { Rect{
					width:  f64(maximum_safe_integer)
					height: f64(maximum_safe_integer)
				} }
				events << dispatch_scroll_action(action, state.global_key_state(), action.duration_ms or { 0 }, bounds)!
			}
			else {}
		}
		state.input_state_map[action.id] = source
	}
	return events
}

pub fn dispatch_actions_for_string(mut state InputState, input_id string, text string) ![]DispatchedEvent {
	state.get_or_create_input_source(.key, input_id, none)!
	mut ticks := [][]ActionObject{}
	mut predicted_shift := (state.input_state_map[input_id] or { InputSource{} }).shift
	for character in text.runes() {
		key := character.str()
		is_shifted := is_shifted_character(key)
		if is_shifted && !predicted_shift {
			ticks << [
				ActionObject{ id: input_id, type_: .key, subtype: .key_down, key: '' },
			]
			predicted_shift = true
		} else if !is_shifted && predicted_shift {
			ticks << [
				ActionObject{ id: input_id, type_: .key, subtype: .key_up, key: '' },
			]
			predicted_shift = false
		}
		ticks << [
			ActionObject{ id: input_id, type_: .key, subtype: .key_down, key: key },
			ActionObject{ id: input_id, type_: .key, subtype: .key_up, key: key },
		]
	}
	return dispatch_actions(mut state, ticks)
}

module webdriver

fn test_extract_action_sequence_transposes_sources_into_ticks() {
	payload :=
		json_value_from_text('{"actions":[{"type":"key","id":"keyboard","actions":[{"type":"keyDown","value":"a"},{"type":"keyUp","value":"a"}]},{"type":"pointer","id":"mouse","parameters":{"pointerType":"mouse"},"actions":[{"type":"pointerMove","x":4,"y":8,"duration":25},{"type":"pointerDown","button":0}]}]}')
	mut state := InputState{}
	ticks := extract_action_sequence(mut state, payload) or { panic(err) }
	assert ticks.len == 2
	assert ticks[0].len == 2
	assert compute_tick_duration(ticks[0]) == 25
	assert state.input_state_map['mouse'].pointer_id == 0
	events := dispatch_tick_actions(mut state, ticks[0]) or { panic(err) }
	assert events.map(it.kind) == ['keyDown', 'pointerMove']
	assert state.global_key_state().pressed == ['a']
	assert state.input_state_map['mouse'].x == 4
	dispatch_tick_actions(mut state, ticks[1]) or { panic(err) }
	assert state.global_key_state().pressed.len == 0
	assert state.input_cancel_list.len == 2
}

fn test_action_validation_enforces_unicode_ranges_and_source_identity() {
	mut state := InputState{}
	extract_action_sequence(mut state,
		json_value_from_text('{"actions":[{"type":"key","id":"k","actions":[{"type":"keyDown","value":"ab"}]}]}')) or {
		assert err.msg().contains('single code point')
		return
	}
	assert false
}

fn test_pointer_ids_and_remove_source_cancel_entries() {
	mut state := InputState{}
	pen := state.get_or_create_input_source(.pointer, 'pen', PointerSubtype.pen) or { panic(err) }
	touch := state.get_or_create_input_source(.pointer, 'touch', PointerSubtype.touch) or {
		panic(err)
	}
	assert pen.pointer_id == 2
	assert touch.pointer_id == 3
	state.input_cancel_list << ActionObject{
		id:      'pen'
		type_:   .pointer
		subtype: .pointer_up
	}
	state.remove_input_source('pen')
	assert 'pen' !in state.input_state_map
	assert state.input_cancel_list.len == 0
}

fn test_dispatch_actions_for_string_balances_key_state() {
	mut state := InputState{}
	events := dispatch_actions_for_string(mut state, 'keyboard', 'A🙂') or { panic(err) }
	assert events.len == 4
	assert state.global_key_state().pressed.len == 0
}

fn test_action_numeric_values_are_limited_to_javascript_safe_integers() {
	mut state := InputState{}
	extract_action_sequence(mut state,
		json_value_from_text('{"actions":[{"type":"pointer","id":"mouse","actions":[{"type":"pointerMove","x":9007199254740992,"y":0}]}]}')) or {
		assert err.msg().contains('outside the allowed range')
		return
	}
	assert false
}

fn test_pointer_dispatch_uses_webdriver_button_masks_and_suppresses_duplicates() {
	mut state := InputState{}
	state.input_state_map['mouse'] = InputSource{
		type_:           .pointer
		pointer_subtype: .mouse
	}
	down := ActionObject{
		id:      'mouse'
		type_:   .pointer
		subtype: .pointer_down
		button:  1
	}
	first_events := dispatch_tick_actions(mut state, [down]) or { panic(err) }
	assert first_events.len == 1
	assert first_events[0].button == 4
	unknown_up_events := dispatch_tick_actions(mut state, [
		ActionObject{
			id:      'mouse'
			type_:   .pointer
			subtype: .pointer_up
			button:  9
		},
	]) or { panic(err) }
	assert unknown_up_events.len == 1
	assert unknown_up_events[0].button == 0
	assert state.input_state_map['mouse'].pressed_buttons == 4
	assert (dispatch_tick_actions(mut state, [down]) or { panic(err) }).len == 0
	assert state.input_cancel_list.len == 2
	up := ActionObject{
		id:      'mouse'
		type_:   .pointer
		subtype: .pointer_up
		button:  1
	}
	assert (dispatch_tick_actions(mut state, [up]) or { panic(err) }).len == 1
	assert state.input_state_map['mouse'].pressed_buttons == 0
	assert (dispatch_tick_actions(mut state, [up]) or { panic(err) }).len == 0
}

fn test_dispatch_preserves_current_upstream_unsupported_boundaries() {
	mut state := InputState{}
	state.input_state_map['wheel'] = InputSource{
		type_: .wheel
	}
	dispatch_tick_actions(mut state, [
		ActionObject{
			id:      'wheel'
			type_:   .wheel
			subtype: .scroll
		},
	]) or {
		assert err.msg().contains('not implemented')
		return
	}
	assert false
}

fn test_pointer_move_viewport_boundary_reports_protocol_error() {
	mut state := InputState{}
	state.input_state_map['mouse'] = InputSource{
		type_:           .pointer
		pointer_subtype: .mouse
	}
	dispatch_tick_actions_in_viewport(mut state, [
		ActionObject{
			id:      'mouse'
			type_:   .pointer
			subtype: .pointer_move
			x:       101
			y:       4
		},
	], Rect{ width: 100, height: 100 }) or {
		assert err.msg().contains('move target out of bounds')
		return
	}
	assert false
}

fn test_host_can_resolve_element_origin_before_pointer_dispatch() {
	action := resolve_pointer_move_element_origin(ActionObject{
		id:      'mouse'
		type_:   .pointer
		subtype: .pointer_move
		origin:  'element-1'
		x:       2
		y:       -1
	}, 20, 30)
	assert action.origin == 'viewport'
	assert action.x == 22
	assert action.y == 29
}

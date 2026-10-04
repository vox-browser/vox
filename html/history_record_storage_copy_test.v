module html

import dom
import libjs
import math

fn test_source_session_history_default_states_use_storage_serialization() {
	entry := &SessionHistoryEntry{}
	assert entry.classic_history_api_state.type_ == .storage
	assert entry.classic_history_api_state.data == structured_serialize_for_storage(dom.js_null())!.data
	assert structured_deserialize(entry.classic_history_api_state)!.kind == .null_
	assert entry.navigation_api_state.type_ == .storage
	assert entry.navigation_api_state.data == structured_serialize_for_storage(dom.js_undefined())!.data
	assert structured_deserialize(entry.navigation_api_state)!.kind == .undefined
}

fn test_history_clone_and_destination_keep_source_storage_record_kind_and_bytes() {
	units := [u16(0x006e), 0xd800, 0, 0xdc00, 0xd83d, 0xde00]
	classic := structured_serialize_for_storage(dom.js_utf16_string(libjs.utf16_string_from_code_units(units)))!
	navigation := structured_serialize_for_storage(dom.js_number(math.f64_from_bits(0x8000000000000000)))!
	entry := &SessionHistoryEntry{
		document_state:            &DocumentState{}
		classic_history_api_state: classic
		navigation_api_state:      navigation
	}
	copy := entry.clone()
	assert copy.classic_history_api_state.type_ == .storage
	assert structured_deserialize(copy.classic_history_api_state)!.string_utf16_?.code_units() == units
	assert copy.navigation_api_state.type_ == .storage
	assert math.f64_bits(structured_deserialize(copy.navigation_api_state)!.number_data) == 0x8000000000000000
	mut destination := NavigationDestination.create()
	destination.set_state(copy.classic_history_api_state)
	assert destination.get_state()!.string_utf16_?.code_units() == units
	destination.set_state(copy.navigation_api_state)
	assert math.f64_bits(destination.get_state()!.number_data) == 0x8000000000000000
}

fn test_navigation_population_and_redirect_state_preserve_storage_payloads() {
	initial := structured_serialize_for_storage(dom.js_string('initial'))!
	navigation := structured_serialize_for_storage(dom.js_bool(true))!
	mut request := create_navigation_population_request(NavigationStartRequest{
		url:                       dom.URL{ value: 'https://history.test/' }
		classic_history_api_state: initial
		navigation_api_state:      navigation
	}, 71)
	assert request.history_entry.classic_history_api_state.type_ == .storage
	assert structured_deserialize(request.history_entry.classic_history_api_state)!.string_data == 'initial'
	assert request.history_entry.navigation_api_state.type_ == .storage
	assert structured_deserialize(request.history_entry.navigation_api_state)!.boolean_data
	redirected := structured_serialize_for_storage(dom.js_number(-2147483648))!
	apply_navigation_population_result(mut request, NavigationPopulationResult{
		classic_history_api_state: redirected
	})
	assert request.history_entry.classic_history_api_state.type_ == .storage
	assert structured_deserialize(request.history_entry.classic_history_api_state)!.number_data == -2147483648
}

fn test_existing_ipc_record_adapter_keeps_its_distinct_kind_during_copies() {
	// Existing standalone callers can still supply IPC DTOs; copies preserve
	// their representation rather than reclassifying bytes by an envelope probe.
	record := structured_serialize(dom.js_string('adapter'))!
	entry := &SessionHistoryEntry{
		document_state:            &DocumentState{}
		classic_history_api_state: record
		navigation_api_state:      record
	}
	copy := entry.clone()
	assert copy.classic_history_api_state.type_ == .ipc
	assert structured_deserialize(copy.classic_history_api_state)!.string_data == 'adapter'
	mut destination := NavigationDestination.create()
	destination.set_state(copy.navigation_api_state)
	assert destination.get_state()!.string_data == 'adapter'
}

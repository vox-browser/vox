module html

import dom
import libjs
import math

fn test_actual_document_history_restore_selects_source_storage_codec() {
	mut document := dom.Document.create(dom.URL{ value: 'https://history.test/' })
	_ = WindowModel.create_top_level(document, none, 'history-storage-owner')!
	defer { document.finalize() }
	for value in [dom.js_bool(true), dom.js_number(-2147483648), dom.js_string('stored')] {
		record := structured_serialize_for_storage(value)!
		entry := &dom.SessionHistoryEntry{
			url:                       document.url
			classic_history_api_state: dom.DOMSerializationRecord{ data: record.data.clone() }
		}
		document.restore_the_history_object_state(entry)
		assert document.history().state.kind == value.kind
		assert structured_serialize_for_storage(document.history().state)!.data == record.data
	}
}

fn test_actual_history_storage_restore_keeps_raw_utf16_and_signed_zero() {
	mut document := dom.Document.create(dom.URL{ value: 'https://history.test/' })
	_ = WindowModel.create_top_level(document, none, 'history-storage-bits')!
	defer { document.finalize() }
	units := [u16(0x006e), 0xd800, 0, 0xdc00, 0xd83d, 0xde00]
	value := dom.js_utf16_string(libjs.utf16_string_from_code_units(units))
	record := structured_serialize_for_storage(value)!
	document.restore_the_history_object_state(&dom.SessionHistoryEntry{
		classic_history_api_state: dom.DOMSerializationRecord{ data: record.data.clone() }
	})
	assert document.history().state.string_utf16_?.code_units() == units
	negative_zero := math.f64_from_bits(0x8000000000000000)
	zero_record := structured_serialize_for_storage(dom.js_number(negative_zero))!
	document.restore_the_history_object_state(&dom.SessionHistoryEntry{
		classic_history_api_state: dom.DOMSerializationRecord{ data: zero_record.data.clone() }
	})
	assert math.f64_bits(document.history().state.number_data) == 0x8000000000000000
}

fn test_actual_history_storage_decode_errors_reset_state_to_source_null() {
	mut document := dom.Document.create(dom.URL{ value: 'https://history.test/' })
	_ = WindowModel.create_top_level(document, none, 'history-storage-errors')!
	defer { document.finalize() }
	valid := structured_serialize_for_storage(dom.js_string('previous'))!
	mut trailing := valid.data.clone()
	trailing << u8(2)
	for invalid in [
		structured_serialize(dom.js_string('IPC is a different overload'))!.data,
		[u8(255)],
		trailing,
	] {
		document.restore_the_history_object_state(&dom.SessionHistoryEntry{
			classic_history_api_state: dom.DOMSerializationRecord{ data: valid.data.clone() }
		})
		assert document.history().state.string_data == 'previous'
		document.restore_the_history_object_state(&dom.SessionHistoryEntry{
			classic_history_api_state: dom.DOMSerializationRecord{ data: invalid.clone() }
		})
		assert document.history().state.kind == .null_
	}
}

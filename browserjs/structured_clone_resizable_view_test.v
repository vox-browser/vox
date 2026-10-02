module browserjs

import html
import webidl

fn resizable_source_view(constructor_name string, auto_length bool) !html.SerializationRecord {
	mut buffer := html.StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4, 5, 6]
	buffer.max_byte_length = u64(10)
	mut view := html.StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = constructor_name
	view.byte_offset = 2
	if !auto_length {
		view.byte_length = u32(2)
		if constructor_name != 'DataView' { view.array_length = u32(1) }
	}
	return html.structured_serialize(html.structured_object_value(view))!
}

fn test_native_source_owned_resizable_view_auto_and_fixed_slots_survive_growth_and_reprojection() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for name in ['DataView', 'Uint16Array'] {
		for auto_length in [false, true] {
			record := resizable_source_view(name, auto_length)!
			actual := bridge.deserialize(record)!
			binding := '__sourceOwned' + name + if auto_length { 'Auto' } else { 'Fixed' }
			runtime.define_value_host_function(binding, fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
			assert bridge.serialize(actual, false)!.data == record.data
			runtime.evaluate_host(binding + '().buffer.resize(8)')!
			assert runtime.evaluate_host(binding + '().byteLength')! == if auto_length { '6' } else { '2' }
			after_growth := bridge.serialize(actual, false)!
			decoded := html.structured_object_from_value(html.structured_deserialize_ipc(after_growth)!)!
			assert (decoded.byte_length == none) == auto_length
			assert (decoded.array_length == none) == (auto_length || name == 'DataView')
			assert decoded.byte_offset == 2
			assert decoded.viewed_array_buffer?.bytes == [u8(1), 2, 3, 4, 5, 6, 0, 0]
			// An independent bridge in the same actual Runtime shares the owning
			// immutable slot record instead of guessing from current getter lengths.
			other_bridge := StructuredCloneBridge.create(runtime)!
			assert other_bridge.serialize(actual, false)!.data == after_growth.data
			stored := bridge.serialize(actual, true)!
			stored_decoded := html.structured_object_from_value(html.structured_deserialize(stored)!)!
			assert (stored_decoded.byte_length == none) == auto_length
			assert stored_decoded.byte_offset == 2
		}
	}
}

fn test_native_source_owned_resizable_view_checks_live_witness_after_shrink_and_regrowth() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for name in ['DataView', 'Uint16Array'] {
		actual := bridge.deserialize(resizable_source_view(name, false)!)!
		binding := '__shrunkenSource' + name
		runtime.define_value_host_function(binding, fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
		runtime.evaluate_host(binding + '().buffer.resize(1)')!
		if _ := bridge.serialize(actual, false) { assert false } else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		runtime.evaluate_host(binding + '().buffer.resize(6)')!
		decoded := html.structured_object_from_value(html.structured_deserialize_ipc(bridge.serialize(actual, false)!)!)!
		assert decoded.byte_length? == 2
		assert decoded.byte_offset == 2
		assert decoded.viewed_array_buffer?.bytes == [u8(1), 0, 0, 0, 0, 0]
	}
}

fn test_native_source_view_slot_owner_retains_actual_identity_until_runtime_close() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	bridge := StructuredCloneBridge.create(runtime)!
	actual := bridge.deserialize(resizable_source_view('Uint16Array', true)!)!
	assert runtime.native_clone_view_slots(actual) != none
	runtime.release_javascript_value(actual)
	// This embedding currently owns the native view root until Runtime.close;
	// it does not claim the full source GC weak-wrapper reclamation boundary.
	assert runtime.native_clone_view_slots(actual) != none
	runtime.close()
	assert runtime.native_clone_view_slots(actual) == none
}

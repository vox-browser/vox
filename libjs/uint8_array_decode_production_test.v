module libjs

fn test_production_uint8_array_decode_reports_read_written_and_updates_its_view() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['setFromHex', 'setFromBase64'] {
		buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 9, 9, 9, 9], false, parent)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1), Value.from_i32(3))!
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, parent] (mut vm VM) !Value {
			// These methods receive the actual TypedArray object, so none of the
			// unrelated primitive prototype getters is requested.
			if name == 'setFromHex' {
				return uint8_array_prototype_set_from_hex(mut vm, PrimitiveObjectPrototypes{}, parent)
			}
			return uint8_array_prototype_set_from_base64(mut vm, PrimitiveObjectPrototypes{}, parent)
		}, 1, PropertyName.from_str(name), none)
		input := if name == 'setFromHex' { '666f6f99' } else { 'Zm9vYg==' }
		result := call(mut vm, Value.from_object(function.object), Value.from_object(array.object), [
			Value.from_string(vm.create_string_from_str(input)),
		])!.as_object()
		if result.own_property_keys().map(it.str()) != ['read', 'written'] || voidptr(result.prototype?) != voidptr(parent) {
			panic('Uint8Array decoder omitted result fields or lost the source prototype')
		}
		read := result.get(mut vm, PropertyName.from_str('read'))!
		written := result.get(mut vm, PropertyName.from_str('written'))!
		expected_read := if name == 'setFromHex' { 6.0 } else { 4.0 }
		if read.number != expected_read || written.number != 3 || buffer.read_bytes(0, 5) != [u8(9), 102, 111, 111, 9] {
			panic('Uint8Array decoder lost its consumed-input count or view update')
		}
		for key in result.own_property_keys() {
			descriptor := result.internal_get_own_property(key)?
			if !descriptor.writable? || !descriptor.enumerable? || !descriptor.configurable? {
				panic('Uint8Array decoder did not use source data-property attributes')
			}
		}
	}
}

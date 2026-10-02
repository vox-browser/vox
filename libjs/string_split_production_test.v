module libjs

fn test_production_string_split_materializes_every_source_result_branch() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototype] (mut vm VM) !Value {
		return string_prototype_split(mut vm, prototype)
	}, 2, PropertyName.from_str('split'), none)
	for row in [['hello', 'undefined', 'hello'], ['', ',', ''], ['abc', '', 'a', 'b', 'c'],
		[',a,,b,', ',', '', 'a', '', 'b', '']] {
		text := Value.from_string(vm.create_string_from_str(row[0]))
		separator := if row[1] == 'undefined' { js_undefined() } else {
			Value.from_string(vm.create_string_from_str(row[1]))
		}
		result := call(mut vm, Value.from_object(function.object), text, [separator])!
		array := result.as_object().array_object or { panic('split did not return an Array') }
		if int(array.length) != row.len - 2 {
			panic('split omitted indexed properties in a production build')
		}
		for index, expected in row[2..] {
			key := PropertyName.from_number(u32(index))
			value := array.object.get(mut vm, key)!
			if !value.is_string() || value.as_string().str() != expected {
				panic('split lost a result string or its position')
			}
			descriptor := array.object.internal_get_own_property(key)?
			if !descriptor.writable? || !descriptor.enumerable? || !descriptor.configurable? {
				panic('split lost the source CreateDataProperty attributes')
			}
		}
	}
	// The empty-separator branch works in UTF-16 units, including unpaired ones.
	units := [u16(0xd83d), 0xde00, 0xd800]
	text := Value.from_string(vm.create_string(Utf16String.from_slice(units)))
	result := call(mut vm, Value.from_object(function.object), text, [
		Value.from_string(vm.empty_string()), Value.from_i32(2),
	])!
	array := result.as_object().array_object?
	if array.length != 2 { panic('split did not apply its limit') }
	for index in 0 .. 2 {
		value := array.object.get(mut vm, PropertyName.from_number(u32(index)))!
		if value.as_string().utf16.data != [units[index]] {
			panic('split changed a UTF-16 code unit')
		}
	}
}

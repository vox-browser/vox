module libjs

@[heap]
struct StringConcatLog {
mut:
	indices []int
}

fn test_string_concat_preserves_utf16_empty_identity_and_ordered_string_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := Value.from_object(NativeFunction.create_raw(mut vm, vm.realm(),
		vm.realm().function_prototype, string_prototype_concat, 1, PropertyName.from_str('concat'), none).object)
	text := vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0xdc00]))
	assert voidptr(call(mut vm, function, Value.from_string(text), []Value{})!.as_string()) == voidptr(text)
	assert voidptr(call(mut vm, function, Value.from_string(text), [
		Value.from_string(vm.empty_string()),
	])!.as_string()) == voidptr(text)
	assert voidptr(call(mut vm, function, Value.from_string(vm.empty_string()), [
		Value.from_string(text),
	])!.as_string()) == voidptr(text)
	mut expected := text.utf16.data.clone()
	expected << utf16('42nullfalse')
	assert call(mut vm, function, Value.from_string(text), [Value.from_i32(42),
		js_null(), Value.from_bool(false)])!.as_string().utf16.data == expected
	mut log := &StringConcatLog{}
	mut values := []Value{}
	for index in 0 .. 4 {
		mut object := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mut log] (mut vm VM) !Value {
			assert vm.argument(0).as_string().str() == 'string'
			log.indices << index
			if index == 2 { return throw_completion(Value.from_i32(77)) }
			return Value.from_string(vm.create_string_from_str(index.str()))
		}, 1, PropertyName.from_str('convert'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		values << Value.from_object(object)
	}
	if _ := call(mut vm, function, values[0], values[1..]) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.indices == [0, 1, 2]
	log.indices.clear()
	if _ := call(mut vm, function, js_null(), values) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert log.indices.len == 0
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

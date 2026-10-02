module libjs

fn test_string_prototype_iterator_coerces_once_then_allocates_in_native_callee_realm() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	local := vm.realm()
	parent := Object.create(local, none)
	prototype := StringIteratorPrototype.create(mut vm, local, parent).object
	getter := fn [local, prototype] (realm &Realm) &Object {
		assert voidptr(realm) == voidptr(local)
		return prototype
	}
	function := Value.from_object(NativeFunction.create(mut vm, local, local.function_prototype, fn [getter] (mut vm VM) !Value {
		return string_prototype_symbol_iterator(mut vm, getter)
	}, 0, PropertyName.from_symbol(vm.well_known_symbol_iterator()), none).object)
	foreign := create_simple_execution_context(mut vm)
	text := Value.from_string(vm.create_string(Utf16String.from_slice([u16(`A`), 0xd83d, 0xde00,
		0xd800, 0])))
	first := call(mut vm, function, text, []Value{})!.as_object()
	second := call(mut vm, function, text, []Value{})!.as_object()
	assert voidptr(first) != voidptr(second)
	assert voidptr(first.prototype?) == voidptr(prototype)
	next := first.get(mut vm, PropertyName.from_str('next'))!
	for units in [[u16(`A`)], [u16(0xd83d), 0xde00], [u16(0xd800)],
		[u16(0)]] {
		step := call(mut vm, next, Value.from_object(first), []Value{})!.as_object()
		assert !step.get(mut vm, PropertyName.from_str('done'))!.as_bool()
		assert step.get(mut vm, PropertyName.from_str('value'))!.as_string().utf16.data == units
	}
	for _ in 0 .. 2 {
		step := call(mut vm, next, Value.from_object(first), []Value{})!.as_object()
		assert step.get(mut vm, PropertyName.from_str('done'))!.as_bool()
		assert step.get(mut vm, PropertyName.from_str('value'))!.is_undefined()
	}
	assert second.string_iterator?.index == 0
	for receiver in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := call(mut vm, function, receiver, []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert vm.running_execution_context() == foreign && vm.interpreter_stack().depth() == 0
}

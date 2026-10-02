module libjs

fn string_replace_call(mut vm VM, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		string_prototype_replace, 2, PropertyName.from_str('replace'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_string_replace_upstream_first_match_tokens_and_utf16_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for row in [['', '', '', ''], ['', 'a', '', ''], ['', '', 'a', 'a'],
		['a', 'a', '', ''], ['a', 'a', 'b', 'b'], ['aa', 'a', 'b', 'ba'],
		['ca', 'a', 'b', 'cb'], ['abc', 'b', '$', 'a$c'], ['abc', 'b', '$.', 'a$.c'],
		['abc', 'b', '$$', 'a$c'], ['abc', 'b', '>$$<', 'a>$<c'],
		['abc', 'b', '$$$$', 'a$$c'], ['abc', 'b', '$&', 'abc'],
		['abc', 'b', '$`', 'aac'], ['abc', 'b', "$'", 'acc'],
		['abc', 'b', '$0/$99/$100/$<g>', 'a$0/$99/$100/$<g>c']] {
		result := string_replace_call(mut vm, Value.from_string(vm.create_string_from_str(row[0])), [
			Value.from_string(vm.create_string_from_str(row[1])),
			Value.from_string(vm.create_string_from_str(row[2])),
		])!
		assert result.as_string().str() == row[3]
	}
	assert string_replace_call(mut vm, Value.from_i32(123), [
		Value.from_i32(2), Value.from_i32(4)])!.as_string().str() == '143'
	text := Value.from_string(vm.create_string_from_str('unchanged'))
	result := string_replace_call(mut vm, text, [
		Value.from_string(vm.create_string_from_str('absent')),
		js_null(),
	])!
	assert result.as_string() == text.as_string()
	assert string_replace_call(mut vm, Value.from_string(vm.create_string_from_str('undefined')),
		[]Value{})!.as_string().str() == 'undefined'
	raw :=
		Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xd83d), 0xde00, 0, 0xd800])))
	assert string_replace_call(mut vm, raw, [
		Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xde00)]))),
		Value.from_string(vm.create_string_from_str('X')),
	])!.as_string().utf16.data == [u16(0xd83d), u16(`X`), 0, 0xd800]
}

@[heap]
struct ReplaceLog {
mut:
	events []string
}

fn test_string_replace_converts_before_absent_match_and_propagates_each_conversion_error() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReplaceLog{}
	for failing in [-1, 0, 1, 2] {
		mut values := []Value{}
		for index, name in ['receiver', 'search', 'replacement'] {
			mut object := Object.create(vm.realm(), none)
			converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, name, failing, mut log] (mut vm VM) !Value {
				log.events << name + ':' + vm.argument(0).as_string().str()
				if index == failing { return throw_completion(Value.from_i32(77)) }
				return Value.from_string(vm.create_string_from_str(if index == 0 {
					'x'
				} else {
					'absent'
				}))
			}, 1, PropertyName.from_str('convert'), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(converter.object), 7)
			values << Value.from_object(object)
		}
		if result := string_replace_call(mut vm, values[0], values[1..]) {
			assert failing == -1 && result.as_string().str() == 'x'
		} else {
			assert failing >= 0 && thrown_value(err).number == 77
		}
		assert log.events == ['receiver:string', 'search:string', 'replacement:string'][..if failing < 0 {
			3
		} else {
			failing + 1
		}]
		log.events.clear()
		for receiver in [js_null(), js_undefined()] {
			if _ := string_replace_call(mut vm, receiver, values[1..]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert log.events.len == 0
	}
	if _ := string_replace_call(mut vm, Value.from_string(vm.create_string_from_str('x')), [
		Value.from_string(vm.create_string_from_str('absent')),
		Value.from_symbol(Symbol.create(none, .unique)),
	])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_string_replace_symbol_hook_precedes_receiver_conversion_and_returns_uncoerced_value() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReplaceLog{}
	mut search := Object.create(vm.realm(), none)
	receiver := Value.from_symbol(Symbol.create(none, .unique))
	replacement := Value.from_symbol(Symbol.create(none, .unique))
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [search, receiver, replacement, mut log] (mut vm VM) !Value {
		log.events << 'call'
		assert vm.this_value().as_object() == search
		assert vm.argument(0).as_symbol() == receiver.as_symbol()
		assert vm.argument(1).as_symbol() == replacement.as_symbol()
		return replacement
	}, 2, PropertyName.from_str('hook'), none)
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [method, mut log] (mut vm VM) !Value {
		log.events << 'get'
		return Value.from_object(method.object)
	}, 0, PropertyName.from_str('getter'), none)
	search.define_property_or_throw(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_replace()), PropertyDescriptor{
		getter:       Value.from_object(getter.object)
		configurable: true
	})!
	result := string_replace_call(mut vm, receiver, [Value.from_object(search), replacement])!
	assert result.as_symbol() == replacement.as_symbol()
	assert log.events == ['get', 'call']
	log.events.clear()
	if _ := string_replace_call(mut vm, js_null(), [Value.from_object(search), replacement]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert log.events.len == 0
	search.define_property_or_throw(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_replace()), PropertyDescriptor{
		value: Value.from_i32(1)
	})!
	if _ := string_replace_call(mut vm, receiver, [Value.from_object(search), replacement]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '1 is not a function'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_string_replace_callable_arguments_result_conversion_and_error_recovery() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReplaceLog{}
	for mode in ['normal', 'throw', 'symbol'] {
		mut result_object := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
			log.events << 'convert:' + vm.argument(0).as_string().str()
			return Value.from_string(vm.create_string_from_str('$&'))
		}, 1, PropertyName.from_str('convert'), none)
		result_object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		replacer := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, result_object, mut log] (mut vm VM) !Value {
			log.events << 'call'
			assert vm.this_value().is_undefined() && vm.argument_count() == 3
			assert vm.argument(0).as_string().str() == 'b'
			assert vm.argument(1).number == 2
			assert vm.argument(2).as_string().str() == '😀b-tail'
			if mode == 'throw' { return throw_completion(Value.from_i32(77)) }
			if mode == 'symbol' { return Value.from_symbol(Symbol.create(none, .unique)) }
			return Value.from_object(result_object)
		}, 3, PropertyName.from_str('replacement'), none)
		text := Value.from_string(vm.create_string_from_str('😀b-tail'))
		if result := string_replace_call(mut vm, text, [
			Value.from_string(vm.create_string_from_str('b')),
			Value.from_object(replacer.object),
		])
		{
			assert mode == 'normal' && result.as_string().str() == '😀$&-tail'
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 77
			} else {
				assert mode == 'symbol'
					&& thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert log.events == if mode == 'normal' {
			['call', 'convert:string']
		} else {
			['call']
		}
		log.events.clear()
		absent := string_replace_call(mut vm, text, [
			Value.from_string(vm.create_string_from_str('missing')),
			Value.from_object(replacer.object),
		])!
		assert absent.as_string() == text.as_string() && log.events.len == 0
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

module libjs

fn string_split_call(mut vm VM, receiver Value, arguments []Value, prototype &Object) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototype] (mut vm VM) !Value {
		return string_prototype_split(mut vm, prototype)
	}, 2, PropertyName.from_str('split'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn split_strings(mut vm VM, value Value, prototype &Object) ![]Utf16String {
	array := value.as_object().array_object or { panic('Expected a real Array record') }
	actual_prototype := array.object.internal_get_prototype_of() or {
		panic('Missing Array prototype')
	}
	assert actual_prototype == prototype
	mut strings := []Utf16String{}
	for index in 0 .. int(array.length) {
		key := PropertyName.from_number(u32(index))
		descriptor := array.object.internal_get_own_property(key) or {
			panic('Missing Array entry')
		}
		assert (descriptor.writable or { false }) && (descriptor.enumerable or { false }) && (descriptor.configurable or {
			false
		})
		strings << array.object.get(mut vm, key)!.as_string().utf16
	}
	return strings
}

fn test_string_split_upstream_separators_empty_fields_limits_and_uint32_wrapping() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for row in [['hello friends', ' ', 'hello', 'friends'], ['a,b,c,d', ',', 'a', 'b', 'c', 'd'],
		[',a,b,c,d', ',', '', 'a', 'b', 'c', 'd'], ['a,b,c,d,', ',', 'a', 'b', 'c', 'd', ''],
		['a,b,,c,d', ',', 'a', 'b', '', 'c', 'd'], [',a,b,,,c,d,', ',,', ',a,b', ',c,d,'],
		['aaaaa', 'aa', '', '', 'a'], ['', ',', ''], ['', ''],
		['foo', 'absent', 'foo']] {
		result := string_split_call(mut vm, Value.from_string(vm.create_string_from_str(row[0])), [
			Value.from_string(vm.create_string_from_str(row[1])),
		], prototype)!
		assert split_strings(mut vm, result, prototype)! == row[2..].map(utf16_string(it))
	}
	text := Value.from_string(vm.create_string_from_str('a,b,c,d'))
	separator := Value.from_string(vm.create_string_from_str(','))
	for index, limit in [Value.from_i32(0), Value.from_i32(1),
		Value.from_f64(3.9), Value.from_i32(100), Value.from_i32(-1),
		Value.from_f64(4294967296), Value.from_f64(4294967297),
		js_null()] {
		length := [0, 1, 3, 4, 4, 0, 1, 0][index]
		result := string_split_call(mut vm, text, [separator, limit], prototype)!
		assert split_strings(mut vm, result, prototype)! == ['a', 'b', 'c', 'd'][..length].map(utf16_string(it))
	}
	for arguments in [[]Value{}, [js_undefined()], [js_undefined(),
		js_undefined()]] {
		result := string_split_call(mut vm, text, arguments, prototype)!
		assert split_strings(mut vm, result, prototype)! == [text.as_string().utf16]
		assert result.as_object().get(mut vm, PropertyName.from_number(0))!.as_string() == text.as_string()
	}
	assert split_strings(mut vm, string_split_call(mut vm, Value.from_i32(1203), [
		Value.from_i32(0),
	], prototype)!, prototype)! == [utf16_string('12'), utf16_string('3')]
}

fn test_string_split_empty_separator_and_matches_preserve_individual_utf16_units() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	text := Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xd83d), 0xde00, 0,
		0xd800])))
	result := string_split_call(mut vm, text, [Value.from_string(vm.empty_string())], prototype)!
	units := split_strings(mut vm, result, prototype)!
	assert units.len == 4
	for index, unit in text.as_string().utf16.data {
		assert units[index].data == [unit]
	}
	truncated := string_split_call(mut vm, text, [
		Value.from_string(vm.empty_string()),
		Value.from_i32(1),
	], prototype)!
	assert split_strings(mut vm, truncated, prototype)! == [
		Utf16String.from_slice([u16(0xd83d)]),
	]
	pair := Value.from_string(vm.create_string_from_str('😀'))
	for row in [[u16(0xd83d)], [u16(0xde00)], [u16(0xd83d), 0xde00]] {
		parts := split_strings(mut vm, string_split_call(mut vm, pair, [
			Value.from_string(vm.create_string(Utf16String.from_slice(row))),
		], prototype)!, prototype)!
		assert parts.len == 2
		assert parts[0].data == if row[0] == 0xde00 {
			[u16(0xd83d)]
		} else {
			[]u16{}
		}
		assert parts[1].data == if row.len == 1 && row[0] == 0xd83d {
			[u16(0xde00)]
		} else {
			[]u16{}
		}
	}
}

@[heap]
struct SplitLog {
mut:
	events []string
}

fn test_string_split_converts_receiver_limit_separator_before_zero_limit_return() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut log := &SplitLog{}
	for failing in [-1, 0, 1, 2] {
		mut values := []Value{}
		for index, name in ['receiver', 'limit', 'separator'] {
			mut object := Object.create(vm.realm(), none)
			converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, name, failing, mut log] (mut vm VM) !Value {
				log.events << name + ':' + vm.argument(0).as_string().str()
				if index == failing { return throw_completion(Value.from_i32(77)) }
				return if index == 1 {
					Value.from_i32(0)
				} else {
					Value.from_string(vm.create_string_from_str(''))
				}
			}, 1, PropertyName.from_str('convert'), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(converter.object), 7)
			values << Value.from_object(object)
		}
		if result := string_split_call(mut vm, values[0], [values[2], values[1]], prototype) {
			assert failing == -1 && result.as_object().array_object?.length == 0
		} else {
			assert failing >= 0 && thrown_value(err).number == 77
		}
		assert log.events == ['receiver:string', 'limit:number', 'separator:string'][..if failing < 0 {
			3
		} else {
			failing + 1
		}]
		log.events.clear()
		if _ := string_split_call(mut vm, js_null(), [values[2], values[1]], prototype) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert log.events.len == 0
	}
	if _ := string_split_call(mut vm, Value.from_string(vm.empty_string()), [
		Value.from_symbol(Symbol.create(none, .unique)),
		Value.from_i32(0),
	], prototype)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_string_split_symbol_hook_keeps_raw_arguments_and_nullish_hooks_fall_back() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut log := &SplitLog{}
	mut separator := Object.create(vm.realm(), none)
	receiver := Value.from_symbol(Symbol.create(none, .unique))
	limit := Value.from_symbol(Symbol.create(none, .unique))
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [receiver, limit, separator, mut log] (mut vm VM) !Value {
		log.events << 'call'
		assert vm.this_value().as_object() == separator && vm.argument_count() == 2
		assert vm.argument(0).as_symbol() == receiver.as_symbol()
		assert vm.argument(1).as_symbol() == limit.as_symbol()
		return limit
	}, 2, PropertyName.from_str('splitter'), none)
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [method, mut log] (mut vm VM) !Value {
		log.events << 'get'
		return Value.from_object(method.object)
	}, 0, PropertyName.from_str('getter'), none)
	key := PropertyName.from_symbol(vm.well_known_symbol_split())
	separator.define_property_or_throw(mut vm, key, PropertyDescriptor{
		getter:       Value.from_object(getter.object)
		configurable: true
	})!
	result := string_split_call(mut vm, receiver, [Value.from_object(separator), limit], prototype)!
	assert result.as_symbol() == limit.as_symbol() && log.events == ['get', 'call']
	log.events.clear()
	for nullish in [js_null(), js_undefined()] {
		if _ := string_split_call(mut vm, nullish, [Value.from_object(separator), limit], prototype) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert log.events.len == 0
	converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_string(vm.create_string_from_str(','))
	}, 0, PropertyName.from_str('convert'), none)
	separator.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(converter.object), 7)
	for absent_hook in [js_null(), js_undefined()] {
		separator.define_property_or_throw(mut vm, key, PropertyDescriptor{ value: absent_hook })!
		parts := split_strings(mut vm, string_split_call(mut vm,
			Value.from_string(vm.create_string_from_str('a,b')), [
			Value.from_object(separator),
		], prototype)!, prototype)!
		assert parts == [utf16_string('a'), utf16_string('b')]
	}
	separator.define_property_or_throw(mut vm, key, PropertyDescriptor{ value: Value.from_i32(1) })!
	if _ := string_split_call(mut vm, receiver, [Value.from_object(separator), limit], prototype) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '1 is not a function'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

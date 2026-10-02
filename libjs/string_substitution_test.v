module libjs

fn test_get_substitution_special_tokens_numeric_fallback_and_overlong_match_tail() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for row in [['$$', '$'], ['$&', 'HELLO'], ['$`', 'abc'], ["$'", 'xyz'],
		['$0 $00 $1 $12 $99', '$0 $00 $1 $12 $99'], ['$<name> $<', '$<name> $<'],
		['$$$&$$', '$HELLO$'], ['x$z$', 'x$z$']] {
		result := get_substitution(mut vm, utf16_string('HELLO'), utf16_string('abcHELLOxyz'), 3,
			[]Value{}, js_undefined(), utf16_string(row[0]))!
		assert result == utf16_string(row[1])
	}
	captures := [Value.from_string(vm.create_string_from_str('first')),
		js_undefined(), Value.from_i32(77)]
	result := get_substitution(mut vm, utf16_string('x'), utf16_string('x'), 0, captures,
		js_undefined(), utf16_string('$00|$01|$02|$03|$04|$09|$10|$12|$30|$99|$100'))!
	assert result.str() == '$00|first||77|$04|$09|first0|first2|770|$99|first00'
	mut many := []Value{}
	for index in 1 .. 100 {
		many << Value.from_i32(index)
	}
	assert get_substitution(mut vm, utf16_string(''), utf16_string(''), 0, many, js_undefined(),
		utf16_string('$99/$100'))!.str() == '99/100'
	// A custom RegExp exec may report a match extending beyond the input.
	assert get_substitution(mut vm, utf16_string('XYZ'), utf16_string('A'), 1, []Value{},
		js_undefined(), utf16_string("$`:$&:$'"))!.str() == 'A:XYZ:'
}

fn test_get_substitution_preserves_utf16_in_text_captures_and_group_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Utf16String.from_slice([u16(0xd800), 0, 0xdc00])
	matched := Utf16String.from_slice([u16(0)])
	result := get_substitution(mut vm, matched, text, 1, [
		Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xdfff)]))),
	], js_undefined(), utf16_string("$`$&$'$1"))!
	assert result.data == [u16(0xd800), 0, 0xdc00, 0xdfff]
	mut groups := Object.create(vm.realm(), none)
	name := Utf16String.from_slice([u16(0xd800), 0])
	groups.define_direct_property(PropertyName.from_utf16(name), Value.from_i32(42), 7)
	groups.define_direct_property(PropertyName.from_str('0'), Value.from_i32(9), 7)
	assert get_substitution(mut vm, matched, text, 1, []Value{}, Value.from_object(groups), Utf16String.from_slice([
		u16(`$`),
		u16(`<`),
		0xd800,
		0,
		u16(`>`),
	]))!.str() == '42'
	assert get_substitution(mut vm, matched, text, 1, []Value{}, Value.from_object(groups),
		utf16_string('$<0>/$<>/$<missing>/$<unclosed'))!.str() == '9///$<unclosed'
}

@[heap]
struct SubstitutionLog {
mut:
	events []string
	reads  int
}

fn test_get_substitution_reads_named_captures_and_converts_captures_live_in_template_order() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &SubstitutionLog{}
	mut capture := Object.create(vm.realm(), none)
	converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'convert:' + vm.argument(0).as_string().str()
		return Value.from_string(vm.create_string_from_str('C'))
	}, 1, PropertyName.from_str('convert'), none)
	capture.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(converter.object), 7)
	mut groups := Object.create(vm.realm(), none)
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log, capture] (mut vm VM) !Value {
		log.reads++
		log.events << 'get'
		return if log.reads == 1 { Value.from_object(capture) } else { js_undefined() }
	}, 0, PropertyName.from_str('group'), none)
	groups.define_property_or_throw(mut vm, PropertyName.from_str('g'), PropertyDescriptor{
		getter:       Value.from_object(getter.object)
		configurable: true
	})!
	result := get_substitution(mut vm, utf16_string('x'), utf16_string('x'), 0, [
		Value.from_object(capture),
		js_undefined(),
		Value.from_symbol(Symbol.create(none, .unique)),
	], Value.from_object(groups), utf16_string('$1/$<g>/$2/$<g>/$1'))!
	assert result.str() == 'C/C///C'
	assert log.events == ['convert:string', 'get', 'convert:string', 'get', 'convert:string']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_get_substitution_propagates_named_getter_and_capture_conversion_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for named in [false, true] {
		for mode in ['throw', 'symbol'] {
			mut capture := Object.create(vm.realm(), none)
			converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode] (mut vm VM) !Value {
				if mode == 'throw' { return throw_completion(Value.from_i32(77)) }
				return Value.from_symbol(Symbol.create(none, .unique))
			}, 1, PropertyName.from_str('convert'), none)
			capture.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(converter.object), 7)
			mut groups := Object.create(vm.realm(), none)
			groups.define_direct_property(PropertyName.from_str('g'), Value.from_object(capture), 7)
			if _ := get_substitution(mut vm, utf16_string('x'), utf16_string('x'), 0, [
				Value.from_object(capture),
			], Value.from_object(groups), utf16_string(if named { '$<g>' } else { '$1' }))
			{
				assert false
			} else {
				if mode == 'throw' {
					assert thrown_value(err).number == 77
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
		}
	}
	mut groups := Object.create(vm.realm(), none)
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(88))
	}, 0, PropertyName.from_str('group'), none)
	groups.define_property_or_throw(mut vm, PropertyName.from_str('g'), PropertyDescriptor{
		getter: Value.from_object(getter.object)
	})!
	if _ := get_substitution(mut vm, utf16_string(''), utf16_string(''), 0, []Value{},
		Value.from_object(groups), utf16_string('$<g>'))
	{
		assert false
	} else {
		assert thrown_value(err).number == 88
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

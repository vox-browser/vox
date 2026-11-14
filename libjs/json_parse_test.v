// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

fn parse_json_text(mut vm VM, text string, reviver Value) !Value {
	json_object := vm.realm().json_object or { panic('Missing JSON object') }
	method := json_object.get(mut vm, PropertyName.from_str('parse'))!
	return call(mut vm, method, Value.from_object(json_object), [
		Value.from_string(vm.create_string_from_str(text)),
		reviver,
	])
}

fn json_parse_eval(mut vm VM, text string) !Value {
	mut script := Script.parse(text, vm.realm(), 'json-parse.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_json_parse_intrinsic_and_strict_json_grammar() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parse_json_text(mut vm, ' \t\r\n true ', js_null())!.as_bool()
	assert !parse_json_text(mut vm, 'false', js_undefined())!.as_bool()
	assert parse_json_text(mut vm, 'null', Value.from_i32(42))!.is_null()
	assert parse_json_text(mut vm, '-12.5e+2', js_undefined())!.number == -1250
	assert math.is_inf(parse_json_text(mut vm, '1e400', js_undefined())!.number, 1)
	assert math.f64_bits(parse_json_text(mut vm, '-0', js_undefined())!.number) == math.f64_bits(-0.0)
	for invalid in ['', '+1', '01', '-01', '.1', '1.', '1e', '1e+', 'NaN', 'Infinity', '0x10',
		'undefined', 'true false', '[1,]', '[,1]', '{"a":1,}', '{a:1}', '{"a" 1}', '/*hi*/1', '\u00a01',
		'\uFEFF1', '"\n"', '"unterminated', r'"\v"', r'"\u0x00"'] {
		parse_json_text(mut vm, invalid, js_undefined()) or {
			assert thrown_value(err).as_object().error_kind()? == .syntax_error, invalid
			continue
		}
		assert false, invalid
	}
	json_object := vm.realm().json_object?
	descriptor := json_object.internal_get_own_property(PropertyName.from_str('parse'))?
	assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
	assert descriptor.value?.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 2
	assert !descriptor.value?.is_constructor()
}

fn test_json_parse_preserves_utf16_escapes_lone_surrogates_and_property_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for input, expected in {
		r'"\uD800"':                 [u16(0xd800)]
		r'"\ud83d\ude00"':           [u16(0xd83d), 0xde00]
		r'"\u0000\b\f\n\r\t\/\\\""': [u16(0), 8, 12, 10, 13, 9, `/`, `\\`, `"`]
		'"é😀\u2028"':               [u16(0xe9), 0xd83d, 0xde00, 0x2028]
	} {
		assert parse_json_text(mut vm, input, js_undefined())!.as_string().utf16.code_units() == expected
	}
	object := parse_json_text(mut vm, r'{"\ud800":20,"\ud801":22,"__proto__":{"x":42},"a":1,"a":2,"2":3,"1":4}', js_undefined())!.as_object()
	assert object.get(mut vm, PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd800)])))!.number == 20
	assert object.get(mut vm, PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd801)])))!.number == 22
	assert object.get(mut vm, PropertyName.from_str('a'))!.number == 2
	assert object.own_property_keys()[..2].map(it.str()) == ['1', '2']
	assert voidptr(object.internal_get_prototype_of()?) == voidptr(vm.realm().object_prototype_record())
	assert object.get(mut vm, PropertyName.from_str('__proto__'))!.as_object().get(mut vm, PropertyName.from_str('x'))!.number == 42
}

fn test_json_parse_reviver_is_postorder_and_preserves_root_this_and_array_holes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert json_parse_eval(mut vm, 'var order="";var result=JSON.parse(\'{"a":20,"b":[21,22]}\',function(k,v){order+=k+",";if(k==="0")return undefined;if(k==="a")return v+22;return v});order+":"+result.a+":"+result.b.length+":"+(0 in result.b)+":"+result.b[1]')!.as_string().str() == 'a,0,1,b,,:42:2:false:22'
	assert json_parse_eval(mut vm, 'JSON.parse("42",function(k,v){return k=== "" && this[k]===v ? v+1 : 0})')!.number == 43
	assert json_parse_eval(mut vm, 'JSON.parse("42",function(){return undefined})')!.is_undefined()
	assert json_parse_eval(mut vm, 'var seen="";JSON.parse(\'{"a":1,"b":2}\',function(k,v){seen+=k+":"+v+",";if(k==="a"){delete this.b;this.added=3}return v});seen')!.as_string().str() == 'a:1,b:undefined,:[object Object],'
}

fn test_json_parse_reviver_context_tracks_exact_unchanged_primitive_source() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert json_parse_eval(mut vm, 'var records="";JSON.parse(\'{"n":1e2,"a":[-0,true]}\',function(k,v,c){records+=k+":"+c.source+";";return v});records')!.as_string().str() == 'n:1e2;0:-0;1:true;a:undefined;:undefined;'
	assert json_parse_eval(mut vm, 'var sources="";JSON.parse(\'{"a":1,"b":2,"a":3}\',function(k,v,c){sources+=k+":"+c.source+";";if(k==="a")this.b=42;return v});sources')!.as_string().str() == 'a:3;b:undefined;:undefined;'
	assert json_parse_eval(mut vm, 'JSON.parse("42",function(k,v,c){return Object.getPrototypeOf(c)===Object.prototype && Object.getOwnPropertyDescriptor(c,"source").enumerable})')!.as_bool()
	assert json_parse_eval(mut vm, 'var c=0;var text={toString:function(){c++;return "42"}};JSON.parse(text)+c')!.number == 43
	if _ := json_parse_eval(mut vm, 'JSON.parse("42",function(){throw 17})') {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
}

fn test_json_parse_nesting_and_token_work_share_the_execution_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	deep := '['.repeat(600) + '0' + ']'.repeat(600)
	parse_json_text(mut vm, deep, js_undefined()) or {
		assert thrown_value(err).as_object().error_kind()? == .range_error
		assert parse_json_text(mut vm, '42', js_undefined())!.number == 42
		mut global := vm.realm().global_object_record()
		global.define_direct_property(PropertyName.from_str('largeJSON'), Value.from_string(vm.create_string_from_str('"' + 'x'.repeat(200) + '"')), 0)
		mut script := Script.parse('JSON.parse(largeJSON)', vm.realm(), 'json-budget.js', unsafe { nil })!
		vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 30 }) or {
			assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
			assert json_parse_eval(mut vm, '6*7')!.number == 42
			return
		}
		assert false, 'JSON parsing must not bypass the caller budget'
		return
	}
	assert false, 'Deep JSON must stop before native stack exhaustion'
}

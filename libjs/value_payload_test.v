module libjs

import math

fn test_value_payload_shares_storage_without_losing_tagged_numeric_bits_or_cells() {
	assert sizeof(Value) == 16
	sample := Value{}
	assert uint(&sample.number) == uint(&sample.cell)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := vm.create_string_from_str('retained payload')
	object := Object.create(vm.realm(), none)
	symbol := Symbol.create(utf16_string('payload'), .unique)
	mut values := [js_undefined(), js_null(), js_special_empty_value(), Value.from_bool(true),
		Value.from_bool(false), Value.from_i32(-2147483647), Value.from_f64(2147483648.0),
		Value.from_f64(-0.0), Value.from_f64(math.nan()), Value.from_f64(math.inf(1)),
		Value.from_string(text), Value.from_object(object), Value.from_symbol(symbol)]
	copy := values.clone()
	values[10] = Value.from_i32(7)
	assert copy[0].is_undefined() && copy[1].is_null() && copy[2].is_special_empty_value()
	assert copy[3].as_bool() && !copy[4].as_bool()
	assert copy[5].number == -2147483647 && copy[6].number == 2147483648.0
	assert copy[7].is_double() && math.signbit(copy[7].number)
	assert math.is_nan(copy[8].number) && math.is_inf(copy[9].number, 1)
	assert copy[10].as_string().str() == 'retained payload'
	assert voidptr(copy[11].as_object()) == voidptr(object)
	assert voidptr(copy[12].as_symbol()) == voidptr(symbol)
	mut roots := HeapRoots{}
	for value in copy { roots.add_value(value) }
	assert roots.cells.len == 3
	assert roots.contains(voidptr(text)) && roots.contains(voidptr(object)) && roots.contains(voidptr(symbol))
}

fn test_value_payload_survives_mixed_registers_throwing_and_nested_native_calls() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('var marker={x:42};function pass(a,b,c,d){try{if(a)throw b;return c}catch(e){return e}finally{d()}}var count=0;pass(true,marker,-0,()=>count++).x===42&&1/pass(false,marker,-0,()=>count++)===-Infinity&&count===2',vm.realm(),'payload.js',unsafe { nil })!
	assert vm.run(mut script)!.as_bool()
	assert vm.interpreter_stack().depth() == 0
}

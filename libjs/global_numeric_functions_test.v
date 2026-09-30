module libjs

import math

// Cases adapted from Tests/LibJS/Runtime/parseInt.js and
// Runtime/builtins/functions/{isFinite,isNaN}.js at the recorded upstream pin.
fn execute_numeric_global(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'numeric-globals.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_numeric_global_functions_coerce_arguments_and_have_upstream_metadata() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for name in ['isFinite', 'isNaN', 'parseInt'] {
		property := vm.get_global_object().internal_get_own_property(PropertyName.from_str(name))?
		assert property.writable? && property.configurable? && !property.enumerable?
		function := property.value?.as_object()
		assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert function.get(mut vm, PropertyName.from_str('length'))!.number == if name == 'parseInt' {
			2
		} else {
			1
		}
	}
	for source, expected in {
		'isFinite(0);':         true
		'isFinite(1.23);':      true
		'isFinite(42);':        true
		'isFinite("");':        true
		'isFinite("42");':      true
		'isFinite(true);':      true
		'isFinite(false);':     true
		'isFinite(null);':      true
		'isFinite();':          false
		'isFinite(NaN);':       false
		'isFinite(undefined);': false
		'isFinite(Infinity);':  false
		'isFinite(-Infinity);': false
		'isFinite("foo");':     false
		'isNaN(0);':            false
		'isNaN(42);':           false
		'isNaN("");':           false
		'isNaN("42");':         false
		'isNaN(true);':         false
		'isNaN(false);':        false
		'isNaN(null);':         false
		'isNaN(Infinity);':     false
		'isNaN(-Infinity);':    false
		'isNaN();':             true
		'isNaN(NaN);':          true
		'isNaN(undefined);':    true
		'isNaN("foo");':        true
	} {
		assert execute_numeric_global(mut vm, source)!.as_bool() == expected, source
	}
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_parse_int_preserves_radix_prefix_termination_and_numeric_string_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source, expected in {
		'parseInt("0");':                  0.0
		'parseInt("100");':                100.0
		'parseInt("1000",16);':            4096.0
		'parseInt("0xF",16);':             15.0
		'parseInt("F",16);':               15.0
		'parseInt("17",8);':               15.0
		'parseInt(021,8);':                15.0
		'parseInt("015",10);':             15.0
		'parseInt(15.99,10);':             15.0
		'parseInt("15,123",10);':          15.0
		'parseInt("FXX123",16);':          15.0
		'parseInt("1111",2);':             15.0
		'parseInt("15 * 3",10);':          15.0
		'parseInt("15e2",10);':            15.0
		'parseInt("15px",10);':            15.0
		'parseInt("12",13);':              15.0
		'parseInt("-0XF",16);':            -15.0
		'parseInt(-15.1,10);':             -15.0
		'parseInt("-1111",2);':            -15.0
		'parseInt("0e0",16);':             224.0
		'parseInt("123_456");':            123.0
		'parseInt("UVWXYZ",36);':          1867590395.0
		'parseInt(4.7*1e22,10);':          4.0
		'parseInt(0.00000000000434,10);':  4.0
		'parseInt(0.0000001,11);':         1.0
		'parseInt(1e21,10);':              1.0
		'parseInt("\u00a0\ufeff -0xF ");': -15.0
		'parseInt("0b11");':               0.0
		'parseInt("0xF",10);':             0.0
		'parseInt("42",4294967296);':      42.0
		'parseInt("42",Infinity);':        42.0
		'parseInt(42n);':                  42.0
	} {
		assert execute_numeric_global(mut vm, source)!.number == expected, source
	}
	for source in ['parseInt();', 'parseInt("");', 'parseInt("+");', 'parseInt("0x");',
		'parseInt("546",2);', 'parseInt("Hello",8);', 'parseInt("42",1);', 'parseInt("42",37);',
		'parseInt("٤٢");'] {
		assert math.is_nan(execute_numeric_global(mut vm, source)!.number), source
	}
	assert math.signbit(execute_numeric_global(mut vm, 'parseInt("-0");')!.number)
	assert !math.signbit(execute_numeric_global(mut vm, 'parseInt("0");')!.number)
}

fn test_numeric_globals_follow_live_object_coercion_and_propagate_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut source := Object.create(vm.realm(), none)
	mut radix := Object.create(vm.realm(), none)
	stringify := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		return Value.from_string(vm.create_string_from_str('11'))
	}, 1, PropertyName.from_str('stringify'), none)
	to_radix := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		return Value.from_i32(8)
	}, 1, PropertyName.from_str('radix'), none)
	source.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(stringify.object))
	radix.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(to_radix.object))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('source'), Value.from_object(source))
	global.create_data_property(PropertyName.from_str('radix'), Value.from_object(radix))
	assert execute_numeric_global(mut vm, 'parseInt(source,radix);')!.number == 9
	assert execute_numeric_global(mut vm, 'isFinite(radix);')!.as_bool()
	assert !execute_numeric_global(mut vm, 'isNaN(radix);')!.as_bool()
	for text in ['isNaN(1n);', 'isFinite(1n);', 'parseInt("11",1n);'] {
		if _ := execute_numeric_global(mut vm, text) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	assert execute_numeric_global(mut vm, 'parseInt("42");')!.number == 42
}

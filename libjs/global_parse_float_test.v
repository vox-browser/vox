module libjs

import math

// Tests/LibJS/Runtime/builtins/functions/parseFloat.js, with native coercion
// fixtures replacing the still-untranslated JavaScript object/function literals.
fn execute_float_global(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'parse-float.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_parse_float_prefixes_follow_the_upstream_decimal_reader() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for text, expected in {
		'0':             0.0
		'1':             1.0
		'.23':           0.23
		'1.23':          1.23
		'0.0123E+2':     1.23
		'1.23e4':        12300.0
		'0x1.23p5':      0.0
		'1.23p5':        1.23
		'1.23e42351245': math.inf(1)
		'Infinity':      math.inf(1)
		'1e':            1.0
		'1e+':           1.0
		'1.e-':          1.0
		'1.e+2':         100.0
		'1.2e-3':        0.0012
	} {
		for prefix in ['', '+', '-'] {
			sign := if prefix == '-' { -1 } else { 1 }
			for suffix in ['', 'foo'] {
				source := 'parseFloat("${prefix}${text}${suffix}");'
				assert execute_float_global(mut vm, source)!.number == sign * expected, source
			}
		}
	}
	for text in ['', 'foo123', 'foo+123', 'fooInfinity', 'foo+Infinity', '+', '-', '.', '++1',
		'-+1', '.e3', 'infinity', 'NaN', '٤٢'] {
		assert math.is_nan(execute_float_global(mut vm, 'parseFloat("${text}");')!.number), text
	}
	assert execute_float_global(mut vm, 'parseFloat("\\u00a0\\ufeff  42xyz");')!.number == 42
	assert execute_float_global(mut vm, 'parseFloat("\\n\\t\\r -1.23\\vfoo");')!.number == -1.23
	assert execute_float_global(mut vm, 'parseFloat(42n);')!.number == 42
	assert execute_float_global(mut vm, 'parseFloat(1.23);')!.number == 1.23
	for source in ['parseFloat();', 'parseFloat(true);', 'parseFloat(false);', 'parseFloat(null);',
		'parseFloat(undefined);', 'parseFloat(NaN);'] {
		assert math.is_nan(execute_float_global(mut vm, source)!.number), source
	}
}

fn test_parse_float_preserves_string_signed_zero_but_normalizes_number_negative_zero() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['parseFloat("-0");', 'parseFloat("-0foo");', 'parseFloat("-1e-400");'] {
		value := execute_float_global(mut vm, source)!
		assert value.number == 0 && math.signbit(value.number), source
	}
	for source in ['parseFloat("0");', 'parseFloat("+0");', 'parseFloat(0);', 'parseFloat(+0);',
		'parseFloat(-0);'] {
		value := execute_float_global(mut vm, source)!
		assert value.number == 0 && !math.signbit(value.number), source
	}
	assert execute_float_global(mut vm, 'parseFloat("1e400");')!.number == math.inf(1)
	assert execute_float_global(mut vm, 'parseFloat("-1e400");')!.number == math.inf(-1)
}

fn test_parse_float_uses_string_hint_and_restores_its_native_frame_after_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut source := Object.create(vm.realm(), none)
	stringify := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		return Value.from_string(vm.create_string_from_str('1.23xyz'))
	}, 1, PropertyName.from_str('stringify'), none)
	source.create_data_property(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(stringify.object)) or { panic(err) }
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('source'), Value.from_object(source)) or {
		panic(err)
	}
	global.create_data_property(mut vm, PropertyName.from_str('key'), Value.from_symbol(Symbol.create(none,
		.unique))) or { panic(err) }
	assert execute_float_global(mut vm, 'parseFloat(source);')!.number == 1.23
	if _ := execute_float_global(mut vm, 'parseFloat(key);') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base
	assert vm.interpreter_stack().depth() == 0
	assert execute_float_global(mut vm, 'parseFloat.name;')!.as_string().str() == 'parseFloat'
	assert execute_float_global(mut vm, 'parseFloat.length;')!.number == 1
}

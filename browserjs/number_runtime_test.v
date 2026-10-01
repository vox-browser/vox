module browserjs

import libjs

fn install_number_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	parent := libjs.Object.create(realm, none)
	// Test-only Intl marker and exact decimal-form input. Neither dependency
	// substitutes for production Intl or AK/fmt's untranslated Dragonbox backend.
	formatter := libjs.NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return libjs.js_undefined()
	}, fn [parent] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
		assert vm.argument_count() == 2
		return parent
	}, 0, libjs.PropertyName.from_str('HostNumberFormat')).object
	locale := libjs.NumberLocaleDependencies{
		constructor_getter: fn [formatter] (realm &libjs.Realm) &libjs.Object {
			return formatter
		}
		format_numeric:     fn [parent] (formatter &libjs.Object, number libjs.Value) libjs.Utf16String {
			assert voidptr(formatter) == voidptr(parent) && number.is_number()
			return libjs.utf16_string('host Intl marker')
		}
	}
	decimal := fn (number f64) libjs.NumberDecimalExponentialForm {
		assert number == 1.25
		return libjs.NumberDecimalExponentialForm{
			fraction: 125
			exponent: -2
		}
	}
	prototype := libjs.NumberPrototype.create(mut vm, realm, parent, decimal, locale).object
	mut global := vm.get_global_object()
	parse_int := global.get(mut vm, libjs.PropertyName.from_str('parseInt')) or { panic(err) }
	parse_float := global.get(mut vm, libjs.PropertyName.from_str('parseFloat')) or { panic(err) }
	constructor := libjs.NumberConstructor.create(mut vm, realm, libjs.NumberConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [prototype] (realm &libjs.Realm) &libjs.Object {
			return prototype
		}
		parse_int:        parse_int.as_object()
		parse_float:      parse_float.as_object()
	}).object
	global.define_direct_property(libjs.PropertyName.from_str('HostNumber'),
		libjs.Value.from_object(constructor), 7)
}

fn test_browser_number_constructor_predicates_and_aliases_execute_translated_records() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_number_test_host(mut runtime)
	assert runtime.evaluate('HostNumber.name==="Number" && HostNumber.length===1 && HostNumber.prototype.constructor===HostNumber;')! == 'true'
	assert runtime.evaluate('HostNumber()===0 && HostNumber.isNaN(HostNumber(undefined)) && HostNumber("0xff")===255 && HostNumber(true)===1;')! == 'true'
	assert runtime.evaluate('HostNumber(9007199254740993n)===9007199254740992 && HostNumber(9007199254740995n)===9007199254740996 && HostNumber(-9007199254740995n)===-9007199254740996;')! == 'true'
	assert runtime.evaluate('HostNumber.isFinite(1) && !HostNumber.isFinite(Infinity) && !HostNumber.isFinite("1") && !HostNumber.isFinite(1n);')! == 'true'
	assert runtime.evaluate('HostNumber.isInteger(-0) && !HostNumber.isInteger(1.25) && HostNumber.isSafeInteger(HostNumber.MAX_SAFE_INTEGER) && !HostNumber.isSafeInteger(9007199254740992);')! == 'true'
	assert runtime.evaluate('HostNumber.isNaN(NaN) && !HostNumber.isNaN("no") && HostNumber.MIN_VALUE>0 && HostNumber.EPSILON===2.220446049250313e-16;')! == 'true'
	assert runtime.evaluate('HostNumber.parseInt===parseInt && HostNumber.parseFloat===parseFloat && HostNumber.parseInt("0xff")===255 && HostNumber.parseFloat("1.25suffix")===1.25;')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_number_prototype_methods_wrappers_bound_calls_and_exact_formatting() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_number_test_host(mut runtime)
	assert runtime.evaluate('var boxed=new HostNumber(1.25); boxed.valueOf()===1.25 && boxed.toString(2)==="1.01" && HostNumber(boxed)===1.25;')! == 'true'
	assert runtime.evaluate('boxed.toExponential()==="1.25e+0" && boxed.toExponential(1)==="1.3e+0" && boxed.toPrecision(2)==="1.3";')! == 'true'
	assert runtime.evaluate('boxed.toFixed(20)==="1.25000000000000000000" && HostNumber.prototype.toFixed.call(1.005,2)==="1.00" && HostNumber.prototype.toFixed.call(2.5,0)==="3";')! == 'true'
	assert runtime.evaluate('HostNumber.prototype.valueOf()===0 && HostNumber.prototype.toExponential()==="0e+0" && HostNumber.prototype.toPrecision.call(-0,3)==="0.00";')! == 'true'
	assert runtime.evaluate('var fixed=boxed.toFixed.bind(boxed,2); fixed()==="1.25" && (new HostNumber(-0)).valueOf()===0;')! == 'true'
	assert runtime.evaluate('var make=HostNumber.bind(null,42); (new make()).valueOf()===42;')! == 'true'
	assert runtime.evaluate('boxed.toLocaleString("en",new Boolean(false));')! == 'host Intl marker'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_number_errors_match_upstream_and_leave_later_scripts_runnable() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_number_test_host(mut runtime)
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'HostNumber(Symbol("x"));', url: 'number-symbol.js' },
		ScriptSource{ code: 'HostNumber.prototype.toString.call(42,37);', url: 'number-radix.js' },
		ScriptSource{
			code: 'HostNumber.prototype.toFixed.call(Infinity,101);'
			url:  'number-fixed.js'
		},
		ScriptSource{
			code: 'HostNumber.prototype.toExponential.call(0,-1);'
			url:  'number-exponential.js'
		},
		ScriptSource{
			code: 'HostNumber.prototype.toPrecision.call(0,0);'
			url:  'number-precision.js'
		},
		ScriptSource{ code: 'HostNumber.prototype.valueOf.call(1n);', url: 'number-brand.js' },
		ScriptSource{
			code: 'HostNumber.prototype.toLocaleString.call(true);'
			url:  'number-locale.js'
		},
	])
	assert errors.len == 7
	for index, message in ['Cannot convert symbol to number',
		'Radix must be an integer no less than 2, and no greater than 36',
		'Fraction Digits must be an integer no less than 0, and no greater than 100',
		'Fraction Digits must be an integer no less than 0, and no greater than 100',
		'Precision must be an integer no less than 1, and no greater than 100',
		'Not an object of type Number', 'Not an object of type Number'] {
		assert errors[index].contains(message)
	}
	assert errors[0].contains('number-symbol.js')
	assert runtime.evaluate('HostNumber.prototype.toExponential.call(Infinity,101)==="Infinity" && HostNumber.prototype.toPrecision.call(NaN,0)==="NaN";')! == 'true'
	assert runtime.evaluate('HostNumber("42")+HostNumber(1);')! == '43'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

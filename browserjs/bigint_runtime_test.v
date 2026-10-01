module browserjs

import libjs

fn install_bigint_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	parent := libjs.Object.create(realm, none)
	// Plumbing-only Intl fixture. Its marker is not locale formatting.
	constructor := libjs.NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return libjs.js_undefined()
	}, fn [parent] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
		assert vm.argument_count() == 2
		return parent
	}, 0, libjs.PropertyName.from_str('HostNumberFormat')).object
	locale := libjs.BigIntLocaleDependencies{
		constructor_getter: fn [constructor] (realm &libjs.Realm) &libjs.Object {
			return constructor
		}
		format_numeric:     fn [parent] (formatter &libjs.Object, number libjs.Value) libjs.Utf16String {
			assert voidptr(formatter) == voidptr(parent) && number.is_bigint()
			return libjs.utf16_string('host Intl marker')
		}
	}
	prototype := libjs.BigIntPrototype.create(mut vm, realm, parent, locale).object
	bigint := libjs.BigIntConstructor.create(mut vm, realm, prototype).object
	box := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [prototype] (mut vm libjs.VM) !libjs.Value {
		integer := vm.argument(0).to_bigint(mut vm)!
		return libjs.Value.from_object(libjs.BigIntObject.create(vm.realm(), integer, prototype).object)
	}, 1, libjs.PropertyName.from_str('HostBigIntBox'), none).object
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('HostBigInt'),
		libjs.Value.from_object(bigint), 7)
	global.define_direct_property(libjs.PropertyName.from_str('HostBigIntBox'),
		libjs.Value.from_object(box), 7)
}

fn test_browser_bigint_constructor_and_width_methods_execute_complete_records() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_bigint_test_host(mut runtime)
	assert runtime.evaluate('HostBigInt.name==="BigInt" && HostBigInt.length===1 && HostBigInt.asIntN.length===2 && HostBigInt.asUintN.length===2;')! == 'true'
	assert runtime.evaluate('HostBigInt.prototype.constructor===HostBigInt && HostBigInt.prototype[Symbol.toStringTag]==="BigInt";')! == 'true'
	assert runtime.evaluate('HostBigInt("0xff")+HostBigInt(true)+HostBigInt(42);')! == '298'
	assert runtime.evaluate('HostBigInt(1e30)===1000000000000000019884624838656n;')! == 'true'
	assert runtime.evaluate('var converted=HostBigInt("9007199254740993"); ++converted;')! == '9007199254740994'
	assert runtime.evaluate('HostBigInt.asIntN(8,255n)===-1n && HostBigInt.asUintN(8,-1n)===255n;')! == 'true'
	assert runtime.evaluate('var huge=123456789123456789123456789123456789123456789123456789n; HostBigInt.asIntN(128,huge);')! == '-99061374399389259395070030194384019691'
	assert runtime.evaluate('HostBigInt.asUintN(128,huge);')! == '241220992521549204068304577237384191765'
	assert runtime.evaluate('HostBigInt.asIntN(9007199254740991,-2n)===-2n && HostBigInt.asUintN(9007199254740991,2n)===2n;')! == 'true'
	assert runtime.evaluate('HostBigInt.asIntN(4.9,"0x1f")===-1n && HostBigInt.asUintN(undefined,true)===0n;')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_bigint_prototype_methods_use_real_wrappers_and_native_call_binding() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_bigint_test_host(mut runtime)
	assert runtime.evaluate('var boxed=HostBigIntBox(42n); boxed.valueOf()===42n && boxed.toString(16)==="2a" && HostBigInt(boxed)===42n;')! == 'true'
	assert runtime.evaluate('HostBigInt.prototype.toString.call(-42n,16);')! == '-2a'
	assert runtime.evaluate('HostBigInt.prototype.toString.call(1267650600228229401496703205375n,16);')! == 'fffffffffffffffffffffffff'
	assert runtime.evaluate('HostBigInt.prototype.toString.call(0n,36)==="0" && HostBigInt.prototype.toString.call(42n,36.9)==="16";')! == 'true'
	assert runtime.evaluate('HostBigInt.prototype.valueOf.call(boxed)===42n && HostBigInt.prototype.valueOf.call(42n)===42n;')! == 'true'
	assert runtime.evaluate('var stringify=HostBigInt.prototype.toString.bind(boxed,16); stringify();')! == '2a'
	assert runtime.evaluate('var convert=HostBigInt.bind(null,"0x2a"); convert();')! == '42'
	assert runtime.evaluate('boxed.toLocaleString("en",new Boolean(false));')! == 'host Intl marker'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_bigint_errors_match_upstream_and_restore_runtime_after_each_script() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_bigint_test_host(mut runtime)
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'new HostBigInt(42);', url: 'bigint-new.js' },
		ScriptSource{ code: 'HostBigInt(1.25);', url: 'bigint-fraction.js' },
		ScriptSource{ code: 'HostBigInt("foo");', url: 'bigint-string.js' },
		ScriptSource{ code: 'HostBigInt.asIntN(-1,0n);', url: 'bigint-width.js' },
		ScriptSource{ code: 'HostBigInt.asIntN(0,1);', url: 'bigint-number.js' },
		ScriptSource{ code: 'HostBigInt.asUintN(9007199254740991,-2n);', url: 'bigint-oom.js' },
		ScriptSource{ code: 'HostBigInt.prototype.toString.call(42n,37);', url: 'bigint-radix.js' },
		ScriptSource{ code: 'HostBigInt.prototype.toString.call(42,16);', url: 'bigint-brand.js' },
		ScriptSource{ code: 'HostBigInt.prototype.valueOf();', url: 'bigint-prototype.js' },
		ScriptSource{ code: 'HostBigInt.prototype.toLocaleString.call(42);', url: 'bigint-locale.js' },
	])
	assert errors.len == 10
	for index, message in ['BigInt is not a constructor',
		'Cannot convert non-integral number to BigInt', 'Invalid value for BigInt: foo',
		'Index must be a positive integer', 'Cannot convert number to BigInt', 'Out of memory',
		'Radix must be an integer no less than 2, and no greater than 36',
		'Not an object of type BigInt', 'Not an object of type BigInt',
		'Not an object of type BigInt'] {
		assert errors[index].contains(message)
	}
	assert errors[0].contains('bigint-new.js') && errors[5].contains('bigint-oom.js')
	assert runtime.evaluate('HostBigInt.asIntN(8,HostBigInt(42));')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

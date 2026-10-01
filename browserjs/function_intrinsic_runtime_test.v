module browserjs

import libjs

fn test_browser_libjs_function_intrinsics_and_legacy_globals_execute_without_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	mut global := vm.get_global_object()
	prototype := libjs.Object.create(vm.realm(), none)
	function := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return vm.this_value().as_object().get(mut vm, libjs.PropertyName.from_str('stored'))
	}, 0, libjs.PropertyName.from_str('Target'), none)
	mut target := function.object
	target.create_data_property(mut vm, libjs.PropertyName.from_str('prototype'),
		libjs.Value.from_object(prototype)) or { panic(err) }
	mut instance := libjs.Object.create(vm.realm(), prototype)
	instance.create_data_property(mut vm, libjs.PropertyName.from_str('stored'),
		libjs.Value.from_i32(42)) or { panic(err) }
	global.create_data_property(mut vm, libjs.PropertyName.from_str('Target'),
		libjs.Value.from_object(target)) or { panic(err) }
	global.create_data_property(mut vm, libjs.PropertyName.from_str('instance'),
		libjs.Value.from_object(instance)) or { panic(err) }
	assert runtime.evaluate('Target.call(instance);')! == '42'
	assert runtime.evaluate('Target.bind(instance)();')! == '42'
	assert runtime.evaluate('instance instanceof Target.bind(null).bind(null);')! == 'true'
	assert runtime.evaluate('parseInt.call(null,"2a",16);')! == '42'
	assert runtime.evaluate('parseInt.bind(null,"2a")(16);')! == '42'
	assert runtime.evaluate('globalThis.length=2; globalThis[0]="2a"; globalThis[1]=16; parseInt.apply(null,globalThis);')! == '42'
	assert runtime.evaluate('parseInt.toString();')! == 'function parseInt() { [native code] }'
	assert runtime.evaluate('parseInt.bind(null).toString();')! == 'function () { [native code] }'
	assert runtime.evaluate('escape("😀");')! == '%uD83D%uDE00'
	assert runtime.evaluate('unescape.bind(null,"%uD83D%uDE00")();')! == '😀'
	assert runtime.evaluate('unescape("%u0g00%41");')! == '%u0g00A'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_function_builtin_errors_preserve_source_and_allow_later_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'parseInt.caller; globalThis.leaked=1;', url: 'restricted.js' },
		ScriptSource{ code: 'parseInt.apply(null,42);', url: 'apply.js' },
		ScriptSource{ code: '42 instanceof parseInt;', url: 'primitive.js' },
		ScriptSource{ code: 'globalThis instanceof parseInt;', url: 'prototype.js' },
		ScriptSource{ code: 'var answer=parseInt.bind(null,"2a")(16);', url: 'after.js' },
	])
	assert errors.len == 3
	for index, filename in ['restricted.js', 'apply.js', 'prototype.js'] {
		assert errors[index].contains('TypeError:') && errors[index].contains('${filename}:1:')
	}
	assert runtime.evaluate('typeof leaked;')! == 'undefined'
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_browser_javascriptcore_flag_preserves_function_builtin_execution() {
	$if darwin {
		mut runtime := Runtime.create_with_engine(.javascriptcore)
		defer { runtime.close() }
		assert runtime.evaluate('parseInt.bind(null,"2a")(16);')! == '42'
		assert runtime.evaluate('parseInt.apply(null,["2a",16]);')! == '42'
		assert runtime.evaluate('unescape(escape("😀"));')! == '😀'
		assert runtime.context != unsafe { nil }
	}
}

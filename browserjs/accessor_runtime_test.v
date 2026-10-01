module browserjs

import libjs

fn install_runtime_accessor_host(mut vm libjs.VM) &libjs.Object {
	mut host := libjs.Object.create(vm.realm(), none)
	host.create_data_property(libjs.PropertyName.from_str('stored'), libjs.Value.from_i32(41))
	host.define_native_accessor(mut vm, vm.realm(), libjs.PropertyName.from_str('value'), fn (mut vm libjs.VM) !libjs.Value {
		return vm.this_value().as_object().get(mut vm, libjs.PropertyName.from_str('stored'))
	}, fn (mut vm libjs.VM) !libjs.Value {
		mut receiver := vm.this_value().as_object()
		receiver.set(mut vm, libjs.PropertyName.from_str('stored'), vm.argument(0), .yes)!
		return libjs.js_undefined()
	}, libjs.attribute_enumerable | libjs.attribute_configurable, none)
	method := libjs.NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm libjs.VM) !libjs.Value {
		return vm.this_value().as_object().get(mut vm, libjs.PropertyName.from_str('stored'))
	}, 0, libjs.PropertyName.from_str('method'), none)
	for name in ['method', 'valueOf'] {
		host.define_native_accessor(mut vm, vm.realm(), libjs.PropertyName.from_str(name), fn [method] (mut vm libjs.VM) !libjs.Value {
			return libjs.Value.from_object(method.object)
		}, unsafe { nil }, libjs.attribute_configurable, none)
	}
	mut global := vm.get_global_object()
	global.create_data_property(libjs.PropertyName.from_str('host'), libjs.Value.from_object(host))
	return host
}

fn test_browser_libjs_backend_executes_host_accessors_and_keeps_javascriptcore_uninitialized() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	host := install_runtime_accessor_host(mut vm)
	assert runtime.evaluate('++host.value;')! == '42'
	assert runtime.evaluate('host.value=41n; host.value+=1n; host.value;')! == '42'
	assert runtime.evaluate('host.value++; host.value;')! == '43'
	assert host.get(mut vm, libjs.PropertyName.from_str('stored'))!.is_bigint()
	assert runtime.evaluate('host.method() === host.stored;')! == 'true'
	assert runtime.evaluate('host+1n;')! == '44'
	assert runtime.evaluate('"value" in host;')! == 'true'
	assert runtime.evaluate('delete host.value;')! == 'true'
	assert runtime.evaluate('"value" in host;')! == 'false'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_accessor_exceptions_preserve_source_and_continue_later_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	mut host := install_runtime_accessor_host(mut vm)
	host.define_native_accessor(mut vm, vm.realm(), libjs.PropertyName.from_str('failure'), fn (mut vm libjs.VM) !libjs.Value {
		return vm.throw_error(.type_error, 'Accessor failure')
	}, unsafe { nil }, libjs.attribute_configurable, none)
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'host.failure; globalThis.leaked=1;', url: 'getter.js' },
		ScriptSource{ code: '"use strict"; host.failure=42;', url: 'setter.js' },
		ScriptSource{ code: 'var answer=++host.value;', url: 'after.js' },
	])
	assert errors.len == 2
	assert errors[0].contains('TypeError: Accessor failure') && errors[0].contains('getter.js:1:')
	assert errors[1].contains('TypeError:') && errors[1].contains('setter.js:1:')
	assert runtime.evaluate('typeof leaked;')! == 'undefined'
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

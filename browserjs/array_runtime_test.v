module browserjs

import libjs

fn test_browser_libjs_array_records_use_live_length_and_function_apply() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	prototype := libjs.Object.create(vm.realm(), none)
	array := libjs.ArrayObject.create_from(mut vm, vm.realm(), [
		libjs.Value.from_string(vm.create_string_from_str('2a')),
		libjs.Value.from_i32(16),
	], prototype)!
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('array'),
		libjs.Value.from_object(array.object))!
	assert runtime.evaluate('parseInt.apply(null,array);')! == '42'
	assert runtime.evaluate('array[4]=17; array.length;')! == '5'
	assert runtime.evaluate('array.length=2; 4 in array;')! == 'false'
	assert runtime.evaluate('delete array.length;')! == 'false'
	assert runtime.evaluate('array.length;')! == '2'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_array_length_errors_preserve_source_and_later_script_execution() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	prototype := libjs.Object.create(vm.realm(), none)
	array := libjs.ArrayObject.create(mut vm, vm.realm(), 3, prototype)!
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('array'),
		libjs.Value.from_object(array.object))!
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'array.length=1.5; globalThis.leaked=1;', url: 'length.js' },
		ScriptSource{ code: '"use strict"; delete array.length;', url: 'delete.js' },
		ScriptSource{ code: 'var answer=array.length+39;', url: 'after.js' },
	])
	assert errors.len == 2
	assert errors[0].contains('RangeError:') && errors[0].contains('length.js:1:')
	assert errors[1].contains('TypeError:') && errors[1].contains('delete.js:1:')
	assert runtime.evaluate('typeof leaked;')! == 'undefined'
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

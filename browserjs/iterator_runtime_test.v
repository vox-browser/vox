module browserjs

import libjs

fn test_browser_libjs_string_exotics_reach_compiled_references_and_function_apply() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	parent := libjs.Object.create(vm.realm(), none)
	text := libjs.StringObject.create(vm.realm(), vm.create_string_from_str('42'), parent)
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('text'), libjs.Value.from_object(text.object))!
	join := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
		return libjs.add(mut vm, vm.argument(0), vm.argument(1))
	}, 2, libjs.PropertyName.from_str('join'), none)
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('join'), libjs.Value.from_object(join.object))!
	assert runtime.evaluate('text.length;')! == '2'
	assert runtime.evaluate('text[0]+text[1];')! == '42'
	assert runtime.evaluate('join.apply(null,text);')! == '42'
	assert runtime.evaluate('text[0]="x"; text[0];')! == '4'
	assert runtime.evaluate('delete text[0];')! == 'false'
	assert runtime.evaluate('0 in text;')! == 'true'
	assert runtime.evaluate('text[2]="z"; text.length;')! == '2'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{code: '"use strict"; text[0]="x";', url: 'string-write.js'},
		ScriptSource{code: '"use strict"; delete text[1];', url: 'string-delete.js'},
		ScriptSource{code: 'var answer=join.apply(null,text);', url: 'string-after.js'},
	])
	assert errors.len == 2
	assert errors[0].contains('TypeError:') && errors[0].contains('string-write.js:1:')
	assert errors[1].contains('TypeError:') && errors[1].contains('string-delete.js:1:')
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_string_iterator_calls_yield_unicode_and_persistent_done_state() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	parent := libjs.Object.create(vm.realm(), none)
	prototype := libjs.StringIteratorPrototype.create(mut vm, vm.realm(), parent, parent)
	iterator := libjs.StringIterator.create(vm.realm(), libjs.utf16_string('A😀B'), prototype.object)
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('iterator'), libjs.Value.from_object(iterator.object))!
	assert runtime.evaluate('iterator.next().value;')! == 'A'
	assert runtime.evaluate('iterator.next().value;')! == '😀'
	assert runtime.evaluate('iterator.next().value;')! == 'B'
	assert runtime.evaluate('iterator.next().done;')! == 'true'
	assert runtime.evaluate('iterator.next().value;')! == 'undefined'
	if _ := runtime.evaluate('iterator.next.call(null);') { assert false } else {
		assert err.msg().contains('TypeError:')
	}
	assert runtime.evaluate('iterator.next().done;')! == 'true'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_array_iterators_observe_live_arrays_and_return_entry_pairs() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	parent := libjs.Object.create(vm.realm(), none)
	prototype := libjs.ArrayIteratorPrototype.create(mut vm, vm.realm(), parent, parent, parent)
	array := libjs.ArrayObject.create_from(mut vm, vm.realm(), [libjs.Value.from_i32(42)], parent)!
	iterator := libjs.ArrayIterator.create(vm.realm(), libjs.Value.from_object(array.object), .value, prototype.object)
	entries := libjs.ArrayIterator.create(vm.realm(), libjs.Value.from_object(array.object), .key_and_value, prototype.object)
	mut global := vm.get_global_object()
	for name, object in {'array': array.object, 'iterator': iterator.object, 'entries': entries.object} {
		assert global.create_data_property(mut vm, libjs.PropertyName.from_str(name), libjs.Value.from_object(object))!
	}
	assert runtime.evaluate('iterator.next().value;')! == '42'
	assert runtime.evaluate('array[1]=17; iterator.next().value;')! == '17'
	assert runtime.evaluate('var pair=entries.next().value; pair[0]+pair[1];')! == '42'
	assert runtime.evaluate('pair.length;')! == '2'
	assert runtime.evaluate('entries.next().value[1];')! == '17'
	assert runtime.evaluate('iterator.next().done;')! == 'true'
	assert runtime.evaluate('array[2]=99; iterator.next().done;')! == 'true'
	assert runtime.evaluate('entries.next().value[1];')! == '99'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

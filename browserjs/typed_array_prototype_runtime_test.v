module browserjs

import libjs

// Test-only installation of the completed bodies with explicit dependencies;
// this does not expose unfinished builtin intrinsics to browser documents.
fn install_typed_prototype_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	mut parent := libjs.Object.create(realm, none)
	prototypes := libjs.PrimitiveObjectPrototypes{
		number: fn (realm &libjs.Realm) &libjs.Object { return realm.data_view_prototype_record() }
		bigint: fn (realm &libjs.Realm) &libjs.Object { return realm.data_view_prototype_record() }
		string: fn (realm &libjs.Realm) &libjs.Object { return realm.data_view_prototype_record() }
	}
	for name in ['at', 'includes', 'indexOf', 'lastIndexOf', 'reverse', 'sort'] {
		function := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, prototypes] (mut vm libjs.VM) !libjs.Value {
			return match name {
				'at' { libjs.typed_array_prototype_at(mut vm, prototypes)! }
				'includes' { libjs.typed_array_prototype_includes(mut vm, prototypes)! }
				'indexOf' { libjs.typed_array_prototype_index_of(mut vm, prototypes)! }
				'lastIndexOf' { libjs.typed_array_prototype_last_index_of(mut vm, prototypes)! }
				'reverse' { libjs.typed_array_prototype_reverse(mut vm, prototypes)! }
				else { libjs.typed_array_prototype_sort(mut vm, prototypes)! }
			}
		}, 1, libjs.PropertyName.from_str(name), none)
		parent.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(function.object), 5)
	}
	for name in ['buffer', 'byteLength', 'byteOffset', 'length'] {
		parent.define_native_accessor(mut vm, realm, libjs.PropertyName.from_str(name), fn [name, prototypes] (mut vm libjs.VM) !libjs.Value {
			return match name {
				'buffer' { libjs.typed_array_prototype_buffer_getter(mut vm, prototypes)! }
				'byteLength' { libjs.typed_array_prototype_byte_length_getter(mut vm, prototypes)! }
				'byteOffset' { libjs.typed_array_prototype_byte_offset_getter(mut vm, prototypes)! }
				else { libjs.typed_array_prototype_length_getter(mut vm, prototypes)! }
			}
		}, unsafe { nil }, libjs.attribute_configurable, realm.function_prototype)
	}
	parent.define_native_accessor(mut vm, realm, libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.typed_array_prototype_to_string_tag_getter, unsafe { nil }, libjs.attribute_configurable, realm.function_prototype)
	mut global := vm.get_global_object()
	for index, name in ['HostBytes', 'HostNumbers', 'HostBig'] {
		kind := [libjs.BufferElementType.uint8, .float64, .big_int64][index]
		constructor := libjs.NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn [kind] (mut vm libjs.VM) !libjs.Value {
			return libjs.call_typed_array_constructor(mut vm, kind)
		}, fn [kind, parent] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
			getter := fn [parent] (realm &libjs.Realm) &libjs.Object { return parent }
			return libjs.construct_typed_array(mut vm, kind, target, getter)!.object
		}, 3, libjs.PropertyName.from_str(name))
		mut object := constructor.object
		object.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(parent), 0)
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(object), 7)
	}
}

fn test_browser_typed_array_accessors_search_reverse_and_numeric_sort_execute_without_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	assert runtime.evaluate('var numbers=new HostNumbers(5); numbers[0]=100; numbers[1]=20; numbers[2]=-0; numbers[3]=0; numbers[4]=NaN; numbers.length;')! == '5'
	assert runtime.evaluate('numbers.byteLength;')! == '40'
	assert runtime.evaluate('numbers[Symbol.toStringTag];')! == 'Float64Array'
	assert runtime.evaluate('numbers.includes(NaN);')! == 'true'
	assert runtime.evaluate('numbers.indexOf(NaN);')! == '-1'
	assert runtime.evaluate('numbers.lastIndexOf(0);')! == '3'
	assert runtime.evaluate('numbers.lastIndexOf(0,undefined);')! == '-1'
	assert runtime.evaluate('numbers.sort()===numbers;')! == 'true'
	assert runtime.evaluate('1/numbers.at(0);')! == '-Infinity'
	assert runtime.evaluate('1/numbers.at(1);')! == 'Infinity'
	assert runtime.evaluate('numbers.at(2);')! == '20'
	assert runtime.evaluate('numbers.at(3);')! == '100'
	assert runtime.evaluate('isNaN(numbers.at(-1));')! == 'true'
	assert runtime.evaluate('numbers.reverse()===numbers;')! == 'true'
	assert runtime.evaluate('numbers.at(-2);')! == '0'
	assert runtime.evaluate('var big=new HostBig(3); big[0]=9007199254740993n; big[1]=-1n; big[2]=9007199254740992n; big.sort().at(1);')! == '9007199254740992'
	assert runtime.evaluate('big.indexOf(9007199254740993n);')! == '2'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_accessors_resize_detach_and_recover_after_script_errors() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(4,options); var tracking=new HostBytes(buffer,1); var fixed=new HostBytes(buffer,1,3); tracking[0]=42; tracking.byteOffset;')! == '1'
	assert runtime.evaluate('tracking.buffer===buffer;')! == 'true'
	assert runtime.evaluate('buffer.resize(2); fixed.length;')! == '0'
	assert runtime.evaluate('fixed.byteOffset;')! == '0'
	assert runtime.evaluate('tracking.length;')! == '1'
	assert runtime.evaluate('buffer.resize(6); fixed.at(0);')! == '42'
	assert runtime.evaluate('tracking.length;')! == '5'
	assert runtime.evaluate('buffer.transfer(); tracking.byteLength;')! == '0'
	assert runtime.evaluate('tracking.buffer===buffer;')! == 'true'
	assert runtime.evaluate('tracking[Symbol.toStringTag];')! == 'Uint8Array'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'tracking.at(0);', url: 'typed-at-detached.js' },
		ScriptSource{ code: 'fixed.sort(17);', url: 'typed-sort-callback.js' },
		ScriptSource{ code: 'HostBytes.prototype.at.call(null,0);', url: 'typed-at-null.js' },
		ScriptSource{ code: 'HostBytes.prototype.at.call(42,0);', url: 'typed-at-number.js' },
		ScriptSource{ code: 'var answer=new HostBytes(1); answer[0]=42; answer.at(0);', url: 'typed-after.js' },
	])
	assert errors.len == 4
	for index, name in ['typed-at-detached.js', 'typed-sort-callback.js', 'typed-at-null.js',
		'typed-at-number.js'] {
		assert errors[index].contains('TypeError:') && errors[index].contains(name + ':1:')
	}
	assert errors[1].contains('17 is not a function')
	assert errors[2].contains('ToObject on null or undefined')
	assert errors[3].contains('Not an object of type TypedArray')
	assert runtime.evaluate('answer.at(0);')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_sort_uses_translated_bound_native_comparator() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	comparator := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.this_value().is_null() && vm.argument_count() == 2
		return libjs.Value.from_f64(vm.argument(1).number - vm.argument(0).number)
	}, 2, libjs.PropertyName.from_str('compare'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('compare'), libjs.Value.from_object(comparator.object), 7)
	assert runtime.evaluate('var bytes=new HostBytes(3); bytes[0]=2; bytes[1]=42; bytes[2]=17; bytes.sort(compare.bind(null)).at(0);')! == '42'
	assert runtime.evaluate('bytes.at(1);')! == '17'
	assert runtime.evaluate('bytes.at(2);')! == '2'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

module browserjs

import libjs

// Test-only installation of the completed bodies with explicit dependencies;
// this does not expose unfinished builtin intrinsics to browser documents.
fn install_typed_prototype_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	mut parent := libjs.Object.create(realm, none)
	prototypes := libjs.PrimitiveObjectPrototypes{
		number: fn (realm &libjs.Realm) &libjs.Object {
			return realm.data_view_prototype_record()
		}
		bigint: fn (realm &libjs.Realm) &libjs.Object {
			return realm.data_view_prototype_record()
		}
		string: fn (realm &libjs.Realm) &libjs.Object {
			return realm.data_view_prototype_record()
		}
	}
	iterator_prototype := libjs.ArrayIteratorPrototype.create(mut vm, realm, parent, parent, parent)
	for name in ['at', 'includes', 'indexOf', 'lastIndexOf', 'reverse', 'sort', 'every', 'some',
		'forEach', 'find', 'findIndex', 'findLast', 'findLastIndex', 'reduce', 'reduceRight',
		'entries', 'keys', 'values'] {
		function := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, prototypes, iterator_prototype] (mut vm libjs.VM) !libjs.Value {
			return match name {
				'at' {
					libjs.typed_array_prototype_at(mut vm, prototypes)!
				}
				'includes' {
					libjs.typed_array_prototype_includes(mut vm, prototypes)!
				}
				'indexOf' {
					libjs.typed_array_prototype_index_of(mut vm, prototypes)!
				}
				'lastIndexOf' {
					libjs.typed_array_prototype_last_index_of(mut vm, prototypes)!
				}
				'reverse' {
					libjs.typed_array_prototype_reverse(mut vm, prototypes)!
				}
				'sort' {
					libjs.typed_array_prototype_sort(mut vm, prototypes)!
				}
				'every' {
					libjs.typed_array_prototype_every(mut vm, prototypes)!
				}
				'some' {
					libjs.typed_array_prototype_some(mut vm, prototypes)!
				}
				'forEach' {
					libjs.typed_array_prototype_for_each(mut vm, prototypes)!
				}
				'find' {
					libjs.typed_array_prototype_find(mut vm, prototypes)!
				}
				'findIndex' {
					libjs.typed_array_prototype_find_index(mut vm, prototypes)!
				}
				'findLast' {
					libjs.typed_array_prototype_find_last(mut vm, prototypes)!
				}
				'findLastIndex' {
					libjs.typed_array_prototype_find_last_index(mut vm, prototypes)!
				}
				'reduce' {
					libjs.typed_array_prototype_reduce(mut vm, prototypes)!
				}
				'reduceRight' {
					libjs.typed_array_prototype_reduce_right(mut vm, prototypes)!
				}
				'entries' {
					libjs.typed_array_prototype_entries(mut vm, prototypes,
						iterator_prototype.object)!
				}
				'keys' {
					libjs.typed_array_prototype_keys(mut vm, prototypes, iterator_prototype.object)!
				}
				else {
					libjs.typed_array_prototype_values(mut vm, prototypes,
						iterator_prototype.object)!
				}
			}
		}, 1, libjs.PropertyName.from_str(name), none)
		parent.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(function.object), 5)
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
	parent.define_native_accessor(mut vm, realm,
		libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		libjs.typed_array_prototype_to_string_tag_getter, unsafe { nil },
		libjs.attribute_configurable, realm.function_prototype)
	mut global := vm.get_global_object()
	for index, name in ['HostBytes', 'HostNumbers', 'HostBig'] {
		kind := [libjs.BufferElementType.uint8, .float64, .big_int64][index]
		constructor := libjs.NativeFunction.create_constructor(mut vm, realm,
			realm.function_prototype, fn [kind] (mut vm libjs.VM) !libjs.Value {
			return libjs.call_typed_array_constructor(mut vm, kind)
		}, fn [kind, parent] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
			getter := fn [parent] (realm &libjs.Realm) &libjs.Object {
				return parent
			}
			return libjs.construct_typed_array(mut vm, kind, target, getter)!.object
		}, 3, libjs.PropertyName.from_str(name))
		mut object := constructor.object
		object.define_direct_property(libjs.PropertyName.from_str('prototype'),
			libjs.Value.from_object(parent), 0)
		global.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(object), 7)
	}
}

@[heap]
struct BrowserTypedCallbackLog {
mut:
	indices []int
	values  []libjs.Value
}

fn test_browser_typed_array_callbacks_find_and_reduce_execute_bound_native_calls() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	mut log := &BrowserTypedCallbackLog{}
	predicate := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm libjs.VM) !libjs.Value {
		assert vm.this_value().is_null() && vm.argument_count() == 3
		assert vm.argument(2).as_object().typed_array != none
		log.indices << int(vm.argument(1).number)
		return libjs.Value.from_bool(vm.argument(0).number == 42)
	}, 3, libjs.PropertyName.from_str('predicate'), none)
	reducer := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.this_value().is_undefined() && vm.argument_count() == 4
		assert vm.argument(3).as_object().typed_array != none
		return libjs.add(mut vm, vm.argument(0), vm.argument(1))
	}, 4, libjs.PropertyName.from_str('reducer'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('predicate'),
		libjs.Value.from_object(predicate.object), 7)
	global.define_direct_property(libjs.PropertyName.from_str('reducer'),
		libjs.Value.from_object(reducer.object), 7)
	assert runtime.evaluate('var bytes=new HostBytes(3); bytes[0]=17; bytes[1]=42; bytes[2]=43; var match=predicate.bind(null); bytes.some(match);')! == 'true'
	assert log.indices == [0, 1]
	log.indices.clear()
	assert runtime.evaluate('bytes.every(match);')! == 'false'
	assert log.indices == [0]
	log.indices.clear()
	assert runtime.evaluate('bytes.forEach(match);')! == 'undefined'
	assert log.indices == [0, 1, 2]
	log.indices.clear()
	assert runtime.evaluate('bytes.find(match);')! == '42'
	assert log.indices == [0, 1]
	assert runtime.evaluate('bytes.findIndex(match);')! == '1'
	log.indices.clear()
	assert runtime.evaluate('bytes.findLast(match);')! == '42'
	assert log.indices == [2, 1]
	assert runtime.evaluate('bytes.findLastIndex(match);')! == '1'
	assert runtime.evaluate('bytes.reduce(reducer);')! == '102'
	assert runtime.evaluate('bytes.reduceRight(reducer,1);')! == '103'
	assert runtime.evaluate('var big=new HostBig(2); big[0]=9007199254740993n; big[1]=42n; big.reduce(reducer,0n);')! == '9007199254741035'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_callback_resize_and_abrupt_completion_recover_between_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	mut log := &BrowserTypedCallbackLog{}
	callback := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm libjs.VM) !libjs.Value {
		index := int(vm.argument(1).number)
		log.indices << index
		log.values << vm.argument(0)
		if index == 0 {
			array := vm.argument(2).as_object().typed_array or { panic('missing typed view') }
			mut buffer := array.viewed_buffer
			assert buffer.try_resize(0, true)
		}
		return libjs.js_undefined()
	}, 3, libjs.PropertyName.from_str('shrink'), none)
	thrower := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return libjs.throw_completion(libjs.Value.from_i32(99))
	}, 3, libjs.PropertyName.from_str('thrower'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('shrink'),
		libjs.Value.from_object(callback.object), 7)
	global.define_direct_property(libjs.PropertyName.from_str('thrower'),
		libjs.Value.from_object(thrower.object), 7)
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(3,options); var bytes=new HostBytes(buffer); bytes[0]=42; bytes[1]=17; bytes[2]=43; bytes.forEach(shrink);')! == 'undefined'
	assert log.indices == [0, 1, 2]
		&& log.values == [libjs.Value.from_i32(42), libjs.js_undefined(), libjs.js_undefined()]
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'bytes.find();', url: 'typed-find-missing.js' },
		ScriptSource{ code: 'bytes.reduce(shrink);', url: 'typed-reduce-empty.js' },
		ScriptSource{ code: 'buffer.resize(3); bytes.some(thrower);', url: 'typed-some-throw.js' },
		ScriptSource{
			code: 'bytes[0]=42; var answer=bytes.values().next().value;'
			url:  'typed-after-callback.js'
		},
	])
	assert errors.len == 3
	assert errors[0].contains('TypedArray.prototype.find() requires at least one argument')
	assert errors[1].contains('Reduce of empty array with no initial value')
	assert errors[2].contains('99')
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_iterator_methods_use_live_buffers_and_branded_next() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(2,options); var bytes=new HostBytes(buffer,1); bytes[0]=42; var values=bytes.values(); var keys=bytes.keys(); var entries=bytes.entries(); values.next().value;')! == '42'
	assert runtime.evaluate('keys.next().value;')! == '0'
	assert runtime.evaluate('var pair=entries.next().value; pair[0]+pair[1];')! == '42'
	assert runtime.evaluate('pair.length;')! == '2'
	assert runtime.evaluate('buffer.resize(4); bytes[1]=43; values.next().value;')! == '43'
	assert runtime.evaluate('keys.next().value;')! == '1'
	assert runtime.evaluate('entries.next().value[1];')! == '43'
	assert runtime.evaluate('buffer.resize(0);')! == 'undefined'
	if _ := runtime.evaluate('values.next();') {
		assert false
	} else {
		assert err.msg().contains('TypeError:') && err.msg().contains('bounds')
	}
	assert runtime.evaluate('buffer.resize(4); bytes[2]=17; values.next().value;')! == '17'
	assert runtime.evaluate('values.next().done;')! == 'true'
	assert runtime.evaluate('buffer.resize(8); values.next().done;')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
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
		ScriptSource{
			code: 'var answer=new HostBytes(1); answer[0]=42; answer.at(0);'
			url:  'typed-after.js'
		},
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
	global.define_direct_property(libjs.PropertyName.from_str('compare'),
		libjs.Value.from_object(comparator.object), 7)
	assert runtime.evaluate('var bytes=new HostBytes(3); bytes[0]=2; bytes[1]=42; bytes[2]=17; bytes.sort(compare.bind(null)).at(0);')! == '42'
	assert runtime.evaluate('bytes.at(1);')! == '17'
	assert runtime.evaluate('bytes.at(2);')! == '2'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

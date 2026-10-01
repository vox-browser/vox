module browserjs

import libjs

@[heap]
struct BrowserTypedIntrinsicTable {
mut:
	constructors map[int]&libjs.Object
	prototypes   map[int]&libjs.Object
}

// Test-only installation of the completed bodies with explicit dependencies;
// this does not expose unfinished builtin intrinsics to browser documents.
fn install_typed_prototype_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	object_parent := libjs.Object.create(realm, none)
	primitive_getter := fn (realm &libjs.Realm) &libjs.Object {
		return realm.data_view_prototype_record()
	}
	prototypes := libjs.PrimitiveObjectPrototypes{
		number: primitive_getter
		bigint: primitive_getter
		string: primitive_getter
	}
	mut array_parent := libjs.Object.create(realm, object_parent)
	// The untranslated Object intrinsic is an explicit host dependency.
	fallback := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_string(vm.create_string_from_str('host object tag'))
	}, 0, libjs.PropertyName.from_str('toString'), none)
	fallback_getter := fn [fallback] (realm &libjs.Realm) &libjs.Object {
		return fallback.object
	}
	shared_string := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [prototypes, fallback_getter] (mut vm libjs.VM) !libjs.Value {
		return libjs.array_prototype_to_string(mut vm, prototypes, fallback_getter)
	}, 0, libjs.PropertyName.from_str('toString'), none)
	array_parent.define_direct_property(libjs.PropertyName.from_str('toString'),
		libjs.Value.from_object(shared_string.object), 5)
	iterator_prototype := libjs.ArrayIteratorPrototype.create(mut vm, realm, object_parent,
		array_parent, object_parent)
	mut table := &BrowserTypedIntrinsicTable{}
	constructor_getter := fn [table] (realm &libjs.Realm, kind libjs.BufferElementType) &libjs.Object {
		return table.constructors[int(kind)] or { panic('test intrinsic not installed') }
	}
	prototype_getter := fn [table] (realm &libjs.Realm, kind libjs.BufferElementType) &libjs.Object {
		return table.prototypes[int(kind)] or { panic('test intrinsic not installed') }
	}
	parent := libjs.TypedArrayPrototype.create(mut vm, realm, object_parent, libjs.TypedArrayPrototypeDependencies{
		primitives:         prototypes
		constructor_getter: constructor_getter
		prototype_getter:   prototype_getter
		iterator_prototype: iterator_prototype.object
		array_prototype:    array_parent
	}).object
	abstract := libjs.TypedArrayConstructor.create(mut vm, realm, parent, prototypes)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('HostTypedArray'),
		libjs.Value.from_object(abstract.object), 7)
	for index, name in ['HostBytes', 'HostNumbers', 'HostBig'] {
		kind := [libjs.BufferElementType.uint8, .float64, .big_int64][index]
		mut concrete_parent := libjs.Object.create(realm, parent)
		table.prototypes[int(kind)] = concrete_parent
		constructor := libjs.NativeFunction.create_constructor(mut vm, realm, abstract.object, fn [kind] (mut vm libjs.VM) !libjs.Value {
			return libjs.call_typed_array_constructor(mut vm, kind)
		}, fn [kind, prototype_getter] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
			getter := fn [kind, prototype_getter] (realm &libjs.Realm) &libjs.Object {
				return prototype_getter(realm, kind)
			}
			return libjs.construct_typed_array(mut vm, kind, target, getter)!.object
		}, 3, libjs.PropertyName.from_str(name))
		mut object := constructor.object
		table.constructors[int(kind)] = object
		object.define_direct_property(libjs.PropertyName.from_str('prototype'),
			libjs.Value.from_object(concrete_parent), 0)
		concrete_parent.define_direct_property(libjs.PropertyName.from_str('constructor'),
			libjs.Value.from_object(object), 5)
		global.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(object), 7)
	}
}

fn test_browser_typed_array_fill_copy_within_join_and_copying_methods_execute_without_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	assert runtime.evaluate('var bytes=new HostBytes(4); bytes.fill(42,1,3)===bytes;')! == 'true'
	assert runtime.evaluate('bytes.join("|");')! == '0|42|42|0'
	assert runtime.evaluate('bytes.copyWithin(0,1,3)===bytes;')! == 'true'
	assert runtime.evaluate('bytes.join();')! == '42,42,42,0'
	assert runtime.evaluate('var reversed=bytes.toReversed(); reversed.join();')! == '0,42,42,42'
	assert runtime.evaluate('reversed!==bytes && reversed.buffer!==bytes.buffer;')! == 'true'
	assert runtime.evaluate('bytes.with(-1,17).join();')! == '42,42,42,17'
	assert runtime.evaluate('bytes.toSorted().join();')! == '0,42,42,42'
	assert runtime.evaluate('bytes.join();')! == '42,42,42,0'
	assert runtime.evaluate('var big=new HostBig(3); big[0]=9007199254740993n; big[1]=9007199254740992n; big[2]=-42n; big.toSorted().join("|");')! == '-42|9007199254740992|9007199254740993'
	assert runtime.evaluate('big.with(1,42n).toReversed().join();')! == '-42,42,9007199254740993'
	assert runtime.evaluate('big.fill(43n,-1).join();')! == '9007199254740993,9007199254740992,43'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_set_slice_subarray_filter_and_map_run_through_translated_bytecode() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	mut global := vm.get_global_object()
	for name in ['select', 'mapValue'] {
		callback := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm libjs.VM) !libjs.Value {
			assert vm.argument_count() == 3 && vm.argument(2).is_object()
			return if name == 'select' {
				libjs.Value.from_bool(vm.argument(1).number != 1)
			} else {
				libjs.Value.from_f64(vm.argument(0).number + vm.this_value().number)
			}
		}, 3, libjs.PropertyName.from_str(name), none)
		global.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(callback.object), 7)
	}
	assert runtime.evaluate('var bytes=new HostBytes(4); bytes.set("123",1); bytes.join();')! == '0,1,2,3'
	assert runtime.evaluate('var copied=bytes.slice(-3,-1); copied.join();')! == '1,2'
	assert runtime.evaluate('copied.buffer!==bytes.buffer;')! == 'true'
	assert runtime.evaluate('var view=bytes.subarray(1,3); view.buffer===bytes.buffer;')! == 'true'
	assert runtime.evaluate('view[0]=42; bytes.join();')! == '0,42,2,3'
	assert runtime.evaluate('bytes.filter(select.bind(null)).join();')! == '0,2,3'
	assert runtime.evaluate('bytes.map(mapValue,10).join();')! == '10,52,12,13'
	assert runtime.evaluate('bytes.set(bytes.subarray(0,3),1); bytes.join();')! == '0,0,42,2'
	assert runtime.evaluate('var big=new HostBig(2); big[0]=9007199254740993n; big[1]=-42n; big.slice().join();')! == '9007199254740993,-42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_static_from_of_shared_to_string_and_inherited_species() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	callback := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.argument_count() == 2 && vm.this_value().number == 10
		return libjs.Value.from_f64(vm.argument(0).to_number(mut vm)!.number + 10)
	}, 2, libjs.PropertyName.from_str('mapValue'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('mapValue'),
		libjs.Value.from_object(callback.object), 7)
	assert runtime.evaluate('HostBytes.from("123",mapValue,10).toString();')! == '11,12,13'
	assert runtime.evaluate('HostBytes.of(1,42,3).toString();')! == '1,42,3'
	assert runtime.evaluate('HostBig.of(9007199254740993n,-42n).toString();')! == '9007199254740993,-42'
	assert runtime.evaluate('HostBytes[Symbol.species]===HostBytes && HostNumbers[Symbol.species]===HostNumbers;')! == 'true'
	assert runtime.evaluate('HostBytes.prototype.toString===HostBig.prototype.toString;')! == 'true'
	assert runtime.evaluate('HostBytes.prototype.values===HostBytes.prototype[Symbol.iterator];')! == 'true'
	assert runtime.evaluate('var bytes=HostBytes.of(1,2,42); var iterator=bytes[Symbol.iterator](); iterator.next().value;')! == '1'
	assert runtime.evaluate('iterator.next().value;')! == '2'
	assert runtime.evaluate('HostBytes.from(bytes).toString();')! == '1,2,42'
	assert runtime.evaluate('HostBytes.bind(null).of(42).toString();')! == '42'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_abstract_typed_array_errors_preserve_later_script_execution() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	for source in ['HostTypedArray();', 'new HostTypedArray();', 'HostTypedArray.from("1");',
		'HostBytes.from("1",42);'] {
		if _ := runtime.evaluate(source) {
			assert false
		} else {
			assert err.msg().contains('Abstract class TypedArray')
				|| err.msg().contains('42 is not a function')
		}
		assert runtime.evaluate('HostBytes.of(42).at(0);')! == '42'
	}
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_species_and_tracking_views_retain_current_realm_dependencies() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(4,options); var bytes=new HostBytes(buffer); bytes.set("1234"); var tracking=bytes.subarray(1); var fixed=bytes.subarray(1,3); buffer.resize(6); tracking.length;')! == '5'
	assert runtime.evaluate('fixed.length;')! == '2'
	assert runtime.evaluate('var holder=new Boolean(false); holder[Symbol.species]=HostNumbers; bytes.constructor=holder; var copy=bytes.slice(0,3); copy[Symbol.toStringTag];')! == 'Float64Array'
	assert runtime.evaluate('copy.join();')! == '1,2,3'
	assert runtime.evaluate('copy.byteLength;')! == '24'
	assert runtime.evaluate('copy.buffer!==buffer;')! == 'true'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_to_locale_string_uses_explicit_host_locale_dependency_without_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	// Supply the pending Number/BigInt locale builtin as an observable host
	// callback; this fixture tests Invoke and forwarding, not Intl formatting.
	mut prototype := vm.realm().data_view_prototype_record()
	function := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.argument_count() == 2
		assert vm.argument(0).as_string().str() == 'host-locale' && vm.argument(1).number == 42
		return vm.this_value()
	}, 0, libjs.PropertyName.from_str('hostLocale'), none)
	prototype.define_direct_property(libjs.PropertyName.from_str('toLocaleString'),
		libjs.Value.from_object(function.object), 7)
	assert runtime.evaluate('var bytes=new HostBytes(3); bytes.set("123"); bytes.toLocaleString("host-locale",42);')! == '1,2,3'
	assert runtime.evaluate('var big=new HostBig(2); big[0]=9007199254740993n; big[1]=-42n; big.toLocaleString("host-locale",42);')! == '9007199254740993,-42'
	assert runtime.evaluate('new HostBytes(0).toLocaleString();')! == ''
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_join_and_fill_callbacks_keep_upstream_resize_coercion_order() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	separator := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		buffer_value := vm.get_global_object().get(mut vm, libjs.PropertyName.from_str('buffer'))!
		mut buffer := buffer_value.as_object().array_buffer or { panic('missing buffer') }
		assert buffer.try_resize(0, true)
		return libjs.Value.from_string(vm.create_string_from_str('|'))
	}, 0, libjs.PropertyName.from_str('toString'), none)
	mut separator_object := libjs.Object.create(vm.realm(), none)
	separator_object.define_direct_property(libjs.PropertyName.from_str('toString'),
		libjs.Value.from_object(separator.object), 7)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('separator'),
		libjs.Value.from_object(separator_object), 7)
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(3,options); var bytes=new HostBytes(buffer); bytes.fill(42); bytes.join(separator);')! == '||'
	assert runtime.evaluate('bytes.length;')! == '0'
	assert runtime.evaluate('buffer.resize(3); bytes.fill(17).copyWithin(1,0).join();')! == '17,17,17'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_typed_array_copying_errors_recover_and_to_sorted_uses_bound_native_comparison() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_prototype_test_host(mut runtime)
	mut vm := runtime.libjs_vm()
	compare := libjs.NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.this_value().is_null() && vm.argument_count() == 2
		return libjs.Value.from_f64(vm.argument(1).number - vm.argument(0).number)
	}, 2, libjs.PropertyName.from_str('compare'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('compare'),
		libjs.Value.from_object(compare.object), 7)
	assert runtime.evaluate('var bytes=new HostBytes(3); bytes[0]=3; bytes[1]=1; bytes[2]=2; bytes.toSorted(compare.bind(null)).join();')! == '3,2,1'
	assert runtime.evaluate('bytes.join();')! == '3,1,2'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'bytes.with(99,42);', url: 'typed-with-range.js' },
		ScriptSource{ code: 'bytes.toSorted(17);', url: 'typed-to-sorted-compare.js' },
		ScriptSource{ code: 'var big=new HostBig(1); big.fill(42);', url: 'typed-fill-content.js' },
		ScriptSource{ code: 'bytes.join(Symbol());', url: 'typed-join-symbol.js' },
		ScriptSource{ code: 'var answer=bytes.toReversed().at(-1);', url: 'typed-copy-after.js' },
	])
	assert errors.len == 4
	assert errors[0].contains('RangeError:') && errors[0].contains('typed-with-range.js')
	assert errors[1].contains('17 is not a function')
	assert errors[2].contains('TypeError:') && errors[3].contains('TypeError:')
	assert runtime.evaluate('answer;')! == '3'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
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

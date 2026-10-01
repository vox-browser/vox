module browserjs

import libjs

// Exercise the translated constructor behaviors with host-supplied prototypes.
// The TypedArray intrinsic graph and Uint8Array encoding methods remain pending.
fn install_typed_array_test_constructor(mut runtime Runtime, name string, kind libjs.BufferElementType) &libjs.Object {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	parent := libjs.Object.create(realm, none)
	function := libjs.NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn [kind] (mut vm libjs.VM) !libjs.Value {
		return libjs.call_typed_array_constructor(mut vm, kind)
	}, fn [kind, parent] (mut vm libjs.VM, target &libjs.Object) !&libjs.Object {
		getter := fn [parent] (realm &libjs.Realm) &libjs.Object {
			return parent
		}
		array := libjs.construct_typed_array(mut vm, kind, target, getter)!
		return array.object
	}, 3, libjs.PropertyName.from_str(kind.typed_array_name()))
	mut object := function.object
	object.define_direct_property(libjs.PropertyName.from_str('prototype'),
		libjs.Value.from_object(parent), 0)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str(name),
		libjs.Value.from_object(object), 7)
	return object
}

fn test_browser_libjs_typed_array_construction_lengths_array_like_copies_and_bound_new() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_array_test_constructor(mut runtime, 'HostBytes', .uint8)
	install_typed_array_test_constructor(mut runtime, 'HostWords', .uint16)
	assert runtime.evaluate('var bytes=new HostBytes(3); ArrayBuffer.isView(bytes);')! == 'true'
	assert runtime.evaluate('bytes[0]=257; bytes[1]=43; bytes[0];')! == '1'
	assert runtime.evaluate('var copy=new HostWords(bytes); copy[1];')! == '43'
	assert runtime.evaluate('copy instanceof HostWords;')! == 'true'
	assert runtime.evaluate('copy[0]=42; bytes[0];')! == '1'
	assert runtime.evaluate('var source=new Boolean(false); source.length=3; source[0]=258; source[2]=42; var fromLike=new HostBytes(source); fromLike[0];')! == '2'
	assert runtime.evaluate('fromLike[1];')! == '0'
	assert runtime.evaluate('fromLike[2];')! == '42'
	assert runtime.evaluate('var Bound=HostWords.bind(null,bytes); var bound=new Bound(); bound[1];')! == '43'
	assert runtime.evaluate('bound instanceof HostWords;')! == 'true'
	mut vm := runtime.libjs_vm()
	global := vm.get_global_object()
	bytes := global.get(mut vm, libjs.PropertyName.from_str('bytes'))!.as_object().typed_array?
	copy := global.get(mut vm, libjs.PropertyName.from_str('copy'))!.as_object().typed_array?
	assert bytes.array_length.length() == 3 && copy.array_length.length() == 3
	assert copy.viewed_buffer.read_bytes(0, 6) == [u8(42), 0, 43, 0, 0, 0]
	assert !copy.viewed_buffer.shares_storage_with(bytes.viewed_buffer)
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_typed_array_construction_buffer_views_copy_snapshot_lengths_and_shared_bigint() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_array_test_constructor(mut runtime, 'HostWords', .uint16)
	install_typed_array_test_constructor(mut runtime, 'HostBig', .big_int64)
	install_typed_array_test_constructor(mut runtime, 'HostUnsignedBig', .big_uint64)
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=16; var buffer=new ArrayBuffer(7,options); var words=new HostWords(buffer,2); words[0]=42; new DataView(buffer).getUint16(2,true);')! == '42'
	assert runtime.evaluate('var copy=new HostWords(words); buffer.resize(12); words[4]=17; copy[2];')! == 'undefined'
	assert runtime.evaluate('copy[0];')! == '42'
	assert runtime.evaluate('var shared=new SharedArrayBuffer(16); var big=new HostBig(shared); big[0]=-1n; big[1]=42n; var unsigned=new HostUnsignedBig(big); unsigned[0];')! == '18446744073709551615'
	assert runtime.evaluate('unsigned[1];')! == '42'
	assert runtime.evaluate('new DataView(shared).getBigInt64(0,true);')! == '-1'
	assert runtime.evaluate('unsigned[0]=7n; big[0];')! == '-1'
	mut vm := runtime.libjs_vm()
	global := vm.get_global_object()
	copy := global.get(mut vm, libjs.PropertyName.from_str('copy'))!.as_object().typed_array?
	unsigned := global.get(mut vm, libjs.PropertyName.from_str('unsigned'))!.as_object().typed_array?
	assert copy.array_length.length() == 2 && copy.viewed_buffer.is_fixed_length()
	assert !unsigned.viewed_buffer.is_shared_array_buffer()
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_typed_array_construction_errors_preserve_later_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_typed_array_test_constructor(mut runtime, 'HostWords', .uint16)
	install_typed_array_test_constructor(mut runtime, 'HostBig', .big_int64)
	assert runtime.evaluate('var buffer=new ArrayBuffer(4); var words=new HostWords(buffer); words[0]=42;')! == '42'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'HostWords(2);', url: 'typed-call.js' },
		ScriptSource{ code: 'new HostWords(-1);', url: 'typed-length.js' },
		ScriptSource{ code: 'new HostWords(buffer,1);', url: 'typed-offset.js' },
		ScriptSource{ code: 'new HostBig(words);', url: 'typed-content.js' },
		ScriptSource{ code: 'buffer.transfer(); new HostWords(words);', url: 'typed-detached.js' },
		ScriptSource{
			code: 'var source=new Boolean(false); source.length=1; source[0]=42; var answer=new HostWords(source)[0];'
			url:  'typed-after.js'
		},
	])
	assert errors.len == 5
	for index, name in ['typed-call.js', 'typed-length.js', 'typed-offset.js', 'typed-content.js',
		'typed-detached.js'] {
		assert errors[index].contains(if index in [1, 2] { 'RangeError:' } else { 'TypeError:' })
		assert errors[index].contains(name + ':1:')
	}
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

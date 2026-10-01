module browserjs

import libjs

// TypedArray constructors/prototypes remain pending. These tests install real
// host-created records and exercise the existing browser's compiled VM path.
fn install_test_typed_array(mut runtime Runtime, name string, buffer_name string, kind libjs.BufferElementType, byte_offset int, length libjs.Value) !&libjs.TypedArray {
	mut vm := runtime.libjs_vm()
	mut global := vm.get_global_object()
	buffer := global.get(mut vm, libjs.PropertyName.from_str(buffer_name))!.as_object().array_buffer or {
		panic('missing test buffer')
	}
	parent := libjs.Object.create(vm.realm(), none)
	mut array := libjs.TypedArray.create(vm.realm(), kind, 0, buffer, parent)
	libjs.initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
		libjs.Value.from_i32(byte_offset), length)!
	global.define_direct_property(libjs.PropertyName.from_str(name),
		libjs.Value.from_object(array.object), 7)
	return array
}

fn test_browser_libjs_typed_array_indices_share_data_views_and_follow_resizable_buffers() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=16; var buffer=new ArrayBuffer(8,options); var view=new DataView(buffer); buffer.byteLength;')! == '8'
	array := install_test_typed_array(mut runtime, 'array', 'buffer', .uint16, 2,
		libjs.js_undefined())!
	fixed := install_test_typed_array(mut runtime, 'fixed', 'buffer', .uint16, 2,
		libjs.Value.from_i32(2))!
	assert runtime.evaluate('ArrayBuffer.isView(array);')! == 'true'
	assert runtime.evaluate('array[0]=42; view.getUint16(2,true);')! == '42'
	assert runtime.evaluate('view.setUint16(4,17,true); array[1];')! == '17'
	assert runtime.evaluate('delete array[0];')! == 'false'
	assert runtime.evaluate('array["-0"]=9; "-0" in array;')! == 'false'
	assert runtime.evaluate('array["01"]=7; array["01"];')! == '7'
	assert runtime.evaluate('buffer.resize(3); array[0];')! == 'undefined'
	assert runtime.evaluate('0 in fixed;')! == 'false'
	assert runtime.evaluate('fixed[0]=99; fixed[0];')! == 'undefined'
	assert runtime.evaluate('buffer.resize(12); array[4]=42; view.getUint16(10,true);')! == '42'
	assert runtime.evaluate('4 in array;')! == 'true'
	assert runtime.evaluate('2 in fixed;')! == 'false'
	mut vm := runtime.libjs_vm()
	assert libjs.typed_array_length(libjs.make_typed_array_with_buffer_witness_record(array,
		.seq_cst)) == 5
	assert libjs.typed_array_length(libjs.make_typed_array_with_buffer_witness_record(fixed,
		.seq_cst)) == 2
	assert runtime.evaluate('buffer.transfer(); ArrayBuffer.isView(array);')! == 'true'
	assert runtime.evaluate('array[0];')! == 'undefined'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_typed_array_bigint_errors_do_not_stop_later_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var buffer=new SharedArrayBuffer(16); buffer.byteLength;')! == '16'
	install_test_typed_array(mut runtime, 'array', 'buffer', .big_int64, 0, libjs.js_undefined())!
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'array[0]=42;', url: 'typed-number.js' },
		ScriptSource{ code: 'array["-0"]=42;', url: 'typed-invalid-number.js' },
		ScriptSource{ code: '"use strict"; delete array[0];', url: 'typed-delete.js' },
		ScriptSource{
			code: 'array[0]=-1n; array[1]=42n; var answer=array[1];'
			url:  'typed-after.js'
		},
	])
	assert errors.len == 3
	for index, filename in ['typed-number.js', 'typed-invalid-number.js', 'typed-delete.js'] {
		assert errors[index].contains('TypeError:') && errors[index].contains(filename + ':1:')
	}
	assert runtime.evaluate('array[0];')! == '-1'
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.evaluate('new DataView(buffer).getBigInt64(0,true);')! == '-1'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_typed_array_iterator_uses_live_witnesses_and_resumes_after_bounds_errors() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new ArrayBuffer(2,options); buffer.byteLength;')! == '2'
	array := install_test_typed_array(mut runtime, 'array', 'buffer', .uint8, 1,
		libjs.js_undefined())!
	mut vm := runtime.libjs_vm()
	parent := libjs.Object.create(vm.realm(), none)
	prototype := libjs.ArrayIteratorPrototype.create(mut vm, vm.realm(), parent, parent, parent)
	iterator := libjs.ArrayIterator.create(vm.realm(), libjs.Value.from_object(array.object),
		.value, prototype.object)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('iterator'),
		libjs.Value.from_object(iterator.object), 7)
	assert runtime.evaluate('array[0]=17; iterator.next().value;')! == '17'
	assert runtime.evaluate('buffer.resize(0); buffer.byteLength;')! == '0'
	if _ := runtime.evaluate('iterator.next();') {
		assert false
	} else {
		assert err.msg().contains('TypeError:')
	}
	assert iterator.index == 1 && !iterator.array.is_undefined()
	assert runtime.evaluate('buffer.resize(4); array[1]=42; iterator.next().value;')! == '42'
	assert runtime.evaluate('iterator.next().value;')! == '0'
	assert runtime.evaluate('iterator.next().done;')! == 'true'
	assert runtime.evaluate('buffer.transfer(); iterator.next().done;')! == 'true'
	assert iterator.array.is_undefined() && iterator.index == 3
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

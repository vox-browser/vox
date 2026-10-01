module browserjs

import libjs

fn test_browser_libjs_shared_array_buffers_grow_and_slice_through_translated_data_views() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=16; var buffer=new SharedArrayBuffer(5,options); var view=new DataView(buffer); view.setUint8(0,42); buffer.byteLength;')! == '5'
	assert runtime.evaluate('buffer.growable;')! == 'true'
	assert runtime.evaluate('buffer.maxByteLength;')! == '16'
	assert runtime.evaluate('SharedArrayBuffer.prototype.constructor===SharedArrayBuffer;')! == 'true'
	assert runtime.evaluate('SharedArrayBuffer[Symbol.species]===SharedArrayBuffer;')! == 'true'
	assert runtime.evaluate('buffer instanceof SharedArrayBuffer;')! == 'true'
	assert runtime.evaluate('buffer instanceof ArrayBuffer;')! == 'false'
	assert runtime.evaluate('ArrayBuffer.isView(view);')! == 'true'
	assert runtime.evaluate('for (let i=5;i<=10;i++) buffer.grow(i); view.byteLength;')! == '10'
	assert runtime.evaluate('view.getUint8(0);')! == '42'
	assert runtime.evaluate('view.getUint8(9);')! == '0'
	assert runtime.evaluate('view.setBigUint64(2,42n,true); view.getBigUint64(2,true);')! == '42'
	assert runtime.evaluate('var copied=buffer.slice(2); var copyView=new DataView(copied); copyView.getBigUint64(0,true);')! == '42'
	assert runtime.evaluate('copied.byteLength;')! == '8'
	assert runtime.evaluate('copied.growable;')! == 'false'
	assert runtime.evaluate('copied.maxByteLength;')! == '8'
	assert runtime.evaluate('copyView.setUint8(0,99); view.getUint8(2);')! == '42'
	assert runtime.evaluate('var BoundBuffer=SharedArrayBuffer.bind(null,3); var bound=new BoundBuffer(); bound.byteLength;')! == '3'
	mut vm := runtime.libjs_vm()
	buffer := vm.get_global_object().get(mut vm, libjs.PropertyName.from_str('buffer'))!.as_object().array_buffer?
	copied := vm.get_global_object().get(mut vm, libjs.PropertyName.from_str('copied'))!.as_object().array_buffer?
	assert buffer.is_shared_array_buffer() && copied.is_shared_array_buffer()
	assert !buffer.shares_storage_with(copied)
	assert buffer.read_bytes(0, 10) == [u8(42), 0, 42, 0, 0, 0, 0, 0, 0, 0]
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_shared_array_buffer_errors_preserve_later_document_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new SharedArrayBuffer(4,options); var fixed=new SharedArrayBuffer(4); buffer.byteLength;')! == '4'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'SharedArrayBuffer(4);', url: 'shared-call.js' },
		ScriptSource{ code: 'new SharedArrayBuffer(2**53);', url: 'shared-length.js' },
		ScriptSource{ code: 'fixed.grow(5);', url: 'shared-fixed.js' },
		ScriptSource{ code: 'buffer.grow(3);', url: 'shared-shrink.js' },
		ScriptSource{ code: 'buffer.grow(9);', url: 'shared-maximum.js' },
		ScriptSource{
			code: 'ArrayBuffer.prototype.transfer.call(buffer);'
			url:  'shared-transfer.js'
		},
		ScriptSource{
			code: 'SharedArrayBuffer.prototype.slice.call(new ArrayBuffer(4));'
			url:  'shared-brand.js'
		},
		ScriptSource{
			code: 'buffer.grow(8); var view=new DataView(buffer); view.setUint8(0,42); var answer=view.getUint8(0);'
			url:  'shared-after.js'
		},
	])
	assert errors.len == 7
	for index, file in ['shared-call.js', 'shared-length.js', 'shared-fixed.js', 'shared-shrink.js',
		'shared-maximum.js', 'shared-transfer.js', 'shared-brand.js'] {
		assert errors[index].contains(if index in [1, 3, 4] { 'RangeError:' } else { 'TypeError:' })
		assert errors[index].contains(file + ':1:')
	}
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_shared_array_buffer_empty_and_fixed_views_keep_their_length_after_growth() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var empty=new SharedArrayBuffer(); empty.byteLength;')! == '0'
	assert runtime.evaluate('empty.growable;')! == 'false'
	assert runtime.evaluate('new DataView(empty).byteLength;')! == '0'
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=8; var buffer=new SharedArrayBuffer(4,options); var tracking=new DataView(buffer,4); var fixed=new DataView(buffer,4,0); buffer.grow(8); tracking.byteLength;')! == '4'
	assert runtime.evaluate('fixed.byteLength;')! == '0'
	assert runtime.evaluate('tracking.getUint32(0);')! == '0'
	if _ := runtime.evaluate('fixed.getUint8(0);') {
		assert false
	} else {
		assert err.msg().contains('RangeError:')
	}
	assert runtime.evaluate('fixed.buffer===buffer;')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

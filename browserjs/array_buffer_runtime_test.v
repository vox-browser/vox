module browserjs

import libjs

fn test_browser_libjs_array_buffer_construction_resize_slice_and_transfer_execute_in_translated_vm() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut vm := runtime.libjs_vm()
	mut options := libjs.Object.create(vm.realm(), none)
	options.define_direct_property(libjs.PropertyName.from_str('maxByteLength'),
		libjs.Value.from_i32(8), 7)
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('options'),
		libjs.Value.from_object(options))!
	assert runtime.evaluate('var buffer=new ArrayBuffer(4,options); buffer.byteLength;')! == '4'
	assert runtime.evaluate('buffer.resizable;')! == 'true'
	assert runtime.evaluate('buffer.maxByteLength;')! == '8'
	buffer := global.get(mut vm, libjs.PropertyName.from_str('buffer'))!.as_object().array_buffer?
	mut writable := buffer
	writable.overwrite(0, [u8(1), 2, 3, 4])
	assert runtime.evaluate('buffer.resize(2); buffer.resize(6); buffer.byteLength;')! == '6'
	assert buffer.read_bytes(0, 6) == [u8(1), 2, 0, 0, 0, 0]
	assert runtime.evaluate('var slice=buffer.slice(1,4); slice.byteLength;')! == '3'
	assert runtime.evaluate('slice.resizable;')! == 'false'
	slice := global.get(mut vm, libjs.PropertyName.from_str('slice'))!.as_object().array_buffer?
	assert slice.read_bytes(0, 3) == [u8(2), 0, 0]
	assert runtime.evaluate('var transferred=buffer.transfer(7); buffer.detached;')! == 'true'
	assert runtime.evaluate('transferred.byteLength;')! == '7'
	assert runtime.evaluate('transferred.maxByteLength;')! == '8'
	assert runtime.evaluate('var fixed=transferred.transferToFixedLength(9); fixed.resizable;')! == 'false'
	assert runtime.evaluate('fixed.byteLength;')! == '9'
	assert runtime.evaluate('transferred.detached;')! == 'true'
	fixed := global.get(mut vm, libjs.PropertyName.from_str('fixed'))!.as_object().array_buffer?
	assert fixed.read_bytes(0, 9) == [u8(1), 2, 0, 0, 0, 0, 0, 0, 0]
	assert runtime.evaluate('ArrayBuffer.isView(fixed);')! == 'false'
	view := libjs.DataView.create(vm.realm(), fixed, libjs.ByteLength.from_u32(2), 1,
		vm.realm().array_buffer_prototype_record())
	assert global.create_data_property(mut vm, libjs.PropertyName.from_str('view'),
		libjs.Value.from_object(view.object))!
	assert runtime.evaluate('ArrayBuffer.isView(view);')! == 'true'
	assert runtime.evaluate('ArrayBuffer[Symbol.species]===ArrayBuffer;')! == 'true'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_array_buffer_errors_keep_later_document_scripts_running() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var buffer=new ArrayBuffer(4); var moved=buffer.transfer();')! == 'undefined'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'ArrayBuffer(4);', url: 'buffer-call.js' },
		ScriptSource{ code: 'new ArrayBuffer(-1);', url: 'buffer-length.js' },
		ScriptSource{ code: 'moved.resize(1);', url: 'buffer-fixed.js' },
		ScriptSource{ code: 'buffer.slice();', url: 'buffer-detached.js' },
		ScriptSource{ code: 'ArrayBuffer.prototype.transfer.call(null);', url: 'buffer-brand.js' },
		ScriptSource{ code: 'var answer=moved.slice().byteLength+38;', url: 'buffer-after.js' },
	])
	assert errors.len == 5
	for index, file in ['buffer-call.js', 'buffer-length.js', 'buffer-fixed.js', 'buffer-detached.js',
		'buffer-brand.js'] {
		assert errors[index].contains(if index == 1 { 'RangeError:' } else { 'TypeError:' })
		assert errors[index].contains(file + ':1:')
	}
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

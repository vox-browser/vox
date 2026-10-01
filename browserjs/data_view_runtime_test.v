module browserjs

import libjs

fn test_browser_libjs_data_view_numeric_methods_execute_in_translated_vm() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var buffer=new ArrayBuffer(16); var view=new DataView(buffer,2,12); view.byteOffset;')! == '2'
	assert runtime.evaluate('view.byteLength;')! == '12'
	assert runtime.evaluate('view.buffer===buffer;')! == 'true'
	assert runtime.evaluate('ArrayBuffer.isView(view);')! == 'true'
	assert runtime.evaluate('ArrayBuffer.isView(DataView.prototype);')! == 'false'
	assert runtime.evaluate('DataView.prototype.constructor===DataView;')! == 'true'
	assert runtime.evaluate('DataView.length;')! == '1'
	for name in ['BigInt64', 'BigUint64', 'Float16', 'Float32', 'Float64', 'Int8', 'Int16', 'Int32',
		'Uint8', 'Uint16', 'Uint32'] {
		value := if name.starts_with('Big') { '42n' } else { '42' }
		for endian in ['false', 'true'] {
			assert runtime.evaluate('view.set${name}(1,${value},${endian});')! == 'undefined'
			assert runtime.evaluate('view.get${name}(1,${endian});')! == '42'
			assert runtime.evaluate('typeof view.get${name}(1,${endian});')! == if name.starts_with('Big') {
				'bigint'
			} else {
				'number'
			}
		}
		assert runtime.evaluate('view.get${name}.name;')! == 'get' + name
		assert runtime.evaluate('view.get${name}.length;')! == '1'
		assert runtime.evaluate('view.set${name}.length;')! == '2'
	}
	mut vm := runtime.libjs_vm()
	buffer := vm.get_global_object().get(mut vm, libjs.PropertyName.from_str('buffer'))!.as_object().array_buffer?
	assert runtime.evaluate('view.setUint16(1,4660); view.getUint16(1,true);')! == '13330'
	assert buffer.read_bytes(3, 2) == [u8(18), 52]
	assert runtime.evaluate('view.setUint16(1,4660,true); view.getUint16(1);')! == '13330'
	assert buffer.read_bytes(3, 2) == [u8(52), 18]
	assert runtime.evaluate('view.setBigInt64(0,-18446744073709551617n); view.getBigInt64(0);')! == '-1'
	assert runtime.evaluate('view.getBigUint64(0);')! == '18446744073709551615'
	assert runtime.evaluate('view.setFloat16(0,1.0004882812500002); view.getUint16(0);')! == '15361'
	assert runtime.evaluate('view.getFloat16(0);')! == '1.0009765625'
	assert runtime.evaluate('view.setFloat32(0,-0); 1/view.getFloat32(0);')! == '-Infinity'
	assert runtime.evaluate('view.setFloat64(0,NaN,true); isNaN(view.getFloat64(0,true));')! == 'true'
	assert runtime.evaluate('var BoundView=DataView.bind(null,buffer,2,4); var bound=new BoundView(); bound.byteLength;')! == '4'
	assert runtime.context == unsafe { nil }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_data_view_tracks_resize_regrowth_and_detach() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var options=new Boolean(false); options.maxByteLength=16; var buffer=new ArrayBuffer(8,options); var tracking=new DataView(buffer,2); var fixed=new DataView(buffer,2,4); tracking.byteLength;')! == '6'
	assert runtime.evaluate('tracking.setUint8(0,42); buffer.resize(4); tracking.byteLength;')! == '2'
	for code in ['fixed.byteLength;', 'fixed.byteOffset;', 'fixed.getUint8(0);'] {
		if _ := runtime.evaluate(code) {
			assert false
		} else {
			assert err.msg().contains('TypeError:')
		}
	}
	assert runtime.evaluate('fixed.buffer===buffer;')! == 'true'
	assert runtime.evaluate('tracking.getUint8(0);')! == '42'
	assert runtime.evaluate('buffer.resize(8); fixed.byteLength;')! == '4'
	assert runtime.evaluate('fixed.getUint8(2);')! == '0'
	assert runtime.evaluate('tracking.byteLength;')! == '6'
	assert runtime.evaluate('var transferred=buffer.transfer(); tracking.buffer===buffer;')! == 'true'
	assert runtime.evaluate('buffer.detached;')! == 'true'
	if _ := runtime.evaluate('tracking.byteLength;') {
		assert false
	} else {
		assert err.msg().contains('TypeError:')
	}
	assert runtime.evaluate('var replacement=new DataView(transferred,2); replacement.getUint8(0);')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_libjs_data_view_errors_leave_later_document_scripts_running() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('var buffer=new ArrayBuffer(8); var view=new DataView(buffer); view.setUint8(0,42);')! == 'undefined'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'DataView(buffer);', url: 'view-call.js' },
		ScriptSource{ code: 'new DataView(8);', url: 'view-buffer.js' },
		ScriptSource{ code: 'new DataView(buffer,-1);', url: 'view-offset.js' },
		ScriptSource{ code: 'view.getFloat64(1);', url: 'view-range.js' },
		ScriptSource{ code: 'DataView.prototype.getUint8.call(null,-1);', url: 'view-brand.js' },
		ScriptSource{ code: 'view.setBigInt64(0,42);', url: 'view-bigint.js' },
		ScriptSource{ code: 'view.setUint32(0,42n);', url: 'view-number.js' },
		ScriptSource{ code: 'var answer=view.getUint8(0);', url: 'view-after.js' },
	])
	assert errors.len == 7
	for index, file in ['view-call.js', 'view-buffer.js', 'view-offset.js', 'view-range.js',
		'view-brand.js', 'view-bigint.js', 'view-number.js'] {
		assert errors[index].contains(if index in [2, 3] { 'RangeError:' } else { 'TypeError:' })
		assert errors[index].contains(file + ':1:')
	}
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

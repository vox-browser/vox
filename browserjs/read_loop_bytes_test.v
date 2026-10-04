module browserjs

import dom
import webidl

fn native_read_loop_document() &dom.Document {
	url := dom.URL{'https://native-read-loop.example.test/'}
	return &dom.Document{ url: url, origin_: url.origin() }
}

fn native_read_loop_result(mut runtime Runtime) !&webidl.Promise {
	actual := runtime.evaluate_host_value('stream')!
	mut native := runtime.native_readable_stream(actual)!
	mut reader := native.get_default_reader()!
	return reader.read_all_bytes_deprecated()
}

fn test_native_read_loop_uses_actual_uint8_slots_and_captured_intrinsics() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_read_loop_document())!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.stream=new ReadableStream({start(c){globalThis.controller=c}},{highWaterMark:0});globalThis.bytes=new Uint8Array([9,1,2,9]).subarray(1,3);for(const p of ["buffer","byteOffset","byteLength"]){Object.defineProperty(bytes,p,{get(){throw new Error("author slot getter")}})}globalThis.Uint8Array=function(){throw new Error("author constructor")};Object.defineProperty(Object.getPrototypeOf(Int8Array.prototype),"byteLength",{get(){throw new Error("author prototype getter")}});undefined')!
	result := native_read_loop_result(mut runtime)!
	assert result.state == .pending
	runtime.evaluate_host('controller.enqueue(bytes);controller.close()')!
	assert result.state == .fulfilled
	assert webidl.get_buffer_source_copy(result.result.buffer_value?) == [u8(1), 2]
}

fn test_native_read_loop_rejects_spoofs_clamped_arrays_and_proxies_with_actual_typeerror() {
	$if !darwin {
		return
	}
	for expression in ['new Uint8ClampedArray([1])', 'new Uint16Array([1])',
		'({[Symbol.toStringTag]:"Uint8Array",buffer:new ArrayBuffer(1),byteLength:1})',
		'new Proxy(new Uint8Array([1]),{get(){throw new Error("author trap")}})'] {
		mut runtime := Runtime.create()
		defer { runtime.close() }
		mut host := ReadableStreamHost.create(native_read_loop_document())!
		host.install(mut runtime)!
		runtime.evaluate_host('globalThis.stream=new ReadableStream({start(c){globalThis.controller=c}},{highWaterMark:0})')!
		result := native_read_loop_result(mut runtime)!
		runtime.evaluate_host('controller.enqueue(${expression})')!
		assert result.state == .rejected
		assert result.result.simple_exception_?.type_ == .type_error
		assert result.result.simple_exception_?.message == 'Chunk data is not Uint8Array'
	}
}

fn test_native_read_loop_typed_array_witness_preserves_detached_and_oob_zero_length() {
	$if !darwin {
		return
	}
	for detach in [false, true] {
		mut runtime := Runtime.create()
		defer { runtime.close() }
		mut host := ReadableStreamHost.create(native_read_loop_document())!
		host.install(mut runtime)!
		runtime.evaluate_host('globalThis.stream=new ReadableStream({start(c){globalThis.controller=c}},{highWaterMark:0});globalThis.buffer=new ArrayBuffer(4,{maxByteLength:8});globalThis.bytes=new Uint8Array(buffer,1,2)')!
		if detach {
			runtime.evaluate_host('buffer.transfer()')!
		} else {
			runtime.evaluate_host('buffer.resize(1)')!
		}
		result := native_read_loop_result(mut runtime)!
		runtime.evaluate_host('controller.enqueue(bytes);controller.close()')!
		assert result.state == .fulfilled
		assert webidl.get_buffer_source_copy(result.result.buffer_value?).len == 0
	}
}

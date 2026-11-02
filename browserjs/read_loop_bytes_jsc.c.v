// Copyright (c) 2023, Matthew Olsson <mattco@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Source ReadLoopReadRequest checks the genuine Uint8Array class and reads its
// typed-array witness, buffer/offset and length slots, without author getters.
module browserjs

import streams
import webidl


fn C.vox_jsc_JSValueGetTypedArrayType(context voidptr, value voidptr, exception &voidptr) int

fn (host &ReadableStreamHost) read_loop_realm() streams.StreamRealm {
	owner := voidptr(host)
	return streams.StreamRealm{
		...host.settings.stream_realm()
		uint8_array_bytes:   fn [owner] (value webidl.Value) !streams.ReadLoopChunkBytes {
			host := unsafe { &ReadableStreamHost(owner) }
			return host.read_loop_bytes(value)
		}
		array_buffer_create: fn [owner] (bytes []u8) !webidl.Value {
			host := unsafe { &ReadableStreamHost(owner) }
			mut runtime := unsafe { &Runtime(host.runtime) }
			return runtime.source_array_buffer(bytes)
		}
		array_buffer_copy:   fn [owner] (value webidl.Value) ![]u8 {
			host := unsafe { &ReadableStreamHost(owner) }
			mut runtime := unsafe { &Runtime(host.runtime) }
			return runtime.source_array_buffer_bytes(value)
		}
		uint8_array_create:  fn [owner] (buffer webidl.Value) !webidl.Value {
			host := unsafe { &ReadableStreamHost(owner) }
			mut runtime := unsafe { &Runtime(host.runtime) }
			return runtime.source_uint8_array(buffer)
		}
	}
}

fn (host &ReadableStreamHost) read_loop_bytes(value webidl.Value) !streams.ReadLoopChunkBytes {
	if host.closed { return error('ReadableStream binding is closed') }
	actual := value.runtime_value_ or { return streams.ReadLoopChunkBytes{} }
	if actual.context != host.runtime.context {
		return error('Read-loop chunk belongs to another engine context')
	}
	mut exception := unsafe { nil }
	type_ := C.vox_jsc_JSValueGetTypedArrayType(actual.context, actual.value, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if type_ != C.kJSTypedArrayTypeUint8Array { return streams.ReadLoopChunkBytes{} }
	mut runtime := unsafe { &Runtime(host.runtime) }
	working_copy := runtime.call_javascript_function(host.read_loop_byte_copy, C.vox_jsc_JSValueMakeUndefined(runtime.context), [actual.value])!
	runtime.retain_javascript_value(working_copy)!
	defer { runtime.release_javascript_value(working_copy) }
	length := C.vox_jsc_JSObjectGetTypedArrayByteLength(runtime.context, working_copy, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if length > uint(2147483647) {
		return error('InternalError: read-loop bytes exceed the source V span')
	}
	mut bytes := []u8{len: int(length)}
	if length > 0 {
		pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, working_copy, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		unsafe { C.memcpy(bytes.data, pointer, length) }
	}
	return streams.ReadLoopChunkBytes{ bytes: bytes }
}

const read_loop_byte_copy_intrinsic = r'(function(){
 const apply=Reflect.apply,U8=Uint8Array,prototype=Object.getPrototypeOf(Int8Array.prototype),get=Object.getOwnPropertyDescriptor,buffer=get(prototype,"buffer").get,offset=get(prototype,"byteOffset").get,length=get(prototype,"byteLength").get,values=Int8Array.prototype.values;
 return function(value){try{apply(values,value,[])}catch(error){return new U8(0)}const backing=apply(buffer,value,[]),start=apply(offset,value,[]),size=apply(length,value,[]);return new U8(new U8(backing,start,size))}
})()'

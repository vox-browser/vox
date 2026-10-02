module browserjs

import html
import webidl

fn test_actual_engine_source_array_buffer_clone_bytes_aliases_and_ipc_storage_goldens() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__sourceArrayBuffer=ArrayBuffer;const buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([1,170,255]);buffer.custom=99;buffer.valueOf=()=>{throw new Error("author conversion")};globalThis.ArrayBuffer=class FakeArrayBuffer {};({buffer,again:buffer})')!
	for for_storage in [false, true] {
		cloned := bridge.deserialize(bridge.serialize(value, for_storage)!)!
		binding := '__nativeBufferClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + binding + r'();result.buffer===result.again&&result.buffer instanceof __sourceArrayBuffer&&!result.buffer.resizable&&result.buffer.byteLength===3&&Array.from(new Uint8Array(result.buffer)).join(",")==="1,170,255"&&!Object.hasOwn(result.buffer,"custom")}')! == 'true'
	}
	buffer := runtime.evaluate_host_value(r'new __sourceArrayBuffer(3)')!
	assert bridge.serialize(buffer, false)!.data == [u8(22), 3, 0, 0, 0, 0, 0, 0]
	assert bridge.serialize(buffer, true)!.data == [u8(76), 66, 83, 67, 1, 0, 22, 3, 0, 0, 0]
	cloned := bridge.clone(buffer)!
	runtime.define_value_host_function('__separateBufferClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	runtime.define_value_host_function('__originalBuffer', fn [buffer] (_ voidptr, _ []voidptr) !voidptr { return buffer })!
	assert runtime.evaluate_host(r'new Uint8Array(__separateBufferClone())[0]=99;new Uint8Array(__originalBuffer())[0]===0')! == 'true'
}

fn test_actual_engine_source_resizable_buffer_slots_empty_presence_and_future_growth() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'const buffer=new ArrayBuffer(2,{maxByteLength:6});new Uint8Array(buffer).set([17,34]);buffer.resize=()=>{throw new Error("author resize")};buffer')!
	assert bridge.serialize(value, false)!.data == [u8(21), 2, 0, 0, 0, 17, 34, 6, 0, 0, 0, 0, 0, 0, 0]
	assert bridge.serialize(value, true)!.data == [u8(76), 66, 83, 67, 1, 0, 21, 2, 17, 34, 6]
	cloned := bridge.clone(value)!
	runtime.define_value_host_function('__nativeResizableClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const buffer=__nativeResizableClone();buffer.resize(4);buffer.resizable&&buffer.maxByteLength===6&&buffer.byteLength===4&&Array.from(new Uint8Array(buffer)).join(",")==="17,34,0,0"}')! == 'true'
	empty := runtime.evaluate_host_value('new ArrayBuffer(0,{maxByteLength:0})')!
	assert bridge.serialize(empty, false)!.data == [u8(21), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	assert bridge.serialize(empty, true)!.data == [u8(76), 66, 83, 67, 1, 0, 21, 0, 0]
}

fn test_actual_engine_source_buffer_clone_rejects_detachment_without_faking_empty_bytes() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for length in [0, 3] {
		value := runtime.evaluate_host_value('{const buffer=new ArrayBuffer(' + length.str() + ');buffer.transfer();buffer}')!
		if _ := bridge.serialize(value, false) { assert false } else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
	}
	mut object := html.StructuredObject.create(.array_buffer)
	object.max_byte_length = u64(9007199254740992)
	if _ := bridge.deserialize(html.structured_serialize(html.structured_object_value(object))!) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
}

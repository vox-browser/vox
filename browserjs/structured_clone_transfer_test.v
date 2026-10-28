module browserjs

import html
import platform
import webidl

fn expose_transferred_value(mut runtime Runtime, name string, value voidptr) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr { return value })!
}

fn transfer_source_view(constructor_name string, auto_length bool) !html.SerializationRecord {
	mut buffer := html.StructuredObject.create(.array_buffer)
	buffer.bytes = [u8(1), 2, 3, 4, 5, 6]
	buffer.max_byte_length = u64(10)
	mut view := html.StructuredObject.create(.array_buffer_view)
	view.viewed_array_buffer = buffer
	view.string_data = constructor_name
	view.byte_offset = 2
	if !auto_length {
		view.byte_length = u32(2)
		if constructor_name != 'DataView' { view.array_length = u32(1) }
	}
	return html.structured_serialize(html.structured_object_value(view))!
}

fn test_native_buffer_transfer_detaches_and_reconstructs_cycles_views_and_aliases_in_target_realm() {
	$if !darwin { return }
	mut sender := Runtime.create()
	mut receiver := Runtime.create()
	defer { sender.close(); receiver.close() }
	send := ArrayBufferTransferBridge.create(sender)!
	receive := ArrayBufferTransferBridge.create(receiver)!
	value := sender.evaluate_host_value(r'
 globalThis.first=new ArrayBuffer(4);new Uint8Array(first).set([1,2,3,4]);
 globalThis.second=new ArrayBuffer(2);new Uint8Array(second).set([8,9]);
 globalThis.unused=new ArrayBuffer(3);
 globalThis.view=new Uint8Array(first,1,2);globalThis.dataView=new DataView(first,2,2);
 globalThis.message={first,again:first,view,dataView,second,map:new Map([[first,view]])};message.self=message;message;
 ')!
	record := send.serialize(value, [sender.evaluate_host_value('second')!, sender.evaluate_host_value('unused')!, sender.evaluate_host_value('first')!])!
	assert record.buffers.len == 3
	assert record.buffers[0].bytes == [u8(8), 9]
	assert record.buffers[1].bytes == [u8(0), 0, 0]
	assert record.buffers[2].bytes == [u8(1), 2, 3, 4]
	assert sender.evaluate_host('first.detached&&second.detached&&unused.detached&&view.byteLength===0')! == 'true'
	actual := receive.deserialize(record)!
	expose_transferred_value(mut receiver, 'received', actual)!
	assert receiver.evaluate_host(r'
 const result=received();result.self===result&&result.first===result.again&&result.first instanceof ArrayBuffer&&result.view instanceof Uint8Array&&result.dataView instanceof DataView&&result.map instanceof Map&&result.view.buffer===result.first&&result.dataView.buffer===result.first&&result.map.get(result.first)===result.view&&Array.from(result.view).join()==="2,3"&&result.dataView.getUint8(0)===3&&Array.from(new Uint8Array(result.second)).join()==="8,9"&&!result.first.detached&&!result.first.resizable;
 ')! == 'true'
}

fn test_native_buffer_transfer_validates_list_before_getters_and_detaches_in_list_order_after_getters() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := ArrayBufferTransferBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.count=0;globalThis.buffer=new ArrayBuffer(2);globalThis.message={get value(){count++;new Uint8Array(buffer)[0]=42;return 7}};message')!
	buffer := runtime.evaluate_host_value('buffer')!
	if _ := bridge.serialize(value, [buffer, buffer]) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
	assert runtime.evaluate_host('count===0&&!buffer.detached')! == 'true'
	mut invalid := ['null', '17', 'new Uint8Array(2)', '({})']
	// The C API realm need not expose the shared-memory constructor.
	if runtime.evaluate_host('typeof SharedArrayBuffer === "function"')! == 'true' {
		invalid << 'new SharedArrayBuffer(2)'
	}
	for expression in invalid {
		if _ := bridge.serialize(value, [runtime.evaluate_host_value(expression)!]) { assert false } else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		assert runtime.evaluate_host('count===0&&!buffer.detached')! == 'true'
	}
	late := runtime.evaluate_host_value('globalThis.late=new ArrayBuffer(1);late.transfer();late')!
	if _ := bridge.serialize(value, [buffer, late]) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
	assert runtime.evaluate_host('count===1&&buffer.detached&&late.detached')! == 'true'
}

fn test_native_buffer_transfer_preserves_getter_exceptions_and_copies_final_buffer_bytes() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := ArrayBufferTransferBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.buffer=new ArrayBuffer(2);globalThis.failure={marker:42};({get value(){throw failure}})')!
	buffer := runtime.evaluate_host_value('buffer')!
	if _ := bridge.serialize(value, [buffer]) { assert false } else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException {
			expose_transferred_value(mut runtime, 'caughtTransferError', err.value)!
			assert runtime.evaluate_host('caughtTransferError()===failure&&!buffer.detached')! == 'true'
		}
	}
	message := runtime.evaluate_host_value(r'({buffer,get changed(){new Uint8Array(buffer).set([41,255]);return true}})')!
	record := bridge.serialize(message, [buffer])!
	assert record.buffers[0].bytes == [u8(41), 255]
	actual := bridge.deserialize(record)!
	expose_transferred_value(mut runtime, 'changedTransfer', actual)!
	assert runtime.evaluate_host('changedTransfer().changed&&Array.from(new Uint8Array(changedTransfer().buffer)).join()==="41,255"&&buffer.detached')! == 'true'
}

fn test_native_buffer_transfer_keeps_wasm_detach_key_exception_and_earlier_detachments() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := ArrayBufferTransferBridge.create(runtime)!
	value := runtime.evaluate_host_value('globalThis.buffer=new ArrayBuffer(1);globalThis.memory=new WebAssembly.Memory({initial:1});({buffer,wasm:memory.buffer})')!
	if _ := bridge.serialize(value, [runtime.evaluate_host_value('buffer')!, runtime.evaluate_host_value('memory.buffer')!]) { assert false } else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException {
			expose_transferred_value(mut runtime, 'wasmTransferError', err.value)!
			assert runtime.evaluate_host('wasmTransferError() instanceof TypeError&&buffer.detached&&!memory.buffer.detached&&memory.buffer.byteLength===65536')! == 'true'
		}
	}
}

fn test_native_buffer_transfer_keeps_resizable_capacities_and_source_owned_view_length_slots() {
	$if !darwin { return }
	for auto_length in [false, true] {
		mut runtime := Runtime.create()
		defer { runtime.close() }
		bridge := ArrayBufferTransferBridge.create(runtime)!
		view := bridge.clone.deserialize(transfer_source_view('Uint16Array', auto_length)!)!
		expose_transferred_value(mut runtime, 'sourceTransferView', view)!
		buffer := runtime.evaluate_host_value('sourceTransferView().buffer')!
		message := runtime.evaluate_host_value('({view:sourceTransferView(),get grow(){sourceTransferView().buffer.resize(8);return true}})')!
		record := bridge.serialize(message, [buffer])!
		assert record.buffers[0].max_byte_length? == 10
		assert record.buffers[0].bytes == [u8(1), 2, 3, 4, 5, 6, 0, 0]
		actual := bridge.deserialize(record)!
		expose_transferred_value(mut runtime, 'resizableTransferred', actual)!
		assert runtime.evaluate_host('resizableTransferred().view.buffer.resizable&&resizableTransferred().view.buffer.maxByteLength===10&&resizableTransferred().view.buffer.byteLength===8&&resizableTransferred().grow')! == 'true'
		assert runtime.evaluate_host('resizableTransferred().view.byteLength')! == if auto_length { '6' } else { '2' }
		runtime.evaluate_host('resizableTransferred().view.buffer.resize(10)')!
		assert runtime.evaluate_host('resizableTransferred().view.byteLength')! == if auto_length { '8' } else { '2' }
	}
	// Serialization checks the earlier witness; receiving checks final bounds.
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := ArrayBufferTransferBridge.create(runtime)!
	view := bridge.clone.deserialize(transfer_source_view('DataView', false)!)!
	expose_transferred_value(mut runtime, 'shrinkingTransferView', view)!
	value := runtime.evaluate_host_value('({view:shrinkingTransferView(),get shrink(){shrinkingTransferView().buffer.resize(1);return true}})')!
	record := bridge.serialize(value, [runtime.evaluate_host_value('shrinkingTransferView().buffer')!])!
	assert record.buffers[0].bytes == [u8(1)]
	if _ := bridge.deserialize(record) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
}

fn test_native_buffer_transfer_uses_captured_intrinsics_and_retains_payload_across_scratch_resets() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut caller := platform.begin_thread_scratch('buffer transfer caller')
	bridge := ArrayBufferTransferBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.originalArrayBuffer=ArrayBuffer;globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);globalThis.message={buffer};ArrayBuffer.prototype.transfer=()=>{throw new Error("author transfer")};globalThis.ArrayBuffer=class Fake {};Reflect.apply=()=>{throw new Error("author apply")};message')!
	record := bridge.serialize(value, [runtime.evaluate_host_value('buffer')!])!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('buffer transfer delivery')
	actual := bridge.deserialize(record)!
	expose_transferred_value(mut runtime, 'retainedTransfer', actual)!
	delivery.finish()
	assert runtime.evaluate_host('buffer.detached&&retainedTransfer().buffer instanceof originalArrayBuffer&&retainedTransfer().buffer.byteLength===3&&new Uint8Array(retainedTransfer().buffer)[2]===255')! == 'true'
	assert record.buffers[0].bytes == [u8(0), 128, 255]
	// Empty transfer lists retain the normal serialization bytes.
	plain := runtime.evaluate_host_value('({answer:42})')!
	assert bridge.serialize(plain, [])!.serialized.data == bridge.clone.serialize(plain, false)!.data
	bad := NativeArrayBufferTransferRecord{
		serialized: html.SerializationRecord{data: [u8(18), 0, 0, 0, 0]}
		buffers: [TransferredArrayBuffer{bytes: [u8(1), 2], max_byte_length: 1}]
	}
	if _ := bridge.deserialize(bad) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
}

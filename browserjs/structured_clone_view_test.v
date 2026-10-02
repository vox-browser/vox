module browserjs

import webidl

fn test_actual_engine_source_fixed_data_view_slots_and_buffer_reference_memory() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	view := runtime.evaluate_host_value(r'globalThis.__nativeDataViewCtor=DataView;const buffer=new ArrayBuffer(4);new Uint8Array(buffer).set([1,2,3,4]);globalThis.__viewedBuffer=buffer;new DataView(buffer,1,2)')!
	assert bridge.serialize(view, false)!.data == [u8(23), 22, 4, 0, 0, 0, 1, 2, 3, 4,
		1, 8, 0, 0, 0, 68, 97, 116, 97, 86, 105, 101, 119,
		0, 2, 0, 0, 0, 1, 0, 0, 0]
	runtime.define_value_host_function('__sourceDataView', fn [view] (_ voidptr, _ []voidptr) !voidptr { return view })!
	value := runtime.evaluate_host_value(r'({view:__sourceDataView(),again:__sourceDataView(),buffer:__viewedBuffer,sibling:new Uint8Array(__viewedBuffer,2,1)})')!
	for for_storage in [false, true] {
		cloned := bridge.deserialize(bridge.serialize(value, for_storage)!)!
		binding := '__nativeViewClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + binding + r'();result.view===result.again&&result.view.buffer===result.buffer&&result.sibling.buffer===result.buffer&&result.view instanceof __nativeDataViewCtor&&result.view.byteOffset===1&&result.view.byteLength===2&&result.view.getUint8(0)===2&&result.sibling.length===1&&result.sibling[0]===3}')! == 'true'
	}
}

fn test_actual_engine_source_typed_array_constructors_slots_and_captured_intrinsics() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	runtime.evaluate_host(r'globalThis.__nativeTypedConstructors=[Int8Array,Uint8Array,Uint8ClampedArray,Int16Array,Uint16Array,Int32Array,Uint32Array,Float16Array,Float32Array,Float64Array,BigInt64Array,BigUint64Array];globalThis.__authorSlotGets=0')!
	for index in 0 .. 12 {
		value := runtime.evaluate_host_value('{const C=__nativeTypedConstructors[' + index.str() + r'],value=new C(new ArrayBuffer(32),8,2);Object.defineProperty(value,"length",{get(){++__authorSlotGets;throw new Error("author length")}});Object.defineProperty(value,"buffer",{get(){++__authorSlotGets;throw new Error("author buffer")}});Object.defineProperty(value,Symbol.toStringTag,{value:"Forged"});value.custom=99;value}')!
		cloned := bridge.clone(value)!
		binding := '__actualTypedClone' + index.str()
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const value=' + binding + '(),C=__nativeTypedConstructors[' + index.str() + r'];Object.getPrototypeOf(value)===C.prototype&&value.byteOffset===8&&value.length===2&&value.byteLength===2*C.BYTES_PER_ELEMENT&&!Object.hasOwn(value,"custom")&&__authorSlotGets===0}')! == 'true'
	}
}

fn test_actual_engine_source_view_witness_rejects_detachment_and_unknown_auto_slots() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for source in [r'{const buffer=new ArrayBuffer(4),view=new Uint8Array(buffer);buffer.transfer();view}',
		r'{const buffer=new ArrayBuffer(4),view=new DataView(buffer);buffer.transfer();view}',
		r'new Uint8Array(new ArrayBuffer(4,{maxByteLength:8}))',
		r'{const buffer=new ArrayBuffer(4,{maxByteLength:8}),view=new DataView(buffer,2,2);buffer.resize(1);view}'] {
		value := runtime.evaluate_host_value(source)!
		if _ := bridge.serialize(value, false) { assert false } else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
	}
}

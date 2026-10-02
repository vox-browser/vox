module browserjs

import html
import math
import webidl

fn test_actual_engine_source_date_clone_reads_internal_value_and_keeps_aliases() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__nativeDateCtor=Date;globalThis.__nativeDateTime=Date.prototype.getTime;globalThis.__dateConversionCalls=0;const date=new Date(1);date.getTime=date.valueOf=function(){++__dateConversionCalls;throw new Error("author method")};date[Symbol.toPrimitive]=function(){++__dateConversionCalls;throw new Error("author conversion")};date.custom=99;({date,again:date,invalid:new Date(NaN)})')!
	for for_storage in [false, true] {
		cloned := bridge.deserialize(bridge.serialize(value, for_storage)!)!
		binding := '__nativeDateClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + binding + r'();result.date===result.again&&result.date instanceof __nativeDateCtor&&__nativeDateTime.call(result.date)===1&&Number.isNaN(__nativeDateTime.call(result.invalid))&&!Object.prototype.hasOwnProperty.call(result.date,"custom")&&__dateConversionCalls===0}')! == 'true'
	}
	date := runtime.evaluate_host_value('new Date(1)')!
	assert bridge.serialize(date, false)!.data == [u8(11), 0, 0, 0, 0, 0, 0, 240, 63]
	assert bridge.serialize(date, true)!.data == [u8(76), 66, 83, 67, 1, 0, 11, 0, 0, 0, 0, 0, 0, 240, 63]
}

fn test_native_date_deserialization_rejects_values_constructor_would_timeclip() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for value in [0.5, -0.5, -0.0, 8640000000000001.0, math.inf(1), math.inf(-1)] {
		mut date := html.StructuredObject.create(.date)
		date.number_data = value
		for for_storage in [false, true] {
			record := if for_storage { html.structured_serialize_for_storage(html.structured_object_value(date))! } else { html.structured_serialize(html.structured_object_value(date))! }
			if _ := bridge.deserialize(record) { assert false } else {
				assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
			}
		}
	}
}

fn test_actual_engine_source_date_clone_uses_captured_target_intrinsic() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__sourceDateCtor=Date;globalThis.__sourceDateTime=Date.prototype.getTime;const value=new Date(-8640000000000000);Date.prototype.getTime=()=>{throw new Error("overridden")};globalThis.Date=class FakeDate {};value')!
	cloned := bridge.clone(value)!
	runtime.define_value_host_function('__capturedDateClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const value=__capturedDateClone();Object.getPrototypeOf(value)===__sourceDateCtor.prototype&&__sourceDateTime.call(value)===-8640000000000000}')! == 'true'
}

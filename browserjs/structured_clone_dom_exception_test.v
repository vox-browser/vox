module browserjs

import html
import webidl

fn test_native_source_dom_exception_clone_uses_actual_record_and_captured_platform_factory() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__nativeDOMException=DOMException;globalThis.__exceptionCloneGets=0;const value=new DOMException(String.fromCharCode(0xd800,0),"AbortError");Object.defineProperty(value,"message",{get(){++__exceptionCloneGets;throw new Error("author message")}});Object.defineProperty(value,"name",{get(){++__exceptionCloneGets;throw new Error("author name")}});value.custom=99;globalThis.DOMException=class FakeDOMException{};({value,again:value})')!
	for for_storage in [false, true] {
		cloned := bridge.deserialize(bridge.serialize(value, for_storage)!)!
		binding := '__nativeExceptionClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + binding + r'();result.value===result.again&&Object.getPrototypeOf(result.value)===__nativeDOMException.prototype&&result.value.name==="AbortError"&&result.value.code===20&&result.value.message===String.fromCharCode(0xd800,0)&&!Object.hasOwn(result.value,"custom")&&__exceptionCloneGets===0}')! == 'true'
	}
	actual := runtime.evaluate_host_value('new __nativeDOMException("stop","AbortError")')!
	record := bridge.serialize(actual, false)!
	assert record.data[..3] == [u8(24), 56, 2]
}

fn test_native_source_dom_exception_codec_checks_target_exposure_before_platform_creation() {
	$if !darwin { return }
	mut source_runtime := Runtime.create()
	defer { source_runtime.close() }
	source_runtime.install_dom_exception_binding()!
	source_bridge := StructuredCloneBridge.create(source_runtime)!
	actual := source_runtime.evaluate_host_value('new DOMException("source","NetworkError")')!
	record := source_bridge.serialize(actual, false)!
	mut target_runtime := Runtime.create()
	defer { target_runtime.close() }
	target_bridge := StructuredCloneBridge.create(target_runtime)!
	if _ := target_bridge.deserialize(record) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
	target_runtime.install_dom_exception_binding()!
	cloned := target_bridge.deserialize(record)!
	assert target_runtime.native_dom_exception(cloned)!.dom_exception_?.name() == 'NetworkError'
	assert target_runtime.native_dom_exception(cloned)!.dom_exception_?.message() == 'source'
	assert cloned != actual
	if _ := target_bridge.deserialize(html.SerializationRecord{data: [u8(24), 56, 2, 1]}) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
}

fn test_native_source_primary_derived_exception_is_never_cloned_as_base_dom_exception() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_quota_exceeded_error_binding()!
	bridge := StructuredCloneBridge.create(runtime)!
	actual := runtime.evaluate_host_value('new QuotaExceededError("quota",{quota:4,requested:6})')!
	assert runtime.native_dom_exception(actual)!.dom_exception_?.name() == 'QuotaExceededError'
	record := bridge.serialize(actual, false)!
	assert record.data[..3] == [u8(24), 57, 2]
	cloned := bridge.deserialize(record)!
	runtime.define_value_host_function('__clonedPrimaryQuota', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host('__clonedPrimaryQuota() instanceof QuotaExceededError && __clonedPrimaryQuota().quota===4 && __clonedPrimaryQuota().requested===6')! == 'true'
}

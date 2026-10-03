module browserjs

import html
import libjs
import math
import webidl

fn test_native_quota_clone_retains_primary_wrapper_and_source_slots_without_author_gets() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_quota_exceeded_error_binding()!
	bridge := StructuredCloneBridge.create(runtime)!
	actual := runtime.evaluate_host_value(r'globalThis.__sourceQuotaConstructor=QuotaExceededError;globalThis.__quotaCloneReads=0;const value=new QuotaExceededError(String.fromCharCode(0xd800,0),{quota:0,requested:2.5});for(const key of ["name","message","quota","requested"])Object.defineProperty(value,key,{get(){++__quotaCloneReads;throw "author field"}});value.extra=9;globalThis.QuotaExceededError=class FakeQuotaExceededError{};globalThis.DOMException=class FakeDOMException{};({value,again:value})')!
	for for_storage in [false, true] {
		record := bridge.serialize(actual, for_storage)!
		cloned := bridge.deserialize(record)!
		name := '__nativePrimaryQuotaClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(name, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + name + r'();result.value===result.again&&Object.getPrototypeOf(result.value)===__sourceQuotaConstructor.prototype&&result.value instanceof __sourceQuotaConstructor&&result.value.name==="QuotaExceededError"&&result.value.message===String.fromCharCode(0xd800,0)&&result.value.code===22&&result.value.quota===0&&result.value.requested===2.5&&!Object.hasOwn(result.value,"extra")&&__quotaCloneReads===0}')! == 'true'
	}
}

fn test_native_quota_clone_checks_actual_primary_target_exposure_and_nullable_fields() {
	$if !darwin { return }
	mut source := Runtime.create()
	defer { source.close() }
	source.install_quota_exceeded_error_binding()!
	source_bridge := StructuredCloneBridge.create(source)!
	actual := source.evaluate_host_value('new QuotaExceededError("empty")')!
	record := source_bridge.serialize(actual, false)!
	assert record.data[..3] == [u8(24), 57, 2]
	mut target := Runtime.create()
	defer { target.close() }
	target.install_dom_exception_binding()!
	target_bridge := StructuredCloneBridge.create(target)!
	if _ := target_bridge.deserialize(record) { assert false } else { assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError' }
	target.install_quota_exceeded_error_binding()!
	cloned := target_bridge.deserialize(record)!
	target.define_value_host_function('__crossOwnerQuotaClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert target.evaluate_host('__crossOwnerQuotaClone() instanceof QuotaExceededError&&__crossOwnerQuotaClone() instanceof DOMException&&__crossOwnerQuotaClone().message==="empty"&&__crossOwnerQuotaClone().quota===null&&__crossOwnerQuotaClone().requested===null')! == 'true'
	assert voidptr(target.native_dom_exception(cloned)!.dom_exception_?) != voidptr(source.native_dom_exception(actual)!.dom_exception_?)
	if _ := target_bridge.deserialize(html.SerializationRecord{data: record.data[..record.data.len - 1]}) { assert false } else { assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError' }
}

fn test_native_quota_source_deserialization_bypasses_author_constructor_validation() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_quota_exceeded_error_binding()!
	bridge := StructuredCloneBridge.create(runtime)!
	mut exception := webidl.QuotaExceededError{}
	exception.deserialization_steps_utf16(webidl.SerializedQuotaExceededErrorUTF16{name: libjs.utf16_string('QuotaExceededError'), message: libjs.utf16_string_from_code_units([u16(0xdc00)]), quota: -2, requested: math.inf(1)})
	object := html.StructuredObject.create_quota_exceeded_error(&exception)
	record := html.structured_serialize(html.structured_object_value(object))!
	cloned := bridge.deserialize(record)!
	runtime.define_value_host_function('__rawQuotaSlots', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'__rawQuotaSlots().quota===-2&&__rawQuotaSlots().requested===Infinity&&__rawQuotaSlots().message===String.fromCharCode(0xdc00)')! == 'true'
	assert bridge.serialize(cloned, false)!.data == record.data
	// The same double values passed through the public IDL constructor still
	// undergo its finite-double/range checks.
	assert runtime.evaluate_host(r'{let finite=false,range=false;try{new QuotaExceededError("",{requested:Infinity})}catch(error){finite=error instanceof TypeError}try{new QuotaExceededError("",{quota:-2})}catch(error){range=error instanceof RangeError}finite&&range}')! == 'true'
}
